from fastapi import APIRouter, UploadFile, File, Header, HTTPException, Query, Depends
from typing import Dict, Any, Optional
from pydantic import BaseModel, Field
from app.services.excel import parse_roster_file, process_roster_ingestion, clean_phone_number
from app.core.dependencies import get_current_user
from app.core.supabase import supabase_client

router = APIRouter(prefix="/api/v1/school", tags=["School Admin Portal"])

class UpdateParentRequest(BaseModel):
    parent_id: str = Field(..., description="ID unique du profil du parent")
    first_name: str = Field(..., description="Prénom du parent")
    last_name: str = Field(..., description="Nom du parent")
    phone_number: str = Field(..., description="Numéro de téléphone du parent")
    address: Optional[str] = Field(None, description="Adresse du parent")

class UpdateInstallmentDatesRequest(BaseModel):
    school_id: Optional[str] = Field(None, description="ID unique de l'établissement scolaire")
    student_id: Optional[str] = Field(None, description="ID de l'étudiant (si modification individuelle)")
    tranche1_date: str = Field(..., description="Date d'échéance de la Tranche 1 (YYYY-MM-DD)")
    tranche2_date: str = Field(..., description="Date d'échéance de la Tranche 2 (YYYY-MM-DD)")
    tranche3_date: str = Field(..., description="Date d'échéance de la Tranche 3 (YYYY-MM-DD)")


@router.post("/upload-roster")
async def upload_roster(
    file: UploadFile = File(...),
    school_id: str = Query(..., description="ID unique du profil de l'école/institution"),
    current_user: dict = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Endpoint FastAPI pour ingérer un roster d'élèves via Excel ou CSV.
    Nettoie les numéros de téléphone et crée automatiquement les profils,
    étudiants, contrats de scolarité, et échéanciers d'installments.
    """
    # Authorization checks
    if current_user.get("role") != "admin" or current_user.get("sub_role") != "school":
        raise HTTPException(
            status_code=403,
            detail="Accès interdit. Seul un administrateur scolaire peut importer un roster."
        )
        
    user_school_id = current_user.get("school_id") or current_user.get("uid")
    if user_school_id != school_id:
        raise HTTPException(
            status_code=403,
            detail="Accès interdit. Vous ne pouvez pas modifier le roster d'un autre établissement."
        )


    # Validate extension
    file_name = file.filename
    if not (file_name.endswith(".xlsx") or file_name.endswith(".xls") or file_name.endswith(".csv")):
        raise HTTPException(
            status_code=400,
            detail="Format de fichier non pris en charge. Veuillez télécharger un fichier Excel (.xlsx) ou CSV (.csv)."
        )
        
    try:
        # Read file bytes
        file_bytes = await file.read()
        
        # Parse data
        records = parse_roster_file(file_bytes, file_name)
        
        if not records:
            raise HTTPException(
                status_code=400,
                detail="Le fichier est vide ou ne contient aucune ligne valide conforme au schéma."
            )
            
        # Process ingestion in Supabase
        report = process_roster_ingestion(records, school_id)
        
        return {
            "message": "Importation terminée avec succès.",
            "school_id": school_id,
            "filename": file_name,
            "resultats": report
        }
        
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur interne lors du traitement du fichier: {str(e)}")

@router.post("/update-parent")
def update_parent_profile(
    request: UpdateParentRequest,
    current_user: dict = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Permet à l'administrateur scolaire de modifier le profil d'un parent (nom, prénom, téléphone, adresse).
    """
    if current_user.get("role") != "admin" or current_user.get("sub_role") != "school":
        raise HTTPException(
            status_code=403,
            detail="Accès interdit. Seul un administrateur scolaire peut modifier un profil parent."
        )

    try:
        cleaned_phone = clean_phone_number(request.phone_number)
    except ValueError as ve:
        raise HTTPException(status_code=400, detail=str(ve))

    update_payload = {
        "first_name": request.first_name.strip(),
        "last_name": request.last_name.strip(),
        "phone_number": cleaned_phone,
    }
    if request.address is not None:
        update_payload["address"] = request.address.strip()

    try:
        res = supabase_client.table("profiles").update(update_payload).eq("id", request.parent_id).execute()
        if not res.data:
            # Check if parent profile exists under FB- placeholder
            res = supabase_client.table("profiles").update(update_payload).eq("id", request.parent_id).execute()
        
        return {
            "status": "success",
            "message": "Profil parent mis à jour avec succès.",
            "parent_id": request.parent_id,
            "data": update_payload
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur lors de la mise à jour du parent: {str(e)}")

@router.post("/update-installment-dates")
def update_installment_dates(
    request: UpdateInstallmentDatesRequest,
    current_user: dict = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Permet à l'école de définir les dates d'échéances des tranches 1, 2 et 3
    pour l'ensemble des élèves de l'établissement ou pour un élève spécifique.
    """
    if current_user.get("role") != "admin" or current_user.get("sub_role") != "school":
        raise HTTPException(
            status_code=403,
            detail="Accès interdit. Seul un administrateur scolaire peut modifier les échéances."
        )

    user_school_id = current_user.get("school_id") or current_user.get("uid")
    school_id = request.school_id or user_school_id

    if user_school_id != school_id:
        raise HTTPException(
            status_code=403,
            detail="Accès interdit. Vous ne pouvez modifier que les échéances de votre établissement."
        )


    try:
        # 1. Retrieve all contracts for this school
        contracts_res = supabase_client.table("school_contracts").select("id").eq("school_id", school_id).execute()

        if not contracts_res.data:
            return {"status": "success", "message": "Aucun contrat trouvé pour cet établissement.", "updated_count": 0}

        contract_ids = [c["id"] for c in contracts_res.data]

        # 2. Retrieve installments
        query = supabase_client.table("school_installments").select("*").in_("contract_id", contract_ids)
        if request.student_id:
            query = query.eq("student_id", request.student_id)
        
        inst_res = query.execute()
        if not inst_res.data:
            return {"status": "success", "message": "Aucune échéance trouvée à mettre à jour.", "updated_count": 0}

        # 3. Group by student_id or contract_id, and update Tranches 1, 2, 3
        from collections import defaultdict
        grouped = defaultdict(list)
        for inst in inst_res.data:
            grouped[inst["contract_id"]].append(inst)

        new_dates = [request.tranche1_date, request.tranche2_date, request.tranche3_date]
        updated_count = 0

        for cid, inst_list in grouped.items():
            # Sort installments by existing due_date or created_at
            inst_list.sort(key=lambda x: x.get("due_date", ""))
            for idx, inst in enumerate(inst_list):
                if idx < len(new_dates):
                    target_date = new_dates[idx]
                    supabase_client.table("school_installments").update({
                        "due_date": target_date
                    }).eq("id", inst["id"]).execute()
                    updated_count += 1

        return {
            "status": "success",
            "message": f"Dates d'échéances mises à jour avec succès pour {updated_count} tranche(s).",
            "updated_count": updated_count,
            "dates": {
                "tranche1": request.tranche1_date,
                "tranche2": request.tranche2_date,
                "tranche3": request.tranche3_date
            }
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur lors de la mise à jour des échéances: {str(e)}")

