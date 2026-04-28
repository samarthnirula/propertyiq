import os
from typing import Optional

import requests
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import Response

from agents.area_researcher import answer_followup, deep_research, research_area
from models.calc_models import CalculationRequest, CalculationResponse
from services.calculator_service import compute_financials
from services.listing_search import search_listings
from services.news_service import get_housing_news
from services.pipeline_runner import run_market_pipeline, run_profile_pipeline
from services.predictor_service import run_prediction_for_zip
from services.stats_service import (
    get_area_stats_simple,
    infer_zipcode_from_area_input,
)

BASE_DIR = os.path.dirname(os.path.abspath(__file__))  # backend/
load_dotenv(os.path.join(BASE_DIR, ".env"), override=True)

GEOAPIFY_API_KEY = os.getenv("GEOAPIFY_API_KEY", "").strip()
RENTCAST_API_KEY = os.getenv("RENTCAST_API_KEY", "").strip()
CENSUS_API_KEY = os.getenv("CENSUS_API_KEY", "").strip()
FRED_API_KEY = os.getenv("FRED_API_KEY", "").strip()
GEOCODIO_API_KEY = os.getenv("GEOCODIO_API_KEY", "").strip()
SIMPLYRETS_API_KEY = os.getenv("SIMPLYRETS_API_KEY", "").strip()
SIMPLYRETS_API_SECRET = os.getenv("SIMPLYRETS_API_SECRET", "").strip()

API_STATUS = {}
REPORT_CACHE = {}


def _check_geoapify():
    if not GEOAPIFY_API_KEY:
        return "MISSING_KEY"
    try:
        url = "https://api.geoapify.com/v1/geocode/autocomplete"
        r = requests.get(
            url,
            params={"text": "75022", "limit": 1, "apiKey": GEOAPIFY_API_KEY},
            timeout=8,
        )
        if r.status_code == 200:
            return "CONNECTED - Autocomplete reachable"
        return f"ERROR {r.status_code}"
    except Exception as e:
        return f"FAILED - {e}"


def _check_rentcast():
    if not RENTCAST_API_KEY:
        return "MISSING_KEY"
    try:
        url = "https://api.rentcast.io/v1/markets"
        r = requests.get(
            url,
            headers={"X-Api-Key": RENTCAST_API_KEY},
            params={"zipCode": "75022", "limit": 1},
            timeout=8,
        )
        if r.status_code == 200:
            return "CONNECTED - Markets endpoint reachable"
        return f"ERROR {r.status_code}"
    except Exception as e:
        return f"FAILED - {e}"


def _check_census():
    if not CENSUS_API_KEY:
        return "MISSING_KEY"
    try:
        url = "https://api.census.gov/data/2023/acs/acs5"
        r = requests.get(
            url,
            params={
                "get": "B19013_001E",
                "for": "zip code tabulation area:75022",
                "key": CENSUS_API_KEY,
            },
            timeout=8,
        )
        if r.status_code == 200:
            return "CONNECTED - ACS endpoint reachable"
        return f"ERROR {r.status_code}"
    except Exception as e:
        return f"FAILED - {e}"


def _check_fred():
    if not FRED_API_KEY:
        return "MISSING_KEY"
    try:
        url = "https://api.stlouisfed.org/fred/series/observations"
        r = requests.get(
            url,
            params={
                "series_id": "UNRATE",
                "api_key": FRED_API_KEY,
                "file_type": "json",
                "limit": 1,
            },
            timeout=8,
        )
        if r.status_code == 200:
            return "CONNECTED - FRED endpoint reachable"
        return f"ERROR {r.status_code}"
    except Exception as e:
        return f"FAILED - {e}"


def _check_geocodio():
    if not GEOCODIO_API_KEY:
        return "MISSING_KEY"
    try:
        url = "https://api.geocod.io/v1.7/geocode"
        r = requests.get(
            url,
            params={"q": "75022", "api_key": GEOCODIO_API_KEY},
            timeout=8,
        )
        if r.status_code == 200:
            return "CONNECTED - Geocodio endpoint reachable"
        return f"ERROR {r.status_code}"
    except Exception as e:
        return f"FAILED - {e}"


def _check_simplyrets():
    if not SIMPLYRETS_API_KEY:
        return "MISSING_KEY"

    try:
        url = "https://api.simplyrets.com/properties"

        # 🔥 fallback: allow missing secret
        if SIMPLYRETS_API_SECRET:
            auth = (SIMPLYRETS_API_KEY, SIMPLYRETS_API_SECRET)
        else:
            auth = (SIMPLYRETS_API_KEY, "")

        r = requests.get(
            url,
            auth=auth,
            params={"limit": 1},
            timeout=8,
        )

        if r.status_code == 200:
            return "CONNECTED - Properties endpoint reachable"
        return f"ERROR {r.status_code}"

    except Exception as e:
        return f"FAILED - {e}"


def refresh_api_status():
    API_STATUS.clear()

    API_STATUS["GEOAPIFY"] = _check_geoapify()
    API_STATUS["RENTCAST"] = _check_rentcast()
    API_STATUS["CENSUS"] = _check_census()
    API_STATUS["FRED"] = _check_fred()
    API_STATUS["GEOCODIO"] = _check_geocodio()
    API_STATUS["SIMPLYRETS"] = _check_simplyrets()

    print("ENV CHECK:")
    print("GEOAPIFY_API_KEY set:", bool(GEOAPIFY_API_KEY))
    print("RENTCAST_API_KEY set:", bool(RENTCAST_API_KEY))
    print("CENSUS_API_KEY set:", bool(CENSUS_API_KEY))
    print("FRED_API_KEY set:", bool(FRED_API_KEY))
    print("GEOCODIO_API_KEY set:", bool(GEOCODIO_API_KEY))
    print("SIMPLYRETS_API_KEY set:", bool(SIMPLYRETS_API_KEY))
    print("SIMPLYRETS_API_SECRET set:", bool(SIMPLYRETS_API_SECRET))

    print("BACKEND STARTUP: API STATUS")
    print("==============================")
    for name, status in API_STATUS.items():
        print(f"{name}: {status}")
    print("==============================\n")


