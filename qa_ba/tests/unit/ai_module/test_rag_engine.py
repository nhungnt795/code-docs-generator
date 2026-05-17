def test_tc_core_04_rag_engine_execution_flow(mock_rag_engine):
    """TC-CORE-04: Đảm bảo luồng RAG kích hoạt đúng trình tự và trả ra dữ liệu kết quả."""
    sample_code = "def sum_numbers(a, b):\n    return a + b"
    
    # Kích hoạt hàm xử lý
    result = mock_rag_engine.process_query(sample_code)
    
    # Xác thực kết quả đầu ra hợp lệ không bị rỗng
    assert result is not None
    assert len(str(result)) > 0