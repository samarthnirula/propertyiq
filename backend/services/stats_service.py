import csv
import os
import re
from typing import Dict, Optional, Tuple

import requests
from dotenv import load_dotenv

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # backend/
SERVICES_DIR = os.path.join(BASE_DIR, "services")
load_dotenv(os.path.join(BASE_DIR, ".env"), override=True)

DATASET_PATH = os.path.join(SERVICES_DIR, "zip_market_dataset.csv")
CRIME_PATH = os.path.join(SERVICES_DIR, "tx_county_crime_data.txt")

CENSUS_API_KEY = (
    os.getenv("CENSUS_API_KEY", "").strip()
    or os.getenv("CENSUSDATA_API_KEY", "").strip()
)
FRED_API_KEY = os.getenv("FRED_API_KEY", "").strip()
GEOAPIFY_API_KEY = os.getenv("GEOAPIFY_API_KEY", "").strip()


# ---------------------------------------------------------------------
# HELPERS
# ---------------------------------------------------------------------
def safe_float(v, default=None):
    try:
        if v in (None, "", "null", ".", "None"):
            return default
        return float(v)
    except Exception:
        return default


def safe_int(v, default=None):
    try:
        if v in (None, "", "null", ".", "None"):
            return default
        return int(float(v))
    except Exception:
        return default


def clean_zip(value: str) -> str:
    value = (value or "").strip()
    m = re.search(r"\b(\d{5})\b", value)
    return m.group(1) if m else ""


def county_key(name: Optional[str]) -> str:
    if not name:
        return ""
    s = name.strip().lower()
    if s.endswith(" county"):
        s = s[:-7].strip()
    return s


def money_text(v: Optional[int]) -> str:
    if v is None:
        return "unknown"
    return f"${v:,.0f}"


def pct_text(v: Optional[float]) -> str:
    if v is None:
        return "unknown"
    return f"{v:.1f}%"


# ---------------------------------------------------------------------
# ZIP INFERENCE
# ---------------------------------------------------------------------
def infer_zipcode_from_area_input(area_input: str) -> Optional[str]:
    area_input = (area_input or "").strip()

    zip_code = clean_zip(area_input)
    if zip_code:
        return zip_code

    if GEOAPIFY_API_KEY:
        try:
            url = "https://api.geoapify.com/v1/geocode/autocomplete"
            r = requests.get(
                url,
                params={
                    "text": area_input,
                    "limit": 1,
                    "filter": "countrycode:us",
                    "apiKey": GEOAPIFY_API_KEY,
                },
                timeout=10,
            )
            r.raise_for_status()
            payload = r.json()
            results = payload.get("results", [])
            if results:
                maybe_zip = clean_zip(results[0].get("postcode", "") or "")
                if maybe_zip:
                    return maybe_zip
        except Exception:
            pass

    return None


