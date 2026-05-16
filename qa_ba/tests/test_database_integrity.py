import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import IntegrityError
from sqlalchemy.engine import Engine
import bcrypt

from backend.models import Base, User, Document, SourceType, ProgrammingLanguage

# Cấu hình chuỗi kết nối cơ sở dữ liệu in-memory phục vụ kiểm thử hiệu năng cao
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

# Đảm bảo SQLite kích hoạt ràng buộc khóa ngoại (Foreign Key Constraints) tại thời điểm thiết lập kết nối
@event.listens_for(Engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()

@pytest.fixture(scope="function")
def db_session():
    """
    Fixture cô lập môi trường kiểm thử (Sandbox) cho từng kịch bản riêng biệt.
    Tự động khởi tạo cấu trúc bảng trước khi chạy và giải phóng tài nguyên sau khi kết thúc.
    """
    engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    
    db = TestingSessionLocal()
    yield db
    db.close()
    Base.metadata.drop_all(bind=engine)


def test_tc_data_04_password_hashing_and_relations(db_session):
    """
    TC-DATA-04: Kiểm thử tính toàn vẹn dữ liệu nghiệp vụ hệ thống (Data Integrity Validation)
    - Xác minh cơ chế mã hóa mật khẩu một chiều bằng thuật toán Bcrypt.
    - Xác minh tính chính xác của quan hệ liên kết (ORM Relationship) giữa thực thể User và Document.
    """
    
    # 1. Kiểm tra tính hợp lệ của cơ chế băm mật khẩu bảo mật
    plain_password = "MySecurePassword123"
    hashed_password = bcrypt.hashpw(plain_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    
    assert plain_password != hashed_password, "Rủi ro an ninh: Mật khẩu người dùng đang lưu trữ dưới dạng văn bản thuần."
    assert bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8')), "Lỗi nghiệp vụ: Thuật toán so khớp mật khẩu hoạt động sai logic."
    
    # 2. Khởi tạo và đồng bộ thực thể User mẫu vào cơ sở dữ liệu
    new_user = User(email="test@gmail.com", password_hash=hashed_password, full_name="Tester QA")
    db_session.add(new_user)
    db_session.commit()
    db_session.refresh(new_user)
    
    assert new_user.user_id is not None, "Lỗi hệ thống: Quá trình khởi tạo định danh User thất bại."

    # 3. Khởi tạo thực thể Document liên kết trực tiếp qua định danh khóa ngoại (User ID)
    new_doc = Document(
        user_id=new_user.user_id,
        title="Hướng dẫn thuật toán QuickSort",
        source_type=SourceType.DIRECT_TEXT,
        language=ProgrammingLanguage.PYTHON,
        raw_code_context="def quicksort(arr): ...",
        content_md="### QuickSort\nThuật toán..."
    )
    db_session.add(new_doc)
    db_session.commit()
    db_session.refresh(new_doc)
    
    # 4. Kiểm định tính toàn vẹn cấu trúc ánh xạ thực thể (ORM Mapping Integrity)
    assert new_doc.doc_id is not None, "Lỗi hệ thống: Quá trình khởi tạo định danh Document thất bại."
    assert new_doc.user_id == new_user.user_id, "Lỗi toàn vẹn: Mã định danh user_id giữa hai thực thể không đồng nhất."
    assert new_doc.owner.email == "test@gmail.com", "Lỗi ánh xạ: Liên kết quan hệ ORM giữa Document và User bị đứt gãy."


def test_tc_data_05_foreign_key_constraint(db_session):
    """
    TC-DATA-04: Kiểm thử ràng buộc nghiêm ngặt của khóa ngoại (Foreign Key Constraint Enforcement)
    Đảm bảo cơ sở dữ liệu chặn đứng hành vi chèn bản ghi Document chứa định danh người dùng không tồn tại.
    """
    invalid_doc = Document(
        user_id=999, 
        title="Tài liệu rác",
        source_type=SourceType.DIRECT_TEXT,
        language=ProgrammingLanguage.PYTHON,
        raw_code_context="print(1)",
        content_md="Lỗi"
    )
    db_session.add(invalid_doc)
    
    # Xác minh cơ sở dữ liệu ném ra ngoại lệ vi phạm ràng buộc dữ liệu khi thực hiện commit hành động bất hợp lệ
    with pytest.raises(IntegrityError):
        db_session.commit()