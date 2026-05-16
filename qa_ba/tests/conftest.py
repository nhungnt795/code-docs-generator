import sys
import os
import pytest
from unittest.mock import MagicMock
from fastapi.testclient import TestClient
import sqlalchemy
from sqlalchemy.pool import StaticPool
from sqlalchemy.orm import sessionmaker

# CẤU HÌNH ĐƯỜNG DẪN HỆ THỐNG (MODULE RESOLUTION)
current_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(current_dir, "../../../")) 
ai_module_path = os.path.join(project_root, "ai_module")
backend_path = os.path.join(project_root, "backend")

for path in [project_root, backend_path, ai_module_path]:
    if path not in sys.path:
        sys.path.insert(0, path)

import ai_module.model.rag_engine as rag_engine_module

# CẤU HÌNH ĐÁNH CHẶN KẾT NỐI HẠ TẦNG AI (LLM / KAGGLE MOCK LAYER)
# Phân đoạn mã nguồn giả lập bên dưới tạm thời được vô hiệu hóa để kết nối trực tiếp đến mô hình phân tích thực tế.
# Kích hoạt lại khối mã này trong trường hợp cần tối ưu hóa tốc độ kiểm thử cô lập.

# def dummy_rag_init(self, *args, **kwargs):
#     print("\n[INFO] Đã kích hoạt chặn kết nối ngoại vi. Vận hành RAG ở chế độ giả lập.")
#     self.db = MagicMock()
#     self.embedder = MagicMock()
#     self.embedder.get_embedding.return_value = [0.1] * 768
#     self.db.search_similar_code.return_value = [
#         {"score": 0.95, "code": "def add(a,b): pass", "graph": "GraphNode"}
#     ]
#     self.llm = MagicMock()
#     self.llm.generate.return_value = "# Documented Code\nThis function calculates the sum."

# rag_engine_module.GraphRAGEngine.__init__ = dummy_rag_init

# CƠ CHẾ ĐÁNH CHẶN KẾT NỐI CƠ SỞ DỮ LIỆU (DATABASE INTERCEPTION LAYER)
original_create_engine = sqlalchemy.create_engine

def intercept_create_engine(url, *args, **kwargs):
    """
    Đánh chặn toàn bộ các yêu cầu khởi tạo kết nối cơ sở dữ liệu Postgres thực tế,
    chuyển hướng luồng dữ liệu một cách an toàn về SQLite In-Memory cục bộ.
    """
    print(f"\n[INFO] Thực hiện đánh chặn phiên kết nối cơ sở dữ liệu: {url} -> Chuyển hướng sang SQLite In-Memory.")
    safe_kwargs = {
        "connect_args": {"check_same_thread": False},
        "poolclass": StaticPool
    }
    return original_create_engine("sqlite:///:memory:", **safe_kwargs)

sqlalchemy.create_engine = intercept_create_engine

# NẠP MÃ NGUỒN PHÂN HỆ BACKEND (DEVELOPER SOURCE CODES)
# Bơm cấu hình tham số môi trường hệ thống nhằm đảm bảo tính ổn định cho PGVectorConnector
os.environ["DB_PORT"] = "5435"
os.environ["DB_HOST"] = "127.0.0.1"
os.environ["DB_NAME"] = "web_and_app_db"
os.environ["DB_USER"] = "airflow"
os.environ["DB_PASS"] = "airflow"

try:
    from backend.main import app
    from backend.database import get_db
    from backend import models
except ImportError as e:
    print(f"[ERROR] Quá trình nhập module thất bại. Yêu cầu kiểm tra cấu trúc thư mục backend/. Chi tiết: {e}")
    raise

# ĐỊNH TUYẾN LẠI PHỤ THUỘC FASTAPI (FASTAPI DEPENDENCY OVERRIDES)
TEST_DB_URL = "sqlite:///:memory:"
test_engine = sqlalchemy.create_engine(TEST_DB_URL)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

models.Base.metadata.create_all(bind=test_engine)

def override_get_db():
    """Hàm ghi đè phiên kết nối cơ sở dữ liệu (Database Session Dependency Override) cho FastAPI client."""
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

# PHẦN TỬ ĐIỀU PHỐI MÔI TRƯỜNG (TEST FIXTURES)
@pytest.fixture(scope="module")
def api_client():
    """Khởi tạo và cung cấp TestClient phục vụ các kịch bản kiểm thử tích hợp API đầu cuối."""
    return TestClient(app)

# Khối quản lý trạng thái giả lập tạm thời được đóng lại do không tương thích cấu trúc GraphRAGEngine thực tế.
@pytest.fixture
def mock_rag_engine():
    import ai_module.model.rag_engine as rag_engine_module
    from unittest.mock import MagicMock
    engine = rag_engine_module.GraphRAGEngine()
    engine.embedder = MagicMock()
    engine.db = MagicMock()
    engine.llm = MagicMock()
    # Reset mock state
    engine.embedder.get_embedding.reset_mock()
    engine.db.search_similar_code.reset_mock()
    engine.llm.generate.reset_mock()
    return engine