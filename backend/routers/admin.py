"""
Admin router (yêu cầu I.9 + II quản lý Model AI).

THAY ĐỔI:
- list_users: thêm lọc theo role (all | active | locked | inactive | admin | user)
- list_users: kèm doc_count cho từng user (không cần gọi thêm API)
- update_user_avatar: endpoint mới cho admin cập nhật avatar của user
"""

from datetime import datetime, timedelta, timezone
from typing import List, Optional
import os
import shutil

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File
from sqlalchemy import desc, func
from sqlalchemy.orm import Session

import models
import schemas
from auth_helpers import require_admin, write_log
from database import get_db

router = APIRouter(prefix="/api/admin", tags=["admin"])

AVATAR_DIR = "data/avatars"


# ─────────────────────────────────────────────────────────────
# HELPER: parse range
# ─────────────────────────────────────────────────────────────
def _parse_range(
    range_key: Optional[str],
    start_date: Optional[str],
    end_date: Optional[str],
) -> tuple[Optional[datetime], Optional[datetime]]:
    now = datetime.now(timezone.utc)
    key = (range_key or "all").lower()

    if key == "today":
        start = now.replace(hour=0, minute=0, second=0, microsecond=0)
        return start, now
    if key == "week":
        start = now - timedelta(days=7)
        return start, now
    if key == "month":
        start = now - timedelta(days=30)
        return start, now
    if key == "year":
        start = now - timedelta(days=365)
        return start, now
    if key == "custom":
        try:
            s = datetime.fromisoformat(start_date) if start_date else None
            e = datetime.fromisoformat(end_date) if end_date else None
            if s and s.tzinfo is None:
                s = s.replace(tzinfo=timezone.utc)
            if e and e.tzinfo is None:
                e = e.replace(tzinfo=timezone.utc)
            return s, e
        except Exception:
            raise HTTPException(status_code=400, detail="start_date/end_date phải ở dạng ISO")
    return None, None


# ═════════════════════════════════════════════════════════════
# DASHBOARD
# ═════════════════════════════════════════════════════════════
@router.get("/dashboard", response_model=schemas.ActionResult[schemas.DashboardStats])
def get_dashboard(
    admin_id: int = Query(...),
    range_key: str = Query("all", description="today | week | month | year | custom | all"),
    start_date: Optional[str] = None,
    end_date: Optional[str] = None,
    db: Session = Depends(get_db),
):
    require_admin(db, admin_id)

    start, end = _parse_range(range_key, start_date, end_date)

    doc_q = db.query(models.Document)
    user_q = db.query(models.User)
    if start:
        doc_q = doc_q.filter(models.Document.created_at >= start)
        user_q = user_q.filter(models.User.created_at >= start)
    if end:
        doc_q = doc_q.filter(models.Document.created_at <= end)
        user_q = user_q.filter(models.User.created_at <= end)

    total_users = db.query(models.User).count()
    total_docs = doc_q.count()

    last_24h = datetime.now(timezone.utc) - timedelta(days=1)
    pending_requests = (
        db.query(models.Document)
        .filter(models.Document.created_at >= last_24h)
        .count()
    )

    today_start = datetime.now(timezone.utc).replace(
        hour=0, minute=0, second=0, microsecond=0
    )
    docs_today = (
        db.query(models.Document)
        .filter(models.Document.created_at >= today_start)
        .count()
    )

    avg_time = db.query(func.avg(models.Document.time_taken_ms)).scalar() or 0

    active_users = (
        db.query(models.User)
        .filter(models.User.is_active == True, models.User.is_locked == False)
        .count()
    )
    locked_users = db.query(models.User).filter(models.User.is_locked == True).count()

    lang_stats = (
        doc_q.with_entities(
            models.Document.language,
            func.count(models.Document.doc_id).label("count"),
        )
        .group_by(models.Document.language)
        .all()
    )
    by_language = [{"language": l.value, "count": c} for l, c in lang_stats]

    model_stats = (
        doc_q.with_entities(
            models.Document.ai_model,
            func.count(models.Document.doc_id).label("count"),
        )
        .group_by(models.Document.ai_model)
        .all()
    )
    by_model = [{"model": (m.value if m else "UNKNOWN"), "count": c} for m, c in model_stats]

    seven_days_ago = datetime.now(timezone.utc) - timedelta(days=6)
    rows = (
        db.query(
            func.date(models.Document.created_at).label("d"),
            func.count(models.Document.doc_id).label("c"),
        )
        .filter(models.Document.created_at >= seven_days_ago)
        .group_by("d")
        .order_by("d")
        .all()
    )
    docs_over_time = [{"date": str(r.d), "count": r.c} for r in rows]

    return schemas.ActionResult(
        success=True,
        message="OK",
        data=schemas.DashboardStats(
            total_users=total_users,
            total_documents=total_docs,
            pending_requests=pending_requests,
            docs_today=docs_today,
            avg_time_ms=int(avg_time),
            active_users=active_users,
            locked_users=locked_users,
            by_language=by_language,
            by_model=by_model,
            docs_over_time=docs_over_time,
        ),
    )


