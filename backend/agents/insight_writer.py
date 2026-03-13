"""
Agent 6: Insight Writer Agent

Takes matched signals from the Matchmaker and writes plain-English,
personalized insight cards. Uses Qwen via Ollama.
"""

import os
import uuid
import json
from datetime import datetime
from sqlalchemy.orm import Session
import httpx

from db.database import UserInsight, UserProfile, MarketSignal

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


def write_insight(user_id: str, profile: UserProfile, signal: MarketSignal, reason: str) -> dict:
    """Generate a personalized insight card for a specific user + signal combo."""

    prompt = f"""
You are a personal real estate advisor writing a brief personalized market alert for a specific investor.

INVESTOR PROFILE:
{profile.raw_summary}
Risk tolerance: {profile.risk_tolerance}
Investment style: {profile.investment_style}

MARKET SIGNAL:
Headline: {signal.headline}
Summary: {signal.raw_summary}
Direction: {signal.direction}
Magnitude: {signal.magnitude}
Zipcode: {signal.zipcode}

WHY THIS IS RELEVANT TO THIS INVESTOR:
{reason}

Write a personalized insight card. Return a JSON object with EXACTLY these fields (no extra text, no markdown, no backticks):
{{
  "headline": "<short punchy headline, max 10 words>",
  "explanation": "<2-3 sentence plain English explanation. Start with what happened, then explain why it matters specifically to this investor's goals.>"
}}

Return only the JSON object, nothing else.
"""

    raw = ask_qwen(prompt)
    if "```" in raw:
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    raw = raw.strip()

    return json.loads(raw)


def write_and_store_insights(db: Session, user_id: str, matches: list[dict]) -> list[UserInsight]:
    """For each matched signal, generate and store a personalized insight."""

    profile = db.query(UserProfile).filter(UserProfile.user_id == user_id).first()
    if not profile:
        return []

    stored = []

    for match in matches:
        signal: MarketSignal = match["signal"]
        reason: str = match["reason"]

        try:
            content = write_insight(user_id, profile, signal, reason)

            insight = UserInsight(
                id=str(uuid.uuid4()),
                user_id=user_id,
                zipcode=signal.zipcode,
                headline=content.get("headline", ""),
                explanation=content.get("explanation", ""),
                direction=signal.direction,
                read="false",
                created_at=datetime.utcnow(),
            )

            db.add(insight)
            db.commit()
            stored.append(insight)

            print(f"[InsightWriter] ✓ Insight written for user {user_id}: {insight.headline}")

        except Exception as e:
            print(f"[InsightWriter] ✗ Failed to write insight for user {user_id}: {e}")

    return stored


def write_insights_for_all_users(db: Session, all_matches: dict) -> int:
    """Write insights for all users. Returns total number of insights written."""
    total = 0
    for user_id, matches in all_matches.items():
        if matches:
            insights = write_and_store_insights(db, user_id, matches)
            total += len(insights)
    return total
