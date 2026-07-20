from fastapi import APIRouter, HTTPException, Depends
from typing import Dict, Any
from uuid import UUID
from datetime import date
from app.models.schemas import MPesaPaymentRequest, CashAdjustmentRequest
from app.core.supabase import supabase_client
from app.services.credit import calculate_futa_score
from app.core.dependencies import get_current_user

router = APIRouter(prefix="/api/v1/payments", tags=["Payments & M-Pesa"])

def process_installment_payment(installment_id: UUID, amount: float, payment_method: str) -> Dict[str, Any]:
    """
    Core helper to apply a payment/adjustment to installments, cascading extra payment amounts
    to subsequent installments, and recalculate the parent's dynamic FUTA credit score.
    """
    # 1. Fetch installment details
    inst_response = supabase_client.table("school_installments").select("*").eq("id", str(installment_id)).execute()
    if not inst_response.data:
        raise HTTPException(status_code=404, detail="Échéance (installment) introuvable.")
        
    installment = inst_response.data[0]
    contract_id = installment["contract_id"]
    
    # Fetch all installments for this contract
    contract_insts_res = supabase_client.table("school_installments").select("*").eq("contract_id", contract_id).execute()
    if not contract_insts_res.data:
        raise HTTPException(status_code=404, detail="Aucune échéance trouvée pour ce contrat.")
        
    installments = sorted(contract_insts_res.data, key=lambda x: x["due_date"])
    
    # Calculate total remaining debt
    total_due = sum(float(inst["amount_due"]) for inst in installments)
    total_paid = sum(float(inst["amount_paid"]) for inst in installments)
    remaining_debt = total_due - total_paid
    
    if amount > remaining_debt:
        raise HTTPException(
            status_code=400,
            detail=f"Le montant ({amount} FCFA) dépasse le solde total dû ({remaining_debt} FCFA)."
        )
        
    # Apply cascading payment
    remaining_payment = amount
    for inst in installments:
        inst_due = float(inst["amount_due"])
        inst_paid = float(inst["amount_paid"])
        inst_remaining = inst_due - inst_paid
        
        if inst_remaining <= 0:
            continue
            
        to_apply = min(remaining_payment, inst_remaining)
        new_inst_paid = inst_paid + to_apply
        remaining_payment -= to_apply
        
        if new_inst_paid >= inst_due:
            new_status = "PAID"
        elif new_inst_paid > 0.0:
            new_status = "PARTIAL"
        else:
            new_status = "PENDING"
            
        from datetime import datetime
        update_data = {
            "amount_paid": new_inst_paid,
            "status": new_status,
            "paid_at": datetime.now().isoformat()
        }
            
        supabase_client.table("school_installments").update(update_data).eq("id", inst["id"]).execute()
        
        if remaining_payment <= 0:
            break
            
    # Check if all installments for this contract are now paid
    updated_contract_insts_res = supabase_client.table("school_installments").select("status").eq("contract_id", contract_id).execute()
    if updated_contract_insts_res.data:
        all_paid = all(inst["status"] == "PAID" for inst in updated_contract_insts_res.data)
        if all_paid:
            supabase_client.table("school_contracts").update({"status": "completed"}).eq("id", contract_id).execute()
            
    # 4. Find parent_id through contract
    contract_res = supabase_client.table("school_contracts").select("parent_id").eq("id", contract_id).execute()
    if not contract_res.data:
        raise HTTPException(status_code=500, detail="Contrat associé introuvable.")
        
    parent_id = contract_res.data[0]["parent_id"]
    
    # 5. Fetch all installments for this parent across all their contracts to recalculate score
    parent_contracts_res = supabase_client.table("school_contracts").select("id").eq("parent_id", parent_id).execute()
    contract_ids = [c["id"] for c in parent_contracts_res.data]
    
    parent_installments = []
    if contract_ids:
        all_inst_res = supabase_client.table("school_installments").select("*").in_("contract_id", contract_ids).execute()
        parent_installments = all_inst_res.data
        
    # 6. Recalculate dynamic FUTA Credit Score
    new_score = calculate_futa_score(parent_installments, today=date.today())
    
    # Refetch the updated state of the originally requested installment to return
    inst_refetched = supabase_client.table("school_installments").select("*").eq("id", str(installment_id)).execute().data[0]
    
    return {
        "status": "success",
        "message": f"Paiement de {amount} FCFA enregistré avec succès via {payment_method}.",
        "payment_method": payment_method,
        "installment_id": installment_id,
        "parent_id": parent_id,
        "previous_paid": float(installment["amount_paid"]),
        "new_paid": float(inst_refetched["amount_paid"]),
        "installment_status": inst_refetched["status"],
        "new_futa_score": new_score
    }