# ---------------------------------------------------------------------
# LOCAL DATA LOADERS
# ---------------------------------------------------------------------
def load_dataset() -> Dict[str, Dict]:
    by_zip: Dict[str, Dict] = {}
    if not os.path.exists(DATASET_PATH):
        return by_zip

    with open(DATASET_PATH, newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            z = clean_zip(row.get("zip_code", ""))
            if not z:
                continue
            by_zip[z] = row

    return by_zip


def load_crime_by_county() -> Dict[str, float]:
    crime = {}
    if not os.path.exists(CRIME_PATH):
        return crime

    with open(CRIME_PATH, "r", encoding="utf-8-sig") as f:
        for line in f:
            line = line.strip()
            if not line or "," not in line:
                continue
            county, value = line.split(",", 1)
            crime[county_key(county)] = safe_float(value, 0.0) or 0.0

    return crime


# ---------------------------------------------------------------------
# EXTERNAL DATA
# ---------------------------------------------------------------------
def fetch_census_zip_stats(zip_code: str) -> Dict[str, Optional[float]]:
    if not CENSUS_API_KEY:
        return {
            "median_household_income": None,
            "population_current": None,
            "population_previous": None,
            "owner_occupied_units": None,
            "renter_occupied_units": None,
        }

    vars_needed = [
        "B19013_001E",  # median household income
        "B01003_001E",  # population
        "B25003_002E",  # owner occupied
        "B25003_003E",  # renter occupied
    ]

    def _fetch(year: int):
        url = f"https://api.census.gov/data/{year}/acs/acs5"
        r = requests.get(
            url,
            params={
                "get": ",".join(vars_needed),
                "for": f"zip code tabulation area:{zip_code}",
                "key": CENSUS_API_KEY,
            },
            timeout=15,
        )
        r.raise_for_status()
        data = r.json()
        if len(data) < 2:
            return None
        return dict(zip(data[0], data[1]))

    try:
        current = _fetch(2023)
    except Exception:
        current = None

    try:
        previous = _fetch(2022)
    except Exception:
        previous = None

    return {
        "median_household_income": safe_int(current.get("B19013_001E")) if current else None,
        "population_current": safe_int(current.get("B01003_001E")) if current else None,
        "population_previous": safe_int(previous.get("B01003_001E")) if previous else None,
        "owner_occupied_units": safe_int(current.get("B25003_002E")) if current else None,
        "renter_occupied_units": safe_int(current.get("B25003_003E")) if current else None,
    }


def fetch_unemployment_signal() -> Tuple[Optional[float], Optional[str], Optional[str]]:
    if not FRED_API_KEY:
        return None, None, None

    try:
        url = "https://api.stlouisfed.org/fred/series/observations"
        r = requests.get(
            url,
            params={
                "series_id": "UNRATE",
                "api_key": FRED_API_KEY,
                "file_type": "json",
                "sort_order": "desc",
                "limit": 2,
            },
            timeout=12,
        )
        r.raise_for_status()
        obs = r.json().get("observations", [])
        if len(obs) < 2:
            return None, None, None

        latest = safe_float(obs[0].get("value"))
        previous = safe_float(obs[1].get("value"))

        trend_pct = None
        if latest is not None and previous not in (None, 0):
            trend_pct = round(latest - previous, 1)

        if trend_pct is None:
            metro_labor_trend = None
            macro_signal = None
        elif trend_pct > 0:
            metro_labor_trend = "Broader labor conditions softened slightly in the latest reading. This is a macro reference point and not a ZIP-specific labor measure."
            macro_signal = "Labor conditions appear mixed but stable; mortgage-rate sensitivity may continue to shape buyer affordability."
        elif trend_pct < 0:
            metro_labor_trend = "Broader labor conditions improved slightly in the latest reading. This is a macro reference point and not a ZIP-specific labor measure."
            macro_signal = "Labor conditions improved modestly; affordability and buyer confidence may receive some support."
        else:
            metro_labor_trend = "Labor conditions were mostly unchanged in the latest reading. This is a macro reference point and not a ZIP-specific labor measure."
            macro_signal = "Macro conditions appear relatively stable; affordability trends may remain the key constraint."
        return trend_pct, metro_labor_trend, macro_signal
    except Exception:
        return None, None, None


# ---------------------------------------------------------------------
# FORECASTING
# ---------------------------------------------------------------------
def build_forecast_prices(
    current_price: Optional[int],
    zhvi_1y_change_pct: Optional[float],
    population_change_pct: Optional[float],
    owner_share_pct: Optional[float],
    price_to_rent_ratio: Optional[float],
) -> Dict[str, Optional[float]]:
    if current_price is None or current_price <= 0:
        return {
            "forecast_current_price": None,
            "forecast_q1_price": None,
            "forecast_q2_price": None,
            "forecast_q3_price": None,
            "forecast_q4_price": None,
            "forecast_q1_growth_pct": None,
            "forecast_q2_growth_pct": None,
            "forecast_q3_growth_pct": None,
            "forecast_q4_growth_pct": None,
        }

    annual_trend = zhvi_1y_change_pct or 0.0
    pop_boost = min(max((population_change_pct or 0.0) * 0.10, -1.0), 1.0)
    owner_boost = 0.15 if (owner_share_pct or 0.0) >= 65 else 0.0
    ptr_drag = -0.15 if (price_to_rent_ratio or 0.0) >= 22 else 0.0

    adjusted_annual = annual_trend + pop_boost + owner_boost + ptr_drag
    adjusted_annual = max(min(adjusted_annual, 8.0), -8.0)

    q_growth = adjusted_annual / 4.0

    q1_growth_pct = round(q_growth, 1)
    q2_growth_pct = round(q_growth, 1)
    q3_growth_pct = round(q_growth * 0.9, 1)
    q4_growth_pct = round(q_growth * 0.9, 1)

    q1_price = round(current_price * (1 + q1_growth_pct / 100.0))
    q2_price = round(q1_price * (1 + q2_growth_pct / 100.0))
    q3_price = round(q2_price * (1 + q3_growth_pct / 100.0))
    q4_price = round(q3_price * (1 + q4_growth_pct / 100.0))

    return {
        "forecast_current_price": int(current_price),
        "forecast_q1_price": int(q1_price),
        "forecast_q2_price": int(q2_price),
        "forecast_q3_price": int(q3_price),
        "forecast_q4_price": int(q4_price),
        "forecast_q1_growth_pct": q1_growth_pct,
        "forecast_q2_growth_pct": q2_growth_pct,
        "forecast_q3_growth_pct": q3_growth_pct,
        "forecast_q4_growth_pct": q4_growth_pct,
    }


def forecast_confidence_label(listing_count: Optional[int], median_rent: Optional[int]) -> str:
    if (listing_count or 0) >= 8 and (median_rent or 0) > 0:
        return "Moderate"
    if (listing_count or 0) >= 3:
        return "Limited"
    return "Limited"


# ---------------------------------------------------------------------
# MAIN AREA STATS BUILDER
# ---------------------------------------------------------------------
def get_area_stats_simple(zip_code: str, area_input: Optional[str] = None) -> Dict:
    zip_code = clean_zip(zip_code)
    if not zip_code:
        raise ValueError("Invalid ZIP code")

    dataset = load_dataset()
    crime_by_county = load_crime_by_county()

    row = dataset.get(zip_code)
    if not row:
        raise ValueError(f"ZIP {zip_code} not found in dataset")

    census = fetch_census_zip_stats(zip_code)

    county_name = row.get("county", "") or ""
    county_name_display = f"{county_name.title()} County" if county_name else None
    county_crime_rate = crime_by_county.get(county_key(county_name))

    median_household_income = (
        census["median_household_income"]
        if census["median_household_income"] is not None
        else safe_int(row.get("median_income"))
    )

    population_current = census["population_current"]
    population_previous = census["population_previous"]
    population_change_pct = safe_float(row.get("population_change_pct"))
    if population_current not in (None, 0) and population_previous not in (None, 0):
        population_change_pct = round(
            ((population_current - population_previous) / population_previous) * 100.0,
            1,
        )

    owner_occupied_units = census["owner_occupied_units"]
    renter_occupied_units = census["renter_occupied_units"]

    owner_share_pct = safe_float(row.get("owner_share_pct"))
    renter_share_pct = None
    if owner_occupied_units is not None and renter_occupied_units is not None:
        total_occ = owner_occupied_units + renter_occupied_units
        if total_occ > 0:
            owner_share_pct = round((owner_occupied_units / total_occ) * 100.0, 1)
            renter_share_pct = round((renter_occupied_units / total_occ) * 100.0, 1)

    if renter_share_pct is None and owner_share_pct is not None:
        renter_share_pct = round(100.0 - owner_share_pct, 1)

    average_property_price = safe_int(row.get("avg_property_value"))
    median_rent_estimate = safe_int(row.get("median_rent"))
    zhvi_1y_change_pct = safe_float(row.get("zhvi_1y_change_pct"))
    price_to_rent_ratio = safe_float(row.get("price_to_rent_ratio"))
    listing_count = safe_int(row.get("listing_count"), 0)

    county_unemployment_trend_pct, metro_labor_trend, macro_signal = fetch_unemployment_signal()

    forecast = build_forecast_prices(
        current_price=average_property_price,
        zhvi_1y_change_pct=zhvi_1y_change_pct,
        population_change_pct=population_change_pct,
        owner_share_pct=owner_share_pct,
        price_to_rent_ratio=price_to_rent_ratio,
    )

    if owner_share_pct is not None and renter_share_pct is not None:
        housing_stats_summary = (
            "The housing mix appears owner-skewed based on occupied unit counts. "
            "Population appears relatively stable over the available ACS comparison window."
            if owner_share_pct >= 60
            else "The housing mix is more renter-balanced, which may indicate a somewhat more fluid local housing profile."
        )
    else:
        housing_stats_summary = "Housing composition data is limited for this ZIP."

    if price_to_rent_ratio is None:
        price_rent_context = "Price-to-rent context is limited because rent support is incomplete."
    elif price_to_rent_ratio < 14:
        price_rent_context = "The price-to-rent relationship suggests relatively strong rent support compared with pricing, which may help screening for yield-oriented scenarios."
    elif price_to_rent_ratio < 20:
        price_rent_context = "The price-to-rent relationship suggests a moderate gross yield profile, which may support balanced screening rather than pure appreciation assumptions."
    else:
        price_rent_context = "The price-to-rent relationship suggests prices are elevated relative to rent, so appreciation assumptions may matter more than pure cash-flow screening."

    notes = []
    if zhvi_1y_change_pct is None:
        notes.append("Historical price trend unavailable for this ZIP.")
    if listing_count == 0:
        notes.append("Listing comp count unavailable for this ZIP.")

    forecast_summary = (
        "The model suggests a mild upward price path over the next four quarters. "
        "This outlook is based on observed price level, recent market trend, rent support, income, population trend, housing mix, live comps, and broad macro context. "
        f"Live comp count used in calibration: {listing_count}. "
        "It should be treated as a screening estimate rather than a formal valuation."
        if average_property_price
        else "Forecast unavailable because current pricing data is incomplete."
    )

    forecast_confidence = forecast_confidence_label(listing_count, median_rent_estimate)

    result = {
        "label": area_input or zip_code,

        "median_household_income": median_household_income,
        "population_change_pct": population_change_pct,

        "owner_occupied_units": owner_occupied_units,
        "renter_occupied_units": renter_occupied_units,
        "owner_share_pct": owner_share_pct,
        "renter_share_pct": renter_share_pct,

        "average_property_price": average_property_price,
        "median_rent_estimate": median_rent_estimate,

        "housing_stats_summary": housing_stats_summary,
        "price_rent_context": price_rent_context,

        "county_unemployment_trend_pct": county_unemployment_trend_pct,
        "metro_labor_trend": metro_labor_trend,
        "macro_signal": macro_signal,

        "county_name": county_name_display,
        "county_crime_rate": county_crime_rate,
        "latitude": safe_float(row.get("latitude")),
        "longitude": safe_float(row.get("longitude")),

        "forecast_current_price": forecast["forecast_current_price"],
        "forecast_q1_price": forecast["forecast_q1_price"],
        "forecast_q2_price": forecast["forecast_q2_price"],
        "forecast_q3_price": forecast["forecast_q3_price"],
        "forecast_q4_price": forecast["forecast_q4_price"],

        "forecast_q1_growth_pct": forecast["forecast_q1_growth_pct"],
        "forecast_q2_growth_pct": forecast["forecast_q2_growth_pct"],
        "forecast_q3_growth_pct": forecast["forecast_q3_growth_pct"],
        "forecast_q4_growth_pct": forecast["forecast_q4_growth_pct"],

        "forecast_summary": forecast_summary,
        "forecast_confidence": forecast_confidence,

        "notes": " | ".join(notes) if notes else None,
    }

    return result