import pytest
from datetime import date
from app.services.credit import calculate_futa_score

def test_neutral_baseline_if_no_installments():
    """
    Assert that if a user has no installments, they get the baseline score of 600.
    """
    assert calculate_futa_score([]) == 600

def test_on_time_full_payment_increases_score():
    """
    On-time full payment (ratio = 1.0, due_date >= today) should award +40.
    600 + 40 = 640
    """
    installments = [
        {
            "amount_due": 100.0,
            "amount_paid": 100.0,
            "due_date": date(2026, 7, 1) # Future date relative to test date
        }
    ]
    test_today = date(2026, 6, 22)
    score = calculate_futa_score(installments, today=test_today)
    assert score == 640

def test_on_time_partial_payment_proportional_increase():
    """
    On-time partial payment (ratio = 0.5, due_date >= today) should award 0.5 * 40 = +20.
    600 + 20 = 620
    """
    installments = [
        {
            "amount_due": 1000.0,
            "amount_paid": 500.0,
            "due_date": date(2026, 6, 25)
        }
    ]
    test_today = date(2026, 6, 22)
    score = calculate_futa_score(installments, today=test_today)
    assert score == 620

def test_overdue_full_unpaid_penalizes():
    """
    Overdue unpaid installment (ratio = 0.0, due_date < today) should penalize -80.
    600 - 80 = 520
    """
    installments = [
        {
            "amount_due": 500.0,
            "amount_paid": 0.0,
            "due_date": date(2026, 6, 1) # Past date
        }
    ]
    test_today = date(2026, 6, 22)
    score = calculate_futa_score(installments, today=test_today)
    assert score == 520

def test_overdue_partial_payment_protects_binary_drop():
    """
    Overdue partial payment:
    1. If 80% paid (ratio = 0.8, due_date < today):
       Net impact = (0.8 * 120) - 80 = +16.
       Score = 600 + 16 = 616.
    2. If 50% paid (ratio = 0.5, due_date < today):
       Net impact = (0.5 * 120) - 80 = -20.
       Score = 600 - 20 = 580.
    This protects the user from a complete -80 binary drop.
    """
    test_today = date(2026, 6, 22)
    
    # Case 1: 80% paid
    inst_80 = [{"amount_due": 100.0, "amount_paid": 80.0, "due_date": date(2026, 6, 15)}]
    score_80 = calculate_futa_score(inst_80, today=test_today)
    assert score_80 == 616
    
    # Case 2: 50% paid
    inst_50 = [{"amount_due": 100.0, "amount_paid": 50.0, "due_date": date(2026, 6, 15)}]
    score_50 = calculate_futa_score(inst_50, today=test_today)
    assert score_50 == 580

def test_score_boundaries_clamped():
    """
    Verify that credit score does not exceed 850 or drop below 300.
    """
    test_today = date(2026, 6, 22)
    
    # Case 1: Large rewards should max out at 850
    lots_of_rewards = [
        {"amount_due": 100.0, "amount_paid": 100.0, "due_date": date(2026, 7, 1)}
        for _ in range(10) # 10 * +40 = +400. 600 + 400 = 1000 -> capped at 850
    ]
    max_score = calculate_futa_score(lots_of_rewards, today=test_today)
    assert max_score == 850
    
    # Case 2: Large penalties should floor at 300
    lots_of_penalties = [
        {"amount_due": 100.0, "amount_paid": 0.0, "due_date": date(2026, 6, 1)}
        for _ in range(10) # 10 * -80 = -800. 600 - 800 = -200 -> floored at 300
    ]
    min_score = calculate_futa_score(lots_of_penalties, today=test_today)
    assert min_score == 300
