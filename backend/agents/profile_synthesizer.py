"""
Agent 2: Profile Synthesizer Agent


Reads a users full behavior event log and uses Qwen (via Ollama) to synthesize
a structured profile: risk tolerance, investment style, preferred areas,
price range, etc. Runs on a schedule (every few hours via APScheduler).
"""

import json
from datetime import datetime
from sqlalchemy.orm import Session
import httpx

from db.database import UserProfile, BehaviorEvent

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL = "qwen2.5"


def ask_qwen(prompt: str) -> str:
    """Send a prompt to Qwen via Ollama and return the response text."""
    response = httpx.post(
        OLLAMA_URL,
        json={"model": MODEL, "prompt": prompt, "stream": False},
        timeout=120.0
    )
    response.raise_for_status()
    return response.json()["response"].strip()


def synthesize_profile(db: Session, user_id: str) -> UserProfile:
    """
    Reads behavior history for a user and asks Qwen to infer their investment profile.
    Writes the result back to user_profiles table.
    """

    events = (
        db.query(BehaviorEvent)
        .filter(BehaviorEvent.user_id == user_id)
        .order_by(BehaviorEvent.created_at.asc())
        .all()
    )

    if not events:
        print(f"[ProfileSynthesizer] No events found for user {user_id}, skipping.")
        return None

    events_text = "\n".join([
        f"- [{e.event_type.upper()}] at {e.created_at.strftime('%Y-%m-%d %H:%M')} | data: {json.dumps(e.payload)}"
        for e in events
    ])

    prompt = f"""
You are analyzing the behavior history of a real estate investor using the PropertyIQ app.
Based on their interactions, infer their investment profile.

USER BEHAVIOR LOG:
{events_text}

Return a JSON object with EXACTLY these fields (no extra text, no markdown, no backticks):
{{
  "risk_tolerance": "low" or "medium" or "high",
  "investment_style": "flip" or "long_term_rental" or "unsure",
  "preferred_zipcodes": ["list", "of", "zipcodes"],
  "price_range_min": <number or null>,
  "price_range_max": <number or null>,
  "target_cash_flow": <monthly dollar amount or null>,
  "investment_horizon": "short" or "medium" or "long",
  "raw_summary": "<2-3 sentence plain English summary of this investor profile>"
}}

Base your inference strictly on the behavior log. If something cannot be inferred, use null.
Return only the JSON object, nothing else.
"""

    raw = ask_qwen(prompt)

    # Strip markdown fences if present
    if "```" in raw:
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    raw = raw.strip()

    data = json.loads(raw)

    existing = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()

    if existing:
        existing.risk_tolerance = data.get("risk_tolerance")
        existing.investment_style = data.get("investment_style")
        existing.preferred_zipcodes = data.get("preferred_zipcodes", [])
        existing.price_range_min = data.get("price_range_min")
        existing.price_range_max = data.get("price_range_max")
        existing.target_cash_flow = data.get("target_cash_flow")
        existing.investment_horizon = data.get("investment_horizon")
        existing.raw_summary = data.get("raw_summary")
        existing.updated_at = datetime.utcnow()
        db.commit()
        return existing
    else:
        profile = UserProfile(
            user_id=user_id,
            risk_tolerance=data.get("risk_tolerance"),
            investment_style=data.get("investment_style"),
            preferred_zipcodes=data.get("preferred_zipcodes", []),
            price_range_min=data.get("price_range_min"),
            price_range_max=data.get("price_range_max"),
            target_cash_flow=data.get("target_cash_flow"),
            investment_horizon=data.get("investment_horizon"),
            raw_summary=data.get("raw_summary"),
            updated_at=datetime.utcnow(),
        )
        db.add(profile)
        db.commit()
        return profile


def synthesize_all_profiles(db: Session):
    """Synthesize profiles for ALL users. Called by the scheduler every few hours."""
    user_ids = db.query(BehaviorEvent.user_id).distinct().all()
    user_ids = [row[0] for row in user_ids]

    print(f"[ProfileSynthesizer] Running for {len(user_ids)} users...")
    for user_id in user_ids:
        try:
            synthesize_profile(db, user_id)
            print(f"[ProfileSynthesizer] ✓ Profile updated for user {user_id}")
        except Exception as e:
            print(f"[ProfileSynthesizer] ✗ Failed for user {user_id}: {e}")
