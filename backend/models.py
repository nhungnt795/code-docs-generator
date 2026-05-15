from sqlalchemy import (
    Column,
    Integer,
    String,
    Text,
    DateTime,
    ForeignKey,
    Enum as SQLEnum
)

from sqlalchemy.orm import declarative_base, relationship

from datetime import datetime, timezone
import enum

Base = declarative_base()

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

# ═════════════════════════════════════════════════════════════
# TIME HELPER
# ═════════════════════════════════════════════════════════════

def utc_now():
    return datetime.now(timezone.utc)

# ═════════════════════════════════════════════════════════════
# USER MODEL
# ═════════════════════════════════════════════════════════════

class User(Base):
    __tablename__ = "users"

    user_id = Column(
        Integer,
        primary_key=True,
        index=True
    )

    email = Column(
        String(255),
        unique=True,
        index=True,
        nullable=False
    )

    password_hash = Column(
        String(255),
        nullable=False
    )

    full_name = Column(
        String(100)
    )

    role = Column(
        SQLEnum(RoleType),
        default=RoleType.USER,
        nullable=False
    )

    created_at = Column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False
    )

    # Relationships
    documents = relationship(
        "Document",
        back_populates="owner",
        cascade="all, delete-orphan"
    )

    logs = relationship(
        "AuditLog",
        back_populates="user",
        cascade="all, delete-orphan"
    )

# ═════════════════════════════════════════════════════════════
# DOCUMENT MODEL
# ═════════════════════════════════════════════════════════════

class Document(Base):
    __tablename__ = "documents"

    doc_id = Column(
        Integer,
        primary_key=True,
        index=True
    )

    user_id = Column(
        Integer,
        ForeignKey("users.user_id"),
        nullable=False
    )

    title = Column(
        String(255)
    )

    source_type = Column(
        SQLEnum(SourceType),
        nullable=False
    )

    language = Column(
        SQLEnum(ProgrammingLanguage),
        nullable=False
    )

    raw_code_context = Column(
        Text,
        nullable=False
    )

    content_md = Column(
        Text,
        nullable=False
    )

    time_taken_ms = Column(
        Integer
    )

    created_at = Column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False
    )

    updated_at = Column(
        DateTime(timezone=True),
        default=utc_now,
        onupdate=utc_now,
        nullable=False
    )

    # Relationships
    owner = relationship(
        "User",
        back_populates="documents"
    )

# ═════════════════════════════════════════════════════════════
# AUDIT LOG MODEL
# ═════════════════════════════════════════════════════════════

class AuditLog(Base):
    __tablename__ = "audit_logs"

    log_id = Column(
        Integer,
        primary_key=True,
        index=True
    )

    user_id = Column(
        Integer,
        ForeignKey("users.user_id")
    )

    action = Column(
        String(100),
        nullable=False
    )

    details = Column(
        Text
    )

    created_at = Column(
        DateTime(timezone=True),
        default=utc_now,
        nullable=False
    )

    # Relationships
    user = relationship(
        "User",
        back_populates="logs"
    )