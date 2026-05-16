import pytest

# Nhóm TC-ADM: Phân quyền & Quản lý User
def test_tc_adm_02_user_call_admin_api(api_client):
    # Dùng một ID của user thường (không phải admin)
    res = api_client.get("/api/admin/stats?admin_id=8888")
    assert res.status_code == 403, "Lỗ hổng: User thường truy cập được Dashboard Admin."

def test_tc_adm_11_admin_demote_self(api_client):
    """TC-ADM-11: Admin tự giáng cấp chính mình (nguy cơ mất quyền root)."""
    payload = {"role": "user"}
    # Giả định admin_id = 1 đang thao tác
    res = api_client.put("/api/admin/users/1/role", json=payload)
    assert res.status_code == 400, "Lỗi logic: Hệ thống cho phép Admin tự khóa/giáng cấp chính mình."

def test_tc_adm_12_13_14_model_toggle_system_halt(api_client):
    """TC-ADM-12, 13, 14: Luồng khóa Model từ Admin và hệ quả phía User."""
    # 1. Admin tắt cả Groq và Kaggle
    api_client.put("/api/admin/models/toggle", json={"groq_enabled": False, "kaggle_enabled": False})
    
    # 2. User cố tình gửi request Generate
    payload = {"title": "Test", "language": "PYTHON", "raw_code_context": "print(1)", "source_type": "DIRECT_TEXT"}
    res = api_client.post("/api/docs/generate", json=payload)
    
    # 3. Backend phải báo 503 Bảo trì
    assert res.status_code == 503, "Hệ thống không chặn User gen code khi Admin đã tắt toàn bộ Model."

# Nhóm TC-SYS: Hệ thống chung
def test_tc_sys_07_rate_limit(api_client):
    """TC-SYS-07: Cơ chế chống Spam (Rate Limiting)."""
    # Gửi liên tục 10 requests (Hoặc số lượng tùy theo config của hệ thống)
    responses = [api_client.get("/api/system/init") for _ in range(20)]
    
    # Kiểm tra xem có bất kỳ request nào bị chặn bởi mã 429 Too Many Requests không
    status_codes = [res.status_code for res in responses]
    assert 429 in status_codes, "Lỗi bảo mật: Hệ thống không cấu hình Rate Limit, dễ bị tấn công DDoS."

def test_tc_sys_09_feedback_validation(api_client):
    """TC-SYS-09: Gửi feedback thiếu Rating bắt buộc."""
    payload = {"document_id": 1, "comment": "Tài liệu sinh ra rất tốt"} # Thiếu trường 'rating' (Star)
    res = api_client.post("/api/feedback", json=payload)
    assert res.status_code == 422, "API Feedback không bắt buộc trường Rating."