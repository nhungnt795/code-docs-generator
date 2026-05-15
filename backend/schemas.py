from datetime import datetime
from typing import Generic, Optional, TypeVar

from pydantic import BaseModel, ConfigDict, EmailStr

from backend.models import (
    ProgrammingLanguage,
    RoleType,
    SourceType
)

# ═════════════════════════════════════════════════════════════
# GENERIC RESPONSE
# ═════════════════════════════════════════════════════════════

T = TypeVar("T")


class ActionResult(BaseModel, Generic[T]):
    success: bool
    message: str
    data: Optional[T] = None

# ═════════════════════════════════════════════════════════════
# USER SCHEMAS
# ═════════════════════════════════════════════════════════════

class UserBase(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None


class UserCreate(UserBase):
    password: str


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserResponse(UserBase):
    user_id: int
    role: RoleType
    created_at: datetime

    model_config = ConfigDict(
        from_attributes=True
    )


class LoginResponse(BaseModel):
    """
    Trả về thông tin user + token.
    """

    user: UserResponse
    token: str

# ═════════════════════════════════════════════════════════════
# DOCUMENT SCHEMAS
# ═════════════════════════════════════════════════════════════

class DocumentBase(BaseModel):
    title: str
    source_type: SourceType
    language: ProgrammingLanguage
    raw_code_context: str


class DocumentCreate(DocumentBase):
    pass


class DocumentResponse(DocumentBase):
    doc_id: Optional[int] = None
    user_id: Optional[int] = None

    content_md: str

    time_taken_ms: Optional[int] = None

    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    model_config = ConfigDict(
        from_attributes=True
    )

# ═════════════════════════════════════════════════════════════
# AUDIT LOG SCHEMAS
# ═════════════════════════════════════════════════════════════

class AuditLogResponse(BaseModel):
    log_id: int
    user_id: Optional[int] = None

    action: str
    details: Optional[str] = None

    created_at: datetime

    model_config = ConfigDict(
        from_attributes=True
    )

# ═════════════════════════════════════════════════════════════
# DASHBOARD STATS
# ═════════════════════════════════════════════════════════════

class DashboardStats(BaseModel):
    """
    Thống kê Dashboard Admin
    """

    total_users: int
    total_documents: int
    total_admins: int

    docs_today: int
    avg_time_ms: int