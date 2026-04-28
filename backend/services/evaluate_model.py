import csv
import json
import os
import statistics
import subprocess
import tempfile
from typing import Dict, List, Optional

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SERVICES_DIR = os.path.join(BASE_DIR, "services")

PREDICTOR_PATH = os.path.join(SERVICES_DIR, "predictor")
DATASET_PATH = os.path.join(SERVICES_DIR, "zip_market_dataset.csv")
CRIME_PATH = os.path.join(SERVICES_DIR, "tx_county_crime_data.txt")
OUTPUT_PATH = os.path.join(SERVICES_DIR, "evaluation_results.csv")

K_VALUES = [3, 5, 7, 9]


def safe_float(v, default=None):
    try:
        if v in (None, "", "null", ".", "None"):
            return default
        return float(v)
    except Exception:
        return default


def safe_int(v, default=0):
    try:
        if v in (None, "", "null", ".", "None"):
            return default
        return int(float(v))
    except Exception:
        return default


def error_pct(predicted, actual):
    if predicted is None or actual in (None, 0):
        return None
    return abs(predicted - actual) / actual * 100.0


def fmt_num(v: Optional[float], digits: int = 2) -> str:
    if v is None:
        return "None"
    return f"{v:.{digits}f}"


def load_rows():
    with open(DATASET_PATH, newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))

    cleaned = []
    for r in rows:
        zip_code = (r.get("zip_code") or "").strip()
        price = safe_float(r.get("avg_property_value"))

        if not zip_code or price is None or price <= 0:
            continue

        cleaned.append({
            "zip_code": zip_code,
            "county": (r.get("county") or "").strip().lower(),
            "latitude": safe_float(r.get("latitude"), 0),
            "longitude": safe_float(r.get("longitude"), 0),
            "avg_property_value": price,
            "median_income": safe_float(r.get("median_income"), 0),
            "median_rent": safe_float(r.get("median_rent"), 0),
            "population_change_pct": safe_float(r.get("population_change_pct"), 0),
            "owner_share_pct": safe_float(r.get("owner_share_pct"), 0),
            "zhvi_1y_change_pct": safe_float(r.get("zhvi_1y_change_pct"), 0),
            "zhvi_5y_change_pct": safe_float(r.get("zhvi_5y_change_pct"), 0),
            "price_to_rent_ratio": safe_float(r.get("price_to_rent_ratio"), 0),
            "listing_count": safe_float(r.get("listing_count"), 0),
            "average_sqft": safe_float(r.get("average_sqft"), 0),
            "market_tier": (r.get("market_tier") or "").strip().lower(),
            "region_bucket": (r.get("region_bucket") or "").strip().lower(),
            "urban_core_flag": safe_int(r.get("urban_core_flag"), 0),
        })

    return cleaned


