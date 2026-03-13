# --- OLD ---
from fastapi import FastAPI, Query, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
import requests
import os
from urllib.parse import unquote
from services.listing_search import search_listings
from census import Census
from us import states
import pandas as pd
import warnings

# --- (agents) ---
from contextlib import asynccontextmanager
from typing import Optional
from sqlalchemy.orm import Session
from db.database import init_db, get_db, UserInsight, UserProfile
from agents.behavior_tracker import track_event
from scheduler import start_scheduler, run_market_pipeline, run_profile_pipeline


warnings.filterwarnings('ignore')

headers = {
    "accept": "application/json",
    "X-API-Key": os.getenv("RENTCAST_API_KEY")
}

censusdate_api_key = os.getenv("CENSUSDATA_API_KEY")
c = Census(censusdate_api_key)

GEOAPIFY_KEY = os.getenv("GEOAPIFY_KEY")
print("GEOAPIFY_KEY loaded: YES")


@asynccontextmanager
async def lifespan(app: FastAPI):
    print("[Startup] Initializing agent database tables...")
    init_db()
    print("[Startup] Starting agent scheduler...")
    scheduler = start_scheduler()
    yield
    scheduler.shutdown()
    print("[Shutdown] Scheduler stopped.")

app = FastAPI(lifespan=lifespan)

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
    # gent tracking ---
    zipcode: Optional[str] = None
    user_id: Optional[str] = "anonymous"

class EventRequest(BaseModel):
    user_id: str
    event_type: str   # search | save | calculate | dismiss | compare | view
    payload: Optional[dict] = {}

@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/calculate")
def calculate(req: CalcRequest, db: Session = Depends(get_db)):
    # added db param + track_event() at bottom 
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

    result = {
        "mortgage_payment": round(mortgage, 2),
        "cash_flow": round(cash_flow, 2),
        "cap_rate": round(cap_rate, 2),
        "roi": round(roi, 2),
        "breakeven_years": round(breakeven_years, 2) if breakeven_years else None,
    }

    # log for agent (never breaks the request) 
    try:
        track_event(db, req.user_id, "calculate", {
            "zipcode": req.zipcode,
            "price": req.price,
            "roi": result["roi"],
            "cash_flow": result["cash_flow"],
        })
    except Exception:
        pass
    return result


@app.get("/autocomplete")
def autocomplete(q: str = Query(..., min_length=3)):
    url = "https://api.geoapify.com/v1/geocode/autocomplete"
    params = {"text": q, "format": "json", "apiKey": GEOAPIFY_KEY, "limit": 6}
    try:
        resp = requests.get(url, params=params, timeout=10)
        resp.raise_for_status()
        data = resp.json()
    except Exception as e:
        return {"results": [], "error": str(e)}

    results = []
    for item in data.get("results", []):
        results.append({
            "formatted": item.get("formatted"),
            "lat": item.get("lat"),
            "lon": item.get("lon"),
        })
    return {"results": results}


@app.get("/listings")
def listings(
    q: str = Query(None, description="Search query (address/keyword)"),
    city: str = Query(None, description="City filter"),
    limit: int = Query(12, ge=1, le=50),
    offset: int = Query(0, ge=0),
    # -user_id and db for agent tracking 
    user_id: str = Query("anonymous"),
    db: Session = Depends(get_db),
):
    try:
        items = search_listings(address_query=q, city=city, limit=limit, offset=offset)

        try:
            track_event(db, user_id, "search", {"query": q, "city": city})
        except Exception:
            pass

        return {"results": items}
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))


@app.get("/image-proxy")
def image_proxy(url: str):
    if not url:
        raise HTTPException(status_code=400, detail="Missing url")
    remote_url = unquote(url)
    try:
        r = requests.get(remote_url, stream=True, timeout=20, headers={"User-Agent": "Mozilla/5.0"})
        r.raise_for_status()
        content_type = r.headers.get("content-type", "image/jpeg")
        return StreamingResponse(r.iter_content(chunk_size=8192), media_type=content_type)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Image proxy failed: {e}")


@app.get("/debug/simplyrets")
def debug_simplyrets(limit: int = 5, offset: int = 0):
    # --- OLD: unchanged ---
    try:
        items = search_listings(limit=limit, offset=offset)
        return {"count": len(items), "sample": items[:1]}
    except Exception as e:
        raise HTTPException(status_code=502, detail=str(e))


