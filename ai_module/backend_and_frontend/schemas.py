from pydantic import BaseModel, EmailStr
from typing import Optional, List, Generic, TypeVar
from datetime import datetime
from models import RoleType, SourceType, ProgrammingLanguage

T = TypeVar('T')

class ActionResult(BaseModel, Generic[T]):
    success: bool
    message: str
    data: Optional[T] = None

class UserBase(BaseModel):
    email: EmailStr
    full_name: Optional[str] = None

class UserCreate(UserBase):
    password: str

class UserResponse(UserBase):
    user_id: int
    role: RoleType
    created_at: datetime

    class Config:
        from_attributes = True

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

    class Config:
        from_attributes = True

class AuditLogResponse(BaseModel):
    log_id: int
    user_id: Optional[int] = None
    action: str
    details: Optional[str] = None
    created_at: datetime

    class Config:
        from_attributes = True