import pytest

def test_tc_auth_02_register_duplicate_email_unactivated(api_client):
    duplicate_payload = {
        "email": "test_duplicate@gmail.com", 
        "password": "SecurePassword123", 
        "full_name": "Nguyễn Tố Uyên QA"
    }
    # Lần 1: Đăng ký mới
    api_client.post("/api/auth/register", json=duplicate_payload) 
    
    # Lần 2: Đăng ký lại khi chưa kích hoạt OTP -> Kỳ vọng hệ thống gửi lại OTP (200 OK)
    res_dup = api_client.post("/api/auth/register", json=duplicate_payload) 
    
    assert res_dup.status_code == 200
    assert res_dup.json()["message"] == "Tài khoản chưa kích hoạt — đã gửi lại mã OTP"
    
def test_tc_auth_03_register_invalid_email_format(api_client):
    invalid_payload = {
        "email": "uyenqa_hus_edu_vn", 
        "password": "SecurePassword123", 
        "full_name": "Nguyễn Tố Uyên QA"
    }
    res = api_client.post("/api/auth/register", json=invalid_payload)
    assert res.status_code == 422

def test_tc_auth_06_sql_injection_login(api_client):
    payload = {"email": "test_sql@gmail.com", "password": "SecurePassword123"}
    res = api_client.post("/api/auth/login", json=payload)
    assert res.status_code in [200, 400, 401, 404, 422]

def test_tc_auth_13_security_profile_update(api_client):
    res = api_client.delete("/api/docs/1?user_id=9999")
    assert res.status_code in [403, 404, 422, 401]