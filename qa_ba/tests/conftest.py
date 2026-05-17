import sys
import os
import pytest
import warnings

warnings.filterwarnings("ignore", category=DeprecationWarning)

try:
    from pydantic.warnings import PydanticDeprecatedSince20
    warnings.filterwarnings("ignore", category=PydanticDeprecatedSince20)
except ImportError:
    pass

from unittest.mock import MagicMock
from fastapi.testclient import TestClient
import sqlalchemy
from sqlalchemy import event
from sqlalchemy.pool import StaticPool
from sqlalchemy.orm import sessionmaker, close_all_sessions

original_table_new = sqlalchemy.Table.__new__

def patched_table_new(cls, *args, **kwargs):
    kwargs["extend_existing"] = True
    return original_table_new(cls, *args, **kwargs)

sqlalchemy.Table.__new__ = patched_table_new

current_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(current_dir, "../../../")) 
backend_path = os.path.join(project_root, "backend")
ai_module_path = os.path.join(project_root, "ai_module")

for path in [project_root, backend_path, ai_module_path]:
    if path not in sys.path:
        sys.path.insert(0, path)

def pytest_configure(config):
    try:
        import sqlalchemy.orm.decl_api as decl_api
        original_init = decl_api.registry.__init__
        def patched_init(self, *args, **kwargs):
            original_init(self, *args, **kwargs)
            self._class_registry = {}  
        decl_api.registry.__init__ = patched_init
    except Exception:
        pass

import ai_module.model.rag_engine as rag_engine_module

def dummy_rag_init(self, *args, **kwargs):
    print("\n[INFO] Đã kích hoạt chặn kết nối ngoại vi. Vận hành RAG ở chế độ giả lập an toàn.")
    self.db = MagicMock()
    self.embedder = MagicMock()
    self.embedder.get_embedding.return_value = [0.1] * 768
    self.db.search_similar_code.return_value = [
        {"score": 0.95, "code": "def add(a,b): pass", "graph": "GraphNode"}
    ]
    self.llm = MagicMock()
    self.llm.generate.return_value = "# Tài liệu cấu trúc giả lập thành công"

rag_engine_module.GraphRAGEngine.__init__ = dummy_rag_init

original_create_engine = sqlalchemy.create_engine

def intercept_create_engine(url, *args, **kwargs):
    print(f"\n[INFO] Thực hiện đánh chặn phiên kết nối cơ sở dữ liệu: {url} -> Chuyển hướng sang SQLite In-Memory.")
    safe_kwargs = {
        "connect_args": {"check_same_thread": False},
        "poolclass": StaticPool
    }
    return original_create_engine("sqlite:///:memory:", **safe_kwargs)

sqlalchemy.create_engine = intercept_create_engine

os.environ["DB_PORT"] = "5435"
os.environ["DB_HOST"] = "127.0.0.1"
os.environ["DB_NAME"] = "web_and_app_db"
os.environ["DB_USER"] = "airflow"
os.environ["DB_PASS"] = "airflow"

try:
    from main import app
    from database import get_db, Base
    import models
except ImportError as e:
    print(f"[ERROR] Quá trình nhập module thất bại. Chi tiết: {e}")
    raise



TEST_DB_URL = "sqlite:///:memory:"
test_engine = sqlalchemy.create_engine(TEST_DB_URL)

@event.listens_for(test_engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()

TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)

print("[PROCESS] Khởi tạo cấu trúc cơ sở dữ liệu ảo sạch cho bộ test suite...")
Base.metadata.create_all(bind=test_engine)

def override_get_db():
    db = TestingSessionLocal()
    try:
        yield db
    finally:
        db.close()

app.dependency_overrides[get_db] = override_get_db

@pytest.fixture(scope="module")
def api_client():
    return TestClient(app)

@pytest.fixture(scope="module")
def client():
    return TestClient(app)

@pytest.fixture
def mock_rag_engine():
    import ai_module.model.rag_engine as rag_engine_module
    from unittest.mock import MagicMock
    
    engine = rag_engine_module.GraphRAGEngine()
    
    if not hasattr(engine, "embedder") or engine.embedder is None:
        engine.embedder = MagicMock()
    if not hasattr(engine, "db") or engine.db is None:
        engine.db = MagicMock()
    if not hasattr(engine, "llm") or engine.llm is None:
        engine.llm = MagicMock()
        
    engine.embedder.get_embedding.reset_mock()
    engine.db.search_similar_code.reset_mock()
    engine.llm.generate.reset_mock()
        
    return engine

@pytest.fixture(scope="session", autouse=True)
def cleanup_database_connections_after_session():
    yield
    print("\n[QA PROCESS] Đang cưỡng chế giải phóng kết nối tồn dư để chống treo Terminal...")
    try:
        if 'test_engine' in globals():
            global test_engine
            test_engine.dispose()
            print("[SUCCESS] Đã dọn dẹp xong Engine Test SQLite.")
        close_all_sessions()
        print("[SUCCESS] Đã giải phóng hoàn toàn các phiên kết nối ngầm.")
    except Exception as e:
        print(f"[WARNING] Có lỗi xảy ra khi giải phóng tài nguyên: {e}")