"""Charger state shared by the routers: online status, free slots, Confidence, public view."""

from datetime import datetime, time, timedelta

from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..models import ARRIVED, CHARGING, CONFIRMED, PENDING, Booking, Charger, User, Vehicle
from . import energy, plug
from .confidence import Confidence, compute_confidence
from .geo import distance_km, travel_minutes
from .match import Candidate, rank
from .pricing import price_at

ACTIVE_STATUSES = (PENDING, CONFIRMED, ARRIVED, CHARGING)


def is_online(charger: Charger, now: datetime) -> bool:
    """Simulated plugs answer directly; a plug that doesn't answer is offline at once.

    Real devices will push /telemetry instead and use the HEARTBEAT_TIMEOUT_S rule.
    """
    if plug.get_plug(charger.device_id).read() is not None:
        charger.last_heartbeat_at = now
        return True
    return heartbeat_fresh(charger, now) and settings.plug_mode != "simulated"


def heartbeat_fresh(charger: Charger, now: datetime) -> bool:
    last = charger.last_heartbeat_at
    return last is not None and (now - last).total_seconds() <= settings.heartbeat_timeout_s


def _hours_on(charger: Charger, day: datetime) -> tuple[datetime, datetime]:
    start = datetime.combine(day.date(), time.fromisoformat(charger.available_from))
    end = datetime.combine(day.date(), time.fromisoformat(charger.available_to))
    return start, end


def busy_intervals(db: Session, charger_id: int, start: datetime, end: datetime) -> list[tuple[datetime, datetime]]:
    rows = db.scalars(
        select(Booking).where(
            Booking.charger_id == charger_id,
            Booking.status.in_(ACTIVE_STATUSES),
            Booking.start_time < end,
            Booking.end_time > start,
        )
    ).all()
    return [(b.start_time, b.end_time) for b in rows]


def free_fraction(db: Session, charger: Charger, start: datetime, end: datetime) -> float:
    """Share of [start, end] inside the host's hours and not booked by anyone else."""
    if end <= start:
        return 0.0
    open_from, open_to = _hours_on(charger, start)
    lo, hi = max(start, open_from), min(end, open_to)
    free = max(0.0, (hi - lo).total_seconds())
    for b_start, b_end in busy_intervals(db, charger.id, start, end):
        overlap = (min(hi, b_end) - max(lo, b_start)).total_seconds()
        free -= max(0.0, overlap)
    return max(0.0, free) / (end - start).total_seconds()


def slot_free(db: Session, charger: Charger, start: datetime, end: datetime) -> bool:
    return free_fraction(db, charger, start, end) >= 0.999


def confidence_for(db: Session, charger: Charger, now: datetime, online: bool) -> Confidence:
    return compute_confidence(
        online=online,
        host_confirmed=charger.auto_approve,
        total_sessions=charger.total_sessions,
        successful_sessions=charger.successful_sessions,
        total_bookings=charger.total_bookings,
        host_cancellations=charger.host_cancellations,
        last_success_at=charger.last_success_at,
        slot_free=slot_free(db, charger, now, now + timedelta(hours=1)),
        now=now,
    )


def charger_view(
    db: Session,
    charger: Charger,
    now: datetime,
    *,
    lat: float | None = None,
    lng: float | None = None,
    exact: bool = False,
    online: bool | None = None,
    conf: Confidence | None = None,
) -> dict:
    """Public view of a charger. Pass `online`/`conf` when already computed to skip a plug read
    and the Confidence queries."""
    if online is None:
        online = is_online(charger, now)
    if conf is None:
        conf = confidence_for(db, charger, now, online)
    host = db.get(User, charger.host_id)
    view = {
        "id": charger.id,
        "name": charger.name,
        "host": {"id": host.id, "name": host.name},
        "rating": charger.rating,
        "connector_type": charger.connector_type,
        "power_kw": charger.power_kw,
        "base_price_per_kwh_paise": charger.base_price_per_kwh_paise,
        "price_now_per_kwh_paise": price_at(charger.base_price_per_kwh_paise, now.hour),
        "available_from": charger.available_from,
        "available_to": charger.available_to,
        "auto_approve": charger.auto_approve,
        "verified": charger.verified,
        "device_id": charger.device_id,
        "image_url": charger.image_url,
        "successful_sessions": charger.successful_sessions,
        "online": online,
        "last_heartbeat_s": (
            int((now - charger.last_heartbeat_at).total_seconds()) if charger.last_heartbeat_at else None
        ),
        "confidence": {"score": conf.score, "band": conf.band, "breakdown": conf.breakdown},
        # Exact location only once a booking is confirmed (PRD F4).
        "location": {"lat": charger.lat, "lng": charger.lng, "exact": True}
        if exact
        else {"lat": charger.approx_lat, "lng": charger.approx_lng, "exact": False},
        "address": charger.address if exact else None,
    }
    if lat is not None and lng is not None:
        view["distance_km"] = round(distance_km(lat, lng, charger.lat, charger.lng), 2)
    return view


def can_see_exact(db: Session, charger_id: int, user_id: int | None) -> bool:
    if user_id is None:
        return False
    charger = db.get(Charger, charger_id)
    if charger and charger.host_id == user_id:
        return True
    return (
        db.scalar(
            select(Booking.id).where(
                Booking.charger_id == charger_id,
                Booking.driver_id == user_id,
                Booking.status.in_((CONFIRMED, ARRIVED, CHARGING)),
            )
        )
        is not None
    )


def booking_vehicle(db: Session, booking: Booking) -> Vehicle | None:
    if booking.vehicle_id:
        return db.get(Vehicle, booking.vehicle_id)
    return db.scalar(select(Vehicle).where(Vehicle.user_id == booking.driver_id))