def get_median_household_income(zipcode):
    variable = "B19013_001E"
    year = 2023
    data = c.acs5.get((variable, 'NAME'), {'for': f'zip code tabulation area:{zipcode}'}, year=year)
    df = pd.DataFrame(data)
    df.rename(columns={variable: 'Median_Household_Income', 'NAME': "ZCTAName"}, inplace=True)
    return df[['ZCTAName', 'Median_Household_Income']]

def get_average_property_price(zipcode):
    url = f"https://api.rentcast.io/v1/markets?zipCode={zipcode}&dataType=Sale&historyRange=1"
    response = requests.get(url, headers=headers)
    return response.json()['saleData']['dataByPropertyType'][2]['averagePrice']

def get_property_price(address):
    url = f"https://api.rentcast.io/v1/avm/value?address={address}"
    response = requests.get(url, headers=headers)
    *_, last = response.json()[0]['taxAssessments'].items()
    return last[1]['value']


@app.post("/events")
def log_event(req: EventRequest, db: Session = Depends(get_db)):
    """
    Manually log any user behavior event from Flutter.
    /calculate and /listings already log automatically above.
    Use this for: save, dismiss, view, compare actions in the frontend.
    """
    try:
        event = track_event(db, req.user_id, req.event_type, req.payload)
        return {"status": "ok", "event_id": event.id}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@app.get("/insights/{user_id}")
def get_insights(user_id: str, limit: int = 20, db: Session = Depends(get_db)):
    """Returns personalized insight cards for a user. Main endpoint for Flutter."""
    insights = (
        db.query(UserInsight)
        .filter(UserInsight.user_id == user_id)
        .order_by(UserInsight.created_at.desc())
        .limit(limit)
        .all()
    )
    return {
        "user_id": user_id,
        "count": len(insights),
        "insights": [
            {
                "id": i.id,
                "zipcode": i.zipcode,
                "headline": i.headline,
                "explanation": i.explanation,
                "direction": i.direction,
                "read": i.read,
                "created_at": i.created_at.isoformat(),
            }
            for i in insights
        ]
    }


@app.patch("/insights/{insight_id}/read")
def mark_insight_read(insight_id: str, db: Session = Depends(get_db)):
    """Mark a specific insight as read."""
    insight = db.query(UserInsight).filter(UserInsight.id == insight_id).first()
    if not insight:
        raise HTTPException(status_code=404, detail="Insight not found")
    insight.read = "true"
    db.commit()
    return {"status": "ok"}


@app.get("/profile/{user_id}")
def get_profile(user_id: str, db: Session = Depends(get_db)):
    """Returns the synthesized investment profile for a user."""
    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if not profile:
        raise HTTPException(status_code=404, detail="No profile found for this user yet")
    return {
        "user_id": profile.user_id,
        "risk_tolerance": profile.risk_tolerance,
        "investment_style": profile.investment_style,
        "preferred_zipcodes": profile.preferred_zipcodes,
        "price_range_min": profile.price_range_min,
        "price_range_max": profile.price_range_max,
        "target_cash_flow": profile.target_cash_flow,
        "investment_horizon": profile.investment_horizon,
        "raw_summary": profile.raw_summary,
        "updated_at": profile.updated_at.isoformat(),
    }


@app.post("/pipeline/run")
def trigger_full_pipeline():
    """Manually trigger the full market pipeline. Use for testing."""
    import threading
    threading.Thread(target=run_market_pipeline, daemon=True).start()
    return {"status": "Pipeline started in background"}


@app.post("/pipeline/profiles")
def trigger_profile_synthesis():
    """Manually trigger profile synthesis for all users."""
    import threading
    threading.Thread(target=run_profile_pipeline, daemon=True).start()
    return {"status": "Profile synthesis started in background"}


from agents.area_researcher import research_area, deep_research, answer_followup, get_us_housing_news

# Cache so we don't re-research the same area repeatedly
_area_report_cache = {}
_deep_report_cache = {}
_housing_news_cache = {"data": None, "fetched_at": None}


class AreaResearchRequest(BaseModel):
    area_input: str


class FollowupRequest(BaseModel):
    area_input: str
    question: str


