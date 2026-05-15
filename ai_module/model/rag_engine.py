import sys
import os

current_dir = os.path.dirname(os.path.abspath(__file__)) # Thư mục model/
parent_dir = os.path.dirname(current_dir) # Lùi ra thư mục ai_module/
sys.path.append(parent_dir)


from data.db_connector import PGVectorConnector
from model.embedder import CodeBERTEmbedder
from model.base_llm import LlamaDocstringGenerator

class GraphRAGEngine:
        def __init__(self):
                print("[*] Đang khởi tạo hệ thống GraphRAG...")
                self.db = PGVectorConnector()
                self.embedder = CodeBERTEmbedder()
                
                # LlamaDocstringGenerator bây giờ chỉ là 1 Client nhẹ, 
                # tự động gọi API lên Kaggle mà không làm nặng máy local.
                self.llm = LlamaDocstringGenerator()

        def process_query(self, user_code):
                print(f"\n[*] Nhận yêu cầu sinh Docstring. Chiều dài code: {len(user_code)} chars")
                
                # 1. Nhúng đoạn code cần viết docs thành Vector
                query_vector = self.embedder.get_embedding(user_code)

                # 2. Rút trích 3 mẫu code + AST Graph giống nhất từ Postgres (Docker)
                print("[*] Đang lục lọi Knowledge Base...")
                similar_docs = self.db.search_similar_code(query_vector, top_k=3)

                # 3. Chuẩn bị Context
                context_str = ""
                for i, doc in enumerate(similar_docs):
                context_str += f"\n[Mẫu tham khảo {i+1} - Độ tương đồng: {doc['score']:.4f}]\n"
                context_str += f"Source Code:\n{doc['code']}\n"
                context_str += f"AST / Phụ thuộc:\n{doc['graph']}\n"
                context_str += "-"*40

                # 4. Ép Prompt cực gắt cho Llama 3.1
                # (Đã kéo khối lệnh này ra ngoài vòng lặp for và căn lề trái chuẩn)
                prompt = f"""Bạn là một kỹ sư phần mềm chuyên viết tài liệu kỹ thuật bằng Tiếng Việt.
        Nhiệm vụ: Dựa vào các mẫu code tương tự và thông tin đồ thị phụ thuộc (AST Graph) dưới đây, viết tài liệu kỹ thuật chuẩn Markdown bằng Tiếng Việt cho mã nguồn được cung cấp.

NGỮ CẢNH:
{context_str}

Viết tài liệu kỹ thuật cho đoạn code sau:
{user_code}

TRẢ LỜI:
"""
        # 5. Đẩy cho Llama sinh chữ
        print("[*] Đóng gói Context và gửi API lên Kaggle/Groq...")
        
        # Hàm generate sẽ bắn payload {"code": prompt} lên Kaggle/Groq
        # và nhận về JSON chứa key "docstring"
        return self.llm.generate(prompt)