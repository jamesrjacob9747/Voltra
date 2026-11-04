"""Demo controls. Used on stage to trigger ChargeSure and to reset between rehearsals."""

import hmac

from fastapi import APIRouter, Depends, Header, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..models import Charger
from ..schemas import PlugOnline
from ..seed import reset_and_seed
from ..services import plug


def require_demo_endpoints(x_admin_token: str | None = Header(default=None)) -> None:
    """Stage controls: they exist only while DEMO_ENDPOINTS=true, and when ADMIN_TOKEN is set
    (any hosted server) the caller must also send it in the X-Admin-Token header."""
    if not settings.demo_endpoints:
        raise HTTPException(404, "Not found")
    if settings.admin_token and not hmac.compare_digest(x_admin_token or "", settings.admin_token):
        raise HTTPException(403, "Admin token required")


router = APIRouter(prefix="/admin", tags=["admin"], dependencies=[Depends(require_demo_endpoints)])


@router.post("/plugs/{device_id}/online")
def set_plug_online(device_id: str, body: PlugOnline, db: Session = Depends(get_db)):
    if db.scalar(select(Charger).where(Charger.device_id == device_id)) is None:
        raise HTTPException(404, "Unknown device")
    plug.get_plug(device_id).set_online(body.online)
    return {"device_id": device_id, "online": body.online}


@router.post("/reset")
def reset_demo():
    plug.reset_plugs()
    reset_and_seed()
    return {"ok": True}
