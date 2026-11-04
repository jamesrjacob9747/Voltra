from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..db import get_db
from ..models import Charger, User
from ..schemas import ChargerCreate
from ..services import plug
from ..services.chargers import can_see_exact, charger_view
from ..services.geo import approximate_location

router = APIRouter(prefix="/chargers", tags=["chargers"])


@router.get("")
def list_chargers(
    lat: float,
    lng: float,
    radius_km: float = 5.0,
    connector: str | None = None,
    max_price_paise: int | None = None,
    available_now: bool = False,
    db: Session = Depends(get_db),
):
    now = plug.clock()
    views = []
    for c in db.scalars(select(Charger)).all():
        if connector and c.connector_type != connector:
            continue
        view = charger_view(db, c, now, lat=lat, lng=lng)
        if view["distance_km"] > radius_km:
            continue
        if max_price_paise and view["price_now_per_kwh_paise"] > max_price_paise:
            continue
        if available_now and not (view["online"] and view["confidence"]["breakdown"]["availability"]):
            continue
        views.append(view)
    db.commit()  # persist refreshed heartbeats
    return sorted(views, key=lambda v: v["distance_km"])


@router.get("/{charger_id}")
def get_charger(charger_id: int, user_id: int | None = None, db: Session = Depends(get_db)):
    charger = db.get(Charger, charger_id)
    if charger is None:
        raise HTTPException(404, "Charger not found")
    view = charger_view(db, charger, plug.clock(), exact=can_see_exact(db, charger_id, user_id))
    db.commit()
    return view


@router.post("", status_code=201)
def create_charger(body: ChargerCreate, db: Session = Depends(get_db)):
    host = db.get(User, body.host_id)
    if host is None:
        raise HTTPException(404, "Host not found")
    if host.role not in ("host", "both"):
        raise HTTPException(403, "Only hosts can add chargers")

    alat, alng = approximate_location(body.lat, body.lng)
    # The code comes from the id the database assigns, so it is unique even when ids skip
    # numbers or two hosts add a charger at the same moment.
    charger = Charger(
        **body.model_dump(), approx_lat=alat, approx_lng=alng, device_id=f"NEW-{uuid4().hex[:12]}", verified=False
    )
    db.add(charger)
    db.flush()
    charger.device_id = f"CHG{charger.id:03d}"
    db.commit()
    return charger_view(db, charger, plug.clock(), exact=True)
