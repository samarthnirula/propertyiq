from sqlalchemy import create_engine, Column, String, Float, JSON, DateTime, Text
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime
import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://user:password@localhost:5432/propertyiq")

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(bind=engine)
Base = declarative_base()


class BehaviorEvent(Base):
    """Logs every user action inside PropertyIQ"""
    __tablename__ = "behavior_events"

    id = Column(String, primary_key=True)             # uuid
    user_id = Column(String, nullable=False)
    event_type = Column(String, nullable=False)        # search | save | calculate | dismiss | compare
    payload = Column(JSON, nullable=True)              # e.g. { zipcode, price, roi }
    created_at = Column(DateTime, default=datetime.utcnow)


class UserProfile(Base):
    """Synthesized profile per user, rebuilt periodically by Profile Synthesizer Agent"""
    __tablename__ = "user_profiles"

    user_id = Column(String, primary_key=True)
    risk_tolerance = Column(String, nullable=True)     # low | medium | high
    investment_style = Column(String, nullable=True)   # flip | long_term_rental | unsure
    preferred_zipcodes = Column(JSON, nullable=True)   # list of zipcodes
    price_range_min = Column(Float, nullable=True)
    price_range_max = Column(Float, nullable=True)
    target_cash_flow = Column(Float, nullable=True)
    investment_horizon = Column(String, nullable=True) # short | medium | long
    raw_summary = Column(Text, nullable=True)          # full LLM-generated profile text
    updated_at = Column(DateTime, default=datetime.utcnow)


class MarketSignal(Base):
    """A ranked market signal for a given zipcode, produced by Market Scanner + Signal Ranker"""
    __tablename__ = "market_signals"

    id = Column(String, primary_key=True)
    zipcode = Column(String, nullable=False)
    headline = Column(Text, nullable=True)
    source_url = Column(Text, nullable=True)
    direction = Column(String, nullable=True)          # bullish | bearish | neutral
    confidence = Column(Float, nullable=True)          # 0.0 - 1.0
    magnitude = Column(String, nullable=True)          # low | medium | high
    raw_summary = Column(Text, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)


class UserInsight(Base):
    """A personalized insight card for a specific user, written by Insight Writer Agent"""
    __tablename__ = "user_insights"

    id = Column(String, primary_key=True)
    user_id = Column(String, nullable=False)
    zipcode = Column(String, nullable=True)
    headline = Column(Text, nullable=True)
    explanation = Column(Text, nullable=True)
    direction = Column(String, nullable=True)          # bullish | bearish | neutral
    read = Column(String, default="false")
    created_at = Column(DateTime, default=datetime.utcnow)


def init_db():
    Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
