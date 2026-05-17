"""
Code & file validators.

KHÁC bản cũ:
- check_syntax(...) TRẢ VỀ object (has_error, message, detail) thay vì raise.
  Lý do: frontend cần hiển thị dialog cảnh báo và cho user quyết định
  "vẫn xuất tài liệu" hay "không".
- validate_file_extension(...) vẫn raise vì lỗi này không cho qua được.
"""

import os
from dataclasses import dataclass
from typing import Optional

from fastapi import HTTPException

# Tree-sitter có thể fail import trong môi trường thiếu ABI tương thích.
# Bọc try/except để fail-safe.
try:
    from tree_sitter import Parser
    import tree_sitter_python
    import tree_sitter_java
    import tree_sitter_javascript
    import tree_sitter_typescript
    import tree_sitter_cpp
    import tree_sitter_rust

    TREE_SITTER_AVAILABLE = True
except Exception as e:
    print(f"[WARNING] Tree-sitter không khả dụng: {e}")
    TREE_SITTER_AVAILABLE = False

from models import ProgrammingLanguage


# ═════════════════════════════════════════════════════════════
# ALLOWED FILE EXTENSIONS
# ═════════════════════════════════════════════════════════════
ALLOWED_EXTENSIONS = {
    ProgrammingLanguage.PYTHON: [".py"],
    ProgrammingLanguage.JAVA: [".java"],
    ProgrammingLanguage.JAVASCRIPT: [".js", ".jsx"],
    ProgrammingLanguage.TYPESCRIPT: [".ts", ".tsx"],
    ProgrammingLanguage.CPP: [".cpp", ".cc", ".cxx", ".h", ".hpp"],
    ProgrammingLanguage.RUST: [".rs"],
}


# ═════════════════════════════════════════════════════════════
# MINIMUM LANGUAGE KEYWORDS
# ═════════════════════════════════════════════════════════════
_LANG_KEYWORDS = {
    ProgrammingLanguage.PYTHON: [
        "def ",
        "class ",
        "import ",
        "return ",
        "if ",
        "for ",
        "while ",
        "=",
        "(",
    ],
    ProgrammingLanguage.JAVASCRIPT: [
        "function",
        "const ",
        "let ",
        "var ",
        "=>",
        "return ",
        "import ",
        "(",
    ],
    ProgrammingLanguage.TYPESCRIPT: [
        "function",
        "const ",
        "let ",
        "interface ",
        "type ",
        "=>",
        "import ",
        "(",
    ],
    ProgrammingLanguage.JAVA: [
        "class ",
        "public ",
        "private ",
        "void ",
        "return ",
        "import ",
        "(",
    ],
    ProgrammingLanguage.CPP: [
        "#include",
        "int ",
        "void ",
        "return ",
        "class ",
        "(",
        "{",
    ],
    ProgrammingLanguage.RUST: [
        "fn ",
        "let ",
        "use ",
        "struct ",
        "impl ",
        "pub ",
        "(",
    ],
}


def _looks_like_code(code: str, lang: ProgrammingLanguage) -> bool:
    """
    Kiểm tra nội dung có giống mã nguồn hay không
    bằng cách tìm ít nhất 1 keyword cơ bản.
    """
    keywords = _LANG_KEYWORDS.get(lang, [])

    if not keywords:
        return True

    code_lower = code.lower()

    return any(kw.lower() in code_lower for kw in keywords)


# ═════════════════════════════════════════════════════════════
# TREE-SITTER LANGUAGE MAP
# ═════════════════════════════════════════════════════════════
def _get_languages_map():
    if not TREE_SITTER_AVAILABLE:
        return {}

    try:
        from tree_sitter import Language

        return {
            ProgrammingLanguage.PYTHON: Language(
                tree_sitter_python.language()
            ),
            ProgrammingLanguage.JAVA: Language(
                tree_sitter_java.language()
            ),
            ProgrammingLanguage.JAVASCRIPT: Language(
                tree_sitter_javascript.language()
            ),
            ProgrammingLanguage.TYPESCRIPT: Language(
                tree_sitter_typescript.language_typescript()
            ),
            ProgrammingLanguage.CPP: Language(
                tree_sitter_cpp.language()
            ),
            ProgrammingLanguage.RUST: Language(
                tree_sitter_rust.language()
            ),
        }

    except Exception as e:
        print(f"[WARNING] Tree-sitter language init failed: {e}")
        return {}


LANGUAGES_MAP = _get_languages_map()


# ═════════════════════════════════════════════════════════════
# RESULT TYPE
# ═════════════════════════════════════════════════════════════
@dataclass
class SyntaxCheckResult:
    has_error: bool
    message: str
    detail: Optional[str] = None