# ═════════════════════════════════════════════════════════════
# USERS LIST (filter + search + role filter + doc_count)
# ═════════════════════════════════════════════════════════════
@router.get(
    "/users",
    response_model=schemas.ActionResult[List[dict]],
)
def list_users(
    admin_id: int = Query(...),
    status: str = Query("all", description="all | active | locked | inactive | admin | user"),
    search: Optional[str] = None,
    db: Session = Depends(get_db),
):
    """
    Lấy danh sách user kèm doc_count.
    status: all | active | locked | inactive | admin | user
    """
    require_admin(db, admin_id)
    q = db.query(models.User)

    # Filter theo trạng thái / role
    if status == "active":
        q = q.filter(models.User.is_active == True, models.User.is_locked == False)
    elif status == "locked":
        q = q.filter(models.User.is_locked == True)
    elif status == "inactive":
        q = q.filter(models.User.is_active == False)
    elif status == "admin":
        q = q.filter(models.User.role == models.RoleType.ADMIN)
    elif status == "user":
        q = q.filter(models.User.role == models.RoleType.USER)

    if search and search.strip():
        s = f"%{search.strip()}%"
        q = q.filter(
            (models.User.email.ilike(s)) | (models.User.full_name.ilike(s))
        )

    users = q.order_by(models.User.created_at.desc()).all()

    # Lấy doc count cho tất cả user trong một truy vấn duy nhất
    user_ids = [u.user_id for u in users]
    doc_counts: dict[int, int] = {}
    if user_ids:
        rows = (
            db.query(
                models.Document.user_id,
                func.count(models.Document.doc_id).label("cnt"),
            )
            .filter(models.Document.user_id.in_(user_ids))
            .group_by(models.Document.user_id)
            .all()
        )
        doc_counts = {r.user_id: r.cnt for r in rows}

    # Kết hợp user data + doc_count
    result = []
    for u in users:
        user_dict = schemas.UserResponse.model_validate(u).model_dump(mode="json")
        user_dict["doc_count"] = doc_counts.get(u.user_id, 0)
        result.append(user_dict)

    return schemas.ActionResult(success=True, message="OK", data=result)


