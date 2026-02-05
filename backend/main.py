from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

class CalcRequest(BaseModel):
    price: float
    down_payment: float
    interest_rate: float
    rent: float
    monthly_expenses: float
    expenses: float
    loan_years: int = 30

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/calculate")
def calculate(req: CalcRequest):
    price = max(req.price, 0)
    down = max(req.down_payment, 0)
    interest = max(req.interest_rate, 0)
    rent = max(req.rent, 0)
    monthly_expenses = max(req.monthly_expenses, 0)
    one_time_expense = max(req.expenses, 0)

    loan_amount = max(price - down, 0)
    r = (interest / 100) / 12
    n = req.loan_years * 12

    if loan_amount == 0:
        mortgage = 0
    elif r == 0:
        mortgage = loan_amount / n
    else:
        mortgage = loan_amount * (r * (1 + r) ** n) / ((1 + r) ** n - 1)

    cash_flow = rent - monthly_expenses - mortgage
    noi = (rent - monthly_expenses) * 12
    cap_rate = (noi / price) * 100 if price > 0 else 0

    total_cash_invested = down + one_time_expense
    if total_cash_invested <= 0:
        total_cash_invested = 1

    annual_cash_flow = cash_flow * 12
    roi = (annual_cash_flow / total_cash_invested) * 100
    breakeven_years = (total_cash_invested / annual_cash_flow) if annual_cash_flow > 0 else None

    return {
        "mortgage_payment": round(mortgage, 2),
        "cash_flow": round(cash_flow, 2),
        "cap_rate": round(cap_rate, 2),
        "roi": round(roi, 2),
        "breakeven_years": round(breakeven_years, 2) if breakeven_years else None,
    }
