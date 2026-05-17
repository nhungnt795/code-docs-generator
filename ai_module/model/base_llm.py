"""
LlamaDocstringGenerator

Hỗ trợ 2 backend:
- GROQ_LLAMA3      : gọi Groq Cloud API (llama-3.1-8b-instant)
- KAGGLE_FINETUNED : gọi endpoint Kaggle riêng (KAGGLE_API_URL trong .env)

Xử lý lỗi:
- 429 Rate limit → chờ thời gian server gợi ý (retry_after) rồi thử lại (tối đa 2 lần)
- Lỗi kết nối / timeout → thông báo rõ ràng bằng Tiếng Việt
- Thiếu API key / URL → trả thông báo hướng dẫn cấu hình
"""

import os
import re
import time
import requests

# ─────────────────────────────────────────────────────────────────────────────
# Cấu hình từ .env
# ─────────────────────────────────────────────────────────────────────────────
_GROQ_API_KEY  = os.getenv("GROQ_API_KEY", "")
_GROQ_MODEL    = os.getenv("GROQ_MODEL", "llama-3.1-8b-instant")
_GROQ_URL      = "https://api.groq.com/openai/v1/chat/completions"

_KAGGLE_URL    = os.getenv("KAGGLE_API_URL", "")   # vd: https://ai.docgenvn.id.vn/generate_docstring
_KAGGLE_TOKEN  = os.getenv("KAGGLE_API_TOKEN", "")

_TIMEOUT       = 90   # giây
_MAX_RETRY     = 2    # số lần thử lại khi gặp 429


# ─────────────────────────────────────────────────────────────────────────────
# Helper: trích xuất retry_after từ message Groq
# ─────────────────────────────────────────────────────────────────────────────
def _parse_retry_after(body: str) -> float:
    """Tìm số giây trong 'Please try again in Xs' hoặc header Retry-After."""
    m = re.search(r"try again in\s+([\d.]+)s", body, re.IGNORECASE)
    if m:
        return min(float(m.group(1)) + 1.0, 30.0)   # tối đa 30s
    return 5.0   # mặc định nếu không tìm thấy


# ─────────────────────────────────────────────────────────────────────────────
# GROQ
# ─────────────────────────────────────────────────────────────────────────────
def _call_groq(prompt: str) -> str:
    if not _GROQ_API_KEY:
        return (
            "⚠️ Chưa cấu hình GROQ_API_KEY.\n\n"
            "Vui lòng thêm `GROQ_API_KEY=<key>` vào file `.env` và khởi động lại backend."
        )

    headers = {
        "Authorization": f"Bearer {_GROQ_API_KEY}",
        "Content-Type":  "application/json",
    }
    payload = {
        "model": _GROQ_MODEL,
        "messages": [
            {
                "role": "system",
                "content": (
                    "Bạn là chuyên gia viết tài liệu kỹ thuật bằng Tiếng Việt. "
                    "Chỉ trả về nội dung Markdown, không giải thích thêm."
                ),
            },
            {"role": "user", "content": prompt},
        ],
        "temperature": 0.3,
        "max_tokens":  1024,
        "top_p":       1,
    }

    last_error = ""
    for attempt in range(1, _MAX_RETRY + 1):
        try:
            resp = requests.post(
                _GROQ_URL, json=payload, headers=headers, timeout=_TIMEOUT
            )

            if resp.status_code == 200:
                result = resp.json()
                return result["choices"][0]["message"]["content"].strip()

            if resp.status_code == 429:
                wait = _parse_retry_after(resp.text)
                print(
                    f"[⚠] Groq rate limit (lần {attempt}/{_MAX_RETRY}). "
                    f"Chờ {wait:.1f}s rồi thử lại..."
                )
                time.sleep(wait)
                last_error = (
                    f"⏳ Mô hình Groq đang bận (giới hạn token/phút). "
                    f"Vui lòng thử lại sau vài giây, hoặc dùng mô hình khác."
                )
                continue   # retry

            # Lỗi khác (401, 500…)
            return (
                f"❌ Groq API lỗi {resp.status_code}.\n\n"
                f"Chi tiết: {resp.text[:300]}"
            )

        except requests.exceptions.Timeout:
            last_error = "⏱️ Groq không phản hồi trong {_TIMEOUT}s. Vui lòng thử lại."
            if attempt < _MAX_RETRY:
                time.sleep(3)
        except requests.exceptions.RequestException as e:
            return f"❌ Lỗi kết nối tới Groq: {e}"

    return last_error or "❌ Groq không phản hồi sau nhiều lần thử."


# ─────────────────────────────────────────────────────────────────────────────
# KAGGLE / FINETUNED
# ─────────────────────────────────────────────────────────────────────────────
def _call_kaggle(prompt: str) -> str:
    if not _KAGGLE_URL:
        return (
            "⚠️ Chưa cấu hình KAGGLE_API_URL.\n\n"
            "Vui lòng thêm `KAGGLE_API_URL=<url>` vào file `.env` và khởi động lại backend."
        )

    headers: dict = {"Content-Type": "application/json"}
    if _KAGGLE_TOKEN:
        headers["Authorization"] = f"Bearer {_KAGGLE_TOKEN}"

    payload = {"code": prompt}

    last_error = ""
    for attempt in range(1, _MAX_RETRY + 1):
        try:
            resp = requests.post(
                _KAGGLE_URL, json=payload, headers=headers, timeout=_TIMEOUT
            )

            if resp.status_code == 200:
                data = resp.json()
                # Thử nhiều key khả năng trả về
                for key in ("docstring", "content", "result", "output", "text"):
                    if key in data and data[key]:
                        return str(data[key]).strip()
                # Nếu không tìm được key, trả thô
                return str(data).strip()

            if resp.status_code == 429:
                wait = _parse_retry_after(resp.text)
                print(f"[⚠] Kaggle rate limit (lần {attempt}/{_MAX_RETRY}). Chờ {wait:.1f}s...")
                time.sleep(wait)
                last_error = (
                    "⏳ Mô hình Kaggle đang bận. Vui lòng thử lại sau vài giây."
                )
                continue

            return (
                f"❌ Kaggle API lỗi {resp.status_code}.\n\n"
                f"Chi tiết: {resp.text[:300]}"
            )

        except requests.exceptions.Timeout:
            last_error = f"⏱️ Kaggle endpoint không phản hồi trong {_TIMEOUT}s."
            if attempt < _MAX_RETRY:
                time.sleep(3)
        except requests.exceptions.RequestException as e:
            return f"❌ Lỗi kết nối tới Kaggle: {e}"

    return last_error or "❌ Kaggle endpoint không phản hồi sau nhiều lần thử."


# ─────────────────────────────────────────────────────────────────────────────
# PUBLIC CLASS
# ─────────────────────────────────────────────────────────────────────────────
class LlamaDocstringGenerator:
    """
    Giao diện thống nhất cho hai backend AI.
    model_type: 'GROQ_LLAMA3' | 'KAGGLE_FINETUNED'
    """

    def __init__(self, model_type: str = "GROQ_LLAMA3"):
        self.model_type = model_type.upper()
        _label = (
            f"Groq Cloud ({_GROQ_MODEL})"
            if self.model_type == "GROQ_LLAMA3"
            else f"Kaggle Finetuned ({_KAGGLE_URL or 'URL chưa đặt'})"
        )
        print(f"[*] Khởi tạo LLM engine: {_label}")

    def generate(self, prompt: str) -> str:
        if self.model_type == "KAGGLE_FINETUNED":
            return _call_kaggle(prompt)
        return _call_groq(prompt)