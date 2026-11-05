"""Network impact for the pitch: what Voltra's chargers have delivered so far.

Everything is computed from the database. Real sessions are metered; the seeded track record
(each charger's successful_sessions beyond the ones recorded here) is estimated at a typical
scooter top-up. Emission factors are approximate and returned with the numbers.
"""

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..models import Booking, Charger, ChargingSession, Payment

router = APIRouter(tags=["impact"])

# Approximate factors (shown in the app's footnote).
KWH_PER_SESSION_ESTIMATE = 1.8  # typical 2-wheeler top-up, ~25% → 80% of a 3 kWh pack
KM_PER_KWH = 30.0  # electric scooter efficiency
PETROL_SCOOTER_KM_PER_LITRE = 50.0
CO2_KG_PER_LITRE_PETROL = 2.31
GRID_CO2_KG_PER_KWH = 0.72  # India grid average (CEA), approximate


@router.get("/impact")
def impact(db: Session = Depends(get_db)):
    chargers = db.scalars(select(Charger)).all()

    # Metered sessions recorded in this database, per charger.
    metered = dict(
        db.execute(
            select(Booking.charger_id, func.count(ChargingSession.id))
            .join(ChargingSession, ChargingSession.booking_id == Booking.id)
            .where(ChargingSession.meter_end_kwh.is_not(None))
            .group_by(Booking.charger_id)
        ).all()
    )
    real_kwh = db.scalar(select(func.coalesce(func.sum(Payment.energy_kwh), 0.0))) or 0.0
    real_host_paise = db.scalar(select(func.coalesce(func.sum(Payment.host_share_paise), 0))) or 0

    host_share = 1 - settings.platform_fee_bps / 10_000
    track_sessions = 0
    track_host_paise = 0.0
    for c in chargers:
        earlier = max(0, c.successful_sessions - metered.get(c.id, 0))
        track_sessions += earlier
        track_host_paise += earlier * KWH_PER_SESSION_ESTIMATE * c.base_price_per_kwh_paise * host_share

    kwh = real_kwh + track_sessions * KWH_PER_SESSION_ESTIMATE
    petrol_litres = kwh * KM_PER_KWH / PETROL_SCOOTER_KM_PER_LITRE
    co2_kg = petrol_litres * CO2_KG_PER_LITRE_PETROL - kwh * GRID_CO2_KG_PER_KWH

    rescues = db.scalar(select(func.count(Booking.id)).where(Booking.transferred_from_booking_id.is_not(None)))
    return {
        "chargers": len(chargers),
        "verified_chargers": sum(1 for c in chargers if c.verified),
        "hosts": len({c.host_id for c in chargers}),
        "sessions_completed": sum(c.successful_sessions for c in chargers),
        "kwh_shared": round(kwh, 1),
        "host_earnings_paise": round(real_host_paise + track_host_paise),
        "chargesure_rescues": rescues,
        "petrol_litres_avoided": round(petrol_litres, 1),
        "co2_kg_avoided": round(co2_kg, 1),
        "estimated_sessions": track_sessions,
        "factors": {
            "kwh_per_session_estimate": KWH_PER_SESSION_ESTIMATE,
            "km_per_kwh": KM_PER_KWH,
            "petrol_scooter_km_per_litre": PETROL_SCOOTER_KM_PER_LITRE,
            "co2_kg_per_litre_petrol": CO2_KG_PER_LITRE_PETROL,
            "grid_co2_kg_per_kwh": GRID_CO2_KG_PER_KWH,
        },
    }