@router.post("/mpesa-push")
def mpesa_push_payment(
    request: MPesaPaymentRequest,
    current_user: dict = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Simulates a C2B M-Pesa push notification in the DRC/ROC.
    Triggers USSD menu on the user's phone. Once payment is simulated as approved,
    updates database records and returns the new parent FUTA credit score.
    """
    # 1. Fetch the parent_id for this installment to authorize access
    inst_res = supabase_client.table("school_installments").select("contract_id").eq("id", str(request.installment_id)).execute()
    if not inst_res.data:
        raise HTTPException(status_code=404, detail="Échéance introuvable.")
    contract_id = inst_res.data[0]["contract_id"]
    
    contract_res = supabase_client.table("school_contracts").select("parent_id").eq("id", contract_id).execute()
    if not contract_res.data:
        raise HTTPException(status_code=404, detail="Contrat associé introuvable.")
    parent_id = contract_res.data[0]["parent_id"]
    
    # Check if the user is authorized to trigger this push payment
    if current_user.get("uid") != parent_id:
        raise HTTPException(
            status_code=403,
            detail="Accès interdit. Vous ne pouvez initier de paiement que pour vos propres échéances."
        )

    # Simulate API orchestration with Vodacom M-Pesa gateway
    transaction_id = f"MPESA-TX-{UUID(int=0).hex[:8].upper()}"
    
    res = process_installment_payment(
        installment_id=request.installment_id,
        amount=request.amount,
        payment_method="M-Pesa Mobile Money"
    )
    res["transaction_id"] = transaction_id
    return res

@router.post("/cash-adjustment")
def cash_adjustment(
    request: CashAdjustmentRequest,
    current_user: dict = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Logs a manual cash payment at the school office.
    Updates the database records and returns the new parent FUTA credit score.
    """
    # Authorization checks: only the school admin can record cash payments
    if current_user.get("role") != "admin" or current_user.get("sub_role") != "school":
        raise HTTPException(
            status_code=403,
            detail="Accès interdit. Seul un administrateur scolaire peut enregistrer un paiement en espèces."
        )
        
    # Fetch school_id associated with this installment
    inst_res = supabase_client.table("school_installments").select("contract_id").eq("id", str(request.installment_id)).execute()
    if not inst_res.data:
        raise HTTPException(status_code=404, detail="Échéance introuvable.")
    contract_id = inst_res.data[0]["contract_id"]
    
    contract_res = supabase_client.table("school_contracts").select("school_id").eq("id", contract_id).execute()
    if not contract_res.data:
        raise HTTPException(status_code=404, detail="Contrat associé introuvable.")
    school_id = contract_res.data[0]["school_id"]
    
    if current_user.get("uid") != school_id:
        raise HTTPException(
            status_code=403,
            detail="Accès interdit. Vous ne pouvez enregistrer des paiements que pour les échéances de votre établissement."
        )

    res = process_installment_payment(
        installment_id=request.installment_id,
        amount=request.amount,
        payment_method="Espèces"
    )
    return res

@router.get("/credit-score/{parent_id}")
def get_credit_score(
    parent_id: str,
    current_user: dict = Depends(get_current_user)
) -> Dict[str, Any]:
    """
    Retrieves and recalculates the dynamic FUTA credit score for a parent.
    Accessible only to the parent themselves or global admins.
    """
    if current_user.get("uid") != parent_id and current_user.get("role") != "admin":
        raise HTTPException(
            status_code=403,
            detail="Accès interdit. Vous ne pouvez consulter que votre propre score de crédit."
        )
        
    try:
        contracts_res = supabase_client.table("school_contracts").select("id").eq("parent_id", parent_id).execute()
        contract_ids = [c["id"] for c in contracts_res.data] if contracts_res.data else []
        
        parent_installments = []
        if contract_ids:
            all_inst_res = supabase_client.table("school_installments").select("*").in_("contract_id", contract_ids).execute()
            parent_installments = all_inst_res.data
            
        score = calculate_futa_score(parent_installments, today=date.today())
        return {
            "status": "success",
            "parent_id": parent_id,
            "futa_score": score
        }
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Erreur lors du calcul du score de crédit: {str(e)}"
        )
