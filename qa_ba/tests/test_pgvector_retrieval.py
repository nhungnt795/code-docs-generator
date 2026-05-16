import sys
import os
import pytest
import psycopg2

# CẤU HÌNH ĐƯỜNG DẪN HỆ THỐNG (MODULE RESOLUTION)
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../'))
BACKEND_DIR = os.path.join(PROJECT_ROOT, 'backend')
AI_MODULE_DIR = os.path.join(PROJECT_ROOT, 'ai_module')

for path in [PROJECT_ROOT, BACKEND_DIR, AI_MODULE_DIR]:
    if path not in sys.path:
        sys.path.insert(0, path)

from dotenv import load_dotenv
load_dotenv()

# Khởi tạo tham số cấu hình kết nối cơ sở dữ liệu dựa trên tệp cấu hình môi trường (.env)
DB_NAME = os.getenv("DB_NAME", "web_and_app_db")
DB_USER = os.getenv("DB_USER", "airflow")
DB_PASS = os.getenv("DB_PASS", "airflow")
DB_HOST = os.getenv("DB_HOST", "127.0.0.1")
DB_PORT = os.getenv("DB_PORT", "5435")

os.environ["DB_NAME"] = DB_NAME

# TỰ ĐỘNG HÓA HẠ TRẦN DỮ LIỆU (FIXTURE SETUP & TEARDOWN)
@pytest.fixture(scope="session", autouse=True)
def setup_test_environment():
    print("\n[INFO] Khởi tạo môi trường kiểm thử cơ sở dữ liệu quan hệ...")
    
    # Bước A: Khởi tạo phiên kết nối thông qua DB mặc định nhằm kiểm tra và tự động tạo cơ sở dữ liệu mục tiêu
    try:
        conn = psycopg2.connect(
            dbname="airflow", user=DB_USER, password=DB_PASS, host=DB_HOST, port=DB_PORT
        )
        conn.autocommit = True
        with conn.cursor() as cursor:
            cursor.execute(f"SELECT 1 FROM pg_database WHERE datname='{DB_NAME}'")
            exists = cursor.fetchone()
            if not exists:
                print(f"[PROCESS] Cơ sở dữ liệu '{DB_NAME}' không tồn tại. Tiến hành khởi tạo phân hệ lưu trữ mới...")
                cursor.execute(f"CREATE DATABASE {DB_NAME}")
            else:
                print(f"[INFO] Ghi nhận cơ sở dữ liệu '{DB_NAME}' đã vận hành sẵn sàng trên Docker Container.")
        conn.close()
    except Exception as e:
        pytest.fail(f"[CRITICAL] Thiết lập hạ tầng cơ sở dữ liệu '{DB_NAME}' thất bại: {e}")

    # Bước B: Thiết lập liên kết trực tiếp tới cơ sở dữ liệu mục tiêu
    try:
        conn = psycopg2.connect(
            dbname=DB_NAME, user=DB_USER, password=DB_PASS, host=DB_HOST, port=DB_PORT
        )
        conn.autocommit = True
        with conn.cursor() as cursor:
            print("[PROCESS] Đang giải phóng các kết nối rác để tránh Deadlock...")
            # Dọn dẹp mọi session đang ngâm kết nối từ các file test trước đó
            cursor.execute(f"""
                SELECT pg_terminate_backend(pid) 
                FROM pg_stat_activity 
                WHERE datname='{DB_NAME}' AND pid <> pg_backend_pid();
            """)
            
            print("[PROCESS] Khởi tạo phần mở rộng không gian vector (PGVector Extension)...")
            cursor.execute("CREATE EXTENSION IF NOT EXISTS vector;")
            
            print("[PROCESS] Đồng bộ cấu hình lược đồ bảng dữ liệu 'code_base'...")
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS code_base (
                    id SERIAL PRIMARY KEY,
                    code_snippet TEXT NOT NULL,
                    ast_graph TEXT,
                    embedding vector(768)
                );
            """)
            
            # Giải phóng dữ liệu cũ nhằm đảm bảo tính độc lập
            cursor.execute("TRUNCATE TABLE code_base;")
            
            # Thiết lập định dạng vector giả lập
            print("[PROCESS] Nạp dữ liệu giả lập (Mock Vector Data) phục vụ quy trình thực nghiệm...")
            mock_vector = "[" + ",".join(["0.01"] * 768) + "]"
            cursor.execute(
                "INSERT INTO code_base (code_snippet, ast_graph, embedding) VALUES (%s, %s, %s::vector)",
                (
                    "def connect_database():\n    return psycopg2.connect()", 
                    "{'type': 'FunctionDef', 'name': 'connect_database'}", 
                    mock_vector
                )
            )
        conn.close()
        print("[SUCCESS] Hoàn tất thiết lập môi trường dữ liệu thực nghiệm mẫu.")
    except Exception as e:
        pytest.fail(f"[CRITICAL] Khởi tạo lược đồ bảng dữ liệu kiểm thử lỗi: {e}")

    yield  # Chuyển quyền thực thi sang các kịch bản kiểm thử tích hợp

    # Bước C: Thực hiện thu hồi tài nguyên và giải phóng dữ liệu (Teardown Phase)
    print("\n[INFO] Khởi chạy quy trình dọn dẹp hạ tầng dữ liệu kiểm thử (Teardown)...")
    try:
        conn = psycopg2.connect(
            dbname=DB_NAME, user=DB_USER, password=DB_PASS, host=DB_HOST, port=DB_PORT
        )
        conn.autocommit = True
        with conn.cursor() as cursor:
            cursor.execute("TRUNCATE TABLE code_base;")
        conn.close()
        print("[SUCCESS] Đã làm sạch và hoàn trả môi trường lưu trữ an toàn.")
    except Exception as e:
        print(f"[WARNING] Phát sinh cảnh báo ngoài dự kiến trong quá trình thu hồi tài nguyên: {e}")


# KỊCH BẢN KIỂM THỬ TRUY XUẤT LÕI (INTEGRATION TESTING)
def test_tc_data_06_pgvector_retrieval_core():
    """TC-DATA-06: Kiểm thử tích hợp luồng truy xuất không gian vector PGVector."""
    print("\n[INFO] Khởi chạy TC-DATA-06...")
    import os
    
    # KỸ THUẬT ÉP MÔI TRƯỜNG: Đảm bảo module phân tích bốc đúng địa chỉ mạng và thông tin xác thực của Docker Container
    os.environ["DB_PORT"] = "5435"
    os.environ["DB_HOST"] = "127.0.0.1"
    os.environ["DB_NAME"] = "web_and_app_db"
    os.environ["DB_USER"] = "airflow"
    os.environ["DB_PASS"] = "airflow"

    try:
        from ai_module.data.db_connector import PGVectorConnector
        from ai_module.model.embedder import CodeBERTEmbedder
        
        # Khởi tạo đối tượng liên kết dữ liệu nghiệp vụ và mô hình nhúng thực tế của hệ thống
        db = PGVectorConnector()
        embedder = CodeBERTEmbedder()
        
        test_query = "def connect_database():"
        
        print("[PROCESS] Kích hoạt mô hình CodeBERT thực thi trích xuất ma trận toán học...")
        query_vector = embedder.get_embedding(test_query)
        
        print("[PROCESS] Khởi chạy thuật toán tìm kiếm lân cận tối ưu (K-Nearest Neighbors)...")
        results = db.search_similar_code(query_vector, top_k=1)
        
        # Kiểm định tính toàn vẹn và cấu trúc dữ liệu của mảng kết quả trả về (Assertions)
        assert isinstance(results, list), "Lỗi nghiệp vụ: Định dạng kết quả trả về từ database sai quy chuẩn, yêu cầu kiểu List."
        assert len(results) > 0, "Lỗi nghiệp vụ: Hệ thống trả về mảng rỗng. Kiểm tra luồng truy vấn hoặc dữ liệu mẫu."
        
        first_match = results[0]
        assert "code" in first_match, "Lỗi cấu trúc dữ liệu: Phản hồi thiếu trường thông tin mã nguồn 'code'."
        assert "graph" in first_match, "Lỗi cấu trúc dữ liệu: Phản hồi thiếu trường thông tin đồ thị phụ thuộc 'graph'."
        assert "score" in first_match, "Lỗi cấu trúc dữ liệu: Phản hồi thiếu trường thông tin thang điểm tương đồng 'score'."
        
        print(f"\n[METRICS REPORT] KẾT QUẢ TRUY XUẤT HỆ THỐNG:")
        print(f"    + Mã nguồn trùng khớp nhất: {first_match['code']}")
        print(f"    + Khoảng cách tương đồng:   {first_match['score']}")
        
        db.conn.close()
        print("[SUCCESS] Quy trình kết nối và truy xuất không gian PGVector vận hành chính xác.")
        
    except Exception as e:
        pytest.fail(f"[FAILURE] Luồng tích hợp dữ liệu phát sinh ngoại lệ runtime: {str(e)}")