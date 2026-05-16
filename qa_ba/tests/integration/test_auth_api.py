import pytest

# Nhóm TC-AUTH: Đăng ký & Đăng nhập (Validation & Security)
import pytest

def test_tc_auth_02_register_duplicate_email(api_client):
    """
    TC-AUTH-02: Kiểm tra hệ thống chặn đăng ký khi Email đã tồn tại trong DB.
    """
    print("\n[EXEC] Khởi chạy TC-AUTH-02...")
    duplicate_payload = {
        "email": "test@gmail.com", 
        "password": "123", 
        "full_name": "Nguyễn Tố Uyên QA",
        "source_type": "DIRECT_TEXT"
    }
    # Đăng ký lần 1 (Đảm bảo email tồn tại trong hệ thống)
    api_client.post("/api/auth/register", json=duplicate_payload) 
    
    # Đăng ký lần 2 (Trùng lặp)
    res_dup = api_client.post("/api/auth/register", json=duplicate_payload) 
    
    # Xác thực lỗi trùng dữ liệu từ phía DB/Backend
    assert res_dup.status_code in [400, 409], f"Lỗi: Hệ thống không chặn trùng lặp Email. Trả về: {res_dup.status_code}"


def test_tc_auth_03_register_invalid_email_format(api_client):
    """
    TC-AUTH-03: Kiểm tra hệ thống chặn format Email sai chuẩn Regex.
    """
    print("\n[EXEC] Khởi chạy TC-AUTH-03...")
    invalid_email_payload = {
        "email": "uyenqa_hus_edu_vn",  # Thiếu ký tự @ đặc trưng
        "password": "123", 
        "full_name": "Nguyễn Tố Uyên QA",
        "source_type": "DIRECT_TEXT"
    }
    res_format = api_client.post("/api/auth/register", json=invalid_email_payload)
    
    # Khớp nối Pydantic Validation lỗi định dạng đầu vào
    assert res_format.status_code == 422, f"Lỗi: Hệ thống không chặn email sai định dạng. Trả về: {res_format.status_code}"
    
def test_tc_auth_06_sql_injection_login(api_client):
    """TC-AUTH-06: Chống tấn công SQL Injection cơ bản vào màn hình Login."""
    payload = {"email": "' OR 1=1 --", "password": "password"}
    res = api_client.post("/api/auth/login", json=payload)
    # SQLAlchemy ORM sẽ sanitize, nên nó phải trả về 401/404/422 chứ không được lỗi 500 hay lộ data
    assert res.status_code in [401, 404, 422]

def test_tc_auth_13_security_profile_update(api_client):
    """TC-AUTH-13: Chặn user cố tình đổi Email (Trường Read-only)."""
    # Lưu ý: Cần thêm header Token thực tế nếu có
    payload = {"full_name": "Nguyễn Tố Uyên QA", "email": "hacked@gmail.com"}
    res = api_client.put("/api/auth/profile", json=payload)
    # Tùy backend: Trả 400 hoặc 200 nhưng lờ đi trường email
    if res.status_code == 200:
        assert res.json().get("email") != "hacked@gmail.com", "Lỗ hổng: User tự đổi được Email."

# Nhóm TC-AUTH: OTP & Password Flow
@pytest.mark.parametrize("otp_code, expected_status", [
    ("000000", 400), # TC-AUTH-08: Sai OTP
    ("EXPIRED", 400) # TC-AUTH-09: Giả lập OTP hết hạn (Cần mock DB)
])
def test_tc_auth_08_09_otp_validation(api_client, otp_code, expected_status):
    payload = {"email": "test@gmail.com", "otp": otp_code}
    res = api_client.post("/api/auth/verify-otp", json=payload)
    assert res.status_code == expected_status