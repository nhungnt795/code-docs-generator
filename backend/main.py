"""
DocGen GraphRAG API — Backend.

Khởi động:
  uvicorn main:app --host 0.0.0.0 --port 8000

Cấu trúc:
  - main.py            : khởi tạo FastAPI, đăng ký router, CORS, static files, seed dữ liệu
  - database.py        : engine + session
  - models.py          : SQLAlchemy models
  - schemas.py         : Pydantic schemas
  - auth_helpers.py    : password, OTP, require_admin/user
  - validators.py      : kiểm tra syntax (trả về kết quả, không tự raise)
  - email_service.py   : OTP qua email (template HTML)
  - export_service.py  : MD / PDF / DOCX
  - routers/
      auth.py          : register, login, OTP, reset password
      profile.py       : đổi tên/email/mật khẩu, upload avatar
      documents.py     : sinh / sửa / xuất tài liệu
      admin.py         : dashboard, quản lý user, model, feedback
      feedback.py      : gửi đánh giá
      public.py        : danh sách model AI active
"""

import os
import sys

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

# ─────────────────────────────────────────────────────────────
# FIX IMPORT PATH (cho ai_module ở thư mục cha)
# ─────────────────────────────────────────────────────────────
_current_dir = os.path.dirname(os.path.abspath(__file__))
_parent_dir = os.path.dirname(_current_dir)
if _parent_dir not in sys.path:
    sys.path.append(_parent_dir)

import models
from database import SessionLocal, engine
from routers import admin as admin_router
from routers import auth as auth_router
from routers import documents as documents_router
from routers import feedback as feedback_router
from routers import profile as profile_router
from routers import public as public_router
from routers import contact as contact_router

# ─────────────────────────────────────────────────────────────
# CREATE TABLES
# ─────────────────────────────────────────────────────────────
models.Base.metadata.create_all(bind=engine)

# ─────────────────────────────────────────────────────────────
# APP
# ─────────────────────────────────────────────────────────────
app = FastAPI(
    title="DocGen GraphRAG API",
    version="2.0.0",
    description="Backend API for DocGen VN — sinh tài liệu code tự động.",
)

# CORS
# Lưu ý: allow_credentials=True không tương thích với allow_origins=["*"]
# Phải liệt kê origin cụ thể hoặc đọc từ env
_cors_origins_env = os.getenv("CORS_ORIGINS", "")
if _cors_origins_env:
    _allow_origins = [o.strip() for o in _cors_origins_env.split(",") if o.strip()]
else:
    # Fallback: cho phép tất cả origin (không dùng credentials)
    _allow_origins = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_allow_origins,
    allow_credentials=_allow_origins != ["*"],  # credentials chỉ bật khi có origin cụ thể
    allow_methods=["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
    allow_headers=["*"],
    expose_headers=["Content-Disposition"],
)

# Static files (avatars, exported files...)
os.makedirs("data/avatars", exist_ok=True)
app.mount("/data", StaticFiles(directory="data"), name="data")

# ─────────────────────────────────────────────────────────────
# REGISTER ROUTERS
# ─────────────────────────────────────────────────────────────
app.include_router(auth_router.router)
app.include_router(profile_router.router)
app.include_router(documents_router.router)
app.include_router(admin_router.router)
app.include_router(feedback_router.router)
app.include_router(public_router.router)
app.include_router(contact_router.router)


# ─────────────────────────────────────────────────────────────
# ROOT & HEALTH
# ─────────────────────────────────────────────────────────────
@app.get("/")
def root():
    return {
        "status": "ok",
        "name": "DocGen GraphRAG API",
        "version": "2.0.0",
    }


@app.get("/health")
def health():
    return {"status": "healthy"}


# ─────────────────────────────────────────────────────────────
# STARTUP: SEED AI MODEL CONFIG
# ─────────────────────────────────────────────────────────────
@app.on_event("startup")
def seed_ai_models():
    db = SessionLocal()
    try:
        existing = db.query(models.AIModelConfig).count()
        if existing == 0:
            db.add_all(
                [
                    models.AIModelConfig(
                        model_type=models.AIModelType.GROQ_LLAMA3,
                        is_active=True,
                        display_name="Llama 3.1 8B (Groq)",
                        description="Mô hình llama 3.1 8b chạy trên Groq Cloud — nhanh, ổn định.",
                    ),
                    models.AIModelConfig(
                        model_type=models.AIModelType.KAGGLE_FINETUNED,
                        is_active=True,
                        display_name="Llama 3.1 Finetuned (Kaggle)",
                        description="Llama 3.1 đã được finetune cho sinh tài liệu code.",
                    ),
                ]
            )
            db.commit()
            print("[STARTUP] Đã seed AIModelConfig mặc định.")
    except Exception as e:
        print(f"[STARTUP] Lỗi seed AIModelConfig: {e}")
        db.rollback()
    finally:
        db.close()


# ─────────────────────────────────────────────────────────────
# LEGACY ENDPOINT (giữ tương thích với client cũ)
# ─────────────────────────────────────────────────────────────
@app.post("/api/users", include_in_schema=False)
def legacy_create_user(user: dict):
    """Redirect tới /api/auth/register."""
    from fastapi import HTTPException
    raise HTTPException(
        status_code=410,
        detail="Endpoint /api/users đã ngừng dùng. Hãy dùng /api/auth/register.",
    )