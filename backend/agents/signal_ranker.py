"""
Agent 4: Signal Ranker Agent

Takes raw articles from the Market Scanner and uses Qwen (via Ollama) to classify each one:
- direction: bullish | bearish | neutral
- confidence: 0.0 to 1.0
- magnitude: low | medium | high
"""

import json
import uuid
from datetime import datetime
from sqlalchemy.orm import Session
import httpx

from db.database import MarketSignal

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


def rank_signal(article: dict) -> dict:
    """Ask Qwen to classify a single article as a market signal."""

    prompt = f"""
You are a real estate market analyst. Read the following news article and classify its impact on residential property values.

ARTICLE HEADLINE: {article.get('headline', '')}
ARTICLE SUMMARY: {article.get('summary', '')}
ZIPCODE: {article.get('zipcode', '')}

Return a JSON object with EXACTLY these fields (no extra text, no markdown, no backticks):
{{
  "direction": "bullish" or "bearish" or "neutral",
  "confidence": <float between 0.0 and 1.0>,
  "magnitude": "low" or "medium" or "high",
  "raw_summary": "<1-2 sentence explanation of why this signal matters for property values>"
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


def rank_and_store_signals(db: Session, articles: list[dict]) -> list[MarketSignal]:
    """Classify all articles and store them as MarketSignal records."""
    stored = []

    for article in articles:
        try:
            classification = rank_signal(article)

            signal = MarketSignal(
                id=str(uuid.uuid4()),
                zipcode=article.get("zipcode", ""),
                headline=article.get("headline", ""),
                source_url=article.get("url", ""),
                direction=classification.get("direction"),
                confidence=classification.get("confidence"),
                magnitude=classification.get("magnitude"),
                raw_summary=classification.get("raw_summary"),
                created_at=datetime.utcnow(),
            )

            db.add(signal)
            db.commit()
            stored.append(signal)

            print(f"[SignalRanker] ✓ [{classification['direction'].upper()}] {article.get('headline', '')[:60]}...")

        except Exception as e:
            print(f"[SignalRanker] ✗ Failed to rank article: {e}")

    return stored


def get_signals_for_zipcode(db: Session, zipcode: str, limit: int = 20) -> list[MarketSignal]:
    return (
        db.query(MarketSignal)
        .filter(MarketSignal.zipcode == zipcode)
        .order_by(MarketSignal.created_at.desc())
        .limit(limit)
        .all()
    )
