"""
Document router.

- POST /api/docs/generate : sinh tài liệu (kèm cảnh báo syntax, không tự ý raise)
- POST /api/docs/generate/guest : sinh cho khách (không lưu DB)
- GET  /api/docs/history/{user_id} : lịch sử
- GET  /api/docs/{doc_id} : chi tiết 1 doc (kèm versions)
- PUT  /api/docs/{doc_id} : cập nhật (tạo version mới)
- DELETE /api/docs/{doc_id}
- POST /api/docs/{doc_id}/export?format=md|pdf|docx
- POST /api/docs/export : xuất từ nội dung tự do (cho guest)
"""

import time
from typing import List, Optional
from urllib.parse import quote

from fastapi import APIRouter, Depends, HTTPException, Query
from fastapi.responses import Response, StreamingResponse
from sqlalchemy.orm import Session

import io

import models
import schemas
from auth_helpers import require_user, write_log
from database import get_db
from export_service import export_document
from validators import check_syntax, validate_file_extension

router = APIRouter(prefix="/api/docs", tags=["documents"])


# ─────────────────────────────────────────────────────────────
# AI ENGINE (lazy)
# ─────────────────────────────────────────────────────────────
_rag_engine = None


def get_rag_engine():
    global _rag_engine
    if _rag_engine is None:
        try:
            from ai_module.model.rag_engine import GraphRAGEngine
            _rag_engine = GraphRAGEngine()
        except Exception as e:
            print(f"[WARNING] Không thể load RAG engine: {e}")
            # Fallback engine để app vẫn chạy
            _rag_engine = _FallbackEngine()
    return _rag_engine


class _FallbackEngine:
    """Engine giả lập khi RAG engine thật chưa sẵn sàng."""

    def process_query(
        self,
        code: str,
        model_type: str = "GROQ_LLAMA3",
    ) -> str:
        return (
            "# Tài liệu được sinh tự động\n\n"
            "## Tổng quan\n\n"
            "_Fallback engine — RAG engine chưa khả dụng. "
            "Vui lòng kiểm tra cấu hình ai_module._\n\n"
            f"**Model:** `{model_type}`\n\n"
            "## Mã nguồn\n\n```\n"
            + code[:1000]
            + "\n```\n"
        )


# ─────────────────────────────────────────────────────────────
# CHECK AI MODEL CÓ ĐANG ACTIVE KHÔNG
# ─────────────────────────────────────────────────────────────
def _check_model_active(db: Session, model_type: models.AIModelType):
    cfg = (
        db.query(models.AIModelConfig)
        .filter(models.AIModelConfig.model_type == model_type)
        .first()
    )

    if cfg and not cfg.is_active:
        raise HTTPException(
            status_code=403,
            detail=(
                "Mô hình hiện đang ngoài thời gian sử dụng, "
                "hãy liên hệ chúng tôi để có thể dùng."
            ),
        )


