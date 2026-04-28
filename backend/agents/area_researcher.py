from typing import Dict, List

from services.stats_service import (
    get_area_stats_simple,
    infer_zipcode_from_area_input,
)


def _safe_text(value, fallback="Not available"):
    if value is None:
        return fallback
    text = str(value).strip()
    return text if text else fallback


def _money(value):
    if value is None:
        return "Not available"
    try:
        return f"${float(value):,.0f}"
    except Exception:
        return "Not available"


def _pct(value):
    if value is None:
        return "Not available"
    try:
        return f"{float(value):.1f}%"
    except Exception:
        return "Not available"


def _build_sources(area_input: str, zip_code: str) -> List[Dict]:
    return [
        {
            "name": "Area Stats API",
            "url": f"/area-stats?area_input={area_input}&zipcode={zip_code}",
        },
        {
            "name": "U.S. Census ACS",
            "url": "https://api.census.gov/data.html",
        },
        {
            "name": "FRED",
            "url": "https://fred.stlouisfed.org/",
        },
        {
            "name": "Local ZIP market dataset",
            "url": "internal://zip_market_dataset.csv",
        },
    ]


def _build_key_insights(stats: Dict) -> List[str]:
    insights = []

    avg_price = stats.get("average_property_price")
    rent = stats.get("median_rent_estimate")
    income = stats.get("median_household_income")
    pop = stats.get("population_change_pct")
    owner = stats.get("owner_share_pct")
    prediction = stats.get("algorithm_prediction")
    forecast_q4 = stats.get("forecast_q4_price")

    if prediction is not None:
        insights.append(
            f"The AI market valuation for this ZIP is approximately **{_money(prediction)}**, which serves as a current comparable-based estimate."
        )

    if avg_price is not None and rent is not None:
        insights.append(
            f"Current area pricing is around **{_money(avg_price)}** with median rent near **{_money(rent)}**, which helps frame the local price-to-rent relationship."
        )

    if income is not None:
        insights.append(
            f"Median household income is estimated at **{_money(income)}**, which provides a useful demand-side affordability signal."
        )

    if pop is not None:
        insights.append(
            f"Population trend is **{_pct(pop)}**, suggesting the area is {'growing' if float(pop) > 0 else 'stable/slightly contracting'} over the latest comparison window."
        )

    if owner is not None:
        insights.append(
            f"Owner occupancy is about **{_pct(owner)}**, which indicates a {'more ownership-oriented' if float(owner) >= 60 else 'more renter-balanced'} housing mix."
        )

    if forecast_q4 is not None:
        insights.append(
            f"The 1-year trend model points to a Q4 projected value near **{_money(forecast_q4)}**, which is useful as a directional screening estimate."
        )

    return insights[:6]


def _build_sections(stats: Dict) -> List[Dict]:
    sections = []

    sections.append({
        "heading": "Market Overview",
        "narrative": (
            f"This area is currently characterized by an average property value near {_money(stats.get('average_property_price'))} "
            f"and median rent near {_money(stats.get('median_rent_estimate'))}. "
            f"The AI comparable-market estimate is {_money(stats.get('algorithm_prediction'))}, which is designed to reflect the current market value based on similar ZIP codes."
        ),
    })

    sections.append({
        "heading": "Demographics & Demand",
        "narrative": (
            f"Median household income is {_money(stats.get('median_household_income'))}, while population change is {_pct(stats.get('population_change_pct'))}. "
            f"Owner share is {_pct(stats.get('owner_share_pct'))} and renter share is {_pct(stats.get('renter_share_pct'))}. "
            f"Together, these signals help indicate the likely stability and demand profile of the local housing base."
        ),
    })

    sections.append({
        "heading": "Rental & Yield Context",
        "narrative": _safe_text(
            stats.get("price_rent_context"),
            "Rental market context is limited for this area."
        ),
    })

    sections.append({
        "heading": "Macro Conditions",
        "narrative": (
            f"County unemployment trend is {_pct(stats.get('county_unemployment_trend_pct'))}. "
            f"{_safe_text(stats.get('metro_labor_trend'), '')} "
            f"{_safe_text(stats.get('macro_signal'), '')}"
        ).strip(),
    })

    sections.append({
        "heading": "Forecast Outlook",
        "narrative": (
            f"Forecast pricing moves from {_money(stats.get('forecast_current_price'))} currently "
            f"to {_money(stats.get('forecast_q1_price'))}, {_money(stats.get('forecast_q2_price'))}, "
            f"{_money(stats.get('forecast_q3_price'))}, and {_money(stats.get('forecast_q4_price'))} over the next four quarters. "
            f"{_safe_text(stats.get('forecast_summary'), '')}"
        ).strip(),
    })

    if stats.get("notes"):
        sections.append({
            "heading": "Data Notes",
            "narrative": _safe_text(stats.get("notes")),
        })

    return sections


