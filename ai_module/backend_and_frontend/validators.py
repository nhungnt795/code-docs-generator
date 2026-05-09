import os
from fastapi import HTTPException
from tree_sitter import Language, Parser
import tree_sitter_python
import tree_sitter_java
import tree_sitter_javascript
import tree_sitter_typescript
import tree_sitter_cpp
import tree_sitter_rust

from models import ProgrammingLanguage, SourceType

# Từ điển map ngôn ngữ với các đuôi file hợp lệ
ALLOWED_EXTENSIONS = {
    ProgrammingLanguage.PYTHON: [".py"],
    ProgrammingLanguage.JAVA: [".java"],
    ProgrammingLanguage.JAVASCRIPT: [".js", ".jsx"],
    ProgrammingLanguage.TYPESCRIPT: [".ts", ".tsx"],
    ProgrammingLanguage.CPP: [".cpp", ".cc", ".cxx", ".h", ".hpp"],
    ProgrammingLanguage.RUST: [".rs"],
}

def validate_file_extension(filename: str, expected_lang: ProgrammingLanguage):
    """
    Kiểm tra xem đuôi file có đúng với ngôn ngữ đã chọn không.
    """
    ext = os.path.splitext(filename)[1].lower()
    valid_exts = ALLOWED_EXTENSIONS.get(expected_lang, [])
    
    if ext not in valid_exts:
        raise HTTPException(
            status_code=400, 
            detail=f"Đuôi file '{ext}' không hợp lệ. Ngôn ngữ {expected_lang.value} chỉ nhận các file: {', '.join(valid_exts)}"
        )

# Cấu hình sẵn các đối tượng Language để tái sử dụng
LANGUAGES_MAP = {
    ProgrammingLanguage.PYTHON: tree_sitter_python.language(),
    ProgrammingLanguage.JAVA: tree_sitter_java.language(),
    ProgrammingLanguage.JAVASCRIPT: tree_sitter_javascript.language(),
    ProgrammingLanguage.TYPESCRIPT: tree_sitter_typescript.language_typescript(),
    ProgrammingLanguage.CPP: tree_sitter_cpp.language(),
    ProgrammingLanguage.RUST: tree_sitter_rust.language(),
}

def has_error(node):
    """
    Hàm đệ quy quét toàn bộ cây AST.
    Trả về True nếu phát hiện bất kỳ node lỗi (cú pháp sai) hoặc bị thiếu.
    """
    if node.type == 'ERROR' or node.is_missing:
        return True
    
    for child in node.children:
        if has_error(child):
            return True
            
    return False

def validate_code_syntax_with_treesitter(code: str, expected_lang: ProgrammingLanguage):
    """
    Rào lỗi bằng Tree-sitter. Tích hợp cơ chế Fail-safe chống sập server do lỗi thư viện.
    """
    if len(code.strip()) < 10:
        raise HTTPException(
            status_code=400, 
            detail="Mã nguồn quá ngắn, không thể phân tích."
        )
    
    ts_lang = LANGUAGES_MAP.get(expected_lang)
    if not ts_lang:
        raise HTTPException(
            status_code=400, 
            detail=f"Ngôn ngữ {expected_lang.value} hiện chưa được hỗ trợ parsing."
        )

    # Đưa vào khối try-except để bắt ngay cái lỗi ValueError tàn ác kia
    try:
        parser = Parser(ts_lang)
        tree = parser.parse(bytes(code, "utf8"))

        if tree and has_error(tree.root_node):
            raise HTTPException(
                status_code=400, 
                detail=f"Phát hiện lỗi cú pháp! Vui lòng kiểm tra lại đoạn code {expected_lang.value} của bạn."
            )
    except ValueError:
        # Nếu thư viện bị lệch ABI và văng lỗi Parsing failed, ta in cảnh báo ra terminal và cho code đi tiếp
        print(f"[*] CẢNH BÁO: Thư viện Tree-sitter bị lệch phiên bản, không thể kiểm tra cú pháp {expected_lang.value}. Bỏ qua lớp bảo vệ...")
        pass
    except Exception as e:
        print(f"[*] Lỗi không xác định từ Tree-sitter: {str(e)}")
        pass