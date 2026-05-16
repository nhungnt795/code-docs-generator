"""
GraphRAGEngine

Thay đổi:
- process_query(user_code, model_type='GROQ_LLAMA3') — nhận model từ caller
- Mỗi request tạo LLM mới theo model_type (không cache toàn cục)
  để caller có thể chọn GROQ hay KAGGLE_FINETUNED
"""

import sys
import os

current_dir = os.path.dirname(os.path.abspath(__file__))
parent_dir  = os.path.dirname(current_dir)
sys.path.append(parent_dir)

from data.db_connector import PGVectorConnector
from model.embedder    import CodeBERTEmbedder
from model.base_llm    import LlamaDocstringGenerator


class GraphRAGEngine:
    def __init__(self):
        print("[*] Đang khởi tạo hệ thống GraphRAG...")
        self.db      = PGVectorConnector()
        self.embedder = CodeBERTEmbedder()

    def process_query(self, user_code: str, model_type: str = "GROQ_LLAMA3") -> str:
        """
        Sinh tài liệu cho user_code.
        model_type: 'GROQ_LLAMA3' | 'KAGGLE_FINETUNED'
        """
        print(
            f"\n[*] Sinh tài liệu (model={model_type}). "
            f"Chiều dài code: {len(user_code)} chars"
        )

        # 1. Nhúng code thành vector
        query_vector = self.embedder.get_embedding(user_code)

        # 2. Tìm mẫu tương tự trong Knowledge Base
        print("[*] Đang tìm kiếm trong Knowledge Base...")
        similar_docs = self.db.search_similar_code(query_vector, top_k=3)

        # 3. Xây dựng context
        context_str = ""
        for i, doc in enumerate(similar_docs):
            context_str += (
                f"\n[Mẫu tham khảo {i+1} - Độ tương đồng: {doc['score']:.4f}]\n"
                f"Source Code:\n{doc['code']}\n"
                f"AST / Phụ thuộc:\n{doc['graph']}\n"
                + "-" * 40
            )

        # 4. Tạo prompt
        prompt = f"""Bạn là một kỹ sư phần mềm chuyên viết tài liệu kỹ thuật bằng Tiếng Việt.
Nhiệm vụ: Dựa vào các mẫu code tương tự và thông tin đồ thị phụ thuộc (AST Graph) dưới đây, \
viết tài liệu kỹ thuật chuẩn Markdown bằng Tiếng Việt cho mã nguồn được cung cấp.

NGỮ CẢNH:
{context_str}

Viết tài liệu kỹ thuật cho đoạn code sau:
{user_code}

TRẢ LỜI:
"""

        # 5. Gọi LLM phù hợp với model_type
        print(f"[*] Đóng gói Context và gọi {model_type}...")
        llm = LlamaDocstringGenerator(model_type=model_type)
        return llm.generate(prompt)