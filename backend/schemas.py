"""
Pydantic schemas (request/response).
"""

from datetime import datetime
from typing import Generic, List, Optional, TypeVar

from pydantic import BaseModel, ConfigDict, EmailStr, Field

from models import (
    AIModelType,
    ProgrammingLanguage,
    RoleType,
    SourceType,
)

# Pydantic v2 cảnh báo cho field bắt đầu bằng "model_".
# Project có nhiều field hợp lệ kiểu này (model_type, ai_model...) nên tắt namespace bảo vệ.
_BASE_CONFIG = ConfigDict(
    from_attributes=True,
    protected_namespaces=(),
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
# USER
# ═════════════════════════════════════════════════════════════
class UserBase(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None


class UserCreate(UserBase):
    password: str = Field(..., min_length=6, max_length=100)


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserResponse(BaseModel):
    user_id: int
    email: str
    full_name: Optional[str] = None
    avatar_url: Optional[str] = None
    role: RoleType
    is_active: bool
    is_locked: bool
    created_at: datetime

    model_config = _BASE_CONFIG


class UserUsageResponse(UserResponse):
    """User kèm thông tin sử dụng (cho admin xem chi tiết)."""
    total_documents: int = 0
    last_active_at: Optional[datetime] = None


# ═════════════════════════════════════════════════════════════
# AUTH
# ═════════════════════════════════════════════════════════════
class VerifyOTP(BaseModel):
    email: EmailStr
    otp: str = Field(..., min_length=6, max_length=6)


class ResendOTP(BaseModel):
    email: EmailStr
    purpose: str = "ACTIVATE"  # ACTIVATE | RESET_PASSWORD


class ForgotPasswordRequest(BaseModel):
    email: EmailStr


class ResetPassword(BaseModel):
    email: EmailStr
    otp: str = Field(..., min_length=6, max_length=6)
    new_password: str = Field(..., min_length=6, max_length=100)


class PasswordChange(BaseModel):
    old_password: str
    new_password: str = Field(..., min_length=6, max_length=100)


class ProfileUpdate(BaseModel):
    full_name: Optional[str] = None
    email: Optional[EmailStr] = None


# ═════════════════════════════════════════════════════════════
# DOCUMENT
# ═════════════════════════════════════════════════════════════
class DocumentBase(BaseModel):
    title: str
    source_type: SourceType
    language: ProgrammingLanguage
    raw_code_context: str


class DocumentCreate(DocumentBase):
    ai_model: AIModelType = AIModelType.GROQ_LLAMA3
    # Cho phép bỏ qua cảnh báo syntax đã được người dùng xác nhận
    ignore_syntax_warning: bool = False


class DocumentUpdate(BaseModel):
    title: Optional[str] = None
    content_md: Optional[str] = None


class DocumentResponse(DocumentBase):
    doc_id: Optional[int] = None
    user_id: Optional[int] = None
    content_md: str
    ai_model: Optional[AIModelType] = None
    time_taken_ms: Optional[int] = None
    created_at: Optional[datetime] = None
    updated_at: Optional[datetime] = None

    model_config = _BASE_CONFIG


class DocumentVersionResponse(BaseModel):
    version_id: int
    version_number: int
    content_md: str
    created_at: datetime

    model_config = _BASE_CONFIG


# Trả về khi sinh tài liệu có cảnh báo syntax
class SyntaxWarning(BaseModel):
    has_error: bool
    message: str
    detail: Optional[str] = None


class GenerateDocResponse(BaseModel):
    document: DocumentResponse
    syntax_warning: Optional[SyntaxWarning] = None


# ═════════════════════════════════════════════════════════════
# AUDIT LOG
# ═════════════════════════════════════════════════════════════
class AuditLogResponse(BaseModel):
    log_id: int
    user_id: Optional[int] = None
    action: str
    details: Optional[str] = None
    created_at: datetime

    model_config = _BASE_CONFIG


# ═════════════════════════════════════════════════════════════
# ADMIN DASHBOARD
# ═════════════════════════════════════════════════════════════
class DashboardStats(BaseModel):
    total_users: int
    total_documents: int
    pending_requests: int   # thay thế total_admins theo yêu cầu I.9
    docs_today: int
    avg_time_ms: int
    active_users: int
    locked_users: int
    by_language: List[dict] = []
    by_model: List[dict] = []
    docs_over_time: List[dict] = []  # [{date, count}]


class BulkUserAction(BaseModel):
    """Khóa/mở khóa/xóa hàng loạt user."""
    user_ids: List[int]
    action: str  # LOCK | UNLOCK | DELETE


# ═════════════════════════════════════════════════════════════
# FEEDBACK
# ═════════════════════════════════════════════════════════════
class FeedbackCreate(BaseModel):
    rating: int = Field(..., ge=1, le=5)
    content: Optional[str] = None


class FeedbackResponse(BaseModel):
    id: int
    user_id: int
    rating: int
    content: Optional[str] = None
    created_at: datetime
    user_email: Optional[str] = None
    user_name: Optional[str] = None

    model_config = _BASE_CONFIG


# ═════════════════════════════════════════════════════════════
# AI MODEL CONFIG
# ═════════════════════════════════════════════════════════════
class AIModelConfigResponse(BaseModel):
    id: int
    model_type: AIModelType
    is_active: bool
    display_name: Optional[str] = None
    description: Optional[str] = None
    updated_at: datetime

    model_config = _BASE_CONFIG


class AIModelToggle(BaseModel):
    is_active: bool


# ═════════════════════════════════════════════════════════════
# EXPORT
# ═════════════════════════════════════════════════════════════
class ExportRequest(BaseModel):
    """Yêu cầu xuất tài liệu (cho guest hoặc preview, không dùng doc_id)."""
    title: str
    content_md: str
    format: str  # md | pdf | docx
