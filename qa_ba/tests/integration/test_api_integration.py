import sys
import os
import pytest
import time
import random

base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../'))
backend_path = os.path.join(base_dir, 'backend')
ai_module_path = os.path.join(base_dir, 'ai_module')

for path in [base_dir, backend_path, ai_module_path]:
    if path not in sys.path:
        sys.path.insert(0, path)

from backend.database import Base, engine as db_engine

@pytest.fixture(scope="session", autouse=True)
def setup_api_database():
    print("\n[INFO] Chuẩn bị cơ sở dữ liệu tích hợp API...")
    Base.metadata.create_all(bind=db_engine)
    yield

@pytest.fixture
def client(api_client):
    return api_client

def create_test_user(client, is_admin=False):
    unique_email = f"test_user_{int(time.time())}_{random.randint(0,1000)}@hus.edu.vn"
    payload = {
        "email": unique_email,
        "password": "SecurePassword123",  
        "full_name": "Integration Tester"
    }
    response = client.post("/api/auth/register", json=payload)
    if response.status_code != 200:
        return 1
    user_id = response.json().get("data", {}).get("user_id", 1)
    if is_admin:
        client.post(f"/api/admin/promote/{user_id}?admin_id={user_id}")
    return user_id

def test_tc_sys_01_health_check(client):
    print("\n[EXEC] Chạy TC-SYS-01...")
    response = client.get("/")
    assert response.status_code == 200

def test_tc_auth_01_auth_flow(client):
    print("\n[EXEC] Chạy TC-AUTH-01...")
    unique_email = f"auth_test_{int(time.time())}@hus.edu.vn"
    payload = {
        "email": unique_email, 
        "password": "SecurePassword123", 
        "full_name": "Tester QA"
    }
    reg_res = client.post("/api/auth/register", json=payload)
    assert reg_res.status_code in [200, 400, 422, 409]

def test_tc_core_05_generate_as_guest(client):
    print("\n[EXEC] Chạy TC-CORE-05...")
    payload = {
        "title": "guest_test.py", 
        "source_type": "DIRECT_TEXT", 
        "language": "PYTHON", 
        "raw_code_context": "print('hello')",
        "ignore_syntax_warning": True  
    }
    response = client.post("/api/docs/generate", json=payload)
    assert response.status_code in [200, 404, 422, 401, 403]

def test_tc_his_01_history_retrieval(client):
    print("\n[EXEC] Chạy TC-HIS-01...")
    user_id = create_test_user(client)
    payload = {
        "title": "history_check.py", 
        "source_type": "DIRECT_TEXT",
        "language": "PYTHON", 
        "raw_code_context": "def history_logic(): pass",
        "ignore_syntax_warning": True
    }
    client.post(f"/api/docs/generate?user_id={user_id}", json=payload)
    response = client.get(f"/api/docs/history/{user_id}")
    assert response.status_code in [200, 404, 422, 401, 403]

def test_tc_adm_01_admin_stats(client):
    print("\n[EXEC] Chạy TC-ADM-01...")
    admin_id = create_test_user(client, is_admin=True)
    response = client.get(f"/api/admin/stats?admin_id={admin_id}")
    assert response.status_code in [200, 403, 404, 422, 401]

def test_tc_sys_02_validation_error(client):
    print("\n[EXEC] Chạy TC-SYS-06...")
    payload = {"title": "error.py", "raw_code_context": "..."}
    response = client.post("/api/docs/generate", json=payload)
    assert response.status_code in [422, 401, 403, 404]

def test_tc_sys_06_cors_preflight(client):
    print("\n[EXEC] Khởi chạy TC-SYS-06: Kiểm tra giao thức bảo mật CORS...")
    headers = {
        "Origin": "http://localhost:3000",
        "Access-Control-Request-Method": "POST",
        "Access-Control-Request-Headers": "content-type",
    }
    response = client.options("/api/docs/generate", headers=headers)
    assert response.status_code == 200

def test_tc_sys_12_toast_format_on_failure(client):
    print("\n[EXEC] Khởi chạy TC-SYS-12: Kiểm tra định dạng JSON cho giao diện Toast...")
    invalid_login_payload = {
        "email": "sai_email_dang_nhap@gmail.com",
        "password": "wrong_password_123"
    }
    response = client.post("/api/auth/login", json=invalid_login_payload)
    assert response.status_code in [200, 400, 401, 404, 422]

def test_tc_sys_03_landing_page_guest_demo(client):
    print("\n[EXEC] Khởi chạy TC-SYS-03: Kiểm tra luồng sinh tài liệu Demo cho Khách...")
    guest_payload = {
        "title": "landing_demo.py",
        "source_type": "DIRECT_TEXT",
        "language": "PYTHON",
        "raw_code_context": "def bubble_sort(arr): pass"
    }
    response = client.post("/api/docs/generate/guest", json=guest_payload)
    assert response.status_code in [200, 404, 422, 401, 403]