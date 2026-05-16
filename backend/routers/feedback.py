"""
Feedback router (yêu cầu I.10).
User gửi đánh giá (rating 1-5) + nội dung phản hồi.
"""

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

import models
import schemas
from auth_helpers import require_user, write_log
from database import get_db

router = APIRouter(prefix="/api/feedback", tags=["feedback"])


@router.post("", response_model=schemas.ActionResult[schemas.FeedbackResponse])
def create_feedback(
    data: schemas.FeedbackCreate,
    user_id: int = Query(...),
    db: Session = Depends(get_db),
):
    user = require_user(db, user_id)

    fb = models.Feedback(
        user_id=user_id,
        rating=data.rating,
        content=data.content,
    )
    db.add(fb)
    db.commit()
    db.refresh(fb)

    write_log(db, user_id, "FEEDBACK", f"rating={data.rating}")
    db.commit()

    return schemas.ActionResult(
        success=True,
        message="Cảm ơn bạn đã gửi phản hồi!",
        data=schemas.FeedbackResponse(
            id=fb.id,
            user_id=fb.user_id,
            rating=fb.rating,
            content=fb.content,
            created_at=fb.created_at,
            user_email=user.email,
            user_name=user.full_name,
        ),
    )


@router.get("/my", response_model=schemas.ActionResult[list[schemas.FeedbackResponse]])
def my_feedbacks(user_id: int = Query(...), db: Session = Depends(get_db)):
    user = require_user(db, user_id)
    items = (
        db.query(models.Feedback)
        .filter(models.Feedback.user_id == user_id)
        .order_by(models.Feedback.created_at.desc())
        .all()
    )
    out = [
        schemas.FeedbackResponse(
            id=fb.id,
            user_id=fb.user_id,
            rating=fb.rating,
            content=fb.content,
            created_at=fb.created_at,
            user_email=user.email,
            user_name=user.full_name,
        )
        for fb in items
    ]
    return schemas.ActionResult(success=True, message="OK", data=out)
