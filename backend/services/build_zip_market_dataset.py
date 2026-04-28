import csv
import os
import re
import time
from typing import Dict, List, Optional, Tuple

import requests
from dotenv import load_dotenv

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # backend/
SERVICES_DIR = os.path.join(BASE_DIR, "services")

load_dotenv(os.path.join(BASE_DIR, ".env"), override=True)

# ---------------------------------------------------------------------
# FILES
# ---------------------------------------------------------------------
ZILLOW_ZHVI_CSV = os.path.join(SERVICES_DIR, "zhvi_zip.csv")
ZILLOW_ZORI_CSV = os.path.join(SERVICES_DIR, "zori_zip.csv")
HUD_ZIP_COUNTY_CSV = os.path.join(SERVICES_DIR, "hud_zip_county_crosswalk.csv")
CENSUS_ZCTA_GAZETTEER = os.path.join(SERVICES_DIR, "zcta_gazetteer.txt")

CURRENT_DATASET_CSV = os.path.join(SERVICES_DIR, "zip_market_dataset.csv")
OUTPUT_DATASET_CSV = os.path.join(SERVICES_DIR, "zip_market_dataset_generated.csv")

STATE_CODE_TX = "48"
ACS_YEAR_CURRENT = 2023
ACS_YEAR_PREVIOUS = 2022

CENSUS_API_KEY = (
    os.getenv("CENSUS_API_KEY", "").strip()
    or os.getenv("CENSUSDATA_API_KEY", "").strip()
)

def print_api_status():
    print("\n==============================")
    print("API CONNECTION STATUS")
    print("==============================")

    print(f"CENSUS API: {'CONNECTED' if CENSUS_API_KEY else 'NOT CONNECTED'}")

    geo = os.getenv("GEOAPIFY_API_KEY", "").strip()
    fred = os.getenv("FRED_API_KEY", "").strip()
    rets_key = os.getenv("SIMPLYRETS_API_KEY", "").strip()
    rets_secret = os.getenv("SIMPLYRETS_API_SECRET", "").strip()

    print(f"GEOAPIFY: {'CONNECTED' if geo else 'NOT CONNECTED'}")
    print(f"FRED: {'CONNECTED' if fred else 'NOT CONNECTED'}")
    print(f"SIMPLYRETS: {'CONNECTED' if (rets_key and rets_secret) else 'NOT CONNECTED'}")

    print("==============================\n")


def detect_data_mode(zhvi_count: int):
    print("\n==============================")
    print("DATA MODE")
    print("==============================")

    if zhvi_count < 300:
        print("⚠️  RUNNING IN SAMPLE DATA MODE")
    else:
        print("✅ RUNNING IN FULL DATA MODE")

    print("==============================\n")
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


def clean_zip(z: str) -> str:
    z = (z or "").strip()
    match = re.search(r"\b(\d{5})\b", z)
    return match.group(1) if match else ""


def county_key(name: Optional[str]) -> str:
    if not name:
        return ""
    s = name.strip().lower()
    if s.endswith(" county"):
        s = s[:-7].strip()
    return s


def pct_change(current: Optional[float], previous: Optional[float]) -> Optional[float]:
    if current in (None, 0) or previous in (None, 0):
        return None
    try:
        return round(((current - previous) / previous) * 100.0, 2)
    except Exception:
        return None


def price_to_rent_ratio(price: Optional[float], monthly_rent: Optional[float]) -> Optional[float]:
    if price in (None, 0) or monthly_rent in (None, 0):
        return None
    try:
        annual_rent = monthly_rent * 12.0
        if annual_rent <= 0:
            return None
        return round(price / annual_rent, 2)
    except Exception:
        return None


def find_date_columns(fieldnames: List[str]) -> List[str]:
    return sorted([c for c in fieldnames if re.match(r"^\d{4}-\d{2}-\d{2}$", c)])


def find_xdate_columns(fieldnames: List[str]) -> List[str]:
    return sorted([c for c in fieldnames if re.match(r"^x\d{4}_\d{2}_\d{2}$", c)])


