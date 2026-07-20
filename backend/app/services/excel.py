import re
import pandas as pd
from io import BytesIO
from datetime import date, timedelta
from typing import List, Dict, Any
from uuid import UUID, uuid4
from app.core.supabase import supabase_client

def clean_phone_number(phone_str: Any) -> str:
    """
    Cleans and normalizes phone numbers to DRC (+243) format.
    E.g. 0812345678 -> +243812345678
         812345678 -> +243812345678
         +243 812 345 678 -> +243812345678
    """
    if not phone_str:
        raise ValueError("Le numéro de téléphone est obligatoire.")
        
    phone = str(phone_str).strip()
    # Remove all non-digits except +
    phone = re.sub(r"[^\d+]", "", phone)
    
    if phone.startswith("+243"):
        return phone
    if phone.startswith("00243"):
        return "+" + phone[2:]
    if phone.startswith("243") and len(phone) == 12:
        return "+" + phone
        
    # Check if it starts with 0 and has 10 digits (DRC format: 0812345678)
    if phone.startswith("0") and len(phone) == 10:
        return "+243" + phone[1:]
        
    # Check if it is a 9 digit number (812345678)
    if len(phone) == 9 and phone[0] in ["8", "9"]:
        return "+243" + phone
        
    # Fallback to appending +243 if it doesn't have it
    if not phone.startswith("+"):
        # If it has 9 or more digits, assume it just needs prefix
        if len(phone) >= 9:
            return "+243" + phone[-9:]
            
    raise ValueError(f"Format de téléphone invalide: {phone_str}")

def parse_roster_file(file_bytes: bytes, file_name: str) -> List[Dict[str, Any]]:
    """
    Parses XLSX or CSV file and extracts parents, students, classes and amounts.
    """
    # Load DataFrame based on extension
    if file_name.endswith(".csv"):
        df = pd.read_csv(BytesIO(file_bytes))
    else:
        df = pd.read_excel(BytesIO(file_bytes))
        
    # Standardize column mappings (English/French)
    header_mappings = {
        "parent_name": ["parent name", "nom parent", "nom du parent", "parent_name", "nom_parent"],
        "parent_phone": ["parent phone", "telephone parent", "téléphone parent", "parent_phone", "telephone_parent", "téléphone_parent"],
        "student_name": ["student name", "nom eleve", "nom élève", "nom de l'élève", "student_name", "nom_eleve", "nom_élève"],
        "classroom": ["class", "classe", "classroom", "class_room", "salle"],
        "amount_due": ["amount due", "montant du", "montant dû", "amount_due", "montant_du", "montant_dû"]
    }
    
    col_mapping = {}
    for standard_key, aliases in header_mappings.items():
        matched = False
        for col in df.columns:
            if str(col).strip().lower() in aliases:
                col_mapping[col] = standard_key
                matched = True
                break
        if not matched:
            raise ValueError(f"Colonne manquante requise pour '{standard_key}' (exemples acceptés: {', '.join(aliases)})")
            
    # Rename matching columns and drop unused ones
    df = df.rename(columns=col_mapping)
    df = df[[col for col in col_mapping.values()]]
    
    # Drop rows where critical info is missing
    df = df.dropna(subset=["parent_name", "parent_phone", "student_name", "amount_due"])
    
    records = []
    for _, row in df.iterrows():
        try:
            cleaned_phone = clean_phone_number(row["parent_phone"])
            records.append({
                "parent_name": str(row["parent_name"]).strip(),
                "parent_phone": cleaned_phone,
                "student_name": str(row["student_name"]).strip(),
                "classroom": str(row["classroom"]).strip() if pd.notna(row["classroom"]) else "Non spécifié",
                "amount_due": float(row["amount_due"])
            })
        except Exception as e:
            # Skip invalid phone/amount formats or raise error based on requirements
            continue
            
    return records

