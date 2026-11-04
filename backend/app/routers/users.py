from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_db
from ..models import User, Vehicle

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
