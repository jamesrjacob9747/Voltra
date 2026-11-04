from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from ..db import get_db
from ..models import COMPLETED, Booking, Charger, Review, User
from ..schemas import ReviewCreate

router = APIRouter(prefix="/reviews", tags=["reviews"])


@router.post("", status_code=201)
def create_review(body: ReviewCreate, db: Session = Depends(get_db)):
    booking = db.get(Booking, body.booking_id)
    if booking is None or booking.status != COMPLETED:
        raise HTTPException(409, "Only a completed booking can be rated")
    charger = db.get(Charger, booking.charger_id)
    if body.reviewer_id == booking.driver_id:
        reviewee_id = charger.host_id
    elif body.reviewer_id == charger.host_id:
        reviewee_id = booking.driver_id
    else:
        raise HTTPException(403, "Only the driver or host of this booking can rate it")

    db.add(Review(booking_id=booking.id, reviewer_id=body.reviewer_id, reviewee_id=reviewee_id,
                  rating=body.rating, tags=",".join(body.tags), comment=body.comment))
    db.flush()
    reviewee = db.get(User, reviewee_id)
    reviewee.rating = round(db.scalar(
        select(func.avg(Review.rating)).where(Review.reviewee_id == reviewee_id)), 1)
    if reviewee_id == charger.host_id:
        charger.rating = reviewee.rating
    db.commit()
    return {"booking_id": booking.id, "reviewee_id": reviewee_id, "new_rating": reviewee.rating}