CHARGESURE_RADIUS_KM = 2.0


def alternatives_for(db: Session, booking: Booking, now: datetime) -> list[dict]:
    """ChargeSure: online chargers near the failed one that can take the same slot length."""
    failed = db.get(Charger, booking.charger_id)
    vehicle = booking_vehicle(db, booking)
    duration = max(booking.end_time - booking.start_time, timedelta(minutes=30))
    start, end = now, now + duration

    candidates, confidences = [], {}
    for c in db.scalars(select(Charger).where(Charger.id != failed.id)).all():
        if vehicle and not energy.is_compatible(vehicle.connector_type, c.connector_type):
            continue
        dist = distance_km(failed.lat, failed.lng, c.lat, c.lng)
        if dist > CHARGESURE_RADIUS_KM or not is_online(c, now) or not slot_free(db, c, start, end):
            continue
        power = energy.charging_power_kw(c.connector_type, c.power_kw, vehicle.charger_kw if vehicle else None)
        confidences[c.id] = confidence_for(db, c, now, online=True)
        candidates.append(
            Candidate(c.id, dist, 1.0, confidences[c.id].score, price_at(c.base_price_per_kwh_paise, now.hour), power)
        )

    results = []
    for cand in rank(candidates, CHARGESURE_RADIUS_KM):
        view = charger_view(
            db,
            db.get(Charger, cand.charger_id),
            now,
            lat=failed.lat,
            lng=failed.lng,
            online=True,
            conf=confidences[cand.charger_id],
        )
        view["match_score"] = cand.score
        results.append(view)
    return results


CHEAPER_LATER_STEP = timedelta(minutes=30)
CHEAPER_LATER_MIN_SAVING_PAISE = 100  # only worth showing from ₹1


def cheaper_later(
    db: Session, charger: Charger, *, need_kwh: float, duration: timedelta, arrive: datetime, ready_by: datetime
) -> dict | None:
    """The cheapest later start that still finishes by ready_by, if it saves at least ₹1.

    The price is locked at the hour a session starts (sessions.start_session), so a driver who
    reserves this slot and starts it really pays this price. Among the cheapest reachable price
    levels, the earliest free half-hour slot wins.
    """
    base = charger.base_price_per_kwh_paise
    now_cost = round(need_kwh * price_at(base, arrive.hour))

    first = arrive.replace(second=0, microsecond=0)
    first += timedelta(minutes=(30 - first.minute % 30) % 30)  # next :00 or :30
    starts = []
    t = first
    while t + duration <= ready_by:
        starts.append(t)
        t += CHEAPER_LATER_STEP

    for level in sorted({price_at(base, s.hour) for s in starts}):
        cost = round(need_kwh * level)
        if now_cost - cost < CHEAPER_LATER_MIN_SAVING_PAISE:
            break  # higher levels save even less
        for s in (s for s in starts if price_at(base, s.hour) == level):
            if slot_free(db, charger, s, s + duration):
                return {
                    "start_at": s.isoformat(timespec="minutes"),
                    "finish_at": (s + duration).isoformat(timespec="minutes"),
                    "price_per_kwh_paise": level,
                    "est_cost_paise": cost,
                    "saving_paise": now_cost - cost,
                }
    return None


def match_chargers(
    db: Session,
    *,
    vehicle: Vehicle,
    current_pct: float,
    target_pct: float,
    ready_by: datetime,
    lat: float,
    lng: float,
    radius_km: float,
    now: datetime,
) -> list[dict]:
    """ChargeMatch: hard filters, then ranking. Returns views with an estimate each."""
    need_kwh = energy.energy_needed_kwh(current_pct, target_pct, vehicle.battery_kwh)
    candidates, estimates, confidences = [], {}, {}
    for c in db.scalars(select(Charger)).all():
        if not energy.is_compatible(vehicle.connector_type, c.connector_type):
            continue
        dist = distance_km(lat, lng, c.lat, c.lng)
        if dist > radius_km or not is_online(c, now):
            continue
        power = energy.charging_power_kw(c.connector_type, c.power_kw, vehicle.charger_kw)
        minutes = energy.charge_hours(need_kwh, power) * 60
        arrive = now + timedelta(minutes=travel_minutes(dist))
        finish = arrive + timedelta(minutes=minutes)
        if finish > ready_by or not slot_free(db, c, arrive, finish):
            continue
        price = price_at(c.base_price_per_kwh_paise, arrive.hour)
        confidences[c.id] = confidence_for(db, c, now, online=True)
        candidates.append(
            Candidate(c.id, dist, free_fraction(db, c, now, ready_by), confidences[c.id].score, price, power)
        )
        estimates[c.id] = {
            "energy_kwh": round(need_kwh, 2),
            "power_kw": round(power, 2),
            "charge_minutes": round(minutes),
            "arrive_at": arrive.isoformat(timespec="minutes"),
            "finish_at": finish.isoformat(timespec="minutes"),
            "est_cost_paise": round(need_kwh * price),
            "cheaper_later": cheaper_later(
                db, c, need_kwh=need_kwh, duration=finish - arrive, arrive=arrive, ready_by=ready_by
            ),
        }

    results = []
    for cand in rank(candidates, radius_km):
        view = charger_view(
            db, db.get(Charger, cand.charger_id), now, lat=lat, lng=lng, online=True, conf=confidences[cand.charger_id]
        )
        view["match_score"] = cand.score
        view["estimate"] = estimates[cand.charger_id]
        results.append(view)
    return results