# ---------------------------------------------------------------------
# MARKET TIER + REGION BUCKET + URBAN CORE
# ---------------------------------------------------------------------
def market_tier_from_price(avg_property_value: int) -> str:
    if avg_property_value < 175000:
        return "low"
    if avg_property_value < 400000:
        return "mid"
    if avg_property_value < 800000:
        return "high"
    if avg_property_value < 1200000:
        return "premium"
    if avg_property_value < 2000000:
        return "luxury"
    return "ultra_luxury"


DFW_COUNTIES = {
    "collin", "dallas", "denton", "tarrant", "rockwall", "parker",
    "kaufman", "ellis", "johnson", "wise", "hood", "somervell", "hunt"
}

AUSTIN_COUNTIES = {
    "travis", "williamson", "hays", "bastrop", "caldwell", "blanco", "burnet"
}

HOUSTON_COUNTIES = {
    "harris", "fort bend", "montgomery", "galveston", "brazoria",
    "waller", "liberty", "chambers"
}

SAN_ANTONIO_COUNTIES = {
    "bexar", "comal", "guadalupe", "kendall", "wilson", "medina", "atascosa"
}

EAST_TEXAS_COUNTIES = {
    "smith", "gregg", "harrison", "rusk", "upshur", "morris", "cherokee",
    "nacogdoches", "panola", "camp", "wood", "henderson", "angelina"
}

WEST_TEXAS_COUNTIES = {
    "midland", "ector", "el paso", "tom green", "howard", "ward", "winkler",
    "reeves", "pecos", "brewster", "presidio", "jeff davis", "culberson",
    "hudspeth", "crane", "upton", "martin"
}

PANHANDLE_COUNTIES = {
    "potter", "randall", "lubbock", "wheeler", "moore", "hutchinson",
    "dallam", "hartley", "deaf smith", "carson", "gray", "oldham",
    "parmer", "swisher", "hale"
}

SOUTH_TEXAS_COUNTIES = {
    "hidalgo", "cameron", "webb", "starr", "zapata", "brooks", "jim wells",
    "kleberg", "nueces", "san patricio", "willacy", "duval", "jim hogg"
}

GULF_COAST_COUNTIES = {
    "galveston", "brazoria", "calhoun", "victoria", "matagorda", "wharton",
    "jackson", "aransas", "refugio"
}

CENTRAL_TEXAS_COUNTIES = {
    "mclennan", "bell", "coryell", "bosque", "falls",
    "lampasas", "milam", "mason", "llano", "lee", "fayette", "washington"
}


def region_bucket_from_zip_county(zip_code: str, county: str) -> str:
    county = county_key(county)

    if county in DFW_COUNTIES:
        return "DFW"
    if county in AUSTIN_COUNTIES:
        return "Austin"
    if county in HOUSTON_COUNTIES:
        return "Houston"
    if county in SAN_ANTONIO_COUNTIES:
        return "SanAntonio"
    if county in EAST_TEXAS_COUNTIES:
        return "EastTexas"
    if county in WEST_TEXAS_COUNTIES:
        return "WestTexas"
    if county in PANHANDLE_COUNTIES:
        return "Panhandle"
    if county in SOUTH_TEXAS_COUNTIES:
        return "SouthTexas"
    if county in GULF_COAST_COUNTIES:
        return "GulfCoast"
    if county in CENTRAL_TEXAS_COUNTIES:
        return "CentralTexas"

    prefix2 = zip_code[:2] if len(zip_code) >= 2 else ""
    prefix3 = zip_code[:3] if len(zip_code) >= 3 else ""

    if prefix2 in {"75", "76"}:
        return "DFW"
    if prefix3 in {"786", "787"}:
        return "Austin"
    if prefix2 == "77":
        return "Houston"
    if prefix3 in {"780", "781", "782"}:
        return "SanAntonio"
    if prefix2 == "79":
        return "WestTexas"
    if prefix2 == "75" and county in EAST_TEXAS_COUNTIES:
        return "EastTexas"

    return "OtherTX"


