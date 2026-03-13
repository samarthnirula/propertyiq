"""
Agent 3: Market Scanner Agent

Runs daily on a schedule. For each zipcode any user has interacted with,
it searches the web for news and events that could affect property values.
Uses Tavily API for web search.
"""

import os
from datetime import datetime
from sqlalchemy.orm import Session
from tavily import TavilyClient

from db.database import BehaviorEvent, MarketSignal
from agents.behavior_tracker import get_user_zipcodes

tavily = TavilyClient(api_key=os.getenv("TAVILY_API_KEY"))

# Search queries to run per zipcode
QUERY_TEMPLATES = [
    "real estate market {zipcode} 2025 2026",
    "new business development {zipcode} area",
    "crime rate change {zipcode}",
    "interest rate housing market Texas",
    "zoning change development {zipcode}",
    "job growth employment {zipcode} area",
]


def scan_zipcode(zipcode: str) -> list[dict]:
    """
    Run multiple web searches for a zipcode and return raw articles.
    """
    articles = []

    for template in QUERY_TEMPLATES:
        query = template.replace("{zipcode}", zipcode)
        try:
            result = tavily.search(
                query=query,
                search_depth="basic",
                max_results=3,
            )
            for item in result.get("results", []):
                articles.append({
                    "zipcode": zipcode,
                    "query_used": query,
                    "headline": item.get("title", ""),
                    "summary": item.get("content", ""),
                    "url": item.get("url", ""),
                })
        except Exception as e:
            print(f"[MarketScanner] Search failed for '{query}': {e}")

    return articles


def scan_all_watched_zipcodes(db: Session) -> list[dict]:
    """
    Collect all unique zipcodes from all users' behavior history,
    then scan each one. Returns all raw articles found.
    """

    # Get all unique zipcodes across all users
    all_events = db.query(BehaviorEvent).all()
    zipcodes = set()
    for event in all_events:
        if event.payload and "zipcode" in event.payload:
            zipcodes.add(str(event.payload["zipcode"]))

    print(f"[MarketScanner] Scanning {len(zipcodes)} zipcodes: {zipcodes}")

    all_articles = []
    for zipcode in zipcodes:
        articles = scan_zipcode(zipcode)
        all_articles.extend(articles)
        print(f"[MarketScanner] ✓ Found {len(articles)} articles for zipcode {zipcode}")

    return all_articles
