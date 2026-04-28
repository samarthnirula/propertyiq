import math
from models.calc_models import CalculationRequest

def _monthly_mortgage_payment(
    principal: float,
    annual_interest_rate_pct: float,
    years: int = 30,
) -> float:
    if principal <= 0:
        return 0.0

    monthly_rate = (annual_interest_rate_pct / 100.0) / 12.0
    total_payments = years * 12

    if monthly_rate == 0:
        return principal / total_payments

    return principal * (
        monthly_rate * math.pow(1 + monthly_rate, total_payments)
    ) / (
        math.pow(1 + monthly_rate, total_payments) - 1
    )


def compute_financials(req: CalculationRequest) -> dict:
    loan_amount = max(req.price - req.down_payment, 0.0)

    mortgage_payment = _monthly_mortgage_payment(
        principal=loan_amount,
        annual_interest_rate_pct=req.interest_rate,
        years=30,
    )

    cash_flow = req.rent - mortgage_payment - req.monthly_expenses

    annual_rent = req.rent * 12.0
    annual_expenses = (mortgage_payment * 12.0) + (req.monthly_expenses * 12.0)
    noi = annual_rent - (req.monthly_expenses * 12.0)

    cap_rate = 0.0
    if req.price > 0:
        cap_rate = (noi / req.price) * 100.0

    total_cash_invested = req.down_payment + req.one_time_expenses
    roi = 0.0
    if total_cash_invested > 0:
        roi = ((cash_flow * 12.0) / total_cash_invested) * 100.0

    breakeven_years = None
    annual_cash_flow = cash_flow * 12.0
    if annual_cash_flow > 0 and total_cash_invested > 0:
        breakeven_years = total_cash_invested / annual_cash_flow

    return {
        "cash_flow": round(cash_flow, 2),
        "roi": round(roi, 2),
        "cap_rate": round(cap_rate, 2),
        "mortgage_payment": round(mortgage_payment, 2),
        "breakeven_years": round(breakeven_years, 2) if breakeven_years is not None else None,
    }