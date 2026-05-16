import pytest

# Nhóm TC-DOC: Thao tác tài liệu
def test_tc_doc_02_unauthorized_edit(api_client):
    """TC-DOC-02: Cố tình sửa Document của User khác."""
    # Giả định user hiện tại đang cố PUT vào một doc_id của Admin/User khác
    payload = {"content_md": "Hacked content"}
    res = api_client.put("/api/docs/9999", json=payload) # 9999 là ID không thuộc sở hữu
    assert res.status_code in [403, 404], "Lỗ hổng: Xuyên quyền ngang (IDOR) - Có thể sửa doc người khác."

def test_tc_doc_07_export_invalid_format(api_client):
    """TC-DOC-07: Truyền sai định dạng Export."""
    res = api_client.get("/api/docs/1/export?format=EXCEL")
    assert res.status_code == 400, "Không được phép export định dạng ngoài md, pdf, docx."

# Nhóm TC-HIS: Lịch sử & Phân trang
def test_tc_his_02_empty_history(api_client):
    """TC-HIS-02: User mới cứng gọi API History phải trả về list rỗng."""
    res = api_client.get("/api/docs/history/9999")
    assert res.status_code == 200
    assert res.json().get("data") == []

def test_tc_his_03_04_05_history_search_and_filter(api_client):
    """TC-HIS-03, 04, 05: Kiểm tra luồng phân trang, tìm kiếm và lọc chuẩn URL."""
    # 1. Phân trang (Đã Pass)
    res_page = api_client.get("/api/docs/history/1?limit=2&page=1")
    assert res_page.status_code == 200

    # 2. Tìm kiếm (Sửa URL nhét thêm user_id = 1)
    res_search = api_client.get("/api/docs/history/1?search=QuickSort")
    assert res_search.status_code == 200

    # 3. Lọc ngôn ngữ (Sửa URL nhét thêm user_id = 1)
    res_filter = api_client.get("/api/docs/history/1?language=PYTHON")
    assert res_filter.status_code == 200

def test_tc_his_09_delete_non_existent(api_client):
    """TC-HIS-09: Xóa tài liệu không tồn tại."""
    res = api_client.delete("/api/docs/99999?user_id=1")
    assert res.status_code == 404