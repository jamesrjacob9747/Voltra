import hashlib
import hmac

import httpx
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..config import settings
from ..db import get_db
from ..models import Payment
from ..schemas import PaymentVerify
from ..services import plug
from .admin import require_demo_endpoints

router = APIRouter(prefix="/payments", tags=["payments"])

RAZORPAY_ORDERS_URL = "https://api.razorpay.com/v1/orders"


def _payment(db: Session, booking_id: int) -> Payment:
    payment = db.scalar(select(Payment).where(Payment.booking_id == booking_id))
    if payment is None:
        raise HTTPException(404, "No bill for this booking yet; stop the session first")
    return payment


def payment_view(p: Payment) -> dict:
    return {
        "id": p.id,
        "booking_id": p.booking_id,
        "status": p.status,
        "energy_kwh": p.energy_kwh,
        "total_paise": p.total_paise,
        "platform_fee_paise": p.platform_fee_paise,
        "host_share_paise": p.host_share_paise,
        "credit_paise": p.credit_paise,
        "payable_paise": p.total_paise - p.credit_paise,
        "razorpay_order_id": p.razorpay_order_id,
    }


def _mark_paid(db: Session, payment: Payment) -> dict:
    payment.status = "PAID"
    payment.paid_at = plug.clock()
    db.commit()
    return payment_view(payment)


@router.post("/{booking_id}/order")
def create_order(booking_id: int, db: Session = Depends(get_db)):
    """Creates a Razorpay test order server-side. The key secret never reaches the app."""
    payment = _payment(db, booking_id)
    if payment.status == "PAID":
        raise HTTPException(409, "Already paid")
    payable = payment.total_paise - payment.credit_paise
    if not settings.razorpay_key_id or not settings.razorpay_key_secret or payable <= 0:
        return {**payment_view(payment), "mode": "demo"}

    # A driver who closes the checkout and taps Pay again gets the same order back: the bill is
    # final once the session stops, and Razorpay lets an unpaid order be retried.
    if payment.razorpay_order_id is None:
        try:
            resp = httpx.post(
                RAZORPAY_ORDERS_URL,
                auth=(settings.razorpay_key_id, settings.razorpay_key_secret),
                json={
                    "amount": payable,
                    "currency": "INR",
                    "receipt": f"voltra_booking_{booking_id}",
                    "notes": {"booking_id": str(booking_id)},
                },
                timeout=10,
            )
        except httpx.HTTPError:
            raise HTTPException(502, "Couldn't reach Razorpay. Please try again.") from None
        if resp.status_code >= 400:
            raise HTTPException(502, "Razorpay couldn't create the order. Please try again.")
        payment.razorpay_order_id = resp.json()["id"]
        db.commit()
    return {**payment_view(payment), "mode": "razorpay", "key_id": settings.razorpay_key_id}


@router.post("/verify")
def verify_payment(body: PaymentVerify, db: Session = Depends(get_db)):
    if not settings.razorpay_key_secret:
        raise HTTPException(409, "Razorpay is not configured on this server")
    payment = _payment(db, body.booking_id)
    if payment.razorpay_order_id is None or body.razorpay_order_id != payment.razorpay_order_id:
        raise HTTPException(409, "Order does not match this booking")
    expected = hmac.new(
        settings.razorpay_key_secret.encode(),
        f"{body.razorpay_order_id}|{body.razorpay_payment_id}".encode(),
        hashlib.sha256,
    ).hexdigest()
    if not hmac.compare_digest(expected, body.razorpay_signature):
        raise HTTPException(400, "Payment signature is invalid")
    if payment.status == "PAID":  # the app retried after a dropped connection
        return payment_view(payment)
    return _mark_paid(db, payment)


@router.post("/{booking_id}/demo-pay", dependencies=[Depends(require_demo_endpoints)])
def demo_pay(booking_id: int, db: Session = Depends(get_db)):
    """Demo fallback when Razorpay is not configured or misbehaves on stage."""
    payment = _payment(db, booking_id)
    if payment.status == "PAID":
        raise HTTPException(409, "Already paid")
    return _mark_paid(db, payment)


@router.get("/{booking_id}")
def get_payment(booking_id: int, db: Session = Depends(get_db)):
    return payment_view(_payment(db, booking_id))