def urban_core_flag_from_zip_county(zip_code: str, county: str, region_bucket: str) -> int:
    zip_code = (zip_code or "").strip()
    county = county_key(county)
    region_bucket = (region_bucket or "").strip()

    downtown_zips = {
        "75201", "75202", "75204", "75206", "75207", "75219",
        "77002", "77003", "77004", "77006", "77007", "77019",
        "78701", "78702", "78703", "78704", "78705",
        "78204", "78205", "78210", "78215",
        "76102", "76104", "76107",
    }

    if zip_code in downtown_zips:
        return 1

    if region_bucket in {"Austin", "Houston", "DFW", "SanAntonio"}:
        if county in {"travis", "harris", "dallas", "tarrant", "bexar"}:
            if zip_code.startswith(("752", "770", "787", "782", "761")):
                return 0

    return 0


# ---------------------------------------------------------------------
# EXISTING FALLBACKS
# ---------------------------------------------------------------------
def load_existing_dataset_fallbacks() -> Dict[str, Dict[str, object]]:
    data: Dict[str, Dict[str, object]] = {}
    if not os.path.exists(CURRENT_DATASET_CSV):
        return data

    with open(CURRENT_DATASET_CSV, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        for row in reader:
            z = clean_zip(row.get("zip_code", ""))
            if not z:
                continue

            data[z] = {
                "median_rent": safe_int(row.get("median_rent"), 0),
                "listing_count": safe_int(row.get("listing_count"), 0),
                "average_sqft": safe_int(row.get("average_sqft"), 0),
                "avg_property_value": safe_int(row.get("avg_property_value"), 0),
                "county": county_key(row.get("county")),
                "median_income": safe_int(row.get("median_income"), 0),
                "population_change_pct": safe_float(row.get("population_change_pct"), 0),
                "owner_share_pct": safe_float(row.get("owner_share_pct"), 0),
                "zhvi_1y_change_pct": safe_float(row.get("zhvi_1y_change_pct"), 0),
                "zhvi_5y_change_pct": safe_float(row.get("zhvi_5y_change_pct"), 0),
                "price_to_rent_ratio": safe_float(row.get("price_to_rent_ratio"), 0),
                "market_tier": row.get("market_tier", ""),
                "region_bucket": row.get("region_bucket", ""),
                "urban_core_flag": safe_int(row.get("urban_core_flag"), 0),
            }

    return data


# ---------------------------------------------------------------------
# FLEXIBLE ZILLOW LOADER
# ---------------------------------------------------------------------
def load_zillow_time_series(csv_path: str, mode: str) -> Dict[str, Dict[str, float]]:
    if not os.path.exists(csv_path):
        raise FileNotFoundError(f"Missing Zillow file: {csv_path}")

    out: Dict[str, Dict[str, float]] = {}

    with open(csv_path, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames or []

        date_cols = find_date_columns(fieldnames)
        xdate_cols = find_xdate_columns(fieldnames)
        raw_date_cols = date_cols if date_cols else xdate_cols

        if raw_date_cols:
            latest_idx = len(raw_date_cols) - 1
            one_year_idx = latest_idx - 12 if latest_idx >= 12 else None
            five_year_idx = latest_idx - 60 if latest_idx >= 60 else None

            latest_col = raw_date_cols[latest_idx]
            one_year_col = raw_date_cols[one_year_idx] if one_year_idx is not None else None
            five_year_col = raw_date_cols[five_year_idx] if five_year_idx is not None else None

            for row in reader:
                zip_code = clean_zip(
                    row.get("RegionName")
                    or row.get("region_name")
                    or row.get("Region")
                    or ""
                )
                if not zip_code:
                    continue

                state_name = (
                    row.get("StateName")
                    or row.get("state_name")
                    or row.get("State")
                    or row.get("state")
                    or ""
                ).strip().upper()

                if state_name and state_name != "TX":
                    continue

                latest_val = safe_float(row.get(latest_col))
                one_year_val = safe_float(row.get(one_year_col)) if one_year_col else None
                five_year_val = safe_float(row.get(five_year_col)) if five_year_col else None

                if latest_val is None:
                    continue

                out[zip_code] = {
                    "latest": latest_val,
                    "one_year_ago": one_year_val,
                    "five_years_ago": five_year_val,
                    "precomputed_1y_pct": None,
                    "precomputed_5y_pct": None,
                }

            print(f"Detected raw Zillow time-series format for {os.path.basename(csv_path)}")
            return out

    with open(csv_path, "r", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        fieldnames = reader.fieldnames or []
        lowered = {c.lower(): c for c in fieldnames}

        zip_col = (
            lowered.get("zip_code")
            or lowered.get("zipcode")
            or lowered.get("zip")
            or lowered.get("regionname")
            or lowered.get("region_name")
        )

        if not zip_col:
            raise ValueError(
                f"Could not detect ZIP column in {csv_path}. Found columns: {fieldnames}"
            )

        if mode == "zhvi":
            latest_candidates = [
                "avg_property_value",
                "average_property_price",
                "zhvi",
                "latest",
                "value",
                "home_value",
            ]
        else:
            latest_candidates = [
                "median_rent",
                "rent",
                "zori",
                "latest",
                "value",
            ]

        latest_col = None
        for c in latest_candidates:
            if c in lowered:
                latest_col = lowered[c]
                break

        one_year_col = lowered.get("zhvi_1y_change_pct") if mode == "zhvi" else None
        five_year_col = lowered.get("zhvi_5y_change_pct") if mode == "zhvi" else None

        if latest_col is None:
            raise ValueError(
                f"Could not detect value column in {csv_path}. Found columns: {fieldnames}"
            )

        for row in reader:
            zip_code = clean_zip(row.get(zip_col, ""))
            if not zip_code:
                continue

            latest_val = safe_float(row.get(latest_col))
            if latest_val is None:
                continue

            out[zip_code] = {
                "latest": latest_val,
                "one_year_ago": None,
                "five_years_ago": None,
                "precomputed_1y_pct": safe_float(row.get(one_year_col)) if one_year_col else None,
                "precomputed_5y_pct": safe_float(row.get(five_year_col)) if five_year_col else None,
            }

        print(f"Detected simplified Zillow format for {os.path.basename(csv_path)}")
        return out


# ---------------------------------------------------------------------
# ZIP -> COUNTY NAME
# ---------------------------------------------------------------------
def load_zip_to_county_name() -> Dict[str, str]:
    """
    Simplified fallback version.
    Since we are skipping HUD for now, return any county values that may already
    exist in the current dataset fallback file.
    """
    existing = load_existing_dataset_fallbacks()
    out: Dict[str, str] = {}

    for zip_code, row in existing.items():
        county = county_key(row.get("county"))
        if county:
            out[zip_code] = county

    return out


def get_county_from_row(zip_code: str, fallback_map: Dict[str, str]) -> str:
    county = fallback_map.get(zip_code, "")
    return county if county else "unknown"
# ---------------------------------------------------------------------
# ZCTA / ZIP COORDINATES
# ---------------------------------------------------------------------
def load_zcta_lat_lon() -> Dict[str, Tuple[float, float]]:
    """
    Simplified fallback version.
    Since we are skipping Gazetteer for now, return any lat/lon already present
    in the current dataset fallback file.
    """
    existing = load_existing_dataset_fallbacks()
    out: Dict[str, Tuple[float, float]] = {}

    for zip_code, row in existing.items():
        lat = safe_float(row.get("latitude"))
        lon = safe_float(row.get("longitude"))
        if lat is not None and lon is not None:
            out[zip_code] = (lat, lon)

    return out

# ---------------------------------------------------------------------
# ACS ZIP FEATURES WITH RETRY
# ---------------------------------------------------------------------
def fetch_acs_zip_features(zip_code: str) -> Dict[str, Optional[float]]:
    vars_needed = [
        "B19013_001E",
        "B01003_001E",
        "B25003_002E",
        "B25003_003E",
    ]

    def _fetch(year: int, retries: int = 3):
        url = f"https://api.census.gov/data/{year}/acs/acs5"
        params = {
            "get": ",".join(vars_needed),
            "for": f"zip code tabulation area:{zip_code}",
            "key": CENSUS_API_KEY,
        }

        last_error = None
        for attempt in range(retries):
            try:
                r = requests.get(url, params=params, timeout=20)
                r.raise_for_status()
                data = r.json()
                if len(data) < 2:
                    return None
                return dict(zip(data[0], data[1]))
            except Exception as e:
                last_error = e
                time.sleep(1.2 * (attempt + 1))

        raise last_error

    try:
        current = _fetch(ACS_YEAR_CURRENT)
    except Exception:
        current = None

    try:
        previous = _fetch(ACS_YEAR_PREVIOUS)
    except Exception:
        previous = None

    if not current:
        return {
            "median_income": None,
            "population_change_pct": None,
            "owner_share_pct": None,
        }

    median_income = safe_int(current.get("B19013_001E"))
    pop_current = safe_int(current.get("B01003_001E"))
    owner_units = safe_int(current.get("B25003_002E"))
    renter_units = safe_int(current.get("B25003_003E"))

    owner_share_pct = None
    if owner_units is not None and renter_units is not None:
        total = owner_units + renter_units
        if total > 0:
            owner_share_pct = round((owner_units / total) * 100.0, 1)

    pop_prev = safe_int(previous.get("B01003_001E")) if previous else None
    population_change_pct = None
    if pop_current is not None and pop_prev not in (None, 0):
        population_change_pct = round(((pop_current - pop_prev) / pop_prev) * 100.0, 1)

    return {
        "median_income": median_income,
        "population_change_pct": population_change_pct,
        "owner_share_pct": owner_share_pct,
    }


# ---------------------------------------------------------------------
# MAIN BUILD
# ---------------------------------------------------------------------
def build_dataset():
    print_api_status()

    if not CENSUS_API_KEY:
        raise RuntimeError("Missing CENSUS_API_KEY or CENSUSDATA_API_KEY in .env")

    print("Loading existing dataset fallbacks...")
    existing = load_existing_dataset_fallbacks()
    print(f"Loaded {len(existing)} fallback ZIP rows")

    print("Loading Zillow ZHVI data...")
    zhvi_by_zip = load_zillow_time_series(ZILLOW_ZHVI_CSV, mode="zhvi")
    print(f"Loaded {len(zhvi_by_zip)} ZHVI ZIP rows")
    detect_data_mode(len(zhvi_by_zip))

    print("Loading Zillow ZORI data...")
    if os.path.exists(ZILLOW_ZORI_CSV):
        zori_by_zip = load_zillow_time_series(ZILLOW_ZORI_CSV, mode="zori")
        print(f"Loaded {len(zori_by_zip)} ZORI ZIP rows")
    else:
        zori_by_zip = {}
        print("ZORI file missing, will use existing rent fallbacks only")

    print("Loading ZIP→county names...")
    zip_to_county_name = load_zip_to_county_name()
    print(f"Loaded {len(zip_to_county_name)} ZIP→county mappings")

    print("Loading ZIP coordinates...")
    latlon_by_zip = load_zcta_lat_lon()
    print(f"Loaded {len(latlon_by_zip)} ZIP coordinates")

    candidate_zips = sorted(set(zhvi_by_zip.keys()))
    print(f"Candidate ZIPs after core joins: {len(candidate_zips)}")

    rows: List[Dict[str, object]] = []

    for i, zip_code in enumerate(candidate_zips, start=1):
        zhvi = zhvi_by_zip.get(zip_code)
        if not zhvi or zhvi.get("latest") is None:
            continue

        county_name = get_county_from_row(zip_code, zip_to_county_name)
        lat, lon = latlon_by_zip.get(zip_code, (0.0, 0.0))

        avg_property_value = int(round(zhvi["latest"]))

        zhvi_1y_change_pct = zhvi.get("precomputed_1y_pct")
        if zhvi_1y_change_pct is None:
            zhvi_1y_change_pct = pct_change(zhvi.get("latest"), zhvi.get("one_year_ago"))

        zhvi_5y_change_pct = zhvi.get("precomputed_5y_pct")
        if zhvi_5y_change_pct is None:
            zhvi_5y_change_pct = pct_change(zhvi.get("latest"), zhvi.get("five_years_ago"))

        zori = zori_by_zip.get(zip_code, {})
        latest_rent = safe_int(zori.get("latest"))
        if latest_rent is None or latest_rent <= 0:
            latest_rent = safe_int(existing.get(zip_code, {}).get("median_rent"), 0)

        ptr_ratio = price_to_rent_ratio(avg_property_value, latest_rent)

        listing_count = safe_int(existing.get(zip_code, {}).get("listing_count"), 0)
        average_sqft = safe_int(existing.get(zip_code, {}).get("average_sqft"), 0)

        if i > 1:
            time.sleep(0.05)

        try:
            acs = fetch_acs_zip_features(zip_code)
        except Exception as e:
            print(f"[ACS] Failed for ZIP {zip_code}: {e}")
            fallback = existing.get(zip_code, {})
            acs = {
                "median_income": fallback.get("median_income"),
                "population_change_pct": fallback.get("population_change_pct"),
                "owner_share_pct": fallback.get("owner_share_pct"),
            }

        market_tier = market_tier_from_price(avg_property_value)
        region_bucket = region_bucket_from_zip_county(zip_code, county_name)
        urban_core_flag = urban_core_flag_from_zip_county(zip_code, county_name, region_bucket)

        row = {
            "zip_code": zip_code,
            "county": county_name,
            "latitude": round(lat, 6),
            "longitude": round(lon, 6),
            "avg_property_value": avg_property_value,
            "median_income": acs["median_income"] or 0,
            "median_rent": latest_rent or 0,
            "population_change_pct": acs["population_change_pct"] if acs["population_change_pct"] is not None else 0,
            "owner_share_pct": acs["owner_share_pct"] if acs["owner_share_pct"] is not None else 0,
            "zhvi_1y_change_pct": zhvi_1y_change_pct if zhvi_1y_change_pct is not None else 0,
            "zhvi_5y_change_pct": zhvi_5y_change_pct if zhvi_5y_change_pct is not None else 0,
            "price_to_rent_ratio": ptr_ratio if ptr_ratio is not None else 0,
            "listing_count": listing_count or 0,
            "average_sqft": average_sqft or 0,
            "market_tier": market_tier,
            "region_bucket": region_bucket,
            "urban_core_flag": urban_core_flag,
        }
        rows.append(row)

        if i % 10 == 0:
            print(f"Processed {i}/{len(candidate_zips)} ZIPs...")

    with open(OUTPUT_DATASET_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=[
                "zip_code",
                "county",
                "latitude",
                "longitude",
                "avg_property_value",
                "median_income",
                "median_rent",
                "population_change_pct",
                "owner_share_pct",
                "zhvi_1y_change_pct",
                "zhvi_5y_change_pct",
                "price_to_rent_ratio",
                "listing_count",
                "average_sqft",
                "market_tier",
                "region_bucket",
                "urban_core_flag",
            ],
        )
        writer.writeheader()
        writer.writerows(rows)

    print("\n==============================")
    print("DATASET BUILD COMPLETE")
    print("==============================")
    print(f"Total ZIPs processed: {len(rows)}")
    print(f"Output file: {OUTPUT_DATASET_CSV}")
    print("==============================\n")


if __name__ == "__main__":
    build_dataset()