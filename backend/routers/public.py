"""
Public endpoints (không cần admin) — để frontend lấy thông tin runtime.
"""

from typing import List

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

import models
import schemas
from database import get_db

router = APIRouter(prefix="/api/public", tags=["public"])


@router.get(
    "/models",
    response_model=schemas.ActionResult[List[schemas.AIModelConfigResponse]],
)
def get_available_models(db: Session = Depends(get_db)):
    """
    Frontend gọi để hiện lựa chọn model. Mỗi item có is_active.
    Nếu is_active=False → frontend hiện banner "Mô hình ngoài thời gian sử dụng".
    """
    configs = db.query(models.AIModelConfig).all()

    # Nếu DB chưa có row nào → tự seed (mặc định cả 2 đều active)
    if not configs:
        defaults = [
            models.AIModelConfig(
                model_type=models.AIModelType.GROQ_LLAMA3,
                is_active=True,
                display_name="Llama 3.1 8B (Groq)",
                description="Nhanh, ổn định, chạy trên hạ tầng Groq Cloud.",
            ),
            models.AIModelConfig(
                model_type=models.AIModelType.KAGGLE_FINETUNED,
                is_active=True,
                display_name="Llama 3.1 8B Finetuned (Kaggle)",
                description="Mô hình đã được tinh chỉnh trên Kaggle.",
            ),
        ]
        db.add_all(defaults)
        db.commit()
        configs = db.query(models.AIModelConfig).all()

    return schemas.ActionResult(success=True, message="OK", data=configs)
