from datetime import datetime

from sqlalchemy import Boolean, DateTime, Float, ForeignKey, Integer, String
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base

# Booking states (PRD section 9, F7)
PENDING, CONFIRMED, ARRIVED, CHARGING, COMPLETED, CANCELLED = (
    "PENDING",
    "CONFIRMED",
    "ARRIVED",
    "CHARGING",
    "COMPLETED",
    "CANCELLED",
)


class User(Base):
    __tablename__ = "users"
    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(80))
    phone: Mapped[str] = mapped_column(String(20))
    role: Mapped[str] = mapped_column(String(10))  # driver | host | both
    rating: Mapped[float] = mapped_column(Float, default=5.0)
    kyc_status: Mapped[str] = mapped_column(String(12), default="VERIFIED")  # mocked in MVP
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)


class Vehicle(Base):
    __tablename__ = "vehicles"
    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    model: Mapped[str] = mapped_column(String(60))
    battery_kwh: Mapped[float] = mapped_column(Float)
    charger_kw: Mapped[float] = mapped_column(Float)  # onboard/portable charger limit
    connector_type: Mapped[str] = mapped_column(String(10))  # 15A | TYPE2 | CCS2


class Charger(Base):
    __tablename__ = "chargers"
    id: Mapped[int] = mapped_column(primary_key=True)
    host_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    name: Mapped[str] = mapped_column(String(80))
    lat: Mapped[float] = mapped_column(Float)
    lng: Mapped[float] = mapped_column(Float)
    approx_lat: Mapped[float] = mapped_column(Float)
    approx_lng: Mapped[float] = mapped_column(Float)
    address: Mapped[str] = mapped_column(String(160))
    connector_type: Mapped[str] = mapped_column(String(10))
    power_kw: Mapped[float] = mapped_column(Float)
    base_price_per_kwh_paise: Mapped[int] = mapped_column(Integer)
    available_from: Mapped[str] = mapped_column(String(5), default="00:00")  # HH:MM
    available_to: Mapped[str] = mapped_column(String(5), default="23:59")
    auto_approve: Mapped[bool] = mapped_column(Boolean, default=True)
    device_id: Mapped[str] = mapped_column(String(20), unique=True)
    last_heartbeat_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    verified: Mapped[bool] = mapped_column(Boolean, default=True)
    image_url: Mapped[str | None] = mapped_column(String(300), nullable=True)
    # Track record, used by Charging Confidence
    total_sessions: Mapped[int] = mapped_column(Integer, default=0)
    successful_sessions: Mapped[int] = mapped_column(Integer, default=0)
    total_bookings: Mapped[int] = mapped_column(Integer, default=0)
    host_cancellations: Mapped[int] = mapped_column(Integer, default=0)
    last_success_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    rating: Mapped[float] = mapped_column(Float, default=5.0)


class Booking(Base):
    __tablename__ = "bookings"
    id: Mapped[int] = mapped_column(primary_key=True)
    charger_id: Mapped[int] = mapped_column(ForeignKey("chargers.id"))
    driver_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    vehicle_id: Mapped[int | None] = mapped_column(ForeignKey("vehicles.id"), nullable=True)
    start_time: Mapped[datetime] = mapped_column(DateTime)
    end_time: Mapped[datetime] = mapped_column(DateTime)
    status: Mapped[str] = mapped_column(String(10), default=PENDING)
    transferred_from_booking_id: Mapped[int | None] = mapped_column(ForeignKey("bookings.id"), nullable=True)
    credit_paise: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)


class ChargingSession(Base):
    __tablename__ = "charging_sessions"
    id: Mapped[int] = mapped_column(primary_key=True)
    booking_id: Mapped[int] = mapped_column(ForeignKey("bookings.id"), unique=True)
    price_per_kwh_paise: Mapped[int] = mapped_column(Integer)  # locked at start
    meter_start_kwh: Mapped[float] = mapped_column(Float)
    meter_end_kwh: Mapped[float | None] = mapped_column(Float, nullable=True)
    started_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)
    ended_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    peak_kw: Mapped[float] = mapped_column(Float, default=0.0)


class Payment(Base):
    __tablename__ = "payments"
    id: Mapped[int] = mapped_column(primary_key=True)
    booking_id: Mapped[int] = mapped_column(ForeignKey("bookings.id"), unique=True)
    energy_kwh: Mapped[float] = mapped_column(Float)
    total_paise: Mapped[int] = mapped_column(Integer)
    platform_fee_paise: Mapped[int] = mapped_column(Integer)
    host_share_paise: Mapped[int] = mapped_column(Integer)
    credit_paise: Mapped[int] = mapped_column(Integer, default=0)  # ChargeSure credit, platform-funded
    razorpay_order_id: Mapped[str | None] = mapped_column(String(40), nullable=True)
    status: Mapped[str] = mapped_column(String(10), default="PENDING")  # PENDING | PAID
    paid_at: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)


class Review(Base):
    __tablename__ = "reviews"
    id: Mapped[int] = mapped_column(primary_key=True)
    booking_id: Mapped[int] = mapped_column(ForeignKey("bookings.id"))
    reviewer_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    reviewee_id: Mapped[int] = mapped_column(ForeignKey("users.id"))
    rating: Mapped[int] = mapped_column(Integer)
    tags: Mapped[str] = mapped_column(String(200), default="")
    comment: Mapped[str] = mapped_column(String(500), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)


class Telemetry(Base):
    __tablename__ = "telemetry"
    id: Mapped[int] = mapped_column(primary_key=True)
    device_id: Mapped[str] = mapped_column(String(20), index=True)
    ts: Mapped[datetime] = mapped_column(DateTime, default=datetime.now)
    voltage: Mapped[float] = mapped_column(Float)
    current: Mapped[float] = mapped_column(Float)
    power_w: Mapped[float] = mapped_column(Float)
    energy_kwh: Mapped[float] = mapped_column(Float)