# ═════════════════════════════════════════════════════════════
# USER DETAIL (kèm usage & history)
# ═════════════════════════════════════════════════════════════
@router.get(
    "/users/{user_id}",
    response_model=schemas.ActionResult[dict],
)
def user_detail(
    user_id: int,
    admin_id: int = Query(...),
    db: Session = Depends(get_db),
):
    require_admin(db, admin_id)
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")

    total_docs = (
        db.query(models.Document)
        .filter(models.Document.user_id == user_id)
        .count()
    )

    recent_docs = (
        db.query(models.Document)
        .filter(models.Document.user_id == user_id)
        .order_by(models.Document.created_at.desc())
        .limit(20)
        .all()
    )

    recent_logs = (
        db.query(models.AuditLog)
        .filter(models.AuditLog.user_id == user_id)
        .order_by(models.AuditLog.created_at.desc())
        .limit(50)
        .all()
    )

    last_login = (
        db.query(models.AuditLog)
        .filter(
            models.AuditLog.user_id == user_id,
            models.AuditLog.action == "LOGIN",
        )
        .order_by(models.AuditLog.created_at.desc())
        .first()
    )

    return schemas.ActionResult(
        success=True,
        message="OK",
        data={
            "user": schemas.UserResponse.model_validate(user).model_dump(mode="json"),
            "total_documents": total_docs,
            "last_active_at": last_login.created_at.isoformat() if last_login else None,
            "recent_documents": [
                schemas.DocumentResponse.model_validate(d).model_dump(mode="json")
                for d in recent_docs
            ],
            "recent_logs": [
                schemas.AuditLogResponse.model_validate(l).model_dump(mode="json")
                for l in recent_logs
            ],
        },
    )