@app.post("/area-report")
def get_area_report(req: AreaResearchRequest, db: Session = Depends(get_db)):
    area_input = req.area_input.strip()
    if not area_input:
        raise HTTPException(status_code=400, detail="area_input is required")
    if area_input in _area_report_cache:
        print(f"[AreaReport] Cache hit for: {area_input}")
        return _area_report_cache[area_input]
    try:
        report = research_area(area_input)
        _area_report_cache[area_input] = report
        try:
            track_event(db, "system", "area_research", {"area": area_input})
        except Exception:
            pass
        return report
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Research failed: {str(e)}")


@app.post("/area-report/deep")
def get_deep_report(req: AreaResearchRequest):
    area_input = req.area_input.strip()
    if not area_input:
        raise HTTPException(status_code=400, detail="area_input is required")
    if area_input in _deep_report_cache:
        print(f"[DeepReport] Cache hit for: {area_input}")
        return _deep_report_cache[area_input]
    try:
        report = deep_research(area_input)
        _deep_report_cache[area_input] = report
        return report
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Deep research failed: {str(e)}")


@app.post("/area-report/followup")
def area_followup(req: FollowupRequest):
    # Check both caches
    report = _deep_report_cache.get(req.area_input) or _area_report_cache.get(req.area_input)
    if not report:
        raise HTTPException(status_code=404, detail="No report found. Call /area-report first.")
    try:
        answer = answer_followup(req.area_input, req.question, report)
        return {"answer": answer}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Followup failed: {str(e)}")


@app.get("/housing-news")
def get_housing_news():
    """Returns recent US housing market news for the Insights tab default cards."""
    from datetime import timedelta
    import datetime as dt
    cache = _housing_news_cache
    if cache["data"] and cache["fetched_at"]:
        age = dt.datetime.utcnow() - cache["fetched_at"]
        if age < timedelta(hours=6):
            return {"news": cache["data"]}
    try:
        news = get_us_housing_news()
        _housing_news_cache["data"] = news
        _housing_news_cache["fetched_at"] = dt.datetime.utcnow()
        return {"news": news}
    except Exception as e:
        return {"news": [], "error": str(e)}


@app.post("/pipeline/run")
def trigger_full_pipeline():
    """Manually trigger the full market pipeline. Use for testing."""
    import threading
    threading.Thread(target=run_market_pipeline, daemon=True).start()
    return {"status": "Pipeline started in background"}


@app.post("/pipeline/profiles")
def trigger_profile_synthesis():
    """Manually trigger profile synthesis for all users."""
    import threading
    threading.Thread(target=run_profile_pipeline, daemon=True).start()
    return {"status": "Profile synthesis started in background"}


from agents.area_researcher import research_area, deep_research, answer_followup, get_us_housing_news

# Cache so we don't re-research the same area repeatedly
_area_report_cache = {}


class AreaResearchRequest(BaseModel):
    area_input: str  # anything: zipcode, address, neighborhood, city


class FollowupRequest(BaseModel):
    area_input: str
    question: str


@app.post("/area-report")
def get_area_report(req: AreaResearchRequest, db: Session = Depends(get_db)):
    """
    Triggers the Area Researcher Agent to autonomously research any area.
    Input can be a zipcode, address, neighborhood name, or city.
    Results are cached so repeat calls are instant.
    """
    area_input = req.area_input.strip()
    if not area_input:
        raise HTTPException(status_code=400, detail="area_input is required")

    if area_input in _area_report_cache:
        print(f"[AreaReport] Cache hit for: {area_input}")
        return _area_report_cache[area_input]

    try:
        report = research_area(area_input)
        _area_report_cache[area_input] = report

        try:
            track_event(db, "system", "area_research", {"area": area_input})
        except Exception:
            pass

        return report
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Research failed: {str(e)}")


@app.post("/area-report/followup")
def area_followup(req: FollowupRequest):
    """Answer a follow-up question using already-cached report data."""
    if req.area_input not in _area_report_cache:
        raise HTTPException(
            status_code=404,
            detail="No report found for this area. Call /area-report first."
        )
    try:
        answer = answer_followup(
            req.area_input,
            req.question,
            _area_report_cache[req.area_input]
        )
        return {"answer": answer}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Followup failed: {str(e)}")
