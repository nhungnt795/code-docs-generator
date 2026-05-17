"""
routers/contact.py
Endpoint nhận tin nhắn từ trang Liên hệ (public, không cần đăng nhập).
Admin xem qua /api/admin/contact-messages.
"""

from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime

import models
from database import get_db
import schemas

router = APIRouter(prefix="/api/contact", tags=["contact"])


class ContactMessageCreate(BaseModel):
    name: Optional[str] = None
    email: EmailStr
    content: str


class ContactMessageResponse(BaseModel):
    id: int
    name: Optional[str]
    email: str
    content: str
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True


@router.post("", response_model=schemas.ActionResult[ContactMessageResponse])
def send_contact_message(
    data: ContactMessageCreate,
    db: Session = Depends(get_db),
):
    """
    Nhận tin nhắn từ form Liên hệ trên landing page.
    Không cần đăng nhập. Tin nhắn lưu vào DB, admin xem được.
    """
    if not data.content.strip():
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="Nội dung không được để trống.")

    msg = models.ContactMessage(
        name=data.name.strip() if data.name else None,
        email=data.email,
        content=data.content.strip(),
    )
    db.add(msg)
    db.commit()
    db.refresh(msg)

    return schemas.ActionResult(
        success=True,
        message="Cảm ơn bạn đã liên hệ! Chúng tôi sẽ phản hồi qua email sớm nhất.",
        data=ContactMessageResponse.from_orm(msg),
    )