# ═════════════════════════════════════════════════════════════
# ADMIN CẬP NHẬT AVATAR CHO USER
# ═════════════════════════════════════════════════════════════
@router.post(
    "/users/{user_id}/avatar",
    response_model=schemas.ActionResult[schemas.UserResponse],
)
async def admin_update_avatar(
    user_id: int,
    admin_id: int = Query(...),
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    """Admin upload/cập nhật avatar cho user bất kỳ."""
    require_admin(db, admin_id)

    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")

    # Validate file type
    allowed = {"image/jpeg", "image/png", "image/gif", "image/webp"}
    if file.content_type not in allowed:
        raise HTTPException(status_code=400, detail="Chỉ chấp nhận ảnh JPG, PNG, GIF, WEBP")

    # Validate kích thước (tối đa 5MB)
    contents = await file.read()
    if len(contents) > 5 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Ảnh không được vượt quá 5MB")

    # Tạo thư mục nếu chưa có
    os.makedirs(AVATAR_DIR, exist_ok=True)

    # Xóa avatar cũ nếu có
    if user.avatar_url and user.avatar_url.startswith(AVATAR_DIR):
        try:
            if os.path.exists(user.avatar_url):
                os.remove(user.avatar_url)
        except Exception:
            pass

    # Lưu file mới
    ext = file.filename.rsplit(".", 1)[-1] if "." in (file.filename or "") else "png"
    import time
    file_path = os.path.join(AVATAR_DIR, f"user_{user_id}_{int(time.time())}.{ext}")
    with open(file_path, "wb") as f:
        f.write(contents)

    user.avatar_url = file_path
    db.commit()
    db.refresh(user)

    write_log(db, admin_id, "ADMIN_UPDATE_AVATAR", f"Cập nhật avatar cho user_id={user_id}")
    db.commit()

    return schemas.ActionResult(
        success=True,
        message="Đã cập nhật avatar",
        data=user,
    )


# ═════════════════════════════════════════════════════════════
# LOCK / UNLOCK 1 USER
# ═════════════════════════════════════════════════════════════
@router.post(
    "/users/{user_id}/lock",
    response_model=schemas.ActionResult[schemas.UserResponse],
)
def lock_user(
    user_id: int,
    admin_id: int = Query(...),
    db: Session = Depends(get_db),
):
    admin = require_admin(db, admin_id)
    if user_id == admin_id:
        raise HTTPException(status_code=400, detail="Không thể tự khóa chính mình")

    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")

    user.is_locked = True
    db.commit()
    db.refresh(user)
    write_log(db, admin_id, "LOCK_USER", f"Khóa user_id={user_id} ({user.email})")
    db.commit()

    return schemas.ActionResult(
        success=True,
        message=f"Đã khóa tài khoản {user.email}",
        data=user,
    )


@router.post(
    "/users/{user_id}/unlock",
    response_model=schemas.ActionResult[schemas.UserResponse],
)
def unlock_user(
    user_id: int,
    admin_id: int = Query(...),
    db: Session = Depends(get_db),
):
    require_admin(db, admin_id)
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")

    user.is_locked = False
    db.commit()
    db.refresh(user)
    write_log(db, admin_id, "UNLOCK_USER", f"Mở khóa user_id={user_id} ({user.email})")
    db.commit()

    return schemas.ActionResult(
        success=True,
        message=f"Đã mở khóa tài khoản {user.email}",
        data=user,
    )


# ═════════════════════════════════════════════════════════════
# BULK ACTION (lock/unlock/delete nhiều user)
# ═════════════════════════════════════════════════════════════
@router.post(
    "/users/bulk",
    response_model=schemas.ActionResult[dict],
)
def bulk_user_action(
    data: schemas.BulkUserAction,
    admin_id: int = Query(...),
    db: Session = Depends(get_db),
):
    require_admin(db, admin_id)
    action = data.action.upper()
    if action not in ("LOCK", "UNLOCK", "DELETE"):
        raise HTTPException(status_code=400, detail="Action phải là LOCK | UNLOCK | DELETE")

    target_ids = [uid for uid in data.user_ids if uid != admin_id]
    if not target_ids:
        return schemas.ActionResult(
            success=True,
            message="Không có user hợp lệ để xử lý",
            data={"affected": 0},
        )

    users = db.query(models.User).filter(models.User.user_id.in_(target_ids)).all()

    if action == "LOCK":
        for u in users:
            u.is_locked = True
    elif action == "UNLOCK":
        for u in users:
            u.is_locked = False
    else:
        for u in users:
            db.delete(u)

    db.commit()
    write_log(
        db, admin_id, f"BULK_{action}",
        f"{action} {len(users)} users: {[u.user_id for u in users]}",
    )
    db.commit()

    return schemas.ActionResult(
        success=True,
        message=f"Đã {action.lower()} {len(users)} tài khoản",
        data={"affected": len(users)},
    )


# ═════════════════════════════════════════════════════════════
# PROMOTE TO ADMIN
# ═════════════════════════════════════════════════════════════
@router.post(
    "/promote/{user_id}",
    response_model=schemas.ActionResult[schemas.UserResponse],
)
def promote_to_admin(
    user_id: int,
    admin_id: int = Query(...),
    db: Session = Depends(get_db),
):
    require_admin(db, admin_id)
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
    user.role = models.RoleType.ADMIN
    db.commit()
    db.refresh(user)
    write_log(db, admin_id, "PROMOTE_ADMIN", f"Cấp admin cho {user.email}")
    db.commit()
    return schemas.ActionResult(
        success=True,
        message=f"Đã cấp quyền Admin cho {user.email}",
        data=user,
    )


# ═════════════════════════════════════════════════════════════
# AUDIT LOGS
# ═════════════════════════════════════════════════════════════
@router.get(
    "/logs",
    response_model=schemas.ActionResult[List[schemas.AuditLogResponse]],
)
def get_logs(
    admin_id: int = Query(...),
    limit: int = Query(500, le=2000),
    db: Session = Depends(get_db),
):
    require_admin(db, admin_id)
    logs = (
        db.query(models.AuditLog)
        .order_by(models.AuditLog.created_at.desc())
        .limit(limit)
        .all()
    )
    return schemas.ActionResult(success=True, message="OK", data=logs)


# ═════════════════════════════════════════════════════════════
# AI MODEL CONFIG
# ═════════════════════════════════════════════════════════════
@router.get(
    "/models",
    response_model=schemas.ActionResult[List[schemas.AIModelConfigResponse]],
)
def list_ai_models(
    admin_id: int = Query(...),
    db: Session = Depends(get_db),
):
    require_admin(db, admin_id)
    configs = db.query(models.AIModelConfig).all()
    return schemas.ActionResult(success=True, message="OK", data=configs)


@router.put(
    "/models/{model_type}",
    response_model=schemas.ActionResult[schemas.AIModelConfigResponse],
)
def toggle_ai_model(
    model_type: models.AIModelType,
    data: schemas.AIModelToggle,
    admin_id: int = Query(...),
    db: Session = Depends(get_db),
):
    require_admin(db, admin_id)
    cfg = (
        db.query(models.AIModelConfig)
        .filter(models.AIModelConfig.model_type == model_type)
        .first()
    )
    if not cfg:
        cfg = models.AIModelConfig(
            model_type=model_type, is_active=data.is_active, display_name=model_type.value,
        )
        db.add(cfg)
    else:
        cfg.is_active = data.is_active
    db.commit()
    db.refresh(cfg)

    write_log(db, admin_id, "TOGGLE_MODEL",
              f"{model_type.value} → {'active' if data.is_active else 'inactive'}")
    db.commit()

    return schemas.ActionResult(success=True, message="Cập nhật model thành công", data=cfg)


# ═════════════════════════════════════════════════════════════
# FEEDBACKS
# ═════════════════════════════════════════════════════════════
@router.get(
    "/feedbacks",
    response_model=schemas.ActionResult[List[schemas.FeedbackResponse]],
)
def list_feedbacks(
    admin_id: int = Query(...),
    min_rating: Optional[int] = None,
    db: Session = Depends(get_db),
):
    require_admin(db, admin_id)
    q = db.query(models.Feedback)
    if min_rating is not None:
        q = q.filter(models.Feedback.rating >= min_rating)
    items = q.order_by(models.Feedback.created_at.desc()).all()
    out = []
    for fb in items:
        user = fb.user
        out.append(
            schemas.FeedbackResponse(
                id=fb.id,
                user_id=fb.user_id,
                rating=fb.rating,
                content=fb.content,
                created_at=fb.created_at,
                user_email=user.email if user else None,
                user_name=user.full_name if user else None,
            )
        )
    return schemas.ActionResult(success=True, message="OK", data=out)

"""
PATCH: Thêm vào cuối file backend/routers/admin.py
Endpoint cho admin xem tin nhắn từ trang liên hệ.
"""

from typing import Optional
from datetime import datetime
from pydantic import BaseModel


class ContactMessageAdminResponse(BaseModel):
    id: int
    name: Optional[str]
    email: str
    content: str
    is_read: bool
    created_at: datetime

    class Config:
        from_attributes = True


# Thêm vào cuối file admin.py (sau phần FEEDBACKS):

# ═════════════════════════════════════════════════════════════
# CONTACT MESSAGES — Tin nhắn từ trang Liên hệ
# ═════════════════════════════════════════════════════════════
@router.get(
    "/contact-messages",
    response_model=schemas.ActionResult[List[ContactMessageAdminResponse]],
)
async def list_contact_messages(
    admin_id: int = Query(...),
    unread_only: bool = Query(False),
    db: Session = Depends(get_db),
):
    require_admin(db, admin_id)
    q = db.query(models.ContactMessage)
    if unread_only:
        q = q.filter(models.ContactMessage.is_read == False)
    items = q.order_by(models.ContactMessage.created_at.desc()).all()
    return schemas.ActionResult(
        success=True,
        message="OK",
        data=[ContactMessageAdminResponse.model_validate(item) for item in items],
    )


@router.post("/contact-messages/{msg_id}/read")
def mark_contact_message_read(
    msg_id: int,
    admin_id: int = Query(...),   # thêm = Query(...)
    db: Session = Depends(get_db),
):
    """Đánh dấu tin nhắn liên hệ đã đọc."""
    # require_admin(db, admin_id)
    msg = db.query(models.ContactMessage).filter(models.ContactMessage.id == msg_id).first()
    if not msg:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Không tìm thấy tin nhắn.")
    msg.is_read = True
    db.commit()
    return schemas.ActionResult(success=True, message="Đã đánh dấu đã đọc.", data=None)