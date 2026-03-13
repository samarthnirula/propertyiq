"""
Area Researcher Agent — Hyper-local neighborhood intelligence
-------------------------------------------------------------

Two modes:
1. research_area()     — fast overview (60-90s)
2. deep_research()     — in-depth neighborhood analysis with more sources

The agent focuses on the specific neighborhood/street level, not the city.
It decides what to research based on what could affect housing in that area.

I also made use of qwen to run the model etc..
"""

import json
import os
from datetime import datetime
from tavily import TavilyClient
import httpx

tavily = TavilyClient(api_key=os.getenv("TAVILY_API_KEY"))

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL = "qwen2.5"


def ask_qwen(prompt: str, timeout: int = 180) -> str:
    response = httpx.post(
        OLLAMA_URL,
        json={"model": MODEL, "prompt": prompt, "stream": False},
        timeout=float(timeout)
    )
    response.raise_for_status()
    return response.json()["response"].strip()


def search(query: str, max_results: int = 5) -> list[dict]:
    try:
        result = tavily.search(
            query=query,
            search_depth="advanced",
            max_results=max_results,
        )
        return [
            {
                "title": r.get("title", ""),
                "content": r.get("content", ""),
                "url": r.get("url", ""),
            }
            for r in result.get("results", [])
        ]
    except Exception as e:
        print(f"[AreaResearcher] Search error: {e}")
        return []


def _collect_data(area_input: str, num_queries: int = 6) -> tuple[list, list]:
    """Step 1: Agent plans queries. Step 2: Execute searches. Returns (findings, sources)."""

    planning_prompt = f"""
You are a hyper-local real estate intelligence agent. A real estate investor wants to understand
the investment potential of this SPECIFIC neighborhood/area: "{area_input}"

Generate {num_queries} targeted search queries to gather data that could affect housing values
in THIS SPECIFIC area — not the broader city. Think street-level, neighborhood-level.

Focus on factors like:
- Actual crime statistics for this specific zipcode/neighborhood (not the city)
- Specific employers, businesses opening or closing nearby
- Local school district performance and ratings
- Flood zone maps, environmental hazards, Superfund sites nearby
- Local zoning changes, new construction permits filed
- Neighborhood demographic shifts, gentrification indicators
- Specific infrastructure projects (highway, transit, utility)
- Local property tax trends for this area
- HOA issues if applicable, code violations
- Any hyper-local news specific to this neighborhood

Use site-specific searches targeting: census.gov, fbi.gov, bls.gov, epa.gov, fema.gov,
zillow.com, redfin.com, realtor.com, greatschools.org, neighborhoodscout.com, city planning sites.

Return ONLY a JSON array of search query strings, nothing else:
["query 1", "query 2", ...]
"""

    raw = ask_qwen(planning_prompt, timeout=60)
    if "```" in raw:
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    raw = raw.strip()

    try:
        queries = json.loads(raw)
    except Exception:
        queries = [
            f"crime rate statistics {area_input} neighborhood site:neighborhoodscout.com OR site:crimemapping.com",
            f"property values housing market {area_input} 2024 2025 site:zillow.com OR site:redfin.com",
            f"flood zone FEMA map {area_input} site:fema.gov OR site:floodsmart.gov",
            f"school ratings {area_input} site:greatschools.org OR site:niche.com",
            f"new development construction permits {area_input} 2024 2025",
            f"employment jobs economy {area_input} site:bls.gov OR site:census.gov",
        ]

    print(f"[AreaResearcher] Planned {len(queries)} hyper-local queries")

    all_sources = []
    all_findings = []

    for query in queries:
        results = search(query, max_results=5)
        for r in results:
            if r["url"] and r["content"]:
                all_findings.append({
                    "source": r["title"],
                    "url": r["url"],
                    "content": r["content"][:800],
                })
                if r["url"] not in [s["url"] for s in all_sources]:
                    all_sources.append({"name": r["title"][:80], "url": r["url"]})
        print(f"[AreaResearcher] ✓ {len(results)} results: {query[:55]}...")

    return all_findings, all_sources


