import pytest

@pytest.fixture(scope="module")
def setup_doc_data(api_client):
    """Khởi tạo dữ liệu giả lập và lấy ID động để không bị xung đột với các file test khác."""
    
    # 1. Tạo User 1 (Có Document)
    res_u1 = api_client.post("/api/auth/register", json={
        "email": "user1_dynamic_doc@gmail.com", 
        "password": "SecurePassword123", 
        "full_name": "User 1"
    })
    user1_id = res_u1.json()["data"]["user_id"]
    
    # Tạo sẵn 1 document thuộc sở hữu của User 1 (Dùng user1_id vừa lấy)
    res_doc = api_client.post(f"/api/docs/generate?user_id={user1_id}", json={
        "title": "Test Doc Export",
        "source_type": "DIRECT_TEXT",
        "language": "PYTHON",
        "raw_code_context": "def hello(): print('world')",
        "ignore_syntax_warning": True
    })
    doc1_id = res_doc.json()["data"]["document"]["doc_id"]
    
    # 2. Tạo User 2 (Mới cứng, không tạo doc)
    res_u2 = api_client.post("/api/auth/register", json={
        "email": "user2_dynamic_empty@gmail.com", 
        "password": "SecurePassword123", 
        "full_name": "User 2"
    })
    user2_id = res_u2.json()["data"]["user_id"]

    # Trả về các ID động này cho các hàm test bên dưới sử dụng
    return {
        "user1_id": user1_id,
        "doc1_id": doc1_id,
        "user2_id": user2_id
    }

# =====================================================================
# Nhóm TC-DOC: Thao tác tài liệu
# =====================================================================
def test_tc_doc_02_unauthorized_edit(api_client, setup_doc_data):
    """TC-DOC-02: Cố tình sửa Document của User khác."""
    payload = {"content_md": "Hacked content"}
    # Dùng user1 đi sửa bậy doc 99999
    u1_id = setup_doc_data["user1_id"]
    res = api_client.put(f"/api/docs/99999?user_id={u1_id}", json=payload) 
    assert res.status_code in [403, 404], "Lỗ hổng: Xuyên quyền ngang (IDOR) - Có thể sửa doc người khác."

def test_tc_doc_07_export_invalid_format(api_client, setup_doc_data):
    """TC-DOC-07: Truyền sai định dạng Export."""
    doc_id = setup_doc_data["doc1_id"]
    u1_id = setup_doc_data["user1_id"]
    # User 1 tải doc_id của chính mình, nhưng sai format
    res = api_client.get(f"/api/docs/{doc_id}/export?format=EXCEL&user_id={u1_id}")
    assert res.status_code == 400, "Không được phép export định dạng ngoài md, pdf, docx."

# =====================================================================
# Nhóm TC-HIS: Lịch sử & Phân trang
# =====================================================================
def test_tc_his_02_empty_history(api_client, setup_doc_data):
    """TC-HIS-02: User mới cứng gọi API History phải trả về list rỗng."""
    u2_id = setup_doc_data["user2_id"]
    res = api_client.get(f"/api/docs/history/{u2_id}")
    assert res.status_code == 200
    assert res.json().get("data") == []

def test_tc_his_03_04_05_history_search_and_filter(api_client, setup_doc_data):
    """TC-HIS-03, 04, 05: Kiểm tra luồng phân trang, tìm kiếm và lọc chuẩn URL."""
    u1_id = setup_doc_data["user1_id"]
    
    res_page = api_client.get(f"/api/docs/history/{u1_id}?limit=2&page=1")
    assert res_page.status_code == 200

    res_search = api_client.get(f"/api/docs/history/{u1_id}?search=QuickSort")
    assert res_search.status_code == 200

    res_filter = api_client.get(f"/api/docs/history/{u1_id}?language=PYTHON")
    assert res_filter.status_code == 200

def test_tc_his_09_delete_non_existent(api_client, setup_doc_data):
    """TC-HIS-09: Xóa tài liệu không tồn tại."""
    u1_id = setup_doc_data["user1_id"]
    res = api_client.delete(f"/api/docs/99999?user_id={u1_id}")
    assert res.status_code == 404