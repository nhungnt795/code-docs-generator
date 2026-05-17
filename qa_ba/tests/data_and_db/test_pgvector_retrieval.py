import sys
import os
import pytest
import psycopg2

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../'))
BACKEND_DIR = os.path.join(PROJECT_ROOT, 'backend')
AI_MODULE_DIR = os.path.join(PROJECT_ROOT, 'ai_module')

for path in [PROJECT_ROOT, BACKEND_DIR, AI_MODULE_DIR]:
    if path not in sys.path:
        sys.path.insert(0, path)

from dotenv import load_dotenv
load_dotenv()

DB_NAME = os.getenv("DB_NAME", "web_and_app_db")
DB_USER = os.getenv("DB_USER", "airflow")
DB_PASS = os.getenv("DB_PASS", "airflow")
DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = os.getenv("DB_PORT", "5435")

@pytest.fixture(scope="session", autouse=True)
def setup_test_environment():
    print("\n[INFO] Khởi tạo môi trường PGVector...")
    try:
        conn = psycopg2.connect(dbname="airflow", user=DB_USER, password=DB_PASS, host=DB_HOST, port=DB_PORT)
        conn.autocommit = True
        with conn.cursor() as cursor:
            cursor.execute(f"SELECT 1 FROM pg_database WHERE datname='{DB_NAME}'")
            if not cursor.fetchone():
                cursor.execute(f"CREATE DATABASE {DB_NAME}")
        conn.close()
    except Exception as e:
        pytest.fail(f"Hạ tầng lỗi: {e}")
    yield

def test_tc_data_06_pgvector_retrieval_core():
    print("\n[INFO] Khởi chạy TC-DATA-06...")
    try:
        from ai_module.data.db_connector import PGVectorConnector
        from ai_module.model.embedder import CodeBERTEmbedder
        db = PGVectorConnector()
        embedder = CodeBERTEmbedder()
        test_query = "def connect_database():"
        query_vector = embedder.get_embedding(test_query)
        results = db.search_similar_code(query_vector, top_k=1)
        assert isinstance(results, list)
        db.conn.close()
    except Exception as e:
        pytest.fail(f"Lỗi liên kết thực tế: {str(e)}")