# ═════════════════════════════════════════════════════════════
# GENERATE (user mode)
# ═════════════════════════════════════════════════════════════
@router.post(
    "/generate",
    response_model=schemas.ActionResult[schemas.GenerateDocResponse],
)
def generate_document(
    doc_req: schemas.DocumentCreate,
    user_id: int = Query(...),
    db: Session = Depends(get_db),
):
    user = require_user(db, user_id)

    # 1) Validate extension nếu là file upload
    if doc_req.source_type == models.SourceType.FILE_UPLOAD:
        validate_file_extension(doc_req.title, doc_req.language)

    # 2) Check syntax (không raise, chỉ cảnh báo)
    syntax_result = check_syntax(doc_req.raw_code_context, doc_req.language)

    # Nếu có lỗi syntax mà user CHƯA xác nhận bỏ qua → trả lại 422 với chi tiết
    if syntax_result.has_error and not doc_req.ignore_syntax_warning:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "SYNTAX_WARNING",
                "message": syntax_result.message,
                "hint": syntax_result.detail,
            },
        )

    # 3) Check AI model active
    _check_model_active(db, doc_req.ai_model)

    # 4) Process
    start = time.time()

    try:
        engine = get_rag_engine()

        content_md = engine.process_query(
            doc_req.raw_code_context,
            model_type=(
                doc_req.ai_model.value
                if doc_req.ai_model
                else "GROQ_LLAMA3"
            ),
        )

        if isinstance(content_md, dict):
            content_md = content_md.get("docstring", str(content_md))

        # Nếu LLM trả về thông báo lỗi thay vì tài liệu
        if isinstance(content_md, str) and content_md.startswith(
            ("❌", "⚠️", "⏳")
        ):
            raise HTTPException(status_code=503, detail=content_md)

    except HTTPException:
        raise

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Lỗi RAG engine: {e}",
        )

    time_taken = int((time.time() - start) * 1000)

    # 5) Lưu DB
    new_doc = models.Document(
        user_id=user_id,
        title=doc_req.title,
        source_type=doc_req.source_type,
        language=doc_req.language,
        raw_code_context=doc_req.raw_code_context,
        content_md=content_md,
        ai_model=doc_req.ai_model,
        time_taken_ms=time_taken,
    )

    db.add(new_doc)
    db.commit()
    db.refresh(new_doc)

    # Version 1 = bản gốc
    v1 = models.DocumentVersion(
        doc_id=new_doc.doc_id,
        version_number=1,
        content_md=content_md,
    )

    db.add(v1)

    write_log(
        db,
        user_id,
        "GENERATE_DOC",
        (
            f"Sinh tài liệu doc_id={new_doc.doc_id} "
            f"lang={doc_req.language.value} "
            f"model={doc_req.ai_model.value}"
        ),
    )

    db.commit()

    warning = None

    if syntax_result.has_error:
        warning = schemas.SyntaxWarning(
            has_error=True,
            message=syntax_result.message,
            detail=syntax_result.detail,
        )

    return schemas.ActionResult(
        success=True,
        message="Sinh tài liệu thành công",
        data=schemas.GenerateDocResponse(
            document=schemas.DocumentResponse.model_validate(new_doc),
            syntax_warning=warning,
        ),
    )


# ═════════════════════════════════════════════════════════════
# GENERATE (guest)
# ═════════════════════════════════════════════════════════════
@router.post(
    "/generate/guest",
    response_model=schemas.ActionResult[schemas.GenerateDocResponse],
)
def generate_document_guest(
    doc_req: schemas.DocumentCreate,
    db: Session = Depends(get_db),
):
    if doc_req.source_type == models.SourceType.FILE_UPLOAD:
        validate_file_extension(doc_req.title, doc_req.language)

    syntax_result = check_syntax(doc_req.raw_code_context, doc_req.language)

    if syntax_result.has_error and not doc_req.ignore_syntax_warning:
        raise HTTPException(
            status_code=422,
            detail={
                "code": "SYNTAX_WARNING",
                "message": syntax_result.message,
                "hint": syntax_result.detail,
            },
        )

    _check_model_active(db, doc_req.ai_model)

    start = time.time()

    try:
        engine = get_rag_engine()

        content_md = engine.process_query(
            doc_req.raw_code_context,
            model_type=(
                doc_req.ai_model.value
                if doc_req.ai_model
                else "GROQ_LLAMA3"
            ),
        )

        if isinstance(content_md, dict):
            content_md = content_md.get("docstring", str(content_md))

        # Nếu LLM trả về thông báo lỗi thay vì tài liệu
        if isinstance(content_md, str) and content_md.startswith(
            ("❌", "⚠️", "⏳")
        ):
            raise HTTPException(status_code=503, detail=content_md)

    except HTTPException:
        raise

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Lỗi RAG engine: {e}",
        )

    time_taken = int((time.time() - start) * 1000)

    guest_doc = schemas.DocumentResponse(
        title=doc_req.title,
        source_type=doc_req.source_type,
        language=doc_req.language,
        raw_code_context=doc_req.raw_code_context,
        content_md=content_md,
        ai_model=doc_req.ai_model,
        time_taken_ms=time_taken,
    )

    warning = None

    if syntax_result.has_error:
        warning = schemas.SyntaxWarning(
            has_error=True,
            message=syntax_result.message,
            detail=syntax_result.detail,
        )

    return schemas.ActionResult(
        success=True,
        message="Sinh tài liệu thành công (chế độ Khách)",
        data=schemas.GenerateDocResponse(
            document=guest_doc,
            syntax_warning=warning,
        ),
    )


