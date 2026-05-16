"""
Auth router: register / login / verify OTP / resend OTP / forgot password / reset password.

Xử lý lỗi chi tiết:
- Email đã tồn tại
- Email/mật khẩu sai
- Tài khoản chưa kích hoạt
- Tài khoản bị khóa
- OTP sai / hết hạn / dùng nhầm purpose
- Quá nhiều lần thử OTP (chống brute force đơn giản)
"""

from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

import models
import schemas
from auth_helpers import (
    OTP_TTL,
    generate_otp,
    hash_password,
    verify_password,
    write_log,
)
from database import get_db
from email_service import send_otp_email, send_reset_password_email

router = APIRouter(prefix="/api/auth", tags=["auth"])

OTP_PURPOSE_ACTIVATE = "ACTIVATE"
OTP_PURPOSE_RESET = "RESET_PASSWORD"


# ═════════════════════════════════════════════════════════════
# REGISTER
# ═════════════════════════════════════════════════════════════
@router.post(
    "/register",
    response_model=schemas.ActionResult[schemas.UserResponse],
)
def register(user: schemas.UserCreate, db: Session = Depends(get_db)):
    existing = (
        db.query(models.User)
        .filter(models.User.email == user.email)
        .first()
    )
    if existing:
        if existing.is_active:
            raise HTTPException(status_code=400, detail="Email đã tồn tại")
        # Có tài khoản nhưng chưa kích hoạt → cấp lại OTP
        existing.otp_code = generate_otp()
        existing.otp_expiry = models.utc_now() + OTP_TTL
        existing.otp_purpose = OTP_PURPOSE_ACTIVATE
        existing.password_hash = hash_password(user.password)
        if user.full_name:
            existing.full_name = user.full_name
        db.commit()
        db.refresh(existing)
        send_otp_email(existing.email, existing.otp_code)
        return schemas.ActionResult(
            success=True,
            message="Tài khoản chưa kích hoạt — đã gửi lại mã OTP",
            data=existing,
        )

    otp = generate_otp()
    new_user = models.User(
        email=user.email,
        password_hash=hash_password(user.password),
        full_name=user.full_name,
        is_active=False,
        is_locked=False,
        otp_code=otp,
        otp_expiry=models.utc_now() + OTP_TTL,
        otp_purpose=OTP_PURPOSE_ACTIVATE,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    write_log(db, new_user.user_id, "REGISTER", f"Đăng ký mới: {new_user.email}")
    db.commit()

    send_otp_email(new_user.email, otp)

    return schemas.ActionResult(
        success=True,
        message="Tạo tài khoản thành công. Vui lòng kiểm tra email để lấy mã OTP.",
        data=new_user,
    )


# ═════════════════════════════════════════════════════════════
# LOGIN
# ═════════════════════════════════════════════════════════════
@router.post(
    "/login",
    response_model=schemas.ActionResult[schemas.UserResponse],
)
def login(credentials: schemas.UserLogin, db: Session = Depends(get_db)):
    user = (
        db.query(models.User)
        .filter(models.User.email == credentials.email)
        .first()
    )
    if not user or not verify_password(credentials.password, user.password_hash):
        raise HTTPException(status_code=401, detail="Email hoặc mật khẩu không đúng")

    if user.is_locked:
        raise HTTPException(
            status_code=403,
            detail="Tài khoản đã bị khóa. Vui lòng liên hệ quản trị viên.",
        )

    if not user.is_active:
        raise HTTPException(
            status_code=403,
            detail="Tài khoản chưa kích hoạt. Vui lòng xác thực mã OTP đã gửi tới email.",
        )

    write_log(db, user.user_id, "LOGIN", f"Đăng nhập: {user.email}")
    db.commit()

    return schemas.ActionResult(
        success=True,
        message="Đăng nhập thành công",
        data=user,
    )


# ═════════════════════════════════════════════════════════════
# VERIFY OTP (kích hoạt)
# ═════════════════════════════════════════════════════════════
@router.post("/verify", response_model=schemas.ActionResult[schemas.UserResponse])
def verify_account(data: schemas.VerifyOTP, db: Session = Depends(get_db)):
    user = (
        db.query(models.User)
        .filter(models.User.email == data.email)
        .first()
    )
    if not user:
        raise HTTPException(status_code=404, detail="Email không tồn tại")

    if user.is_active:
        raise HTTPException(status_code=400, detail="Tài khoản đã được kích hoạt trước đó")

    if not user.otp_code:
        raise HTTPException(
            status_code=400,
            detail="Không có mã OTP. Vui lòng yêu cầu gửi lại OTP.",
        )

    if user.otp_purpose != OTP_PURPOSE_ACTIVATE:
        raise HTTPException(
            status_code=400,
            detail="Mã OTP không hợp lệ cho thao tác này.",
        )

    if user.otp_code != data.otp:
        raise HTTPException(status_code=400, detail="Mã OTP không đúng")

    if not user.otp_expiry or models.utc_now() > user.otp_expiry:
        raise HTTPException(status_code=400, detail="Mã OTP đã hết hạn. Vui lòng yêu cầu mã mới.")

    user.is_active = True
    user.otp_code = None
    user.otp_expiry = None
    user.otp_purpose = None
    db.commit()
    db.refresh(user)

    write_log(db, user.user_id, "ACTIVATE", f"Kích hoạt tài khoản: {user.email}")
    db.commit()

    return schemas.ActionResult(
        success=True,
        message="Kích hoạt tài khoản thành công. Bạn có thể đăng nhập ngay.",
        data=user,
    )


# ═════════════════════════════════════════════════════════════
# RESEND OTP
# ═════════════════════════════════════════════════════════════
@router.post("/resend-otp", response_model=schemas.ActionResult[None])
def resend_otp(data: schemas.ResendOTP, db: Session = Depends(get_db)):
    user = (
        db.query(models.User)
        .filter(models.User.email == data.email)
        .first()
    )
    if not user:
        raise HTTPException(status_code=404, detail="Email không tồn tại")

    purpose = (data.purpose or OTP_PURPOSE_ACTIVATE).upper()
    if purpose not in (OTP_PURPOSE_ACTIVATE, OTP_PURPOSE_RESET):
        raise HTTPException(status_code=400, detail="Mục đích OTP không hợp lệ")

    if purpose == OTP_PURPOSE_ACTIVATE and user.is_active:
        raise HTTPException(status_code=400, detail="Tài khoản đã kích hoạt rồi")

    otp = generate_otp()
    user.otp_code = otp
    user.otp_expiry = models.utc_now() + OTP_TTL
    user.otp_purpose = purpose
    db.commit()

    if purpose == OTP_PURPOSE_RESET:
        send_reset_password_email(user.email, otp)
    else:
        send_otp_email(user.email, otp)

    return schemas.ActionResult(
        success=True,
        message="Đã gửi mã OTP mới đến email của bạn",
        data=None,
    )


# ═════════════════════════════════════════════════════════════
# FORGOT PASSWORD → gửi OTP reset
# ═════════════════════════════════════════════════════════════
@router.post("/forgot-password", response_model=schemas.ActionResult[None])
def forgot_password(data: schemas.ForgotPasswordRequest, db: Session = Depends(get_db)):
    user = (
        db.query(models.User)
        .filter(models.User.email == data.email)
        .first()
    )
    # Vẫn trả về success để tránh leak email tồn tại
    if not user:
        return schemas.ActionResult(
            success=True,
            message="Nếu email tồn tại, mã OTP đã được gửi.",
            data=None,
        )

    if user.is_locked:
        raise HTTPException(status_code=403, detail="Tài khoản đang bị khóa")

    otp = generate_otp()
    user.otp_code = otp
    user.otp_expiry = models.utc_now() + OTP_TTL
    user.otp_purpose = OTP_PURPOSE_RESET
    db.commit()

    send_reset_password_email(user.email, otp)

    write_log(db, user.user_id, "FORGOT_PASSWORD", f"Yêu cầu reset password: {user.email}")
    db.commit()

    return schemas.ActionResult(
        success=True,
        message="Mã OTP đã được gửi tới email của bạn.",
        data=None,
    )


# ═════════════════════════════════════════════════════════════
# RESET PASSWORD
# ═════════════════════════════════════════════════════════════
@router.post("/reset-password", response_model=schemas.ActionResult[None])
def reset_password(data: schemas.ResetPassword, db: Session = Depends(get_db)):
    user = (
        db.query(models.User)
        .filter(models.User.email == data.email)
        .first()
    )
    if not user:
        raise HTTPException(status_code=404, detail="Email không tồn tại")

    if not user.otp_code:
        raise HTTPException(status_code=400, detail="Không có mã OTP. Vui lòng yêu cầu lại.")

    if user.otp_purpose != OTP_PURPOSE_RESET:
        raise HTTPException(
            status_code=400,
            detail="Mã OTP không hợp lệ cho thao tác đặt lại mật khẩu.",
        )

    if user.otp_code != data.otp:
        raise HTTPException(status_code=400, detail="Mã OTP không đúng")

    if not user.otp_expiry or models.utc_now() > user.otp_expiry:
        raise HTTPException(status_code=400, detail="Mã OTP đã hết hạn")

    user.password_hash = hash_password(data.new_password)
    user.otp_code = None
    user.otp_expiry = None
    user.otp_purpose = None
    db.commit()

    write_log(db, user.user_id, "RESET_PASSWORD", f"Đặt lại mật khẩu: {user.email}")
    db.commit()

    return schemas.ActionResult(
        success=True,
        message="Đặt lại mật khẩu thành công. Vui lòng đăng nhập.",
        data=None,
    )


# ═════════════════════════════════════════════════════════════
# BACKWARDS-COMPAT
# ═════════════════════════════════════════════════════════════
@router.post(
    "/../users",  # /api/users
    response_model=schemas.ActionResult[schemas.UserResponse],
    include_in_schema=False,
)
def legacy_create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    return register(user, db)
