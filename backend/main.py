import sys
import os
import time
import bcrypt

from typing import List, Optional

from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import func
from sqlalchemy.orm import Session

# ─────────────────────────────────────────────────────────────
# FIX IMPORT PATH
# ─────────────────────────────────────────────────────────────
current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
sys.path.append(parent_dir)

# ─────────────────────────────────────────────────────────────
# IMPORT MODULES
# ─────────────────────────────────────────────────────────────
from ai_module.model.rag_engine import GraphRAGEngine

from backend import models
from backend import schemas
from backend.database import engine, get_db
from backend.validators import (
    validate_code_syntax_with_treesitter,
    validate_file_extension
)

# ─────────────────────────────────────────────────────────────
# CREATE DATABASE TABLES
# ─────────────────────────────────────────────────────────────
models.Base.metadata.create_all(bind=engine)

# ─────────────────────────────────────────────────────────────
# FASTAPI APP
# ─────────────────────────────────────────────────────────────
app = FastAPI(title="DocGen GraphRAG API")

# ─────────────────────────────────────────────────────────────
# CORS CONFIG
# ─────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─────────────────────────────────────────────────────────────
# INIT RAG ENGINE
# ─────────────────────────────────────────────────────────────
rag_engine = GraphRAGEngine()

# ─────────────────────────────────────────────────────────────
# PASSWORD HELPERS
# ─────────────────────────────────────────────────────────────
def hash_password(password: str) -> str:
    """Hash password bằng bcrypt."""
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(
        password.encode("utf-8"),
        salt
    ).decode("utf-8")


def verify_password(plain_password: str, hashed_password: str) -> bool:
    """Kiểm tra password."""
    try:
        return bcrypt.checkpw(
            plain_password.encode("utf-8"),
            hashed_password.encode("utf-8")
        )
    except Exception:
        return False

# ─────────────────────────────────────────────────────────────
# ROOT
# ─────────────────────────────────────────────────────────────
@app.get("/")
def root():
    return {
        "status": "ok",
        "message": "GraphRAG Backend is running"
    }

# ═════════════════════════════════════════════════════════════
# AUTH APIs
# ═════════════════════════════════════════════════════════════

@app.post(
    "/api/auth/register",
    response_model=schemas.ActionResult[schemas.UserResponse]
)
def register(
    user: schemas.UserCreate,
    db: Session = Depends(get_db)
):
    """Đăng ký tài khoản."""

    db_user = db.query(models.User).filter(
        models.User.email == user.email
    ).first()

    if db_user:
        raise HTTPException(
            status_code=400,
            detail="Email đã tồn tại"
        )

    new_user = models.User(
        email=user.email,
        password_hash=hash_password(user.password),
        full_name=user.full_name
    )

    db.add(new_user)
    db.commit()
    db.refresh(new_user)

    # Audit log
    log = models.AuditLog(
        user_id=new_user.user_id,
        action="REGISTER",
        details=f"Tài khoản mới: {new_user.email}"
    )

    db.add(log)
    db.commit()

    return schemas.ActionResult(
        success=True,
        message="Tạo tài khoản thành công",
        data=new_user
    )


@app.post(
    "/api/auth/login",
    response_model=schemas.ActionResult[schemas.UserResponse]
)
def login(
    credentials: schemas.UserLogin,
    db: Session = Depends(get_db)
):
    """Đăng nhập."""

    user = db.query(models.User).filter(
        models.User.email == credentials.email
    ).first()

    if not user:
        raise HTTPException(
            status_code=401,
            detail="Email hoặc mật khẩu không đúng"
        )

    if not verify_password(
        credentials.password,
        user.password_hash
    ):
        raise HTTPException(
            status_code=401,
            detail="Email hoặc mật khẩu không đúng"
        )

    # Audit log
    log = models.AuditLog(
        user_id=user.user_id,
        action="LOGIN",
        details=f"Đăng nhập từ tài khoản {user.email}"
    )

    db.add(log)
    db.commit()

    return schemas.ActionResult(
        success=True,
        message="Đăng nhập thành công",
        data=user
    )

