import csv
import json
import os
import subprocess
from typing import Any, Dict, List, Optional

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # backend/
SERVICES_DIR = os.path.join(BASE_DIR, "services")

PREDICTOR_PATH = os.path.join(SERVICES_DIR, "predictor")
DATASET_PATH = os.path.join(SERVICES_DIR, "zip_market_dataset.csv")
CRIME_PATH = os.path.join(SERVICES_DIR, "tx_county_crime_data.txt")
EVAL_RESULTS_PATH = os.path.join(SERVICES_DIR, "evaluation_results.csv")

DEFAULT_K = 9


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


def _load_dataset_row(zip_code: str) -> Optional[Dict[str, Any]]:
    if not os.path.exists(DATASET_PATH):
        raise FileNotFoundError(f"Dataset not found: {DATASET_PATH}")

    with open(DATASET_PATH, newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            if (row.get("zip_code") or "").strip() == zip_code:
                return row

    return None


def _load_zip_specific_error(zip_code: str) -> Optional[float]:
    if not os.path.exists(EVAL_RESULTS_PATH):
        return None

    try:
        with open(EVAL_RESULTS_PATH, newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                if (row.get("zip_code") or "").strip() == zip_code:
                    return safe_float(row.get("error_pct"))
    except Exception:
        return None

    return None


def _load_global_mean_error() -> Optional[float]:
    if not os.path.exists(EVAL_RESULTS_PATH):
        return None

    vals: List[float] = []
    try:
        with open(EVAL_RESULTS_PATH, newline="", encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                v = safe_float(row.get("error_pct"))
                if v is not None:
                    vals.append(v)
    except Exception:
        return None

    if not vals:
        return None

    return round(sum(vals) / len(vals), 2)


def _run_predictor(row: Dict[str, Any], k: int = DEFAULT_K) -> Dict[str, Any]:
    if not os.path.exists(PREDICTOR_PATH):
        raise FileNotFoundError(
            f"Predictor binary not found: {PREDICTOR_PATH}. "
            f"Compile it first with: g++ -std=c++17 -O2 -o services/predictor services/main.cpp"
        )

    args = [
        PREDICTOR_PATH,
        DATASET_PATH,
        CRIME_PATH,
        (row.get("zip_code") or "").strip(),
        (row.get("county") or "").strip().lower(),
        str(safe_float(row.get("latitude"), 0) or 0),
        str(safe_float(row.get("longitude"), 0) or 0),
        str(safe_float(row.get("median_income"), 0) or 0),
        str(safe_float(row.get("median_rent"), 0) or 0),
        str(safe_float(row.get("population_change_pct"), 0) or 0),
        str(safe_float(row.get("owner_share_pct"), 0) or 0),
        str(k),
        str(safe_float(row.get("zhvi_1y_change_pct"), 0) or 0),
        str(safe_float(row.get("zhvi_5y_change_pct"), 0) or 0),
        str(safe_float(row.get("price_to_rent_ratio"), 0) or 0),
        str(safe_float(row.get("listing_count"), 0) or 0),
        str(safe_float(row.get("average_sqft"), 0) or 0),
        str(safe_float(row.get("avg_property_value"), 0) or 0),
        (row.get("market_tier") or "").strip().lower(),
        (row.get("region_bucket") or "").strip().lower(),
        str(safe_int(row.get("urban_core_flag"), 0) or 0),
    ]

    result = subprocess.run(
        args,
        capture_output=True,
        text=True,
        cwd=BASE_DIR,
        timeout=25,
    )

    if result.returncode != 0:
        stderr = (result.stderr or "").strip()
        stdout = (result.stdout or "").strip()
        raise RuntimeError(
            f"Predictor failed. returncode={result.returncode}, stdout={stdout}, stderr={stderr}"
        )

    try:
        return json.loads(result.stdout)
    except Exception as e:
        raise RuntimeError(f"Predictor returned invalid JSON: {e}\nRaw output: {result.stdout}")


def run_prediction_for_zip(zip_code: str, k: int = DEFAULT_K) -> Dict[str, Any]:
    """
    Returns:
    {
        "predicted_value": float | None,
        "error_pct": float | None,
        "k": int,
        "neighbors": list,
        "confidence_score": float | None
    }
    """
    zip_code = (zip_code or "").strip()
    if not zip_code:
        raise ValueError("zip_code is required")

    row = _load_dataset_row(zip_code)
    if not row:
        raise ValueError(f"ZIP {zip_code} not found in {DATASET_PATH}")

    predictor_json = _run_predictor(row, k=k)

    zip_specific_error = _load_zip_specific_error(zip_code)
    global_error = _load_global_mean_error()

    return {
        "predicted_value": safe_float(
            predictor_json.get("predicted_average_property_value")
        ),
        "error_pct": zip_specific_error if zip_specific_error is not None else global_error,
        "k": safe_int(predictor_json.get("k_used"), k) or k,
        "neighbors": predictor_json.get("neighbors", []) or [],
        "confidence_score": safe_float(predictor_json.get("confidence_score")),
    }