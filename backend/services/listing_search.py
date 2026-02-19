import os
import requests
from dotenv import load_dotenv

# Load .env reliably from backend/.env (even when running uvicorn from different folders)
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # backend/
load_dotenv(os.path.join(BASE_DIR, ".env"))

BASE_URL = os.getenv("SIMPLYRETS_BASE_URL", "https://api.simplyrets.com").rstrip("/")
USERNAME = os.getenv("SIMPLYRETS_USERNAME", "simplyrets").strip()
PASSWORD = os.getenv("SIMPLYRETS_PASSWORD", "simplyrets").strip()
DEFAULT_LIMIT = int(os.getenv("SIMPLYRETS_DEFAULT_LIMIT", "20"))

# Optional: only needed for some SimplyRETS accounts (multi-feed / multi-MLS)
VENDOR = os.getenv("SIMPLYRETS_VENDOR", "").strip()

print("SimplyRETS config:",
      {"base_url": BASE_URL,
       "username_set": "YES" if USERNAME else "NO",
       "vendor": VENDOR or "(none)"})


def _pick_first_photo(item):
    photos = item.get("photos") or item.get("images") or []
    if isinstance(photos, list) and photos:
        return str(photos[0])
    return None


def _safe_int(x):
    try:
        if x is None:
            return None
        return int(float(x))
    except Exception:
        return None


def _safe_float(x):
    try:
        if x is None:
            return None
        return float(x)
    except Exception:
        return None


def _string(x):
    if x is None:
        return ""
    return str(x).strip()


def normalize_listing(item):
    address = item.get("address") or {}
    geo = item.get("geo") or {}
    listing_id = (
        item.get("mlsId")
        or item.get("listingId")
        or item.get("id")
        or item.get("propertyId")
        or item.get("mlsNumber")
    )

    street = _string(
        address.get("full")
        or address.get("address")
        or address.get("line1")
        or address.get("streetName")
    )
    city = _string(address.get("city") or item.get("city"))
    state = _string(address.get("state") or item.get("state")).upper()
    postal = _string(address.get("postalCode") or item.get("postalCode") or item.get("zip"))

    price = _safe_int(item.get("listPrice") or item.get("price"))

    prop = item.get("property") if isinstance(item.get("property"), dict) else {}
    beds = _safe_float(prop.get("bedrooms") if prop else item.get("bedrooms"))
    baths = _safe_float(prop.get("bathrooms") if prop else item.get("bathrooms"))

    sqft = _safe_int(
        (prop.get("area") if prop else None)
        or item.get("squareFeet")
        or item.get("sqft")
        or item.get("area")
    )

    status = _string(
        item.get("status")
        or item.get("statusText")
        or item.get("mlsStatus")
        or item.get("standardStatus")
    )
    photo = _pick_first_photo(item)

    lat = _safe_float(geo.get("lat") or item.get("latitude"))
    lng = _safe_float(geo.get("lng") or item.get("longitude"))

    photos = item.get("photos") or item.get("images") or []
    if not isinstance(photos, list):
        photos = []

    return {
        "id": _string(listing_id),
        "address": street,
        "city": city,
        "state": state,
        "zip": postal,
        "price": price,
        "beds": beds,
        "baths": baths,
        "sqft": sqft,
        "status": status,
        "photo": photo,
        "photos": [str(p) for p in photos if p],
        "lat": lat,
        "lng": lng,
        "raw": item,
    }


def _request_properties(params):
    url = f"{BASE_URL}/properties"
    r = requests.get(url, params=params, auth=(USERNAME, PASSWORD), timeout=20)

    # Debug log (safe + useful)
    print("SimplyRETS REQUEST:", r.url, "| status:", r.status_code)

    if r.status_code >= 400:
        body_snip = (r.text or "")[:800]
        raise RuntimeError(f"SimplyRETS HTTP error {r.status_code}: {body_snip}")

    data = r.json()

    if isinstance(data, dict) and ("error" in data or "message" in data):
        raise RuntimeError(f"SimplyRETS API error: {data}")

    if isinstance(data, list):
        return data
    if isinstance(data, dict) and isinstance(data.get("data"), list):
        return data["data"]
    if isinstance(data, dict) and isinstance(data.get("results"), list):
        return data["results"]

    return []


def search_listings(address_query=None, city=None, limit=None, offset=None):
    """
    General search (no state restriction).
    Uses optional SIMPLYRETS_VENDOR if provided.
    """
    if limit is None:
        limit = DEFAULT_LIMIT
    if offset is None:
        offset = 0

    base_params = {
        "limit": str(int(limit)),
        "offset": str(int(offset)),
    }

    if VENDOR:
        base_params["vendor"] = VENDOR

    if city:
        base_params["cities"] = str(city)

    tried = []
    if address_query:
        for key in ("q", "address", "query"):
            p = dict(base_params)
            p[key] = str(address_query)
            tried.append(p)
    else:
        tried.append(dict(base_params))

    last_err = None
    for p in tried:
        try:
            items = _request_properties(p)
            return [normalize_listing(x) for x in items if isinstance(x, dict)]
        except Exception as e:
            last_err = e

    raise RuntimeError(f"Search failed: {last_err}")
