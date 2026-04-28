import os
from datetime import datetime


BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SERVICES_DIR = os.path.join(BASE_DIR, "services")

DATASET_PATH = os.path.join(SERVICES_DIR, "zip_market_dataset.csv")
EVAL_RESULTS_PATH = os.path.join(SERVICES_DIR, "evaluation_results.csv")


def _file_info(path: str) -> dict:
    exists = os.path.exists(path)
    return {
        "path": path,
        "exists": exists,
        "size_bytes": os.path.getsize(path) if exists else 0,
        "modified_at": datetime.fromtimestamp(os.path.getmtime(path)).isoformat()
        if exists
        else None,
    }


def run_market_pipeline() -> dict:
    """
    Lightweight pipeline status runner.

    This does not rebuild the dataset by itself.
    It reports the current state of the key market-model artifacts so the
    frontend/backend pipeline endpoints have something stable to return.
    """
    dataset_info = _file_info(DATASET_PATH)
    eval_info = _file_info(EVAL_RESULTS_PATH)

    status = "ok" if dataset_info["exists"] else "missing_dataset"

    return {
        "pipeline": "market",
        "status": status,
        "checked_at": datetime.utcnow().isoformat() + "Z",
        "artifacts": {
            "zip_market_dataset": dataset_info,
            "evaluation_results": eval_info,
        },
        "message": (
            "Market pipeline artifacts are available."
            if status == "ok"
            else "zip_market_dataset.csv is missing. Build the dataset first."
        ),
    }


def run_profile_pipeline() -> dict:
    """
    Lightweight placeholder profile pipeline.

    Keeps the route functional even if you have not rebuilt the full profile
    generation system yet.
    """
    return {
        "pipeline": "profiles",
        "status": "ok",
        "checked_at": datetime.utcnow().isoformat() + "Z",
        "message": "Profile pipeline placeholder is active.",
    }