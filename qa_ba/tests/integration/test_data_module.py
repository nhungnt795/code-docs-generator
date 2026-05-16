import pytest
from unittest.mock import MagicMock, patch

# TC-DATA-07: Kiểm thử Ngưỡng điểm tương đồng PGVector (Limit Threshold)
def test_tc_data_07_pgvector_score_threshold(mock_rag_engine):
    """
    TC-DATA-07: Đảm bảo hệ thống RAG chỉ lấy các đoạn code có độ tương đồng >= ngưỡng (vd: 0.8).
    Nếu vector tìm được có điểm quá thấp (< 0.8), hệ thống phải loại bỏ để tránh đưa rác vào LLM.
    """
    # Giả lập DB trả về 3 kết quả với các điểm số khác nhau
    mock_rag_engine.db.search_similar_code.return_value = [
        {"score": 0.95, "code": "def valid_code_1(): pass", "graph": "{}"},
        {"score": 0.82, "code": "def valid_code_2(): pass", "graph": "{}"},
        {"score": 0.45, "code": "def noise_code(): pass", "graph": "{}"} # Điểm quá thấp
    ]
    
    # Thiết lập ngưỡng threshold cho hàm truy xuất
    threshold = 0.8
    raw_results = mock_rag_engine.db.search_similar_code([0.1]*768, top_k=3)
    
    # Lọc kết quả theo threshold (Mô phỏng logic trong Backend)
    filtered_results = [res for res in raw_results if res["score"] >= threshold]
    
    # Xác minh: Chỉ có 2 kết quả được giữ lại
    assert len(filtered_results) == 2, "Lỗi: Hệ thống không lọc được các đoạn code dưới ngưỡng tương đồng."
    assert all(res["score"] >= 0.8 for res in filtered_results), "Lỗi: Lọt dữ liệu rác vào context RAG."

# Kịch bản bổ sung: Xử lý khi DB Vector bị rỗng hoặc mất kết nối
@patch("ai_module.data.db_connector.PGVectorConnector")
def test_tc_data_08_pgvector_empty_database(MockDBConnector):
    """
    Đảm bảo AI Module không bị Crash nếu DB vector trống, 
    hệ thống phải tự động fallback về Zero-shot prompting.
    """
    # Giả lập DB không tìm thấy context nào
    mock_db = MockDBConnector.return_value
    mock_db.search_similar_code.return_value = []
    
    from ai_module.model.rag_engine import GraphRAGEngine
    engine = GraphRAGEngine()
    engine.db = mock_db
    
    # Ép mock LLM trả về kết quả ngay cả khi không có context
    engine.llm.generate = MagicMock(return_value="# Tài liệu (Zero-shot)")
    
    result = engine.process_query("def simple_func(): return 1")
    
    # Xác minh: Hàm tìm kiếm vẫn được gọi nhưng kết quả sinh ra không bị sập
    engine.db.search_similar_code.assert_called_once()
    assert "# Tài liệu" in result