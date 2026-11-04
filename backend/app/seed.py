"""Demo data around Koramangala, Bengaluru. Run: python -m app.seed"""
from datetime import datetime, timedelta

from sqlalchemy.orm import Session

from .db import Base, SessionLocal, engine
from .models import Charger, User, Vehicle
from .services.geo import approximate_location


CHARGERS = [
    # name, host idx, lat, lng, connector, kW, Rs/kWh, auto-approve, sessions, ok, bookings, cancels, rating
    ("Manoj's Home Charger", 0, 12.9352, 77.6245, "15A", 3.3, 12, True, 143, 140, 150, 1, 4.8),
    ("Rahul's Charging Point", 1, 12.9381, 77.6262, "15A", 3.3, 11, True, 88, 86, 92, 1, 4.7),
    ("Koramangala 5th Block Cafe", 2, 12.9339, 77.6190, "15A", 2.2, 14, True, 51, 48, 55, 2, 4.5),
    ("Priya's Wallbox", 3, 12.9305, 77.6280, "TYPE2", 7.2, 15, False, 30, 29, 33, 1, 4.9),
    ("Sony Signal Kirana", 2, 12.9372, 77.6301, "15A", 2.2, 10, True, 12, 10, 15, 2, 4.2),
    ("HSR Office Parking", 1, 12.9260, 77.6330, "TYPE2", 7.2, 13, True, 64, 63, 66, 0, 4.6),
    ("Ejipura Garage Socket", 0, 12.9420, 77.6230, "15A", 3.3, 9, False, 0, 0, 0, 0, 5.0),
    ("Forum Mall Lane Host", 3, 12.9345, 77.6110, "15A", 3.3, 12, True, 20, 15, 24, 3, 4.0),
]


def seed(db: Session) -> None:
    hosts = [
        User(name="Manoj", phone="+919800000001", role="host"),
        User(name="Rahul", phone="+919800000002", role="host"),
        User(name="Ayesha", phone="+919800000003", role="host"),
        User(name="Priya", phone="+919800000004", role="both"),
    ]
    driver = User(name="Arjun", phone="+919800000010", role="driver")
    db.add_all([*hosts, driver])
    db.flush()

    db.add_all([
        Vehicle(user_id=driver.id, model="Ather 450X", battery_kwh=3.0, charger_kw=0.75, connector_type="15A"),
        Vehicle(user_id=hosts[3].id, model="Tata Nexon EV", battery_kwh=30.0, charger_kw=7.2, connector_type="TYPE2"),
    ])

    now = datetime.now()
    for i, (name, h, lat, lng, conn, kw, rs, auto, sess, ok, books, cancels, rating) in enumerate(CHARGERS, 1):
        alat, alng = approximate_location(lat, lng)
        db.add(Charger(
            host_id=hosts[h].id, name=name, lat=lat, lng=lng, approx_lat=alat, approx_lng=alng,
            address=f"{name}, Koramangala, Bengaluru", connector_type=conn, power_kw=kw,
            base_price_per_kwh_paise=rs * 100, auto_approve=auto, device_id=f"CHG{i:03d}",
            total_sessions=sess, successful_sessions=ok, total_bookings=books,
            host_cancellations=cancels, rating=rating,
            last_success_at=now - timedelta(days=1) if sess else None,
        ))
    db.commit()


def reset_and_seed() -> None:
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    with SessionLocal() as db:
        seed(db)


if __name__ == "__main__":
    reset_and_seed()
    print("Seeded demo data.")
