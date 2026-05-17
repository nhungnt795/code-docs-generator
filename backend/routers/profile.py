"""
Profile router: cập nhật profile, đổi mật khẩu, upload avatar.
"""

import os
import time
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile
from sqlalchemy.orm import Session

import models
import schemas
from auth_helpers import (
    hash_password,
    require_user,
    verify_password,
    write_log,
)
from database import get_db

router = APIRouter(prefix="/api/users", tags=["profile"])

AVATAR_DIR = "data/avatars"
ALLOWED_AVATAR_EXT = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
MAX_AVATAR_SIZE = 5 * 1024 * 1024  # 5MB


# ═════════════════════════════════════════════════════════════
# GET PROFILE
# ═════════════════════════════════════════════════════════════
@router.get("/{user_id}", response_model=schemas.ActionResult[schemas.UserResponse])
def get_profile(user_id: int, db: Session = Depends(get_db)):
    user = require_user(db, user_id)
    return schemas.ActionResult(
        success=True,
        message="Lấy thông tin thành công",
        data=user,
    )


# ═════════════════════════════════════════════════════════════
# UPDATE PROFILE (tên + email)
# ═════════════════════════════════════════════════════════════
@router.put(
    "/{user_id}/profile",
    response_model=schemas.ActionResult[schemas.UserResponse],
)
def update_profile(
    user_id: int,
    data: schemas.ProfileUpdate,
    db: Session = Depends(get_db),
):
    user = require_user(db, user_id)

    changed = []

    if data.full_name is not None and data.full_name.strip():
        old = user.full_name
        user.full_name = data.full_name.strip()
        changed.append(f"full_name: '{old}' → '{user.full_name}'")

    if data.email is not None and data.email != user.email:
        # Kiểm tra email mới chưa bị dùng
        dup = (
            db.query(models.User)
            .filter(models.User.email == data.email, models.User.user_id != user_id)
            .first()
        )
        if dup:
            raise HTTPException(status_code=400, detail="Email mới đã tồn tại")
        old = user.email
        user.email = data.email
        changed.append(f"email: '{old}' → '{user.email}'")

    if not changed:
        return schemas.ActionResult(
            success=True,
            message="Không có thay đổi",
            data=user,
        )

    db.commit()
    db.refresh(user)

    write_log(db, user.user_id, "UPDATE_PROFILE", "; ".join(changed))
    db.commit()

    return schemas.ActionResult(
        success=True,
        message="Cập nhật thông tin thành công",
        data=user,
    )


# ═════════════════════════════════════════════════════════════
# CHANGE PASSWORD
# ═════════════════════════════════════════════════════════════
@router.put(
    "/{user_id}/password",
    response_model=schemas.ActionResult[None],
)
def change_password(
    user_id: int,
    data: schemas.PasswordChange,
    db: Session = Depends(get_db),
):
    user = require_user(db, user_id)

    if not verify_password(data.old_password, user.password_hash):
        raise HTTPException(status_code=400, detail="Mật khẩu hiện tại không đúng")

    if data.old_password == data.new_password:
        raise HTTPException(
            status_code=400,
            detail="Mật khẩu mới phải khác mật khẩu cũ",
        )

    user.password_hash = hash_password(data.new_password)
    db.commit()

    write_log(db, user.user_id, "CHANGE_PASSWORD", "Đổi mật khẩu")
    db.commit()

    return schemas.ActionResult(
        success=True,
        message="Đổi mật khẩu thành công",
        data=None,
    )


# ═════════════════════════════════════════════════════════════
# UPLOAD AVATAR
# ═════════════════════════════════════════════════════════════
@router.post(
    "/{user_id}/avatar",
    response_model=schemas.ActionResult[schemas.UserResponse],
)
async def upload_avatar(
    user_id: int,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    user = require_user(db, user_id)

    # Validate content-type
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="Chỉ chấp nhận tệp hình ảnh")

    # Validate extension
    ext = Path(file.filename or "").suffix.lower()
    if ext not in ALLOWED_AVATAR_EXT:
        raise HTTPException(
            status_code=400,
            detail=f"Đuôi file không hợp lệ. Chấp nhận: {', '.join(sorted(ALLOWED_AVATAR_EXT))}",
        )

    # Validate size
    content = await file.read()
    if len(content) > MAX_AVATAR_SIZE:
        raise HTTPException(status_code=400, detail="Kích thước file tối đa 5MB")

    os.makedirs(AVATAR_DIR, exist_ok=True)
    # Tên file unique theo timestamp
    filename = f"user_{user_id}_{int(time.time())}{ext}"
    file_path = os.path.join(AVATAR_DIR, filename)

    # Xóa avatar cũ nếu có
    if user.avatar_url and user.avatar_url.startswith(AVATAR_DIR):
        try:
            if os.path.exists(user.avatar_url):
                os.remove(user.avatar_url)
        except Exception:
            pass

    with open(file_path, "wb") as f:
        f.write(content)

    user.avatar_url = file_path
    db.commit()
    db.refresh(user)

    write_log(db, user.user_id, "UPDATE_AVATAR", f"Avatar: {file_path}")
    db.commit()

    return schemas.ActionResult(
        success=True,
        message="Cập nhật ảnh đại diện thành công",
        data=user,
    )
