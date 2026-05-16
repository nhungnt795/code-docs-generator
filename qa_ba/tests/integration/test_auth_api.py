import pytest

# Nhóm TC-AUTH: Đăng ký & Đăng nhập (Validation & Security)

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
    
    # Xác thực lỗi trùng dữ liệu từ phía DB/Backend (Hỗ trợ bắt mã 400 hoặc 400 từ Backend của Hùng)
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
    
    # Khớp nối Pydantic Validation lỗi định dạng đầu vào của FastAPI
    assert res_format.status_code == 422, f"Lỗi: Hệ thống không chặn email sai định dạng. Trả về: {res_format.status_code}"
    

def test_tc_auth_06_sql_injection_login(api_client):
    """
    TC-AUTH-06: Chống tấn công SQL Injection cơ bản vào màn hình Login.
    """
    print("\n[EXEC] Khởi chạy TC-AUTH-06...")
    payload = {"email": "' OR 1=1 --", "password": "password"}
    res = api_client.post("/api/auth/login", json=payload)
    # SQLAlchemy ORM của Backend sẽ tự động sanitize, hệ thống phải chặn đứng bằng mã lỗi chặn xác thực
    assert res.status_code in [400, 401, 404, 422], f"Lỗi bảo mật: SQL Injection không bị chặn. Trả về: {res.status_code}"


def test_tc_auth_13_security_profile_update(api_client):
    """
    TC-AUTH-13: Chặn user cố tình đổi Email khi cập nhật Profile (Trường Read-only).
    """
    print("\n[EXEC] Khởi chạy TC-AUTH-13...")
    payload = {"full_name": "Nguyễn Tố Uyên QA", "email": "hacked@gmail.com"}
    
    # FIX: Chuyển đổi endpoint sang /api/profile/update khớp với router/profile.py mới của Hùng
    res = api_client.put("/api/profile/update", json=payload)
    
    # Nếu hệ thống xử lý thành công (mã 200), bắt buộc email trả về phải giữ nguyên cấu trúc cũ, không được đổi sang hacked email
    if res.status_code == 200:
        assert res.json().get("email") != "hacked@gmail.com", "Lỗ hổng bảo mật: Hệ thống cho phép User tự ý thay đổi Email liên kết."


# Nhóm TC-AUTH: OTP & Password Flow
@pytest.mark.parametrize("otp_code, expected_status", [
    ("000000", 400), # TC-AUTH-08: Sai OTP -> Trả về 400 Bad Request
    ("EXPIRED", 400) # TC-AUTH-09: OTP hết hạn -> Trả về 400 Bad Request
])
def test_tc_auth_08_09_otp_validation(api_client, otp_code, expected_status):
    print(f"\n[EXEC] Khởi chạy luồng OTP thực tế với mã: {otp_code}...")
    payload = {"email": "test@gmail.com", "otp": otp_code}
    
    # Endpoint khớp với backend/routers/auth.py của Hùng
    res = api_client.post("/api/auth/verify-otp", json=payload)
    assert res.status_code == expected_status, f"Lỗi xác thực OTP: Kỳ vọng {expected_status} nhưng nhận được {res.status_code}"