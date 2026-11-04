from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_db
from ..models import Charger, Telemetry
from ..schemas import TelemetryIn
from ..services import plug

router = APIRouter(tags=["telemetry"])


@router.post("/telemetry", status_code=202)
def ingest(body: TelemetryIn, db: Session = Depends(get_db)):
    """For real devices later: each reading is stored and counts as a heartbeat."""
    charger = db.scalar(select(Charger).where(Charger.device_id == body.charger_id))
    if charger is None:
        raise HTTPException(404, "Unknown device")
    now = plug.clock()
    db.add(
        Telemetry(
            device_id=body.charger_id,
            ts=now,
            voltage=body.voltage,
            current=body.current,
            power_w=body.power_w,
            energy_kwh=body.energy_kwh,
        )
    )
    charger.last_heartbeat_at = now
    db.commit()
    return {"ok": True}
