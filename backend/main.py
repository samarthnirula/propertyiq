from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from census import Census
from us import states
import pandas as pd
import warnings
import os
from dotenv import load_dotenv
import requests

load_dotenv()

#header for rentcast api
headers = { 
    "accept": "application/json",
    "X-API-Key": os.getenv("RENTCAST_API_KEY")
}

warnings.filterwarnings('ignore') #ignore warnings from data retrieval
censusdate_api_key = os.getenv("CENSUSDATA_API_KEY")
c = Census(censusdate_api_key)

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

#using census python package to retrieve median household income based off a given zipcode
def get_median_household_income(zipcode):
    dataset = "acs5" #5-year American Community Survey for ZCTA data
    variable = "B19013_001E" # Median household Income estimate
    year = 2023 #most recent year available for ACS 5-year data

    data = c.acs5.get((variable, 'NAME'),
            {'for': 'zip code tabulation area:{zipcode}'},
                   year=year)

    df = pd.DataFrame(data)

    df.rename(columns={variable: 'Median_Household_Income', 'NAME': "ZCTAName"}, inplace=True)

    average_property_price = df[['ZCTAName', 'Median_Household_Income']]
    print("Median Household Income for {zipcode}: {average_property_price}")

    return average_property_price



#using rentcast api to retrieve average price of properties in a given zipcode
def get_average_property_price(zipcode):
    url_average_price = "https://api.rentcast.io/v1/markets?zipCode={zipcode}&dataType=Sale&historyRange=1"
    response = requests.get(url_average_price, headers=headers)
    average_price = response.json()['saleData']['dataByPropertyType'][2]['averagePrice']
    print("Average property price for {zipcode}: {average_price}")

    return average_price


#using rentcast api to retrieve price of a property for a given address
def get_property_price(address):

    url_property_price = "https://api.rentcast.io/v1/avm/value?address={address}"

    response = requests.get(url_property_price, headers=headers)

    *_, last = response.json()[0]['taxAssessments'].items()
    property_price = last[1]['value']
    print("Current property price of {address}: {property_price}")

    return property_price


