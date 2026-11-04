from datetime import datetime
from typing import Literal

from pydantic import BaseModel, Field, model_validator

HHMM = r"^([01]\d|2[0-3]):[0-5]\d$"


class ChargerCreate(BaseModel):
    host_id: int
    name: str = Field(min_length=3, max_length=80)
    # Rough bounding box of India: catches swapped or zeroed coordinates.
    lat: float = Field(ge=6.0, le=37.5)
    lng: float = Field(ge=68.0, le=97.5)
    address: str = Field(min_length=5, max_length=160)
    connector_type: Literal["15A", "TYPE2", "CCS2"]
    power_kw: float = Field(ge=0.5, le=22)
    base_price_per_kwh_paise: int = Field(ge=500, le=5000)  # ₹5–₹50 per kWh
    available_from: str = Field(default="00:00", pattern=HHMM)
    available_to: str = Field(default="23:59", pattern=HHMM)
    auto_approve: bool = True
    image_url: str | None = None

    @model_validator(mode="after")
    def _opens_before_it_closes(self):
        if self.available_from >= self.available_to:  # zero-padded HH:MM compares correctly as text
            raise ValueError("available_from must be earlier than available_to")
        return self


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
