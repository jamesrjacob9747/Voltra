from datetime import datetime, time, timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from ..db import get_db
from ..models import Vehicle
from ..schemas import MatchRequest
from ..services import plug
from ..services.chargers import match_chargers

router = APIRouter(tags=["match"])


def parse_ready_by(value: str, now: datetime) -> datetime:
    if len(value) == 5 and value[2] == ":":
        ready = datetime.combine(now.date(), time.fromisoformat(value))
        return ready if ready > now else ready + timedelta(days=1)
    return datetime.fromisoformat(value)


@router.post("/match")
def charge_match(body: MatchRequest, db: Session = Depends(get_db)):
    vehicle = db.get(Vehicle, body.vehicle_id)
    if vehicle is None:
        raise HTTPException(404, "Vehicle not found")
    if body.target_pct <= body.current_pct:
        raise HTTPException(422, "Target battery must be above current battery")
    now = plug.clock()
    results = match_chargers(
        db, vehicle=vehicle, current_pct=body.current_pct, target_pct=body.target_pct,
        ready_by=parse_ready_by(body.ready_by, now), lat=body.lat, lng=body.lng,
        radius_km=body.radius_km, now=now,
    )
    db.commit()
    return {"best": results[0] if results else None, "results": results}