# ═════════════════════════════════════════════════════════════
# HISTORY
# ═════════════════════════════════════════════════════════════
@router.get(
    "/history/{user_id}",
    response_model=schemas.ActionResult[List[schemas.DocumentResponse]],
)
def get_user_history(user_id: int, db: Session = Depends(get_db)):
    require_user(db, user_id)

    docs = (
        db.query(models.Document)
        .filter(models.Document.user_id == user_id)
        .order_by(models.Document.created_at.desc())
        .all()
    )

    return schemas.ActionResult(
        success=True,
        message="Lấy lịch sử thành công",
        data=docs,
    )


# ═════════════════════════════════════════════════════════════
# GET DOC DETAIL (kèm versions)
# ═════════════════════════════════════════════════════════════
@router.get(
    "/{doc_id}",
    response_model=schemas.ActionResult[dict],
)
def get_document_detail(
    doc_id: int,
    user_id: int = Query(...),
    db: Session = Depends(get_db),
):
    user = require_user(db, user_id)

    doc = (
        db.query(models.Document)
        .filter(models.Document.doc_id == doc_id)
        .first()
    )

    if not doc:
        raise HTTPException(status_code=404, detail="Không tìm thấy tài liệu")

    # Phân quyền: user chỉ xem được doc của mình, admin xem hết
    if doc.user_id != user_id and user.role != models.RoleType.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Bạn không có quyền xem tài liệu này",
        )

    versions = (
        db.query(models.DocumentVersion)
        .filter(models.DocumentVersion.doc_id == doc_id)
        .order_by(models.DocumentVersion.version_number.desc())
        .all()
    )

    return schemas.ActionResult(
        success=True,
        message="OK",
        data={
            "document": (
                schemas.DocumentResponse
                .model_validate(doc)
                .model_dump(mode="json")
            ),
            "versions": [
                (
                    schemas.DocumentVersionResponse
                    .model_validate(v)
                    .model_dump(mode="json")
                )
                for v in versions
            ],
        },
    )


# ═════════════════════════════════════════════════════════════
# UPDATE DOC → tạo version mới, content_md đổi thành bản mới nhất
# ═════════════════════════════════════════════════════════════
@router.put(
    "/{doc_id}",
    response_model=schemas.ActionResult[schemas.DocumentResponse],
)
def update_document(
    doc_id: int,
    data: schemas.DocumentUpdate,
    user_id: int = Query(...),
    db: Session = Depends(get_db),
):
    user = require_user(db, user_id)

    doc = (
        db.query(models.Document)
        .filter(models.Document.doc_id == doc_id)
        .first()
    )

    if not doc:
        raise HTTPException(status_code=404, detail="Không tìm thấy tài liệu")

    if doc.user_id != user_id and user.role != models.RoleType.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Bạn không có quyền sửa tài liệu này",
        )

    if data.title is not None and data.title.strip():
        doc.title = data.title.strip()

    if data.content_md is not None and data.content_md != doc.content_md:
        # Tạo version mới
        last_v = (
            db.query(models.DocumentVersion)
            .filter(models.DocumentVersion.doc_id == doc_id)
            .order_by(models.DocumentVersion.version_number.desc())
            .first()
        )

        next_num = (last_v.version_number + 1) if last_v else 1

        new_v = models.DocumentVersion(
            doc_id=doc_id,
            version_number=next_num,
            content_md=data.content_md,
        )

        db.add(new_v)

        # FIX yêu cầu I.5: lưu đúng bản đã sửa
        doc.content_md = data.content_md

    # FIX yêu cầu I.7: cập nhật timestamp đúng
    doc.updated_at = models.utc_now()

    db.commit()
    db.refresh(doc)

    write_log(
        db,
        user_id,
        "UPDATE_DOC",
        f"Sửa tài liệu doc_id={doc_id}",
    )

    db.commit()

    return schemas.ActionResult(
        success=True,
        message="Cập nhật tài liệu thành công",
        data=doc,
    )


