"""
Auth utility functions.
"""

import random
import secrets
import string
from datetime import timedelta

import bcrypt
from fastapi import HTTPException
from sqlalchemy.orm import Session

import models


# ─────────────────────────────────────────────────────────────
# PASSWORD
# ─────────────────────────────────────────────────────────────
def hash_password(password: str) -> str:
    return bcrypt.hashpw(
        password.encode("utf-8"),
        bcrypt.gensalt(),
    ).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(
            plain.encode("utf-8"),
            hashed.encode("utf-8"),
        )
    except Exception:
        return False


# ─────────────────────────────────────────────────────────────
# OTP
# ─────────────────────────────────────────────────────────────
def generate_otp() -> str:
    return f"{random.randint(0, 999999):06d}"


def generate_token(length: int = 32) -> str:
    """Token đơn giản (không phải JWT) — dùng cho session."""
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


# ─────────────────────────────────────────────────────────────
# OTP TTL
# ─────────────────────────────────────────────────────────────
OTP_TTL = timedelta(minutes=5)


# ─────────────────────────────────────────────────────────────
# PERMISSION CHECKS
# ─────────────────────────────────────────────────────────────
def require_admin(db: Session, admin_id: int) -> models.User:
    """Trả về user nếu là admin, raise 403 nếu không."""
    admin = (
        db.query(models.User)
        .filter(
            models.User.user_id == admin_id,
            models.User.role == models.RoleType.ADMIN,
        )
        .first()
    )
    if not admin:
        raise HTTPException(
            status_code=403,
            detail="Bạn không có quyền truy cập chức năng này",
        )
    if admin.is_locked:
        raise HTTPException(
            status_code=403,
            detail="Tài khoản admin đang bị khóa",
        )
    return admin


def require_user(db: Session, user_id: int) -> models.User:
    """Trả về user nếu hợp lệ & không bị khóa."""
    user = (
        db.query(models.User)
        .filter(models.User.user_id == user_id)
        .first()
    )
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
    if user.is_locked:
        raise HTTPException(
            status_code=403,
            detail="Tài khoản của bạn đã bị khóa. Vui lòng liên hệ quản trị viên.",
        )
    return user


def write_log(db: Session, user_id, action: str, details: str = ""):
    """Ghi audit log (không commit ở đây - phụ thuộc context gọi)."""
    log = models.AuditLog(user_id=user_id, action=action, details=details)
    db.add(log)
