from fastapi import APIRouter, UploadFile, File, Header, HTTPException, Query, Depends
from typing import Dict, Any
from app.services.excel import parse_roster_file, process_roster_ingestion
from app.core.dependencies import get_current_user

router = APIRouter(prefix="/api/v1/school", tags=["School Admin Portal"])

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
        
    if current_user.get("uid") != school_id:
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
