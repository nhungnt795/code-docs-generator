import sys
import os

current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir = os.path.dirname(current_dir)
sys.path.append(parent_dir)

from model.rag_engine import GraphRAGEngine

import time
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import List, Optional

import models
import schemas
from database import engine, get_db
from validators import validate_code_syntax_with_treesitter, validate_file_extension

# Khởi tạo các bảng trong Database (nếu chưa có)
models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="DocGen GraphRAG API")

# Cấu hình CORS để Flutter có thể gọi API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Khởi tạo RAG Engine một lần duy nhất lúc bật server
rag_engine = GraphRAGEngine()

@app.get("/")
def root():
    return {"status": "ok", "message": "GraphRAG Backend is running"}

@app.post("/api/users", response_model=schemas.ActionResult[schemas.UserResponse])
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    db_user = db.query(models.User).filter(models.User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email đã tồn tại")
    
    new_user = models.User(
        email=user.email,
        password_hash=user.password, 
        full_name=user.full_name
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return schemas.ActionResult(
        success=True,
        message="Tạo tài khoản thành công",
        data=new_user
    )

@app.post("/api/docs/generate", response_model=schemas.ActionResult[schemas.DocumentResponse])
def generate_document(
    doc_req: schemas.DocumentCreate, 
    user_id: Optional[int] = None, 
    db: Session = Depends(get_db)
):
    # --- 1. RÀO LỖI ĐẦU VÀO KÉP (VALIDATION) ---
    # Nếu người dùng gửi file, kiểm tra đuôi file trước
    if doc_req.source_type == models.SourceType.FILE_UPLOAD:
        validate_file_extension(doc_req.title, doc_req.language)
        
    # Bắt buộc check cú pháp Tree-sitter cho ruột code
    validate_code_syntax_with_treesitter(doc_req.raw_code_context, doc_req.language)
    
    # --- 2. GỌI GRAPHRAG ENGINE ---
    start_time = time.time()
    try:
        markdown_content = rag_engine.process_query(doc_req.raw_code_context)
        if isinstance(markdown_content, dict):
            markdown_content = markdown_content.get("docstring", str(markdown_content))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lỗi khi xử lý RAG: {str(e)}")
    
    time_taken = int((time.time() - start_time) * 1000)

    # --- 3. PHÂN NHÁNH LUỒNG XỬ LÝ (GUEST vs USER) ---
    
    # LUỒNG GUEST (Không lưu Database)
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

    # LUỒNG USER (Lưu vào Database & Ghi log)
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")

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

@app.get("/api/docs/history/{user_id}", response_model=schemas.ActionResult[List[schemas.DocumentResponse]])
def get_user_history(user_id: int, db: Session = Depends(get_db)):
    # Trả về danh sách tài liệu sắp xếp theo ngày sinh mới nhất
    docs = db.query(models.Document).filter(models.Document.user_id == user_id).order_by(models.Document.created_at.desc()).all()
    return schemas.ActionResult(
        success=True,
        message="Lấy lịch sử thành công",
        data=docs
    )

# --- CÁC API DÀNH CHO ADMIN ---

@app.post("/api/admin/promote/{user_id}", response_model=schemas.ActionResult[schemas.UserResponse])
def promote_to_admin(user_id: int, db: Session = Depends(get_db)):
    """API nội bộ để 'nâng cấp' một user bình thường lên làm ADMIN"""
    user = db.query(models.User).filter(models.User.user_id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="Không tìm thấy người dùng")
    
    user.role = models.RoleType.ADMIN
    db.commit()
    db.refresh(user)
    
    return schemas.ActionResult(
        success=True,
        message=f"Đã cấp quyền Admin cho user {user.email}",
        data=user
    )

@app.get("/api/admin/users", response_model=schemas.ActionResult[List[schemas.UserResponse]])
def get_all_users(admin_id: int, db: Session = Depends(get_db)):
    """Lấy danh sách tất cả người dùng trên hệ thống"""
    # 1. Kiểm tra xem người gọi có phải là Admin không
    admin = db.query(models.User).filter(models.User.user_id == admin_id, models.User.role == models.RoleType.ADMIN).first()
    if not admin:
        raise HTTPException(status_code=403, detail="Bạn không có quyền truy cập chức năng này")
    
    # 2. Lấy toàn bộ user
    users = db.query(models.User).order_by(models.User.created_at.desc()).all()
    return schemas.ActionResult(
        success=True,
        message="Lấy danh sách người dùng thành công",
        data=users
    )

@app.get("/api/admin/logs", response_model=schemas.ActionResult[List[schemas.AuditLogResponse]])
def get_system_logs(admin_id: int, db: Session = Depends(get_db)):
    """Xem nhật ký hoạt động (Audit Logs) của toàn hệ thống"""
    # 1. Kiểm tra quyền Admin
    admin = db.query(models.User).filter(models.User.user_id == admin_id, models.User.role == models.RoleType.ADMIN).first()
    if not admin:
        raise HTTPException(status_code=403, detail="Bạn không có quyền truy cập chức năng này")
    
    # 2. Lấy log của toàn bộ hệ thống
    logs = db.query(models.AuditLog).order_by(models.AuditLog.created_at.desc()).all()
    return schemas.ActionResult(
        success=True,
        message="Lấy nhật ký hệ thống thành công",
        data=logs
    )