def research_area(area_input: str) -> Dict:
    zip_code = infer_zipcode_from_area_input(area_input) or area_input.strip()

    stats = get_area_stats_simple(zip_code, area_input=area_input)

    title = f"Area Intelligence Report for {area_input}"

    executive_summary = (
        f"{area_input} shows current pricing around {_money(stats.get('average_property_price'))} "
        f"with an AI-estimated market value of {_money(stats.get('algorithm_prediction')) if stats.get('algorithm_prediction') is not None else 'not available'}. "
        f"Median household income is {_money(stats.get('median_household_income'))}, and population change is {_pct(stats.get('population_change_pct'))}. "
        f"This area appears {'owner-oriented' if (stats.get('owner_share_pct') or 0) >= 60 else 'more renter-balanced'}, "
        f"with a directional 1-year outlook toward {_money(stats.get('forecast_q4_price'))}."
    )

    return {
        "title": title,
        "executive_summary": executive_summary,
        "key_insights": _build_key_insights(stats),
        "sections": _build_sections(stats),
        "sources": _build_sources(area_input, zip_code),
        "raw_stats": stats,
    }


def deep_research(area_input: str) -> Dict:
    base = research_area(area_input)
    stats = base.get("raw_stats", {})

    deep_sections = list(base["sections"])

    deep_sections.insert(1, {
        "heading": "Comparable Market Interpretation",
        "narrative": (
            f"The AI pricing model estimated {_money(stats.get('algorithm_prediction'))} for this ZIP using nearby and structurally similar ZIP code comparables. "
            f"The model also tracks its historical error level at {_pct(stats.get('algorithm_error_pct')) if stats.get('algorithm_error_pct') is not None else 'not available'}, "
            f"which helps frame confidence in the current estimate."
        ),
    })

    deep_sections.append({
        "heading": "Strategic Read",
        "narrative": (
            f"For screening purposes, this ZIP appears most useful as a {'stability-oriented' if (stats.get('owner_share_pct') or 0) >= 60 else 'turnover/liquidity-oriented'} market. "
            f"Analysts should compare the AI valuation, current price level, and Q4 projection together rather than relying on any one figure in isolation."
        ),
    })

    return {
        "title": f"Deep Area Research for {area_input}",
        "executive_summary": base["executive_summary"],
        "key_insights": base["key_insights"],
        "sections": deep_sections,
        "sources": base["sources"],
        "raw_stats": stats,
        "deep": True,
    }


def answer_followup(area_input: str, question: str) -> Dict:
    q = (question or "").strip().lower()
    report = research_area(area_input)
    stats = report.get("raw_stats", {})

    if not q:
        return {"answer": "Please ask a question about the area."}

    if "rent" in q:
        answer = (
            f"Median rent is currently around {_money(stats.get('median_rent_estimate'))}. "
            f"{_safe_text(stats.get('price_rent_context'))}"
        )
    elif "income" in q or "salary" in q:
        answer = (
            f"Median household income is estimated at {_money(stats.get('median_household_income'))}. "
            f"This is one of the signals used to understand local affordability and demand strength."
        )
    elif "forecast" in q or "1 year" in q or "q4" in q:
        answer = (
            f"The current forecast path ends near {_money(stats.get('forecast_q4_price'))} by Q4. "
            f"This is a directional trend estimate and should be read together with the AI market value estimate."
        )
    elif "ai" in q or "prediction" in q or "model" in q:
        answer = (
            f"The AI comparable-market estimate is {_money(stats.get('algorithm_prediction')) if stats.get('algorithm_prediction') is not None else 'not available'}. "
            f"It is based on similar ZIPs and historical feature patterns rather than a formal appraisal."
        )
    elif "crime" in q or "safety" in q:
        answer = (
            f"County crime rate context is {_safe_text(stats.get('county_crime_rate'))}. "
            f"This is county-level context, not a block-by-block safety score."
        )
    else:
        answer = (
            f"For {area_input}, the main takeaways are: AI value around "
            f"{_money(stats.get('algorithm_prediction')) if stats.get('algorithm_prediction') is not None else 'not available'}, "
            f"current price around {_money(stats.get('average_property_price'))}, "
            f"and Q4 directional projection near {_money(stats.get('forecast_q4_price'))}."
        )

    return {"answer": answer}