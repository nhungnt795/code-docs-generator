import os

from fastapi import HTTPException
from tree_sitter import Parser

import tree_sitter_python
import tree_sitter_java
import tree_sitter_javascript
import tree_sitter_typescript
import tree_sitter_cpp
import tree_sitter_rust

from backend.models import ProgrammingLanguage

# ═════════════════════════════════════════════════════════════
# ALLOWED FILE EXTENSIONS
# ═════════════════════════════════════════════════════════════

ALLOWED_EXTENSIONS = {
    ProgrammingLanguage.PYTHON: [".py"],

    ProgrammingLanguage.JAVA: [".java"],

    ProgrammingLanguage.JAVASCRIPT: [
        ".js",
        ".jsx"
    ],

    ProgrammingLanguage.TYPESCRIPT: [
        ".ts",
        ".tsx"
    ],

    ProgrammingLanguage.CPP: [
        ".cpp",
        ".cc",
        ".cxx",
        ".h",
        ".hpp"
    ],

    ProgrammingLanguage.RUST: [".rs"],
}

# ═════════════════════════════════════════════════════════════
# TREE-SITTER LANGUAGES
# ═════════════════════════════════════════════════════════════

LANGUAGES_MAP = {
    ProgrammingLanguage.PYTHON:
        tree_sitter_python.language(),

    ProgrammingLanguage.JAVA:
        tree_sitter_java.language(),

    ProgrammingLanguage.JAVASCRIPT:
        tree_sitter_javascript.language(),

    ProgrammingLanguage.TYPESCRIPT:
        tree_sitter_typescript.language_typescript(),

    ProgrammingLanguage.CPP:
        tree_sitter_cpp.language(),

    ProgrammingLanguage.RUST:
        tree_sitter_rust.language(),
}

# ═════════════════════════════════════════════════════════════
# FILE EXTENSION VALIDATION
# ═════════════════════════════════════════════════════════════

def validate_file_extension(
    filename: str,
    expected_lang: ProgrammingLanguage
):
    """
    Kiểm tra đuôi file có hợp lệ với language không.
    """

    ext = os.path.splitext(filename)[1].lower()

    valid_extensions = ALLOWED_EXTENSIONS.get(
        expected_lang,
        []
    )

    if ext not in valid_extensions:

        allowed = ", ".join(valid_extensions)

        raise HTTPException(
            status_code=400,
            detail=(
                f"Đuôi file '{ext}' không hợp lệ. "
                f"Ngôn ngữ {expected_lang.value} "
                f"chỉ chấp nhận: {allowed}"
            )
        )

# ═════════════════════════════════════════════════════════════
# TREE-SITTER ERROR CHECKER
# ═════════════════════════════════════════════════════════════

def has_syntax_error(node) -> bool:
    """
    Duyệt toàn bộ AST để tìm node lỗi.
    """

    if node.type == "ERROR" or node.is_missing:
        return True

    for child in node.children:
        if has_syntax_error(child):
            return True

    return False

# ═════════════════════════════════════════════════════════════
# CODE SYNTAX VALIDATION
# ═════════════════════════════════════════════════════════════

def validate_code_syntax_with_treesitter(
    code: str,
    expected_lang: ProgrammingLanguage
):
    """
    Validate syntax bằng Tree-sitter.

    Có fail-safe để tránh crash server nếu:
    - Tree-sitter lệch ABI
    - parser lỗi
    - thư viện không tương thích
    """

    # ─────────────────────────────────────────────────────────
    # BASIC VALIDATION
    # ─────────────────────────────────────────────────────────
    if not code or len(code.strip()) < 10:
        raise HTTPException(
            status_code=400,
            detail="Mã nguồn quá ngắn hoặc rỗng."
        )

    ts_language = LANGUAGES_MAP.get(expected_lang)

    if not ts_language:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Ngôn ngữ "
                f"{expected_lang.value} "
                f"chưa được hỗ trợ parsing."
            )
        )

    # ─────────────────────────────────────────────────────────
    # TREE-SITTER PARSING
    # ─────────────────────────────────────────────────────────
    try:
        parser = Parser(ts_language)

        tree = parser.parse(
            bytes(code, "utf-8")
        )

        if tree is None:
            raise HTTPException(
                status_code=400,
                detail="Không thể phân tích mã nguồn."
            )

        if has_syntax_error(tree.root_node):
            raise HTTPException(
                status_code=400,
                detail=(
                    f"Phát hiện lỗi cú pháp "
                    f"{expected_lang.value}. "
                    f"Vui lòng kiểm tra lại mã nguồn."
                )
            )

    # ABI mismatch / parser mismatch
    except ValueError as e:

        print(
            "[WARNING] Tree-sitter ABI mismatch:",
            str(e)
        )

        print(
            f"[WARNING] Bỏ qua syntax validation cho "
            f"{expected_lang.value}"
        )

        # Fail-safe:
        # Không chặn request để tránh sập hệ thống
        return

    # Unknown parser errors
    except Exception as e:

        print(
            "[WARNING] Tree-sitter unexpected error:",
            str(e)
        )

        print(
            f"[WARNING] Bỏ qua syntax validation cho "
            f"{expected_lang.value}"
        )

        return