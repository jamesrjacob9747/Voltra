"""Demo controls. Used on stage to trigger ChargeSure and to reset between rehearsals."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_db
from ..models import Charger
from ..schemas import PlugOnline
from ..seed import reset_and_seed
from ..services import plug

router = APIRouter(prefix="/admin", tags=["admin"])


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
