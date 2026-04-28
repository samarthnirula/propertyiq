from pydantic import BaseModel


class CalculationRequest(BaseModel):
    price: float
    down_payment: float
    interest_rate: float
    rent: float
    monthly_expenses: float
    one_time_expenses: float


class CalculationResponse(BaseModel):
    cash_flow: float
    roi: float
    cap_rate: float
    mortgage_payment: float
    breakeven_years: float | None = None