def _synthesize(area_input: str, all_findings: list, all_sources: list, deep: bool = False) -> dict:
    """Ask Qwen to reason across all data and write a narrative report."""

    findings_text = "\n\n".join([
        f"SOURCE: {f['source']}\nURL: {f['url']}\nDATA: {f['content']}"
        for f in all_findings
    ])

    depth_instruction = """
This is a DEEP RESEARCH report. Go beyond surface-level summaries.
- Cite specific numbers, percentages, dollar amounts from the data
- Connect multiple data points to surface non-obvious conclusions
- Identify contradictions between sources and explain what they mean
- Point out what the data does NOT say but an investor should be suspicious of
- Be skeptical — don't just repeat what sources say, analyze it
""" if deep else """
Focus on the most important findings. Be specific to this neighborhood, not the broader city.
Cite actual numbers and data points from the sources, not vague generalities.
"""

    synthesis_prompt = f"""
You are an expert real estate investment analyst writing a research report about:
"{area_input}"

{depth_instruction}

You have data from {len(all_findings)} sources. Your job is to CONNECT THE DOTS and surface
insights a normal model wouldn't catch. Be SPECIFIC to this neighborhood — not the city.
If a source talks about the broader city and you can't confirm it applies to this specific area, say so.

Do NOT sound like ChatGPT. Be direct, specific, and analytical like a Goldman Sachs analyst would be.
Use actual data points. Say things like "property values in this zipcode rose 4.2% YoY" not
"property values have been increasing."

RAW DATA:
{findings_text}

Return a JSON object (no markdown, no backticks):
{{
  "title": "<specific research report title for this neighborhood>",
  "executive_summary": "<3-4 sentences. Bottom line investment thesis. Be specific with numbers.>",
  "sections": [
    {{
      "heading": "<specific topic>",
      "narrative": "<3-5 sentences of specific, data-backed analysis. Reference sources inline as [Name](url). Be specific to this neighborhood not the city.>"
    }}
  ],
  "key_insights": [
    "<non-obvious insight 1 connecting multiple data points with specifics>",
    "<non-obvious insight 2>",
    "<non-obvious insight 3>"
  ],
  "risks": "<specific risks with data to back them up>",
  "opportunities": "<specific opportunities with data to back them up>",
  "bottom_line": "<1-2 sentence verdict. Be direct. Would you invest here or not and why.>",
  "sources": [{{"name": "<name>", "url": "<url>"}}]
}}
"""

    print(f"[AreaResearcher] {'Deep' if deep else 'Standard'} synthesis across {len(all_findings)} data points...")
    raw = ask_qwen(synthesis_prompt, timeout=300 if deep else 240)

    if "```" in raw:
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    raw = raw.strip()

    report = json.loads(raw)
    report["area_input"] = area_input
    report["generated_at"] = datetime.utcnow().isoformat()
    report["sources"] = all_sources[:20]
    report["is_deep"] = deep

    sections = len(report.get("sections", []))
    print(f"[AreaResearcher] ✓ {'Deep' if deep else 'Standard'} report done — {sections} sections, {len(all_sources)} sources")
    return report


def research_area(area_input: str) -> dict:
    """Standard research — 6 queries, ~60-90s."""
    findings, sources = _collect_data(area_input, num_queries=6)
    return _synthesize(area_input, findings, sources, deep=False)


def deep_research(area_input: str) -> dict:
    """
    Deep research — 12 queries, much more data, deeper analysis.
    Triggered by user clicking 'Deep Dive' button.
    """
    findings, sources = _collect_data(area_input, num_queries=12)
    return _synthesize(area_input, findings, sources, deep=True)


def get_us_housing_news() -> list[dict]:
    """
    Fetch recent US housing market news for the Insights tab default cards.
    Returns a list of news items with title, summary, and source.
    """
    queries = [
        "US housing market news 2025 2026 mortgage rates",
        "real estate investment trends United States 2025",
        "Federal Reserve interest rates housing impact 2025",
    ]

    news_items = []
    for query in queries:
        results = search(query, max_results=3)
        for r in results:
            if r["title"] and r["content"]:
                news_items.append({
                    "title": r["title"],
                    "summary": r["content"][:300],
                    "url": r["url"],
                    "source": r["title"][:50],
                })

    return news_items[:6]


def answer_followup(area_input: str, question: str, existing_report: dict) -> str:
    prompt = f"""
You are a real estate analyst. You researched "{area_input}" and produced this report:
{json.dumps(existing_report, indent=2)}

User question: "{question}"

Answer directly and specifically using the report data. Cite sources as [Name](url).
If the question goes beyond what was researched, say so honestly — don't make things up.

Return ONLY a JSON object:
{{"answer": "<your specific answer in 2-4 sentences>"}}
"""
    raw = ask_qwen(prompt)
    if "```" in raw:
        raw = raw.split("```")[1]
        if raw.startswith("json"):
            raw = raw[4:]
    raw = raw.strip()
    return json.loads(raw).get("answer", "")