def process_roster_ingestion(records: List[Dict[str, Any]], school_id: str) -> Dict[str, Any]:
    """
    Inserts or merges profiles, student records, contracts, and splits amounts into automated installments.
    """
    success_count = 0
    error_count = 0
    errors = []
    
    # Track student IDs currently in database for this school to find removed students
    db_student_ids = []
    contract_ids = []
    try:
        contracts_response = supabase_client.table("school_contracts").select("id").eq("school_id", school_id).execute()
        contract_ids = [c["id"] for c in contracts_response.data] if contracts_response.data else []
        
        students_response = supabase_client.table("students").select("id").eq("school_id", school_id).execute()
        db_student_ids = [s["id"] for s in students_response.data] if students_response.data else []
    except Exception as e:
        print(f"Error checking existing student roster: {e}")
        
    processed_student_ids = []
    
    for rec in records:
        try:
            parent_name = rec["parent_name"]
            phone = rec["parent_phone"]
            student_name = rec["student_name"]
            classroom = rec["classroom"]
            amount_due = rec["amount_due"]
            
            # Split parent name into first and last name if possible
            parts = parent_name.split(maxsplit=1)
            parent_first = parts[0]
            parent_last = parts[1] if len(parts) > 1 else ""
            
            # Check if profile exists by phone_number
            profile_response = supabase_client.table("profiles").select("id").eq("phone_number", phone).execute()
            
            parent_id = None
            if profile_response.data:
                parent_id = profile_response.data[0]["id"]
            else:
                # Generate a placeholder parent ID starting with FB-
                # This will be replaced with the real Firebase Auth UID when the parent logs in/registers.
                parent_id = f"FB-{uuid4().hex[:14].upper()}"
                
                # Insert profile in public.profiles table
                supabase_client.table("profiles").insert({
                    "id": parent_id,
                    "phone_number": phone,
                    "first_name": parent_first,
                    "last_name": parent_last,
                    "role": "client",
                    "sub_role": "parent"
                }).execute()
                
            # Create or Update Student record
            student_parts = student_name.split(maxsplit=1)
            stud_first = student_parts[0]
            stud_last = student_parts[1] if len(student_parts) > 1 else ""
            
            # Check if student already exists under this parent and school
            student_check = supabase_client.table("students") \
                .select("id") \
                .eq("school_id", school_id) \
                .eq("parent_id", parent_id) \
                .eq("first_name", stud_first) \
                .eq("last_name", stud_last) \
                .execute()
                
            student_id = None
            if student_check.data:
                student_id = student_check.data[0]["id"]
                # Update classroom
                supabase_client.table("students").update({
                    "classroom": classroom
                }).eq("id", student_id).execute()
            else:
                # Insert Student
                student_res = supabase_client.table("students").insert({
                    "school_id": school_id,
                    "parent_id": parent_id,
                    "first_name": stud_first,
                    "last_name": stud_last,
                    "classroom": classroom,
                    "academic_score": 15.0, # Default mock starting average grade (out of 20)
                    "attendance_rate": 95.0 # Default starting attendance rate
                }).execute()
                student_id = student_res.data[0]["id"]
            
            # Check if school contract installments already exist for this student
            installments_check = supabase_client.table("school_installments") \
                .select("id, contract_id, status, due_date") \
                .eq("student_id", student_id) \
                .execute()
                
            if installments_check.data:
                contract_id = installments_check.data[0]["contract_id"]
                # Update existing contract total tuition
                supabase_client.table("school_contracts").update({
                    "total_tuition_due": amount_due
                }).eq("id", contract_id).execute()
                
                # If all installments are unpaid (PENDING), recalculate splits
                all_pending = all(inst["status"] == "PENDING" for inst in installments_check.data)
                if all_pending:
                    # Sort by due_date to apply 30%, 30%, 40% in order
                    inst_list = installments_check.data
                    inst_list.sort(key=lambda x: x["due_date"])
                    
                    ratios = [0.30, 0.30, 0.40]
                    for i, inst_item in enumerate(inst_list):
                        if i < len(ratios):
                            supabase_client.table("school_installments").update({
                                "amount_due": round(amount_due * ratios[i], 2)
                            }).eq("id", inst_item["id"]).execute()
            else:
                # Create new school contract
                contract_res = supabase_client.table("school_contracts").insert({
                    "school_id": school_id,
                    "parent_id": parent_id,
                    "total_tuition_due": amount_due,
                    "status": "active"
                }).execute()
                
                contract_id = contract_res.data[0]["id"]
                
                # Generate 3 automated installments:
                # Tranche 1: 30%, due in 30 days
                # Tranche 2: 30%, due in 60 days
                # Tranche 3: 40%, due in 90 days
                installments_to_insert = [
                    {
                        "contract_id": contract_id,
                        "student_id": student_id,
                        "amount_due": round(amount_due * 0.30, 2),
                        "amount_paid": 0.0,
                        "due_date": (date.today() + timedelta(days=30)).isoformat(),
                        "status": "PENDING"
                    },
                    {
                        "contract_id": contract_id,
                        "student_id": student_id,
                        "amount_due": round(amount_due * 0.30, 2),
                        "amount_paid": 0.0,
                        "due_date": (date.today() + timedelta(days=60)).isoformat(),
                        "status": "PENDING"
                    },
                    {
                        "contract_id": contract_id,
                        "student_id": student_id,
                        "amount_due": round(amount_due * 0.40, 2),
                        "amount_paid": 0.0,
                        "due_date": (date.today() + timedelta(days=90)).isoformat(),
                        "status": "PENDING"
                    }
                ]
                
                supabase_client.table("school_installments").insert(installments_to_insert).execute()
                
            success_count += 1
            processed_student_ids.append(student_id)
            
        except Exception as e:
            error_count += 1
            errors.append(f"Échec pour la ligne {rec.get('student_name', 'Inconnu')}: {str(e)}")
            
    # Remove students who are no longer in the uploaded excel roster
    removed_count = 0
    try:
        students_to_remove = [sid for sid in db_student_ids if sid not in processed_student_ids]
        for sid in students_to_remove:
            supabase_client.table("students").delete().eq("id", sid).execute()
            removed_count += 1
            
        # Clean up orphan contracts that no longer have installments
        if contract_ids:
            for cid in contract_ids:
                inst_check = supabase_client.table("school_installments").select("id").eq("contract_id", cid).execute()
                if not inst_check.data:
                    supabase_client.table("school_contracts").delete().eq("id", cid).execute()

        # Clean up placeholder parent profiles that no longer have any children in the database
        parents_res = supabase_client.table("profiles") \
            .select("id") \
            .eq("role", "client") \
            .eq("sub_role", "parent") \
            .execute()
            
        if parents_res.data:
            for parent in parents_res.data:
                pid = parent["id"]
                is_placeholder = pid.startswith("FB-") or len(pid) == 36
                if is_placeholder:
                    child_check = supabase_client.table("students").select("id").eq("parent_id", pid).execute()
                    if not child_check.data:
                        supabase_client.table("profiles").delete().eq("id", pid).execute()
    except Exception as clean_err:
        print(f"Error cleaning up removed students/parents: {clean_err}")

    return {
        "success_count": success_count,
        "error_count": error_count,
        "removed_count": removed_count,
        "errors": errors
    }
