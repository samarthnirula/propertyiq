from fastapi import FastAPI, Query, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
<<<<<<< HEAD
import requests
import os
from dotenv import load_dotenv
from urllib.parse import unquote

# Load .env reliably from backend folder
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
load_dotenv(os.path.join(BASE_DIR, ".env"))

from services.listing_search import search_listings  # UPDATED
=======
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
>>>>>>> a7275b8c9d76d832cbe67b421cf71b9c2857e5ce

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

GEOAPIFY_KEY = os.getenv("GEOAPIFY_KEY", "").strip()
print("GEOAPIFY_KEY loaded:", "YES" if GEOAPIFY_KEY else "NO")


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
    breakeven_years = (
        total_cash_invested / annual_cash_flow
        if annual_cash_flow > 0
        else None
    )

    return {
        "mortgage_payment": round(mortgage, 2),
        "cash_flow": round(cash_flow, 2),
        "cap_rate": round(cap_rate, 2),
        "roi": round(roi, 2),
        "breakeven_years": round(breakeven_years, 2) if breakeven_years else None,
    }

<<<<<<< HEAD

@app.get("/autocomplete")
def autocomplete(q: str = Query(..., min_length=3)):
    if not GEOAPIFY_KEY:
        return {"results": [], "error": "GEOAPIFY_KEY not set. Check backend/.env"}

    url = "https://api.geoapify.com/v1/geocode/autocomplete"
    params = {
        "text": q,
        "format": "json",
        "apiKey": GEOAPIFY_KEY,
        "limit": 6,
    }

    try:
        resp = requests.get(url, params=params, timeout=10)
        resp.raise_for_status()
        data = resp.json()
    except Exception as e:
        return {"results": [], "error": str(e)}

    results = []
    for item in data.get("results", []):
        results.append(
            {
                "formatted": item.get("formatted"),
                "lat": item.get("lat"),
                "lon": item.get("lon"),
            }
        )

    return {"results": results}


@app.get("/listings")
def listings(
    q: str = Query(None, description="Search query (address/keyword)"),
    city: str = Query(None, description="City filter"),
    limit: int = Query(12, ge=1, le=50),
    offset: int = Query(0, ge=0),
):
    """
    Returns normalized listings from SimplyRETS (no state restriction).
    """
    try:
        items = search_listings(address_query=q, city=city, limit=limit, offset=offset)
        return {"results": items}
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))


@app.get("/image-proxy")
def image_proxy(url: str):
    """
    Proxies remote images so Flutter Web can load them without CORS/mixed-content issues.
    Usage: /image-proxy?url=<encoded_remote_url>
    """
    if not url:
        raise HTTPException(status_code=400, detail="Missing url")

    remote_url = unquote(url)

    try:
        r = requests.get(
            remote_url,
            stream=True,
            timeout=20,
            headers={"User-Agent": "Mozilla/5.0"},
        )
        r.raise_for_status()

        content_type = r.headers.get("content-type", "image/jpeg")

        return StreamingResponse(
            r.iter_content(chunk_size=8192),
            media_type=content_type,
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Image proxy failed: {e}")


@app.get("/debug/simplyrets")
def debug_simplyrets(limit: int = 5, offset: int = 0):
    try:
        items = search_listings(limit=limit, offset=offset)
        return {"count": len(items), "sample": items[:1]}
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))
=======
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


>>>>>>> a7275b8c9d76d832cbe67b421cf71b9c2857e5ce
