from fastapi import APIRouter, Depends, HTTPException, status, Query
from typing import Dict, Any, List, Optional
from pydantic import BaseModel
import calendar
from datetime import datetime, timezone

from app.core.dependencies import get_current_user
from app.core.supabase import supabase_client

router = APIRouter(prefix="/api/v1/network", tags=["Network Hierarchy & Aggregation"])

class NetworkRegisterRequest(BaseModel):
    network_code: str
    name: str
    admin_name: str
    phone_number: str
    address: Optional[str] = None
    logo_url: Optional[str] = None

@router.get("/validate-code")
async def validate_network_code(code: str = Query(..., description="Network / Aggregator code, e.g. RECC")):
    """
    Public validation endpoint for school registration.
    Checks if a network code exists and calculates the next available sub-code.
    """
    clean_code = code.strip().upper()
    if not clean_code:
        raise HTTPException(status_code=400, detail="Le code réseau ne peut pas être vide.")

    try:
        net_res = supabase_client.table("school_networks").select("id, name, network_code").eq("network_code", clean_code).execute()
        if not net_res.data:
            return {
                "valid": False,
                "message": f"Aucun réseau scolaire trouvé avec le code '{clean_code}'."
            }

        network = net_res.data[0]
        network_id = network["id"]

        # Count existing member schools to propose next child code e.g. RECC-003
        schools_res = supabase_client.table("school_profiles").select("id, invite_code").eq("network_id", network_id).execute()
        existing_count = len(schools_res.data) if schools_res.data else 0
        suggested_code = f"{clean_code}-{str(existing_count + 1).zfill(3)}"

        return {
            "valid": True,
            "network_id": network_id,
            "network_name": network["name"],
            "network_code": clean_code,
            "suggested_child_code": suggested_code,
            "total_member_schools": existing_count,
            "message": f"Réseau validé : {network['name']}"
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur lors de la validation du code réseau: {str(e)}")

@router.get("/overview")
async def get_network_overview(current_user: Dict[str, Any] = Depends(get_current_user)):
    """
    Returns aggregated financial, recovery, and enrollment statistics for the logged-in network administrator.
    """
    uid = current_user.get("uid")
    if not uid:
        raise HTTPException(status_code=401, detail="Non autorisé.")

    try:
        # 1. Resolve network profile
        net_res = supabase_client.table("school_networks").select("*").eq("id", uid).execute()
        if not net_res.data:
            # Fallback by phone number
            phone = current_user.get("phone_number") or ""
            clean_phone = phone.replace(" ", "") if phone else ""
            if clean_phone:
                net_res = supabase_client.table("school_networks").select("*").eq("phone_number", clean_phone).execute()

        if not net_res.data:
            raise HTTPException(status_code=404, detail="Profil de réseau scolaire introuvable.")

        network = net_res.data[0]
        network_id = network["id"]

        # 2. Fetch all member schools
        schools_res = supabase_client.table("school_profiles").select("id, school_name, address, phone_number, invite_code, created_at").eq("network_id", network_id).execute()
        member_schools = schools_res.data or []
        school_ids = [s["id"] for s in member_schools]

        total_schools_count = len(member_schools)
        total_students_count = 0
        total_amount_collected = 0.0
        total_amount_to_perceive = 0.0
        school_breakdowns = []

        # 3. Monthly aggregated revenue map (last 6 months)
        now = datetime.now(timezone.utc)
        monthly_revenues = {f"{now.year}-{month:02d}": 0.0 for month in range(max(1, now.month - 5), now.month + 1)}

        if school_ids:
            # Fetch all students in network
            students_res = supabase_client.table("students").select("id, school_id").in_("school_id", school_ids).execute()
            total_students_count = len(students_res.data) if students_res.data else 0
            
            # Map student counts per school
            student_count_by_school = {}
            for st in (students_res.data or []):
                s_id = st.get("school_id")
                student_count_by_school[s_id] = student_count_by_school.get(s_id, 0) + 1

            # Fetch contracts
            contracts_res = supabase_client.table("school_contracts").select("id, school_id").in_("school_id", school_ids).execute()
            contracts = contracts_res.data or []
            contract_to_school = {c["id"]: c["school_id"] for c in contracts}
            contract_ids = list(contract_to_school.keys())

            school_financials = {s_id: {"collected": 0.0, "due": 0.0} for s_id in school_ids}

            if contract_ids:
                installments_res = supabase_client.table("school_installments").select("amount_due, amount_paid, paid_at, contract_id").in_("contract_id", contract_ids).execute()
                for inst in (installments_res.data or []):
                    c_id = inst.get("contract_id")
                    s_id = contract_to_school.get(c_id)
                    due = float(inst.get("amount_due") or 0.0)
                    paid = float(inst.get("amount_paid") or 0.0)

                    total_amount_to_perceive += due
                    total_amount_collected += paid

                    if s_id and s_id in school_financials:
                        school_financials[s_id]["due"] += due
                        school_financials[s_id]["collected"] += paid

                    # Track monthly revenue
                    paid_at = inst.get("paid_at")
                    if paid_at and paid > 0:
                        try:
                            dt = datetime.fromisoformat(paid_at.replace("Z", "+00:00"))
                            key = f"{dt.year}-{dt.month:02d}"
                            if key in monthly_revenues:
                                monthly_revenues[key] += paid
                        except Exception:
                            pass

            # Build per-school summary items
            for s in member_schools:
                s_id = s["id"]
                s_fin = school_financials.get(s_id, {"collected": 0.0, "due": 0.0})
                s_due = s_fin["due"]
                s_col = s_fin["collected"]
                s_rec = (s_col / s_due * 100.0) if s_due > 0 else 0.0
                
                school_breakdowns.append({
                    "school_id": s_id,
                    "school_name": s.get("school_name", "Établissement"),
                    "invite_code": s.get("invite_code", ""),
                    "address": s.get("address", ""),
                    "phone_number": s.get("phone_number", ""),
                    "students_count": student_count_by_school.get(s_id, 0),
                    "amount_collected": s_col,
                    "amount_to_perceive": s_due,
                    "recovery_rate": round(s_rec, 1),
                })

        # Calculate network-wide recovery rate
        network_recovery_rate = (total_amount_collected / total_amount_to_perceive * 100.0) if total_amount_to_perceive > 0 else 0.0

        return {
            "network": {
                "id": network_id,
                "name": network.get("name", "Réseau Scolaire"),
                "network_code": network.get("network_code", ""),
                "admin_name": network.get("admin_name", ""),
                "phone_number": network.get("phone_number", ""),
                "address": network.get("address", ""),
            },
            "summary": {
                "total_schools_count": total_schools_count,
                "total_students_count": total_students_count,
                "total_amount_collected": total_amount_collected,
                "total_amount_to_perceive": total_amount_to_perceive,
                "recovery_rate": round(network_recovery_rate, 1),
            },
            "schools": school_breakdowns,
            "monthly_revenues": monthly_revenues,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur lors de la récupération des données du réseau: {str(e)}")

@router.get("/schools")
async def get_network_schools(current_user: Dict[str, Any] = Depends(get_current_user)):
    """
    Returns list of all member schools under this network with individual performance metrics.
    """
    overview = await get_network_overview(current_user=current_user)
    return {"schools": overview.get("schools", [])}
