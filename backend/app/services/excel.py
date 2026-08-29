import re
import pandas as pd
from io import BytesIO
from datetime import date, timedelta
from typing import List, Dict, Any
from uuid import UUID, uuid4
from app.core.supabase import supabase_client

def clean_phone_number(phone_str: Any) -> str:
    """
    Cleans and normalizes phone numbers.
    If a number starts with '+', existing international prefix is preserved (e.g. +1..., +33...).
    If no '+' is present, normalizes to DRC (+243) format (e.g. 0812345678 -> +243812345678).
    """
    if not phone_str:
        raise ValueError("Le numéro de téléphone est obligatoire.")
        
    phone = str(phone_str).strip()
    # Remove all spaces, dashes, or non-digits except leading +
    phone = re.sub(r"[^\d+]", "", phone)
    
    # 1. If it already starts with '+', keep international prefix as is
    if phone.startswith("+"):
        if len(phone) >= 8:
            return phone
        raise ValueError(f"Numéro international trop court: {phone_str}")

    # 2. If it starts with '00', convert to '+'
    if phone.startswith("00"):
        return "+" + phone[2:]

    # 3. If starting with 243 without '+', prepend '+'
    if phone.startswith("243") and len(phone) == 12:
        return "+" + phone

    # 4. DRC local formats: starts with '0' (e.g. 0812345678 -> +243812345678)
    if phone.startswith("0") and len(phone) == 10:
        return "+243" + phone[1:]

    # 5. 9-digit DRC numbers (e.g. 812345678 -> +243812345678)
    if len(phone) == 9 and phone[0] in ["8", "9"]:
        return "+243" + phone

    # 6. Fallback if no '+' prefix: default to adding +243
    if len(phone) >= 8:
        return "+243" + phone

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
    High-performance bulk ingestion of students, parents, contracts, and installments.
    Pre-fetches existing records in batch and executes bulk upserts/inserts to minimize roundtrips.
    """
    success_count = 0
    error_count = 0
    errors = []
    
    # 1. Pre-fetch existing data in batch
    existing_profiles = {}
    try:
        prof_res = supabase_client.table("profiles").select("id, phone_number").execute()
        if prof_res.data:
            existing_profiles = {p["phone_number"]: p["id"] for p in prof_res.data if p.get("phone_number")}
    except Exception as e:
        print(f"Warning: Could not prefetch profiles: {e}")

    existing_students = {}
    db_student_ids = []
    try:
        stud_res = supabase_client.table("students").select("id, parent_id, first_name, last_name, classroom").eq("school_id", school_id).execute()
        if stud_res.data:
            for s in stud_res.data:
                db_student_ids.append(s["id"])
                key = (s.get("parent_id"), (s.get("first_name") or "").strip().lower(), (s.get("last_name") or "").strip().lower())
                existing_students[key] = s
    except Exception as e:
        print(f"Warning: Could not prefetch students: {e}")

    existing_contracts = {}
    contract_ids = []
    try:
        cont_res = supabase_client.table("school_contracts").select("id, parent_id, total_tuition_due").eq("school_id", school_id).execute()
        if cont_res.data:
            for c in cont_res.data:
                contract_ids.append(c["id"])
                existing_contracts[c["parent_id"]] = c
    except Exception as e:
        print(f"Warning: Could not prefetch contracts: {e}")

    existing_installments_by_student = {}
    if contract_ids:
        try:
            inst_res = supabase_client.table("school_installments").select("id, contract_id, student_id, amount_due, amount_paid, status, due_date").in_("contract_id", contract_ids).execute()
            if inst_res.data:
                for inst in inst_res.data:
                    sid = inst.get("student_id")
                    if sid not in existing_installments_by_student:
                        existing_installments_by_student[sid] = []
                    existing_installments_by_student[sid].append(inst)
        except Exception as e:
            print(f"Warning: Could not prefetch installments: {e}")

    # 2. Phase 1: Identify and create missing parent profiles in bulk
    new_profiles = []
    seen_phones = set()
    for rec in records:
        phone = rec.get("parent_phone")
        if phone and phone not in existing_profiles and phone not in seen_phones:
            parent_name = rec.get("parent_name", "")
            parts = parent_name.split(maxsplit=1)
            p_first = parts[0] if parts else "Parent"
            p_last = parts[1] if len(parts) > 1 else ""
            placeholder_id = f"FB-{uuid4().hex[:14].upper()}"
            existing_profiles[phone] = placeholder_id
            seen_phones.add(phone)
            new_profiles.append({
                "id": placeholder_id,
                "phone_number": phone,
                "first_name": p_first,
                "last_name": p_last,
                "role": "client",
                "sub_role": "parent"
            })

    if new_profiles:
        try:
            supabase_client.table("profiles").insert(new_profiles).execute()
        except Exception as p_err:
            print(f"Error bulk inserting profiles: {p_err}")
            # Fallback to individual inserts if needed
            for p in new_profiles:
                try:
                    supabase_client.table("profiles").insert(p).execute()
                except Exception:
                    pass

    # 3. Phase 2: Process students, contracts, and installments in batch
    students_to_insert = []
    contracts_to_insert = []
    installments_to_insert = []
    processed_student_ids = []

    for rec in records:
        try:
            phone = rec["parent_phone"]
            parent_id = existing_profiles.get(phone)
            if not parent_id:
                raise ValueError(f"Profil parent introuvable pour le numéro {phone}")

            student_name = rec["student_name"]
            classroom = rec["classroom"]
            amount_due = rec["amount_due"]

            student_parts = student_name.split(maxsplit=1)
            stud_first = student_parts[0].strip()
            stud_last = student_parts[1].strip() if len(student_parts) > 1 else ""

            stud_key = (parent_id, stud_first.lower(), stud_last.lower())
            existing_stud = existing_students.get(stud_key)

            if existing_stud:
                student_id = existing_stud["id"]
                # Update classroom if changed
                if existing_stud.get("classroom") != classroom:
                    try:
                        supabase_client.table("students").update({"classroom": classroom}).eq("id", student_id).execute()
                    except Exception:
                        pass
                
                # Check existing installments
                existing_insts = existing_installments_by_student.get(student_id, [])
                if existing_insts:
                    contract_id = existing_insts[0]["contract_id"]
                    # Update contract tuition
                    try:
                        supabase_client.table("school_contracts").update({"total_tuition_due": amount_due}).eq("id", contract_id).execute()
                    except Exception:
                        pass
                    
                    # If all pending, recalculate
                    if all(inst["status"] == "PENDING" for inst in existing_insts):
                        existing_insts.sort(key=lambda x: x.get("due_date", ""))
                        ratios = [0.30, 0.30, 0.40]
                        for i, inst_item in enumerate(existing_insts):
                            if i < len(ratios):
                                try:
                                    supabase_client.table("school_installments").update({
                                        "amount_due": round(amount_due * ratios[i], 2)
                                    }).eq("id", inst_item["id"]).execute()
                                except Exception:
                                    pass
                else:
                    # Existing student but missing contract/installments
                    new_contract_id = str(uuid4())
                    contracts_to_insert.append({
                        "id": new_contract_id,
                        "school_id": school_id,
                        "parent_id": parent_id,
                        "total_tuition_due": amount_due,
                        "status": "active"
                    })
                    installments_to_insert.extend([
                        {
                            "contract_id": new_contract_id,
                            "student_id": student_id,
                            "amount_due": round(amount_due * 0.30, 2),
                            "amount_paid": 0.0,
                            "due_date": (date.today() + timedelta(days=30)).isoformat(),
                            "status": "PENDING"
                        },
                        {
                            "contract_id": new_contract_id,
                            "student_id": student_id,
                            "amount_due": round(amount_due * 0.30, 2),
                            "amount_paid": 0.0,
                            "due_date": (date.today() + timedelta(days=60)).isoformat(),
                            "status": "PENDING"
                        },
                        {
                            "contract_id": new_contract_id,
                            "student_id": student_id,
                            "amount_due": round(amount_due * 0.40, 2),
                            "amount_paid": 0.0,
                            "due_date": (date.today() + timedelta(days=90)).isoformat(),
                            "status": "PENDING"
                        }
                    ])
            else:
                # Brand new student
                new_student_id = str(uuid4())
                students_to_insert.append({
                    "id": new_student_id,
                    "school_id": school_id,
                    "parent_id": parent_id,
                    "first_name": stud_first,
                    "last_name": stud_last,
                    "classroom": classroom,
                    "academic_score": 15.0,
                    "attendance_rate": 95.0
                })
                student_id = new_student_id

                new_contract_id = str(uuid4())
                contracts_to_insert.append({
                    "id": new_contract_id,
                    "school_id": school_id,
                    "parent_id": parent_id,
                    "total_tuition_due": amount_due,
                    "status": "active"
                })
                installments_to_insert.extend([
                    {
                        "contract_id": new_contract_id,
                        "student_id": student_id,
                        "amount_due": round(amount_due * 0.30, 2),
                        "amount_paid": 0.0,
                        "due_date": (date.today() + timedelta(days=30)).isoformat(),
                        "status": "PENDING"
                    },
                    {
                        "contract_id": new_contract_id,
                        "student_id": student_id,
                        "amount_due": round(amount_due * 0.30, 2),
                        "amount_paid": 0.0,
                        "due_date": (date.today() + timedelta(days=60)).isoformat(),
                        "status": "PENDING"
                    },
                    {
                        "contract_id": new_contract_id,
                        "student_id": student_id,
                        "amount_due": round(amount_due * 0.40, 2),
                        "amount_paid": 0.0,
                        "due_date": (date.today() + timedelta(days=90)).isoformat(),
                        "status": "PENDING"
                    }
                ])

            success_count += 1
            processed_student_ids.append(student_id)

        except Exception as e:
            error_count += 1
            errors.append(f"Échec pour la ligne {rec.get('student_name', 'Inconnu')}: {str(e)}")

    # Execute bulk inserts for students, contracts, and installments
    if students_to_insert:
        try:
            supabase_client.table("students").insert(students_to_insert).execute()
        except Exception as s_err:
            print(f"Error bulk inserting students: {s_err}")
            for s in students_to_insert:
                try:
                    supabase_client.table("students").insert(s).execute()
                except Exception:
                    pass

    if contracts_to_insert:
        try:
            supabase_client.table("school_contracts").insert(contracts_to_insert).execute()
        except Exception as c_err:
            print(f"Error bulk inserting contracts: {c_err}")
            for c in contracts_to_insert:
                try:
                    supabase_client.table("school_contracts").insert(c).execute()
                except Exception:
                    pass

    if installments_to_insert:
        try:
            supabase_client.table("school_installments").insert(installments_to_insert).execute()
        except Exception as i_err:
            print(f"Error bulk inserting installments: {i_err}")
            for i in installments_to_insert:
                try:
                    supabase_client.table("school_installments").insert(i).execute()
                except Exception:
                    pass

    # 4. Phase 3: Cleanup removed students
    removed_count = 0
    try:
        students_to_remove = [sid for sid in db_student_ids if sid not in processed_student_ids]
        if students_to_remove:
            # Delete removed students in batches
            for i in range(0, len(students_to_remove), 50):
                batch = students_to_remove[i:i+50]
                supabase_client.table("students").delete().in_("id", batch).execute()
            removed_count = len(students_to_remove)

        # Cleanup empty contracts
        if contract_ids:
            for cid in contract_ids:
                try:
                    inst_check = supabase_client.table("school_installments").select("id").eq("contract_id", cid).execute()
                    if not inst_check.data:
                        supabase_client.table("school_contracts").delete().eq("id", cid).execute()
                except Exception:
                    pass
    except Exception as clean_err:
        print(f"Error cleaning up removed students: {clean_err}")

    return {
        "success_count": success_count,
        "error_count": error_count,
        "removed_count": removed_count,
        "errors": errors
    }