def create_temp_dataset(all_rows, exclude_zip):
    temp_file = tempfile.NamedTemporaryFile(
        delete=False,
        mode="w",
        newline="",
        suffix=".csv",
        encoding="utf-8",
    )

    writer = csv.DictWriter(
        temp_file,
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

    for r in all_rows:
        if r["zip_code"] != exclude_zip:
            writer.writerow(r)

    temp_file.close()
    return temp_file.name


def run_predictor(row, dataset_path, k):
    args = [
        PREDICTOR_PATH,
        dataset_path,
        CRIME_PATH,
        row["zip_code"],
        row["county"],
        str(row["latitude"]),
        str(row["longitude"]),
        str(row["median_income"]),
        str(row["median_rent"]),
        str(row["population_change_pct"]),
        str(row["owner_share_pct"]),
        str(k),
        str(row["zhvi_1y_change_pct"]),
        str(row["zhvi_5y_change_pct"]),
        str(row["price_to_rent_ratio"]),
        str(row["listing_count"]),
        str(row["average_sqft"]),
        str(row["avg_property_value"]),
        str(row["market_tier"]),
        str(row["region_bucket"]),
        str(row["urban_core_flag"]),
    ]

    result = subprocess.run(
        args,
        capture_output=True,
        text=True,
        cwd=BASE_DIR,
        timeout=20,
    )

    if result.returncode != 0:
        return None

    try:
        return json.loads(result.stdout)
    except Exception:
        return None


def summarize_results(results):
    valid = [r["error_pct"] for r in results if r["error_pct"] is not None]

    if not valid:
        return {
            "mean_error_pct": None,
            "median_error_pct": None,
            "best_error_pct": None,
            "worst_error_pct": None,
        }

    return {
        "mean_error_pct": round(statistics.mean(valid), 2),
        "median_error_pct": round(statistics.median(valid), 2),
        "best_error_pct": round(min(valid), 2),
        "worst_error_pct": round(max(valid), 2),
    }


def print_ranked_rows(rows: List[Dict], title: str, reverse: bool, limit: int = 10):
    valid_rows = [r for r in rows if r.get("error_pct") is not None and r.get("status") == "OK"]
    ranked = sorted(valid_rows, key=lambda r: r["error_pct"], reverse=reverse)[:limit]

    print(f"\n{title}")
    print("-" * len(title))
    if not ranked:
        print("No valid rows")
        return

    for r in ranked:
        print(
            f"ZIP {r['zip_code']} | "
            f"County={r['county']} | "
            f"Tier={r['market_tier']} | "
            f"Region={r['region_bucket']} | "
            f"UrbanCore={r['urban_core_flag']} | "
            f"Actual={fmt_num(r['actual_price'], 0)} | "
            f"Predicted={fmt_num(r['predicted_price'], 0)} | "
            f"Error%={fmt_num(r['error_pct'], 2)} | "
            f"Confidence={fmt_num(r.get('confidence_score'), 2)}"
        )


def main():
    rows = load_rows()

    print("DEBUG: script started")
    print(f"DEBUG: rows loaded = {len(rows)}")

    if len(rows) == 0:
        print("🚨 ERROR: No rows loaded")
        return

    # TEMP: limit to 10 rows so we can debug quickly

    print(f"DEBUG: predictor path = {PREDICTOR_PATH}")
    print(f"DEBUG: dataset path = {DATASET_PATH}")
    print(f"DEBUG: crime path = {CRIME_PATH}")
    print(f"DEBUG: predictor exists = {os.path.exists(PREDICTOR_PATH)}")
    print(f"DEBUG: dataset exists = {os.path.exists(DATASET_PATH)}")
    print(f"DEBUG: crime file exists = {os.path.exists(CRIME_PATH)}")

    k_summaries = []
    best_k_results = None

    for k in K_VALUES:
        print("\n==============================")
        print(f"Evaluating K = {k}")
        print("==============================")

        results_for_k = []

        for i, row in enumerate(rows, start=1):
            print(f"RUNNING ZIP {row.get('zip_code')}")
            print(f"DEBUG: running row {i}/{len(rows)} zip={row['zip_code']} k={k}")

            temp_dataset = create_temp_dataset(rows, row["zip_code"])

            try:
                output = run_predictor(row, temp_dataset, k)
            finally:
                if os.path.exists(temp_dataset):
                    os.remove(temp_dataset)

            actual = row["avg_property_value"]

            if not output:
                print(f"[K={k}] [{i}/{len(rows)}] {row['zip_code']} FAILED")
                result_row = {
                    "k": k,
                    "zip_code": row["zip_code"],
                    "county": row["county"],
                    "market_tier": row["market_tier"],
                    "region_bucket": row["region_bucket"],
                    "urban_core_flag": row["urban_core_flag"],
                    "actual_price": round(actual, 2),
                    "predicted_price": None,
                    "error_pct": None,
                    "confidence_score": None,
                    "status": "FAILED",
                }
                results_for_k.append(result_row)
                continue

            predicted = safe_float(output.get("predicted_average_property_value"))
            confidence = safe_float(output.get("confidence_score"))
            err = error_pct(predicted, actual)

            print(
                f"[K={k}] [{i}/{len(rows)}] {row['zip_code']} "
                f"actual={actual:.0f} predicted={fmt_num(predicted, 0)} "
                f"error={fmt_num(err, 2)} confidence={fmt_num(confidence, 2)}"
            )

            result_row = {
                "k": k,
                "zip_code": row["zip_code"],
                "county": row["county"],
                "market_tier": row["market_tier"],
                "region_bucket": row["region_bucket"],
                "urban_core_flag": row["urban_core_flag"],
                "actual_price": round(actual, 2),
                "predicted_price": round(predicted, 2) if predicted is not None else None,
                "error_pct": round(err, 2) if err is not None else None,
                "confidence_score": round(confidence, 4) if confidence is not None else None,
                "status": "OK",
            }
            results_for_k.append(result_row)

        summary = summarize_results(results_for_k)
        k_summaries.append({
            "k": k,
            "results": results_for_k,
            **summary,
        })

        print(f"\nSummary for K = {k}")
        print("----------------------")
        print(f"Mean error %:   {summary['mean_error_pct']}")
        print(f"Median error %: {summary['median_error_pct']}")
        print(f"Best error %:   {summary['best_error_pct']}")
        print(f"Worst error %:  {summary['worst_error_pct']}")

    valid_summaries = [s for s in k_summaries if s["mean_error_pct"] is not None]

    print("\n==============================")
    print("FINAL K COMPARISON")
    print("==============================")
    for s in valid_summaries:
        print(
            f"K={s['k']} | "
            f"Mean={s['mean_error_pct']} | "
            f"Median={s['median_error_pct']} | "
            f"Best={s['best_error_pct']} | "
            f"Worst={s['worst_error_pct']}"
        )

    if valid_summaries:
        best = min(valid_summaries, key=lambda x: x["mean_error_pct"])
        best_k_results = best["results"]

        print("\nBEST K BASED ON LOWEST MEAN ERROR")
        print("---------------------------------")
        print(f"K = {best['k']}")
        print(f"Mean error %:   {best['mean_error_pct']}")
        print(f"Median error %: {best['median_error_pct']}")
        print(f"Best error %:   {best['best_error_pct']}")
        print(f"Worst error %:  {best['worst_error_pct']}")

        print_ranked_rows(best_k_results, "WORST 10 ZIPS (BEST K)", reverse=True, limit=10)
        print_ranked_rows(best_k_results, "BEST 10 ZIPS (BEST K)", reverse=False, limit=10)

    if best_k_results:
        success_rows = [r for r in best_k_results if r.get("status") == "OK"]

        with open(OUTPUT_PATH, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(
                f,
                fieldnames=[
                    "k",
                    "zip_code",
                    "county",
                    "market_tier",
                    "region_bucket",
                    "urban_core_flag",
                    "actual_price",
                    "predicted_price",
                    "error_pct",
                    "confidence_score",
                    "status",
                ],
            )
            writer.writeheader()
            writer.writerows(success_rows)

        print(f"\nSaved only best-K successful results to: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()