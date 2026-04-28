import time
import urllib.parse
import xml.etree.ElementTree as ET
from typing import Dict, List

import requests

_CACHE: Dict[str, object] = {
    "timestamp": 0.0,
    "data": [],
}

CACHE_TTL_SECONDS = 60 * 60 * 6  # 6 hours


def _parse_google_news_rss(query: str) -> List[Dict]:
    encoded_query = urllib.parse.quote(query)
    url = f"https://news.google.com/rss/search?q={encoded_query}&hl=en-US&gl=US&ceid=US:en"

    r = requests.get(url, timeout=20)
    r.raise_for_status()

    root = ET.fromstring(r.text)
    items = []

    channel = root.find("channel")
    if channel is None:
        return items

    for item in channel.findall("item"):
        title = (item.findtext("title") or "").strip()
        link = (item.findtext("link") or "").strip()
        pub_date = (item.findtext("pubDate") or "").strip()
        source_el = item.find("source")
        source = source_el.text.strip() if source_el is not None and source_el.text else ""

        if not title or not link:
            continue

        items.append({
            "title": title,
            "url": link,
            "source": source,
            "published_at": pub_date,
        })

    return items


def get_housing_news() -> Dict[str, List[Dict]]:
    now = time.time()

    if (
        _CACHE["data"]
        and isinstance(_CACHE["timestamp"], (int, float))
        and (now - float(_CACHE["timestamp"])) < CACHE_TTL_SECONDS
    ):
        return {"news": _CACHE["data"]}

    queries = [
        "housing market",
        "real estate market",
        "mortgage rates housing",
    ]

    seen = set()
    combined: List[Dict] = []

    for q in queries:
        try:
            items = _parse_google_news_rss(q)
        except Exception:
            continue

        for item in items:
            key = (item.get("title", ""), item.get("url", ""))
            if key in seen:
                continue
            seen.add(key)
            combined.append(item)

    keywords = [
        "housing",
        "real estate",
        "home price",
        "mortgage",
        "rent",
        "rental",
        "inventory",
        "housing market",
        "property market",
    ]

    filtered = []
    for item in combined:
        hay = f"{item.get('title', '')} {item.get('source', '')}".lower()
        if any(k in hay for k in keywords):
            filtered.append(item)

    filtered = filtered[:20]

    _CACHE["timestamp"] = now
    _CACHE["data"] = filtered

    return {"news": filtered}