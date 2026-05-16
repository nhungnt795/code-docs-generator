"""
SQLAlchemy models.

Bổ sung so với bản cũ:
- DocumentVersion: lưu các phiên bản đã chỉnh sửa
- Feedback: rating + nội dung phản hồi
- AIModelConfig: bật/tắt model AI (admin quản lý)
- User.is_locked: admin khóa account
- User.is_active: kích hoạt qua OTP
"""

import enum
from datetime import datetime, timezone

from sqlalchemy import (
    Boolean,
    Column,
    DateTime,
    Enum as SQLEnum,
    ForeignKey,
    Integer,
    String,
    Text,
)
from sqlalchemy.orm import relationship

from database import Base


# ═════════════════════════════════════════════════════════════
# ENUMS
# ═════════════════════════════════════════════════════════════
class RoleType(str, enum.Enum):
    GUEST = "GUEST"
    USER = "USER"
    ADMIN = "ADMIN"


class SourceType(str, enum.Enum):
    DIRECT_TEXT = "DIRECT_TEXT"
    FILE_UPLOAD = "FILE_UPLOAD"


class ProgrammingLanguage(str, enum.Enum):
    PYTHON = "PYTHON"
    JAVA = "JAVA"
    JAVASCRIPT = "JAVASCRIPT"
    CPP = "CPP"
    TYPESCRIPT = "TYPESCRIPT"
    RUST = "RUST"


class AIModelType(str, enum.Enum):
    GROQ_LLAMA3 = "GROQ_LLAMA3"
    KAGGLE_FINETUNED = "KAGGLE_FINETUNED"


def utc_now() -> datetime:
    return datetime.now(timezone.utc)


# ═════════════════════════════════════════════════════════════
# USER
# ═════════════════════════════════════════════════════════════
class User(Base):
    __tablename__ = "users"

    user_id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    password_hash = Column(String(255), nullable=False)
    full_name = Column(String(100))
    avatar_url = Column(String(500), nullable=True)

    role = Column(
        SQLEnum(RoleType),
        default=RoleType.USER,
        nullable=False,
    )

    # Đã kích hoạt qua OTP chưa
    is_active = Column(Boolean, default=False, nullable=False)
    # Bị admin khóa
    is_locked = Column(Boolean, default=False, nullable=False)

    # OTP
    otp_code = Column(String(6), nullable=True)
    otp_expiry = Column(DateTime(timezone=True), nullable=True)
    # OTP loại: ACTIVATE | RESET_PASSWORD
    otp_purpose = Column(String(20), nullable=True)

    created_at = Column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=utc_now,
        onupdate=utc_now,
        nullable=False,
    )

    documents = relationship(
        "Document",
        back_populates="owner",
        cascade="all, delete-orphan",
    )
    logs = relationship(
        "AuditLog",
        back_populates="user",
        cascade="all, delete-orphan",
    )
    feedbacks = relationship(
        "Feedback",
        back_populates="user",
        cascade="all, delete-orphan",
    )


# ═════════════════════════════════════════════════════════════
# DOCUMENT
# ═════════════════════════════════════════════════════════════
class Document(Base):
    __tablename__ = "documents"

    doc_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer,
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
    )

    title = Column(String(255))
    source_type = Column(SQLEnum(SourceType), nullable=False)
    language = Column(SQLEnum(ProgrammingLanguage), nullable=False)

    raw_code_context = Column(Text, nullable=False)
    content_md = Column(Text, nullable=False)

    # Model AI đã dùng để sinh
    ai_model = Column(
        SQLEnum(AIModelType),
        default=AIModelType.GROQ_LLAMA3,
        nullable=False,
    )

    time_taken_ms = Column(Integer)

    created_at = Column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )
    updated_at = Column(
        DateTime(timezone=True),
        default=utc_now,
        onupdate=utc_now,
        nullable=False,
    )

    owner = relationship("User", back_populates="documents")
    versions = relationship(
        "DocumentVersion",
        back_populates="document",
        cascade="all, delete-orphan",
        order_by="DocumentVersion.version_number.desc()",
    )


# ═════════════════════════════════════════════════════════════
# DOCUMENT VERSION
# Lưu các phiên bản chỉnh sửa: bản v1 là bản gốc, v2 trở đi là bản sửa
# ═════════════════════════════════════════════════════════════
class DocumentVersion(Base):
    __tablename__ = "document_versions"

    version_id = Column(Integer, primary_key=True, index=True)
    doc_id = Column(
        Integer,
        ForeignKey("documents.doc_id", ondelete="CASCADE"),
        nullable=False,
    )
    version_number = Column(Integer, nullable=False)
    content_md = Column(Text, nullable=False)

    created_at = Column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )

    document = relationship("Document", back_populates="versions")


# ═════════════════════════════════════════════════════════════
# AUDIT LOG
# ═════════════════════════════════════════════════════════════
class AuditLog(Base):
    __tablename__ = "audit_logs"

    log_id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer,
        ForeignKey("users.user_id", ondelete="SET NULL"),
        nullable=True,
    )
    action = Column(String(100), nullable=False)
    details = Column(Text)

    created_at = Column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )

    user = relationship("User", back_populates="logs")


# ═════════════════════════════════════════════════════════════
# AI MODEL CONFIG
# Admin bật/tắt model. Người dùng chọn model nào hoạt động.
# ═════════════════════════════════════════════════════════════
class AIModelConfig(Base):
    __tablename__ = "ai_model_configs"

    id = Column(Integer, primary_key=True, index=True)
    model_type = Column(
        SQLEnum(AIModelType),
        unique=True,
        nullable=False,
    )
    is_active = Column(Boolean, default=True, nullable=False)
    display_name = Column(String(100))
    description = Column(String(255))

    updated_at = Column(
        DateTime(timezone=True),
        default=utc_now,
        onupdate=utc_now,
        nullable=False,
    )


# ═════════════════════════════════════════════════════════════
# FEEDBACK
# ═════════════════════════════════════════════════════════════
class Feedback(Base):
    __tablename__ = "feedbacks"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(
        Integer,
        ForeignKey("users.user_id", ondelete="CASCADE"),
        nullable=False,
    )
    rating = Column(Integer, nullable=False)  # 1..5
    content = Column(Text, nullable=True)

    created_at = Column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )

    user = relationship("User", back_populates="feedbacks")

"""
PATCH: Thêm model ContactMessage vào models.py
Thêm đoạn code này vào cuối file backend/models.py
"""

# ═════════════════════════════════════════════════════════════
# CONTACT MESSAGE
# Tin nhắn từ trang Liên hệ (không cần đăng nhập)
# ═════════════════════════════════════════════════════════════
class ContactMessage(Base):
    __tablename__ = "contact_messages"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(120), nullable=True)
    email = Column(String(255), nullable=False)
    content = Column(Text, nullable=False)
    is_read = Column(Boolean, default=False, nullable=False)

    created_at = Column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False,
    )