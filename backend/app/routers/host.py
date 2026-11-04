from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_db
from ..models import (ARRIVED, CANCELLED, CHARGING, CONFIRMED, PENDING, Booking, Charger, ChargingSession,
                      Payment, User)
from ..services import plug
from .bookings import booking_view
from .sessions import live_view

router = APIRouter(prefix="/host", tags=["host"])


@router.get("/{host_id}/dashboard")
def dashboard(host_id: int, db: Session = Depends(get_db)):
    if db.get(User, host_id) is None:
        raise HTTPException(404, "Host not found")
    now = plug.clock()
    day_start = datetime.combine(now.date(), datetime.min.time())
    charger_ids = list(db.scalars(select(Charger.id).where(Charger.host_id == host_id)))

    bookings = db.scalars(select(Booking).where(
        Booking.charger_id.in_(charger_ids)).order_by(Booking.start_time)).all()
    day_end = day_start + timedelta(days=1)
    today = [b for b in bookings if day_start <= b.start_time < day_end and b.status != CANCELLED]
    payments = db.scalars(select(Payment).where(
        Payment.booking_id.in_([b.id for b in today]))).all()

    live = None
    charging = next((b for b in bookings if b.status == CHARGING), None)
    if charging:
        session = db.scalar(select(ChargingSession).where(ChargingSession.booking_id == charging.id))
        live = live_view(db, session) if session else None

    db.commit()
    return {
        "host_id": host_id,
        "today": {
            "bookings": len(today),
            "energy_sold_kwh": round(sum(p.energy_kwh for p in payments), 2),
            "earnings_paise": sum(p.host_share_paise for p in payments if p.status == "PAID"),
            "pending_earnings_paise": sum(p.host_share_paise for p in payments if p.status != "PAID"),
        },
        "requests": [booking_view(db, b) for b in bookings if b.status == PENDING],
        "upcoming": [booking_view(db, b) for b in bookings
                     if b.status in (CONFIRMED, ARRIVED) and b.end_time >= now],
        "live_session": live,
    }
