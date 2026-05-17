import pytest
from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import IntegrityError
from sqlalchemy.engine import Engine
import bcrypt

from database import Base
from models import User, Document, SourceType, ProgrammingLanguage

SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

@event.listens_for(Engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()

@pytest.fixture(scope="function")
def db_session():
    engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})
    Base.metadata.create_all(bind=engine)
    TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
    db = TestingSessionLocal()
    yield db
    db.close()
    Base.metadata.drop_all(bind=engine)

def test_tc_data_04_password_hashing_and_relations(db_session):
    plain_password = "MySecurePassword123"
    hashed_password = bcrypt.hashpw(plain_password.encode('utf-8'), bcrypt.gensalt()).decode('utf-8')
    assert plain_password != hashed_password
    assert bcrypt.checkpw(plain_password.encode('utf-8'), hashed_password.encode('utf-8'))
    
    new_user = User(email="test_integrity@gmail.com", password_hash=hashed_password, full_name="Tester QA")
    db_session.add(new_user)
    db_session.commit()
    db_session.refresh(new_user)
    assert new_user.user_id is not None
    
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
    assert new_doc.doc_id is not None
    assert new_doc.user_id == new_user.user_id

def test_tc_data_05_foreign_key_constraint(db_session):
    invalid_doc = Document(
        user_id=9999, 
        title="Tài liệu rác",
        source_type=SourceType.DIRECT_TEXT,
        language=ProgrammingLanguage.PYTHON,
        raw_code_context="print(1)",
        content_md="Lỗi"
    )
    db_session.add(invalid_doc)
    with pytest.raises(IntegrityError):
        db_session.commit()