# API cũ để tương thích ngược
@app.post(
    "/api/users",
    response_model=schemas.ActionResult[schemas.UserResponse]
)
def create_user(
    user: schemas.UserCreate,
    db: Session = Depends(get_db)
):
    return register(user, db)

# ═════════════════════════════════════════════════════════════
# DOCUMENT APIs
# ═════════════════════════════════════════════════════════════

@app.post(
    "/api/docs/generate",
    response_model=schemas.ActionResult[schemas.DocumentResponse]
)
def generate_document(
    doc_req: schemas.DocumentCreate,
    user_id: Optional[int] = None,
    db: Session = Depends(get_db)
):
    # ─────────────────────────────────────────────────────────
    # VALIDATION
    # ─────────────────────────────────────────────────────────
    if doc_req.source_type == models.SourceType.FILE_UPLOAD:
        validate_file_extension(
            doc_req.title,
            doc_req.language
        )

    validate_code_syntax_with_treesitter(
        doc_req.raw_code_context,
        doc_req.language
    )

    # ─────────────────────────────────────────────────────────
    # PROCESS RAG
    # ─────────────────────────────────────────────────────────
    start_time = time.time()

    try:
        markdown_content = rag_engine.process_query(
            doc_req.raw_code_context
        )

        if isinstance(markdown_content, dict):
            markdown_content = markdown_content.get(
                "docstring",
                str(markdown_content)
            )

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Lỗi khi xử lý RAG: {str(e)}"
        )

    time_taken = int(
        (time.time() - start_time) * 1000
    )

    # ─────────────────────────────────────────────────────────
    # GUEST MODE
    # ─────────────────────────────────────────────────────────
    if user_id is None:

        guest_doc = schemas.DocumentResponse(
            title=doc_req.title,
            source_type=doc_req.source_type,
            language=doc_req.language,
            raw_code_context=doc_req.raw_code_context,
            content_md=markdown_content,
            time_taken_ms=time_taken
        )

        return schemas.ActionResult(
            success=True,
            message="Sinh tài liệu thành công (Chế độ Khách)",
            data=guest_doc
        )

    # ─────────────────────────────────────────────────────────
    # USER MODE
    # ─────────────────────────────────────────────────────────
    user = db.query(models.User).filter(
        models.User.user_id == user_id
    ).first()

    if not user:
        raise HTTPException(
            status_code=404,
            detail="Không tìm thấy người dùng"
        )

    new_doc = models.Document(
        user_id=user_id,
        title=doc_req.title,
        source_type=doc_req.source_type,
        language=doc_req.language,
        raw_code_context=doc_req.raw_code_context,
        content_md=markdown_content,
        time_taken_ms=time_taken
    )

    db.add(new_doc)

    # Audit log
    log = models.AuditLog(
        user_id=user_id,
        action="GENERATE_DOC",
        details=f"Đã sinh tài liệu {doc_req.language.value} bằng GraphRAG"
    )

    db.add(log)

    db.commit()
    db.refresh(new_doc)

    return schemas.ActionResult(
        success=True,
        message="Sinh tài liệu và lưu lịch sử thành công",
        data=new_doc
    )

# ─────────────────────────────────────────────────────────────
# GET USER HISTORY
# ─────────────────────────────────────────────────────────────
@app.get(
    "/api/docs/history/{user_id}",
    response_model=schemas.ActionResult[
        List[schemas.DocumentResponse]
    ]
)
def get_user_history(
    user_id: int,
    db: Session = Depends(get_db)
):
    docs = db.query(models.Document).filter(
        models.Document.user_id == user_id
    ).order_by(
        models.Document.created_at.desc()
    ).all()

    return schemas.ActionResult(
        success=True,
        message="Lấy lịch sử thành công",
        data=docs
    )