app = FastAPI(title="PropertyIQ Backend")


@app.on_event("startup")
async def startup_event():
    print("\n🚀 Starting PropertyIQ Backend...")
    print("[Startup] Skipping database initialization.")
    refresh_api_status()
    print("✅ Backend is fully initialized and ready.\n")


app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    return {"message": "PropertyIQ backend running"}


@app.get("/health")
def health():
    return {"ok": True, "api_status": API_STATUS}


@app.get("/debug/api-status")
def debug_api_status():
    return API_STATUS


@app.get("/autocomplete")
def autocomplete(q: str = Query(..., min_length=2)):
    if not GEOAPIFY_API_KEY:
        raise HTTPException(status_code=500, detail="GEOAPIFY_API_KEY missing")

    url = "https://api.geoapify.com/v1/geocode/autocomplete"
    try:
        r = requests.get(
            url,
            params={
                "text": q,
                "limit": 8,
                "format": "json",
                "apiKey": GEOAPIFY_API_KEY,
                "filter": "countrycode:us",
            },
            timeout=12,
        )
        r.raise_for_status()
        payload = r.json()
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Autocomplete failed: {e}")

    results = []
    for item in payload.get("results", []):
        formatted = item.get("formatted") or item.get("address_line1") or q
        results.append(
            {
                "formatted": formatted,
                "lat": item.get("lat"),
                "lon": item.get("lon"),
            }
        )

    return results


@app.get("/listings")
def listings(
    q: Optional[str] = None,
    city: Optional[str] = None,
    limit: int = Query(12, ge=1, le=50),
    offset: int = Query(0, ge=0),
):
    try:
        return search_listings(query=q, city=city, limit=limit, offset=offset)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Listing search failed: {e}")


@app.get("/image-proxy")
def image_proxy(url: str):
    try:
        r = requests.get(url, timeout=20)
        r.raise_for_status()
        content_type = r.headers.get("Content-Type", "image/jpeg")
        return Response(content=r.content, media_type=content_type)
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Image proxy failed: {e}")


@app.post("/calculate", response_model=CalculationResponse)
def calculate(req: CalculationRequest):
    try:
        result = compute_financials(req)
        return CalculationResponse(**result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Calculation failed: {e}")


@app.get("/area-stats")
def area_stats(
    area_input: str = Query(..., description="Area label from search box"),
    zipcode: Optional[str] = Query(None, description="Optional zipcode override"),
):
    zip_code = zipcode or infer_zipcode_from_area_input(area_input)

    if not zip_code:
        raise HTTPException(
            status_code=400,
            detail="Could not determine zipcode from input",
        )

    try:
        stats = get_area_stats_simple(zip_code, area_input=area_input)

        try:
            prediction_result = run_prediction_for_zip(zip_code)
        except Exception as e:
            print(f"[ML] Prediction failed for {zip_code}: {e}")
            prediction_result = None

        if prediction_result:
            stats["algorithm_prediction"] = prediction_result.get("predicted_value")
            stats["algorithm_error_pct"] = prediction_result.get("error_pct")
            stats["algorithm_k_used"] = prediction_result.get("k")
            stats["algorithm_neighbors"] = prediction_result.get("neighbors", [])
            stats["algorithm_confidence_score"] = prediction_result.get("confidence_score")
        else:
            stats["algorithm_prediction"] = None
            stats["algorithm_error_pct"] = None
            stats["algorithm_k_used"] = None
            stats["algorithm_neighbors"] = []
            stats["algorithm_confidence_score"] = None

        return stats

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Stats generation failed: {str(e)}",
        )


@app.get("/area-report")
def area_report(area_input: str = Query(...)):
    cache_key = ("report", area_input.strip().lower())
    if cache_key in REPORT_CACHE:
        return REPORT_CACHE[cache_key]

    try:
        result = research_area(area_input)
        REPORT_CACHE[cache_key] = result
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Area report failed: {e}")


@app.get("/area-report/deep")
def area_report_deep(area_input: str = Query(...)):
    cache_key = ("deep", area_input.strip().lower())
    if cache_key in REPORT_CACHE:
        return REPORT_CACHE[cache_key]

    try:
        result = deep_research(area_input)
        REPORT_CACHE[cache_key] = result
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Deep area report failed: {e}")


@app.get("/area-report/followup")
def area_report_followup(
    area_input: str = Query(...),
    question: str = Query(...),
):
    try:
        return answer_followup(area_input, question)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Follow-up failed: {e}")


@app.get("/housing-news")
def housing_news():
    try:
        return get_housing_news()
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"News fetch failed: {e}")


@app.post("/pipeline/run")
def pipeline_run():
    try:
        result = run_market_pipeline()
        return {"ok": True, "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Pipeline run failed: {e}")


@app.post("/pipeline/profiles")
def pipeline_profiles():
    try:
        result = run_profile_pipeline()
        return {"ok": True, "result": result}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Profile pipeline failed: {e}")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)