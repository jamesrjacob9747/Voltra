"""Demo controls. Used on stage to trigger ChargeSure and to reset between rehearsals."""

import hmac

from fastapi import APIRouter, BackgroundTasks, Depends, Header, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..models import ARRIVED, CONFIRMED, PENDING, Booking, Charger
from ..schemas import PlugOnline
from ..seed import reset_and_seed
from ..services import plug, push


def require_demo_endpoints(x_admin_token: str | None = Header(default=None)) -> None:
    """Stage controls: they exist only while DEMO_ENDPOINTS=true, and when ADMIN_TOKEN is set
    (any hosted server) the caller must also send it in the X-Admin-Token header."""
    if not settings.demo_endpoints:
        raise HTTPException(404, "Not found")
    if settings.admin_token and not hmac.compare_digest(x_admin_token or "", settings.admin_token):
        raise HTTPException(403, "Admin token required")


router = APIRouter(prefix="/admin", tags=["admin"], dependencies=[Depends(require_demo_endpoints)])


@router.post("/plugs/{device_id}/online")
def set_plug_online(device_id: str, body: PlugOnline, background: BackgroundTasks, db: Session = Depends(get_db)):
    charger = db.scalar(select(Charger).where(Charger.device_id == device_id))
    if charger is None:
        raise HTTPException(404, "Unknown device")
    plug.get_plug(device_id).set_online(body.online)

    if not body.online:
        # ChargeSure, before the driver even leaves home: warn everyone with an upcoming booking here.
        upcoming = db.scalars(
            select(Booking).where(
                Booking.charger_id == charger.id,
                Booking.status.in_((PENDING, CONFIRMED, ARRIVED)),
                Booking.end_time > plug.clock(),
            )
        )
        credit = push.rupees(settings.chargesure_credit_paise)
        text = f"{charger.name} just went offline. Open Voltra: ChargeSure has nearby chargers and a {credit} credit."
        for b in upcoming:
            background.add_task(
                push.notify, b.driver_id, "Your charger is offline", text, type="chargesure", booking_id=str(b.id)
            )
    return {"device_id": device_id, "online": body.online}


@router.post("/reset")
def reset_demo():
    plug.reset_plugs()
    reset_and_seed()
    return {"ok": True}
