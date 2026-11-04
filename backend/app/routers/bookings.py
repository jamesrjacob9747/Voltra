from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..models import ARRIVED, CANCELLED, CONFIRMED, PENDING, Booking, Charger, ChargingSession, User, Vehicle
from ..schemas import BookingAction, BookingCreate, TransferRequest
from ..services import plug
from ..services.chargers import alternatives_for, is_online, slot_free

router = APIRouter(prefix="/bookings", tags=["bookings"])


def booking_view(db: Session, b: Booking) -> dict:
    charger = db.get(Charger, b.charger_id)
    driver = db.get(User, b.driver_id)
    return {
        "id": b.id,
        "status": b.status,
        "charger": {"id": charger.id, "name": charger.name, "device_id": charger.device_id},
        "driver": {"id": driver.id, "name": driver.name},
        "vehicle_id": b.vehicle_id,
        "start_time": b.start_time.isoformat(timespec="minutes"),
        "end_time": b.end_time.isoformat(timespec="minutes"),
        "credit_paise": b.credit_paise,
        "transferred_from_booking_id": b.transferred_from_booking_id,
        # Lets the app reopen the live screen or the bill for this booking.
        "session_id": db.scalar(select(ChargingSession.id).where(ChargingSession.booking_id == b.id)),
    }


def _get(db: Session, booking_id: int) -> Booking:
    booking = db.get(Booking, booking_id)
    if booking is None:
        raise HTTPException(404, "Booking not found")
    return booking


@router.post("", status_code=201)
def create_booking(body: BookingCreate, db: Session = Depends(get_db)):
    charger = db.get(Charger, body.charger_id)
    if charger is None or db.get(User, body.driver_id) is None:
        raise HTTPException(404, "Charger or driver not found")
    if body.vehicle_id and db.get(Vehicle, body.vehicle_id) is None:
        raise HTTPException(404, "Vehicle not found")
    if body.end_time <= body.start_time:
        raise HTTPException(422, "End time must be after start time")
    if not slot_free(db, charger, body.start_time, body.end_time):
        raise HTTPException(409, "That slot is not available")

    booking = Booking(**body.model_dump(), status=CONFIRMED if charger.auto_approve else PENDING)
    charger.total_bookings += 1
    db.add(booking)
    db.commit()
    return booking_view(db, booking)


@router.get("")
def list_bookings(driver_id: int | None = None, host_id: int | None = None, db: Session = Depends(get_db)):
    query = select(Booking).order_by(Booking.start_time.desc())
    if driver_id is not None:
        query = query.where(Booking.driver_id == driver_id)
    if host_id is not None:
        query = query.join(Charger, Charger.id == Booking.charger_id).where(Charger.host_id == host_id)
    return [booking_view(db, b) for b in db.scalars(query)]


@router.get("/{booking_id}")
def get_booking(booking_id: int, db: Session = Depends(get_db)):
    return booking_view(db, _get(db, booking_id))


@router.patch("/{booking_id}")
def update_booking(booking_id: int, body: BookingAction, db: Session = Depends(get_db)):
    booking = _get(db, booking_id)
    charger = db.get(Charger, booking.charger_id)
    is_host = body.actor_id == charger.host_id
    is_driver = body.actor_id == booking.driver_id

    if body.action in ("accept", "decline"):
        if not is_host or booking.status != PENDING:
            raise HTTPException(409, "Only the host can accept or decline a pending booking")
        booking.status = CONFIRMED if body.action == "accept" else CANCELLED
        if body.action == "decline":
            charger.host_cancellations += 1
    elif body.action == "cancel":
        if not (is_host or is_driver) or booking.status not in (PENDING, CONFIRMED, ARRIVED):
            raise HTTPException(409, "This booking can't be cancelled")
        booking.status = CANCELLED
        if is_host:
            charger.host_cancellations += 1
    elif body.action == "arrive":
        if not is_driver or booking.status != CONFIRMED:
            raise HTTPException(409, "Only the driver can mark a confirmed booking as arrived")
        booking.status = ARRIVED
    db.commit()
    return booking_view(db, booking)


@router.get("/{booking_id}/health")
def booking_health(booking_id: int, db: Session = Depends(get_db)):
    """The app polls this before and on arrival; offline triggers the ChargeSure screen."""
    booking = _get(db, booking_id)
    now = plug.clock()
    online = is_online(db.get(Charger, booking.charger_id), now)
    alternatives = [] if online else alternatives_for(db, booking, now)
    db.commit()
    return {
        "booking_id": booking.id,
        "online": online,
        "alternatives": alternatives,
        "credit_paise": 0 if online else settings.chargesure_credit_paise,
    }


@router.post("/{booking_id}/transfer", status_code=201)
def transfer_booking(booking_id: int, body: TransferRequest, db: Session = Depends(get_db)):
    """ChargeSure: move the booking to another charger and add the platform-funded credit."""
    old = _get(db, booking_id)
    if old.status not in (PENDING, CONFIRMED, ARRIVED):
        raise HTTPException(409, "Only an upcoming booking can be transferred")
    target = db.get(Charger, body.to_charger_id)
    if target is None or target.id == old.charger_id:
        raise HTTPException(404, "Pick a different charger")

    now = plug.clock()
    start = max(now, old.start_time)
    end = start + max(old.end_time - old.start_time, timedelta(minutes=30))
    if not is_online(target, now) or not slot_free(db, target, start, end):
        raise HTTPException(409, "That charger can't take this booking")

    old.status = CANCELLED
    db.get(Charger, old.charger_id).host_cancellations += 1  # a failed charger counts against it
    new = Booking(
        charger_id=target.id,
        driver_id=old.driver_id,
        vehicle_id=old.vehicle_id,
        start_time=start,
        end_time=end,
        status=CONFIRMED,
        transferred_from_booking_id=old.id,
        credit_paise=old.credit_paise + settings.chargesure_credit_paise,
    )
    target.total_bookings += 1
    db.add(new)
    db.commit()
    return booking_view(db, new)
