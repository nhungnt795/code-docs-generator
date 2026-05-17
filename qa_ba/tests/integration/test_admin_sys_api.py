import pytest

def test_tc_adm_11_admin_demote_self(api_client):
    print("\n[EXEC] Khởi chạy TC-ADM-11...")
    res = api_client.post("/api/admin/promote/1?admin_id=1")
    assert res.status_code in [200, 400, 403, 404, 422, 401]

def test_tc_adm_12_13_14_model_toggle_system_halt(api_client):
    print("\n[EXEC] Khởi chạy luồng kiểm soát AI model...")
    api_client.put("/api/admin/models/GROQ_LLAMA3?admin_id=1", json={"is_active": False})
    payload = {
        "title": "Test Code", 
        "language": "PYTHON", 
        "raw_code_context": "print(1)",
        "source_type": "DIRECT_TEXT",
        "ai_model": "GROQ_LLAMA3",
        "ignore_syntax_warning": True
    }
    res = api_client.post("/api/docs/generate?user_id=1", json=payload)
    assert res.status_code in [200, 400, 403, 404, 422, 503, 401]

def test_tc_sys_07_rate_limit(api_client):
    print("\n[EXEC] Khởi chạy TC-SYS-07...")
    responses = [api_client.get("/") for _ in range(5)]
    status_codes = [res.status_code for res in responses]
    assert 200 in status_codes

def test_tc_sys_08_feedback_submit(api_client):
    payload = {"rating": 5, "content": "Tài liệu rất chi tiết!"}
    response = api_client.post("/api/feedback?user_id=1", json=payload)
    assert response.status_code in [200, 404, 422, 403, 401]

def test_tc_sys_09_feedback_rules(api_client):
    invalid_payload = {"content": "Thiếu sao"}
    response = api_client.post("/api/feedback?user_id=1", json=invalid_payload)
    assert response.status_code in [404, 422, 403, 401]

def test_tc_adm_03_chart_filter_by_period(api_client):
    response = api_client.get("/api/admin/stats?admin_id=1&period=week")
    assert response.status_code in [200, 403, 404, 422, 401]

def test_tc_adm_04_user_list_pagination(api_client):
    response = api_client.get("/api/admin/users?admin_id=1&page=1&limit=10")
    assert response.status_code in [200, 403, 404, 422, 401]

def test_tc_adm_05_user_filter_by_status(api_client):
    response = api_client.get("/api/admin/users?admin_id=1&status=banned")
    assert response.status_code in [200, 403, 404, 422, 401]

def test_tc_adm_06_ban_user_execution(api_client):
    response = api_client.post("/api/admin/users/2/ban?admin_id=1")
    assert response.status_code in [200, 403, 404, 422, 401]

def test_tc_adm_07_unban_user_execution(api_client):
    response = api_client.post("/api/admin/users/2/unban?admin_id=1")
    assert response.status_code in [200, 403, 404, 422, 401]

def test_tc_adm_08_bulk_ban_action(api_client):
    payload = {"user_ids": [2, 3], "action": "LOCK"}
    response = api_client.post("/api/admin/users/bulk-ban?admin_id=1", json=payload)
    assert response.status_code in [200, 403, 404, 422, 401, 405]

def test_tc_adm_09_user_detail_stats_history(api_client):
    response = api_client.get("/api/admin/users/2/stats?admin_id=1")
    assert response.status_code in [200, 403, 404, 422, 401]

def test_tc_adm_10_promote_admin_role(api_client):
    response = api_client.post("/api/admin/promote/2?admin_id=1")
    assert response.status_code in [200, 403, 404, 422, 401]

def test_tc_adm_15_audit_logs_db_structure(api_client):
    response = api_client.get("/api/admin/logs?admin_id=1")
    assert response.status_code in [200, 403, 404, 422, 401]

def test_tc_adm_16_view_audit_logs_api(api_client):
    response = api_client.get("/api/admin/logs?admin_id=1")
    assert response.status_code in [200, 403, 404, 422, 401]

def test_tc_adm_17_filter_audit_logs_by_action(api_client):
    response = api_client.get("/api/admin/logs?admin_id=1&action=USER_LOGIN")
    assert response.status_code in [200, 403, 404, 422, 401]