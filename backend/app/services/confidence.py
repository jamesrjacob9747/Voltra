"""Charging Confidence, 0-100 (PRD Algorithms 3). Deterministic, not AI."""
from dataclasses import dataclass
from datetime import datetime, timedelta

RECENT_WINDOW = timedelta(days=7)


@dataclass(frozen=True)
class Confidence:
    score: int
    band: str
    breakdown: dict[str, float]


def band_for(score: int) -> str:
    if score >= 85:
        return "Highly reliable"
    if score >= 60:
        return "Reliable"
    return "Unverified"


def compute_confidence(*, online: bool, host_confirmed: bool, total_sessions: int,
                       successful_sessions: int, total_bookings: int, host_cancellations: int,
                       last_success_at: datetime | None, slot_free: bool,
                       now: datetime) -> Confidence:
    success = 10.0 if total_sessions == 0 else 20 * successful_sessions / total_sessions
    cancel_rate = host_cancellations / total_bookings if total_bookings else 0.0
    recent = last_success_at is not None and now - last_success_at <= RECENT_WINDOW

    breakdown = {
        "iot_online": 30.0 if online else 0.0,
        "host_confirmed": 20.0 if host_confirmed else 0.0,
        "successful_sessions": round(success, 1),
        "cancellation_rate": round(10 * max(0.0, 1 - cancel_rate * 10), 1),
        "recent_activity": 10.0 if recent else 0.0,
        "availability": 10.0 if slot_free else 0.0,
    }
    score = round(sum(breakdown.values()))
    return Confidence(score, band_for(score), breakdown)
