from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..models import ARRIVED, CHARGING, COMPLETED, CONFIRMED, Booking, Charger, ChargingSession, Payment
from ..schemas import SessionStart
from ..services import energy, plug
from ..services.billing import compute_bill, metered_kwh
from ..services.chargers import alternatives_for, booking_vehicle, is_online
from ..services.pricing import price_at

router = APIRouter(prefix="/sessions", tags=["sessions"])

QR_PREFIX = "voltra://charger/"
SCOOTER_FALLBACK_KW = 0.75


def _session(db: Session, session_id: int) -> ChargingSession:
    session = db.get(ChargingSession, session_id)
    if session is None:
        raise HTTPException(404, "Session not found")
    return session


@router.post("/start", status_code=201)
def start_session(body: SessionStart, db: Session = Depends(get_db)):
    booking = db.get(Booking, body.booking_id)
    if booking is None:
        raise HTTPException(404, "Booking not found")
    charger = db.get(Charger, booking.charger_id)
    if body.qr != f"{QR_PREFIX}{charger.device_id}":
        raise HTTPException(409, "This QR code belongs to a different charger")
    if booking.status not in (CONFIRMED, ARRIVED):
        raise HTTPException(409, f"Booking is {booking.status}, not ready to charge")

    now = plug.clock()
    if now > booking.end_time:
        raise HTTPException(409, "This booking's slot has ended")
    if not is_online(charger, now):
        # ChargeSure: hand the app the alternatives in the same response.
        alternatives = alternatives_for(db, booking, now)
        db.commit()
        raise HTTPException(
            409,
            {"code": "CHARGER_OFFLINE", "alternatives": alternatives, "credit_paise": settings.chargesure_credit_paise},
        )

    vehicle = booking_vehicle(db, booking)
    load_kw = energy.charging_power_kw(
        charger.connector_type, charger.power_kw, vehicle.charger_kw if vehicle else SCOOTER_FALLBACK_KW
    )
    device = plug.get_plug(charger.device_id)
    device.switch(True, load_kw)
    reading = device.read()

    session = ChargingSession(
        booking_id=booking.id,
        meter_start_kwh=reading.energy_kwh,
        price_per_kwh_paise=price_at(charger.base_price_per_kwh_paise, now.hour),
        started_at=now,
    )
    booking.status = CHARGING
    db.add(session)
    db.commit()
    return live_view(db, session)


def live_view(db: Session, session: ChargingSession) -> dict:
    booking = db.get(Booking, session.booking_id)
    charger = db.get(Charger, booking.charger_id)
    now = plug.clock()
    ended = session.meter_end_kwh is not None
    reading = None if ended else plug.get_plug(charger.device_id).read()

    meter = session.meter_end_kwh if ended else (reading.energy_kwh if reading else session.meter_start_kwh)
    kwh = metered_kwh(session.meter_start_kwh, meter)
    if reading:
        session.peak_kw = max(session.peak_kw, reading.power_w / 1000)
    bill = compute_bill(kwh, session.price_per_kwh_paise, settings.platform_fee_bps)
    return {
        "session_id": session.id,
        "booking_id": booking.id,
        "charger": {"id": charger.id, "name": charger.name},
        "status": "COMPLETED" if ended else "CHARGING",
        "online": ended or reading is not None,
        "voltage": reading.voltage if reading else None,
        "current": reading.current if reading else None,
        "power_kw": round(reading.power_w / 1000, 2) if reading else 0.0,
        "energy_kwh": kwh,
        # Same simulated clock as the energy, so kWh / duration always matches the power shown.
        "duration_s": int(((session.ended_at or now) - session.started_at).total_seconds() * plug.demo_speed),
        "price_per_kwh_paise": session.price_per_kwh_paise,
        "cost_paise": bill.total_paise,
        "demo_speed": plug.demo_speed,
    }


@router.get("/{session_id}/live")
def get_live(session_id: int, db: Session = Depends(get_db)):
    session = _session(db, session_id)
    view = live_view(db, session)
    db.commit()
    return view


@router.post("/{session_id}/stop")
def stop_session(session_id: int, db: Session = Depends(get_db)):
    session = _session(db, session_id)
    if session.meter_end_kwh is not None:
        raise HTTPException(409, "Session already stopped")
    booking = db.get(Booking, session.booking_id)
    charger = db.get(Charger, booking.charger_id)
    device = plug.get_plug(charger.device_id)
    reading = device.read()
    if reading is None:
        raise HTTPException(409, "Can't read the meter: the charger is offline")
    device.switch(False)

    now = plug.clock()
    session.meter_end_kwh = reading.energy_kwh
    session.ended_at = now
    kwh = metered_kwh(session.meter_start_kwh, session.meter_end_kwh)
    bill = compute_bill(kwh, session.price_per_kwh_paise, settings.platform_fee_bps)

    booking.status = COMPLETED
    charger.total_sessions += 1
    if kwh > 0:
        charger.successful_sessions += 1
        charger.last_success_at = now

    payment = db.scalar(select(Payment).where(Payment.booking_id == booking.id))
    if payment is None:
        payment = Payment(booking_id=booking.id)
        db.add(payment)
    payment.energy_kwh = kwh
    payment.total_paise = bill.total_paise
    payment.platform_fee_paise = bill.platform_fee_paise
    payment.host_share_paise = bill.host_share_paise
    payment.credit_paise = min(booking.credit_paise, bill.total_paise)
    db.commit()

    return {
        **live_view(db, session),
        "meter_start_kwh": session.meter_start_kwh,
        "meter_end_kwh": session.meter_end_kwh,
        "bill": {
            "energy_kwh": kwh,
            "total_paise": bill.total_paise,
            "platform_fee_paise": bill.platform_fee_paise,
            "host_share_paise": bill.host_share_paise,
            "credit_paise": payment.credit_paise,
            "payable_paise": bill.total_paise - payment.credit_paise,
        },
        "payment_id": payment.id,
    }