# ═════════════════════════════════════════════════════════════
# FILE EXTENSION
# ═════════════════════════════════════════════════════════════
def validate_file_extension(
    filename: str,
    expected_lang: ProgrammingLanguage,
):
    """
    Validate đuôi file.

    Lỗi extension vẫn raise vì không thể tiếp tục xử lý.
    """
    ext = os.path.splitext(filename)[1].lower()
    valid_extensions = ALLOWED_EXTENSIONS.get(expected_lang, [])

    if ext and ext not in valid_extensions:
        allowed = ", ".join(valid_extensions)

        raise HTTPException(
            status_code=400,
            detail=(
                f"Đuôi file '{ext}' không hợp lệ. "
                f"Ngôn ngữ {expected_lang.value} "
                f"chỉ chấp nhận: {allowed}"
            ),
        )


# ═════════════════════════════════════════════════════════════
# AST ERROR DETECTION
# ═════════════════════════════════════════════════════════════
def _find_first_error(node) -> Optional[tuple]:
    """
    Tìm node lỗi đầu tiên trong AST.

    Returns:
        (line, column) hoặc None
    """
    if node.type == "ERROR" or node.is_missing:
        start = node.start_point
        return (start[0] + 1, start[1] + 1)

    for child in node.children:
        result = _find_first_error(child)

        if result is not None:
            return result

    return None


# ═════════════════════════════════════════════════════════════
# CODE SYNTAX CHECK
# ═════════════════════════════════════════════════════════════
def check_syntax(
    code: str,
    expected_lang: ProgrammingLanguage,
) -> SyntaxCheckResult:
    """
    Kiểm tra syntax bằng Tree-sitter.

    TRẢ VỀ SyntaxCheckResult (không raise) để frontend có thể:
    - Hiện dialog cảnh báo
    - Cho phép user vẫn tiếp tục sinh tài liệu
    """

    # Code rỗng / quá ngắn vẫn raise
    if not code or len(code.strip()) < 5:
        raise HTTPException(
            status_code=400,
            detail="Mã nguồn quá ngắn hoặc rỗng.",
        )

    # Kiểm tra nội dung có giống code không
    if not _looks_like_code(code, expected_lang):
        return SyntaxCheckResult(
            has_error=True,
            message=(
                f"Nội dung không giống mã nguồn "
                f"{expected_lang.value}."
            ),
            detail=(
                "Bạn có chắc muốn tiếp tục "
                "sinh tài liệu không?"
            ),
        )

    # Nếu tree-sitter không khả dụng thì bỏ qua
    if not TREE_SITTER_AVAILABLE:
        return SyntaxCheckResult(
            has_error=False,
            message=(
                "OK (bỏ qua kiểm tra - "
                "tree-sitter không khả dụng)"
            ),
        )

    ts_language = LANGUAGES_MAP.get(expected_lang)

    if not ts_language:
        return SyntaxCheckResult(
            has_error=False,
            message=(
                f"OK (ngôn ngữ "
                f"{expected_lang.value} "
                f"chưa hỗ trợ check)"
            ),
        )

    try:
        parser = Parser()
        parser.language = ts_language

        tree = parser.parse(bytes(code, "utf-8"))

        if tree is None:
            return SyntaxCheckResult(
                has_error=True,
                message="Không thể phân tích mã nguồn.",
            )

        err_pos = _find_first_error(tree.root_node)

        if err_pos:
            line, col = err_pos

            return SyntaxCheckResult(
                has_error=True,
                message=(
                    f"Phát hiện lỗi cú pháp "
                    f"{expected_lang.value} "
                    f"tại dòng {line}, cột {col}."
                ),
                detail=(
                    "Bạn có chắc muốn tiếp tục "
                    "sinh tài liệu từ đoạn code "
                    "có lỗi này không?"
                ),
            )

        return SyntaxCheckResult(
            has_error=False,
            message="Cú pháp hợp lệ",
        )

    except Exception as e:
        # Fail-safe: không chặn pipeline khi parser lỗi nội bộ
        print(f"[WARNING] Tree-sitter error: {e}")

        return SyntaxCheckResult(
            has_error=False,
            message=(
                "OK (bỏ qua check do parser error: "
                f"{str(e)[:80]})"
            ),
        )


# ═════════════════════════════════════════════════════════════
# BACKWARD COMPATIBILITY
# ═════════════════════════════════════════════════════════════
def validate_code_syntax_with_treesitter(
    code,
    expected_lang,
):
    """
    DEPRECATED - dùng check_syntax thay thế.
    """

    result = check_syntax(code, expected_lang)

    if result.has_error:
        raise HTTPException(
            status_code=400,
            detail=result.message,
        )