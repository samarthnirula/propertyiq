"""
 every 4 hours: Profile Synthesizer (rebuild all user profiles)
 every 24 hours: Market Scanner - Signal Ranker - Matchmaker - Insight Writer
"""

from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
from db.database import SessionLocal
from agents.profile_synthesizer import synthesize_all_profiles
from agents.market_scanner import scan_all_watched_zipcodes
from agents.signal_ranker import rank_and_store_signals
from agents.matchmaker import match_all_users
from agents.insight_writer import write_insights_for_all_users


def run_profile_pipeline():
    """Rebuild all user profiles from behavior history."""
    print("\n[Scheduler] ▶ Starting Profile Synthesis Pipeline...")
    db = SessionLocal()
    try:
        synthesize_all_profiles(db)
        print("[Scheduler] ✓ Profile Synthesis complete.\n")
    except Exception as e:
        print(f"[Scheduler] ✗ Profile pipeline failed: {e}")
    finally:
        db.close()


def run_market_pipeline():
    """
            can web - Rank signals - Match to users - Write insights
    """
    print("\n[Scheduler] ▶ Starting Market Intelligence Pipeline...")
    db = SessionLocal()
    try:
        # Step 1: Scan the web for market news
        articles = scan_all_watched_zipcodes(db)
        print(f"[Scheduler] Market scan complete. {len(articles)} articles found.")

        if not articles:
            print("[Scheduler] No articles found, skipping rest of pipeline.")
            return

        # Step 2: Rank and classify signals
        signals = rank_and_store_signals(db, articles)
        print(f"[Scheduler] Signal ranking complete. {len(signals)} signals stored.")

        # Step 3: Match signals to users
        all_matches = match_all_users(db)
        total_matches = sum(len(v) for v in all_matches.values())
        print(f"[Scheduler] Matchmaking complete. {total_matches} total matches across all users.")

        # Step 4: Write personalized insight cards
        total_insights = write_insights_for_all_users(db, all_matches)
        print(f"[Scheduler] ✓ Market pipeline complete. {total_insights} insights written.\n")

    except Exception as e:
        print(f"[Scheduler] ✗ Market pipeline failed: {e}")
    finally:
        db.close()


def start_scheduler():
    scheduler = BackgroundScheduler()

    # Rebuild user profiles every 4 hours
    scheduler.add_job(
        run_profile_pipeline,
        trigger=IntervalTrigger(hours=4),
        id="profile_pipeline",
        name="Profile Synthesizer",
        replace_existing=True,
    )

    # Run full market intelligence pipeline every 24 hours
    scheduler.add_job(
        run_market_pipeline,
        trigger=IntervalTrigger(hours=24),
        id="market_pipeline",
        name="Market Intelligence Pipeline",
        replace_existing=True,
    )

    scheduler.start()
    print("[Scheduler] ✓ Scheduler started. Profile pipeline: every 4h | Market pipeline: every 24h")
    return scheduler
