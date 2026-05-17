"""
Database configuration.

Hỗ trợ 2 cách cấu hình:
1) DATABASE_URL trực tiếp (ưu tiên - thường dùng trong Docker Compose)
2) Tách rời DB_USER / DB_PASS / DB_HOST / DB_PORT / DB_NAME (local dev)
"""

import os
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, declarative_base
from dotenv import load_dotenv

load_dotenv()

# ─────────────────────────────────────────────────────────────
# BUILD DATABASE URL
# ─────────────────────────────────────────────────────────────
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    DB_USER = os.getenv("DB_USER", "postgres")
    DB_PASS = os.getenv("DB_PASS", "postgres")
    DB_HOST = os.getenv("DB_HOST", "localhost")
    DB_PORT = os.getenv("DB_PORT", "5432")
    DB_NAME = os.getenv("DB_NAME", "web_and_app_db")

    DATABASE_URL = (
        f"postgresql+psycopg2://{DB_USER}:{DB_PASS}"
        f"@{DB_HOST}:{DB_PORT}/{DB_NAME}"
    )

# ─────────────────────────────────────────────────────────────
# ENGINE & SESSION
# ─────────────────────────────────────────────────────────────
engine = create_engine(
    DATABASE_URL,
    pool_pre_ping=True,   # Tự kiểm tra connection còn sống
    pool_recycle=1800,    # Recycle connection sau 30 phút
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

Base = declarative_base()


def get_db():
    """Dependency: cấp 1 session cho request, đóng khi xong."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
