from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field


class ChargerCreate(BaseModel):
    host_id: int
    name: str
    lat: float
    lng: float
    address: str
    connector_type: Literal["15A", "TYPE2", "CCS2"]
    power_kw: float = Field(gt=0)
    base_price_per_kwh_paise: int = Field(gt=0)
    available_from: str = "00:00"
    available_to: str = "23:59"
    auto_approve: bool = True
    image_url: str | None = None


class MatchRequest(BaseModel):
    vehicle_id: int
    current_pct: float = Field(ge=0, le=100)
    target_pct: float = Field(ge=0, le=100)
    ready_by: str  # "HH:MM" today (tomorrow if already past) or ISO datetime
    lat: float
    lng: float
    radius_km: float = Field(default=2.0, gt=0, le=20)


class BookingCreate(BaseModel):
    driver_id: int
    charger_id: int
    vehicle_id: int | None = None
    start_time: datetime
    end_time: datetime


class BookingAction(BaseModel):
    action: Literal["accept", "decline", "cancel", "arrive"]
    actor_id: int


class TransferRequest(BaseModel):
    to_charger_id: int


class SessionStart(BaseModel):
    booking_id: int
    qr: str  # voltra://charger/<device_id>


class TelemetryIn(BaseModel):
    charger_id: str  # device id, e.g. CHG001
    voltage: float
    current: float
    power_w: float
    energy_kwh: float


class PaymentVerify(BaseModel):
    booking_id: int
    razorpay_order_id: str
    razorpay_payment_id: str
    razorpay_signature: str


class ReviewCreate(BaseModel):
    booking_id: int
    reviewer_id: int
    rating: int = Field(ge=1, le=5)
    tags: list[str] = []
    comment: str = ""


class PlugOnline(BaseModel):
    online: bool
