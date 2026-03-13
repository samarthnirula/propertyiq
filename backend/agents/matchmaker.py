"""
Agent 5: Matchmaker Agent


Cross-references each users profile against all available market signals
and decides which signals are personally relevant to that specific user.
Uses Qwen via Ollama.
"""

import json
from sqlalchemy.orm import Session
import httpx

from db.database import UserProfile, MarketSignal, BehaviorEvent

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL = "qwen2.5"


def ask_qwen(prompt: str) -> str:
    response = httpx.post(
        OLLAMA_URL,
        json={"model": MODEL, "prompt": prompt, "stream": False},
        timeout=120.0
    )
    response.raise_for_status()
    return response.json()["response"].strip()


def match_signals_for_user(db: Session, user_id: str) -> list[dict]:
    """
    Given a user's profile and all available market signals for their
    watched zipcodes, return only the signals genuinely relevant to this user.
    """

    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if not profile:
        print(f"[Matchmaker] No profile found for user {user_id}, skipping.")
        return []

    events = db.query(BehaviorEvent).filter(BehaviorEvent.user_id == user_id).all()
    user_zipcodes = set()
    for e in events:
        if e.payload and "zipcode" in e.payload:
            user_zipcodes.add(str(e.payload["zipcode"]))

    if not user_zipcodes:
        print(f"[Matchmaker] No watched zipcodes for user {user_id}, skipping.")
        return []

    signals = (
        db.query(MarketSignal)
        .filter(MarketSignal.zipcode.in_(user_zipcodes))
        .order_by(MarketSignal.created_at.desc())
        .limit(50)
        .all()
    )

    if not signals:
        print(f"[Matchmaker] No signals found for user {user_id}'s zipcodes.")
        return []

    profile_text = f"""
Risk tolerance: {profile.risk_tolerance}
Investment style: {profile.investment_style}
Preferred zipcodes: {profile.preferred_zipcodes}
Price range: ${profile.price_range_min} - ${profile.price_range_max}
Target monthly cash flow: ${profile.target_cash_flow}
Investment horizon: {profile.investment_horizon}
Profile summary: {profile.raw_summary}
"""

    signals_text = "\n".join([
        f"[SIGNAL {i+1}] zipcode={s.zipcode} direction={s.direction} magnitude={s.magnitude} "
        f"confidence={s.confidence} | {s.headline} | {s.raw_summary}"
        for i, s in enumerate(signals)
    ])

    prompt = f"""
You are a personalized real estate advisor. Given a specific investor's profile and a list of market signals,
decide which signals are genuinely relevant and important to THIS investor.

INVESTOR PROFILE:
{profile_text}

AVAILABLE MARKET SIGNALS:
{signals_text}

Return a JSON array of matched signals. Only include signals that are meaningfully relevant to this investor.
Each item must have EXACTLY these fields (no extra text, no markdown, no backticks):
[
  {{
    "signal_index": <1-based index from the list above>,
    "relevance_score": <float 0.0 to 1.0>,
    "reason": "<1 sentence explaining why this signal matters specifically to this investor>"
  }}
]

Rules:
- Only include signals with relevance_score >= 0.5
- Limit to the top 5 most relevant signals maximum
- Return an empty array [] if nothing is relevant
- Return only the JSON array, nothing else.
"""

    raw = ask_qwen(prompt)
    if "```" in raw:
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    raw = raw.strip()

    matches = json.loads(raw)

    results = []
    for match in matches:
        idx = match["signal_index"] - 1
        if 0 <= idx < len(signals):
            results.append({
                "signal": signals[idx],
                "relevance_score": match["relevance_score"],
                "reason": match["reason"],
            })

    print(f"[Matchmaker] ✓ {len(results)} relevant signals matched for user {user_id}")
    return results


def match_all_users(db: Session) -> dict:
    """Run matchmaking for all users who have a profile."""
    profiles = db.query(UserProfile).all()
    all_matches = {}
    for profile in profiles:
        matches = match_signals_for_user(db, profile.user_id)
        all_matches[profile.user_id] = matches
    return all_matches
