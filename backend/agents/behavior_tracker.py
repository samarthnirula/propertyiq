"""
Agent 1: Behavior Tracker Agent

Logs every user action into the behavior-events table.
Called directly from FastAPI endpoints whenever the user does anything.
"""

import uuid
from datetime import datetime
from sqlalchemy.orm import Session
from db.database import BehaviorEvent


VALID_EVENT_TYPES = {"search", "save", "calculate", "dismiss", "compare", "view"}


def track_event(db: Session, user_id: str, event_type: str, payload: dict = None):
    """
    Log a user behavior event.

    Args:
        db:         SQLAlchemy session
        user_id:    ID of the user performing the action
        event_type: One of: search | save | calculate | dismiss | compare | view
        payload:    Any relevant data (zipcode, price, roi, etc.)
    """
    if event_type not in VALID_EVENT_TYPES:
        raise ValueError(f"Invalid event_type '{event_type}'. Must be one of {VALID_EVENT_TYPES}")

    event = BehaviorEvent(
        id=str(uuid.uuid4()),
        user_id=user_id,
        event_type=event_type,
        payload=payload or {},
        created_at=datetime.utcnow(),
    )

    db.add(event)
    db.commit()
    return event


def get_user_events(db: Session, user_id: str, limit: int = 100):
    """Fetch the most recent N events for a user."""
    return (
        db.query(BehaviorEvent)
        .filter(BehaviorEvent.user_id == user_id)
        .order_by(BehaviorEvent.created_at.desc())
        .limit(limit)
        .all()
    )


def get_user_zipcodes(db: Session, user_id: str) -> list[str]:
    """
    Extract all unique zipcodes a user has interacted with.
    Used by Market Scanner Agent to know what areas to watch.
    """
    events = (
        db.query(BehaviorEvent)
        .filter(BehaviorEvent.user_id == user_id)
        .all()
    )

    zipcodes = set()
    for event in events:
        if event.payload and "zipcode" in event.payload:
            zipcodes.add(str(event.payload["zipcode"]))

    return list(zipcodes)