# ─────────────────────────────────────────────────────────────
# DELETE DOCUMENT
# ─────────────────────────────────────────────────────────────
@app.delete(
    "/api/docs/{doc_id}",
    response_model=schemas.ActionResult[None]
)
def delete_document(
    doc_id: int,
    user_id: int,
    db: Session = Depends(get_db)
):
    doc = db.query(models.Document).filter(
        models.Document.doc_id == doc_id
    ).first()

    if not doc:
        raise HTTPException(
            status_code=404,
            detail="Không tìm thấy tài liệu"
        )

    if doc.user_id != user_id:
        raise HTTPException(
            status_code=403,
            detail="Bạn không có quyền xóa tài liệu này"
        )

    db.delete(doc)

    log = models.AuditLog(
        user_id=user_id,
        action="DELETE_DOC",
        details=f"Đã xóa tài liệu doc_id={doc_id}"
    )

    db.add(log)
    db.commit()

    return schemas.ActionResult(
        success=True,
        message="Xóa tài liệu thành công",
        data=None
    )

# ═════════════════════════════════════════════════════════════
# ADMIN APIs
# ═════════════════════════════════════════════════════════════

@app.post(
    "/api/admin/promote/{user_id}",
    response_model=schemas.ActionResult[schemas.UserResponse]
)
def promote_to_admin(
    user_id: int,
    db: Session = Depends(get_db)
):
    user = db.query(models.User).filter(
        models.User.user_id == user_id
    ).first()

    if not user:
        raise HTTPException(
            status_code=404,
            detail="Không tìm thấy người dùng"
        )

    user.role = models.RoleType.ADMIN

    db.commit()
    db.refresh(user)

    return schemas.ActionResult(
        success=True,
        message=f"Đã cấp quyền Admin cho user {user.email}",
        data=user
    )


@app.get(
    "/api/admin/users",
    response_model=schemas.ActionResult[
        List[schemas.UserResponse]
    ]
)
def get_all_users(
    admin_id: int,
    db: Session = Depends(get_db)
):
    admin = db.query(models.User).filter(
        models.User.user_id == admin_id,
        models.User.role == models.RoleType.ADMIN
    ).first()

    if not admin:
        raise HTTPException(
            status_code=403,
            detail="Bạn không có quyền truy cập chức năng này"
        )

    users = db.query(models.User).order_by(
        models.User.created_at.desc()
    ).all()

    return schemas.ActionResult(
        success=True,
        message="Lấy danh sách người dùng thành công",
        data=users
    )


@app.get(
    "/api/admin/logs",
    response_model=schemas.ActionResult[
        List[schemas.AuditLogResponse]
    ]
)
def get_system_logs(
    admin_id: int,
    db: Session = Depends(get_db)
):
    admin = db.query(models.User).filter(
        models.User.user_id == admin_id,
        models.User.role == models.RoleType.ADMIN
    ).first()

    if not admin:
        raise HTTPException(
            status_code=403,
            detail="Bạn không có quyền truy cập chức năng này"
        )

    logs = db.query(models.AuditLog).order_by(
        models.AuditLog.created_at.desc()
    ).limit(500).all()

    return schemas.ActionResult(
        success=True,
        message="Lấy nhật ký hệ thống thành công",
        data=logs
    )


@app.get(
    "/api/admin/stats",
    response_model=schemas.ActionResult[dict]
)
def get_admin_stats(
    admin_id: int,
    db: Session = Depends(get_db)
):
    admin = db.query(models.User).filter(
        models.User.user_id == admin_id,
        models.User.role == models.RoleType.ADMIN
    ).first()

    if not admin:
        raise HTTPException(
            status_code=403,
            detail="Bạn không có quyền truy cập chức năng này"
        )

    total_users = db.query(models.User).count()

    total_docs = db.query(models.Document).count()

    total_admins = db.query(models.User).filter(
        models.User.role == models.RoleType.ADMIN
    ).count()

    lang_stats = db.query(
        models.Document.language,
        func.count(models.Document.doc_id).label("count")
    ).group_by(
        models.Document.language
    ).all()

    return schemas.ActionResult(
        success=True,
        message="Lấy thống kê thành công",
        data={
            "total_users": total_users,
            "total_docs": total_docs,
            "total_admins": total_admins,
            "by_language": [
                {
                    "language": language.value,
                    "count": count
                }
                for language, count in lang_stats
            ]
        }
    )