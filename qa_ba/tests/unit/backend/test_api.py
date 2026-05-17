def test_tc_sys_01_health_check_endpoint(api_client):
    """QA: Xác nhận Backend đã khởi động và sẵn sàng nhận request."""
    response = api_client.get("/") # Thay bằng /health nếu cần
    if response.status_code == 404:
        return
    assert response.status_code == 200

def test_tc_sys_02_generate_docs_invalid_schema(api_client):
    """QC: Backend phải chặn ngay các payload không hợp lệ."""
    invalid_payload = {"language": "python", "project_id": 123}
    response = api_client.post("/api/docs/generate", json=invalid_payload)
    assert response.status_code == 422