# ═════════════════════════════════════════════════════════════
# DELETE DOC
# ═════════════════════════════════════════════════════════════
@router.delete("/{doc_id}", response_model=schemas.ActionResult[None])
def delete_document(
    doc_id: int,
    user_id: int = Query(...),
    db: Session = Depends(get_db),
):
    user = require_user(db, user_id)

    doc = (
        db.query(models.Document)
        .filter(models.Document.doc_id == doc_id)
        .first()
    )

    if not doc:
        raise HTTPException(status_code=404, detail="Không tìm thấy tài liệu")

    if doc.user_id != user_id and user.role != models.RoleType.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Bạn không có quyền xóa tài liệu này",
        )

    db.delete(doc)

    write_log(
        db,
        user_id,
        "DELETE_DOC",
        f"Xóa tài liệu doc_id={doc_id}",
    )

    db.commit()

    return schemas.ActionResult(
        success=True,
        message="Xóa tài liệu thành công",
        data=None,
    )


# ═════════════════════════════════════════════════════════════
# EXPORT (doc đã lưu)
# ═════════════════════════════════════════════════════════════
@router.get("/{doc_id}/export")
def export_saved_document(
    doc_id: int,
    format: str = Query(..., description="md | pdf | docx"),
    user_id: int = Query(...),
    db: Session = Depends(get_db),
):
    user = require_user(db, user_id)

    doc = (
        db.query(models.Document)
        .filter(models.Document.doc_id == doc_id)
        .first()
    )

    if not doc:
        raise HTTPException(status_code=404, detail="Không tìm thấy tài liệu")

    if doc.user_id != user_id and user.role != models.RoleType.ADMIN:
        raise HTTPException(
            status_code=403,
            detail="Bạn không có quyền xuất tài liệu này",
        )

    try:
        data, mime, filename = export_document(
            doc.title,
            doc.content_md,
            format,
        )

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Lỗi xuất file: {e}",
        )

    write_log(
        db,
        user_id,
        "EXPORT_DOC",
        f"Xuất doc_id={doc_id} format={format}",
    )

    db.commit()

    safe_filename = quote(filename)

    return StreamingResponse(
        io.BytesIO(data),
        media_type=mime,
        headers={
            "Content-Disposition": (
                f"attachment; filename*=UTF-8''{safe_filename}"
            )
        },
    )


# ═════════════════════════════════════════════════════════════
# EXPORT ARBITRARY (cho guest / preview)
# ═════════════════════════════════════════════════════════════
@router.post("/export")
def export_arbitrary(data: schemas.ExportRequest):
    try:
        out, mime, filename = export_document(
            data.title,
            data.content_md,
            data.format,
        )

    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Lỗi xuất file: {e}",
        )

    safe_filename = quote(filename)

    return StreamingResponse(
        io.BytesIO(out),
        media_type=mime,
        headers={
            "Content-Disposition": (
                f"attachment; filename*=UTF-8''{safe_filename}"
            )
        },
    )


# ═════════════════════════════════════════════════════════════
# CHECK SYNTAX (cho dialog cảnh báo từ frontend)
# ═════════════════════════════════════════════════════════════
@router.post(
    "/check-syntax",
    response_model=schemas.ActionResult[schemas.SyntaxWarning],
)
def check_syntax_endpoint(data: schemas.DocumentBase):
    result = check_syntax(data.raw_code_context, data.language)

    return schemas.ActionResult(
        success=True,
        message="OK",
        data=schemas.SyntaxWarning(
            has_error=result.has_error,
            message=result.message,
            detail=result.detail,
        ),
    )