from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import local_now
from ..db import get_db
from ..models import DeviceToken, User, Vehicle
from ..schemas import DeviceTokenIn

router = APIRouter(prefix="/users", tags=["users"])


def _user(u: User) -> dict:
    return {
        "id": u.id,
        "name": u.name,
        "phone": u.phone,
        "role": u.role,
        "rating": u.rating,
        "kyc_status": u.kyc_status,
    }


@router.get("")
def list_users(db: Session = Depends(get_db)):
    """Demo login: the app shows these as a pick-a-user screen."""
    return [_user(u) for u in db.scalars(select(User).order_by(User.id))]


@router.post("/{user_id}/device-token", status_code=204)
def register_device_token(user_id: int, body: DeviceTokenIn, db: Session = Depends(get_db)):
    """The app sends its push token on every login; registering the same one again is a no-op."""
    if db.get(User, user_id) is None:
        raise HTTPException(404, "User not found")
    existing = db.scalar(select(DeviceToken).where(DeviceToken.user_id == user_id, DeviceToken.token == body.token))
    if existing is None:
        db.add(DeviceToken(user_id=user_id, token=body.token))
    else:
        existing.updated_at = local_now()
    db.commit()


@router.get("/{user_id}/vehicles")
def list_vehicles(user_id: int, db: Session = Depends(get_db)):
    if db.get(User, user_id) is None:
        raise HTTPException(404, "User not found")
    return [
        {
            "id": v.id,
            "model": v.model,
            "battery_kwh": v.battery_kwh,
            "charger_kw": v.charger_kw,
            "connector_type": v.connector_type,
        }
        for v in db.scalars(select(Vehicle).where(Vehicle.user_id == user_id))
    ]
