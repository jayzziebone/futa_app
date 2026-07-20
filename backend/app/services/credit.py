from datetime import date
from typing import List, Dict, Any

def calculate_futa_score(installments: List[Dict[str, Any]], today: date = None) -> int:
    """
    Calculates a dynamic FUTA credit score between 300 and 850.
    
    Logic details:
    - Base starting score: 600 (neutral/good baseline).
    - Minimum score: 300.
    - Maximum score: 850.
    - If a user has no installments, they default to 600.
    - For each installment:
        - Let ratio = amount_paid / amount_due (clamped 0.0 to 1.0).
        - If the installment is not yet due (due_date >= today):
            - We award a proportional bonus for early/on-time payment: ratio * 40.
            - If ratio is 0.0, there is no reward, but no penalty since it is not overdue.
        - If the installment is overdue (due_date < today):
            - If paid in full (ratio == 1.0), we award the full bonus of +40.
            - If not paid in full, we calculate a net contribution:
                - Reward for paid portion: ratio * 40
                - Penalty for unpaid portion: (1.0 - ratio) * -80
                - Combined impact: ratio * 120 - 80.
                - This ensures that paying 80% yields: 0.8 * 120 - 80 = +16 (positive impact)
                - Paying 50% yields: 0.5 * 120 - 80 = -20 (minor negative impact)
                - Paying 0% yields: 0 - 80 = -80 (full negative impact)
                - This prevents a binary drop and rewards every single Franc paid.
    """
    if not today:
        today = date.today()
        
    if not installments:
        return 600

    score = 600.0
    
    for inst in installments:
        amount_due = float(inst.get("amount_due", 0.0))
        amount_paid = float(inst.get("amount_paid", 0.0))
        due_date_raw = inst.get("due_date")
        
        if amount_due <= 0.0:
            continue
            
        # Parse due_date to date object
        if isinstance(due_date_raw, str):
            due_date = date.fromisoformat(due_date_raw)
        else:
            due_date = due_date_raw
            
        # Clamp ratio
        ratio = min(max(amount_paid / amount_due, 0.0), 1.0)
        
        if due_date >= today:
            # Not overdue yet: positive reward for payment, no penalty
            score += ratio * 40.0
        else:
            # Overdue: reward for paid amount, penalty for unpaid amount
            net_impact = (ratio * 120.0) - 80.0
            score += net_impact

    # Clamp the final score within the range [300, 850]
    final_score = int(round(score))
    return min(max(final_score, 300), 850)
