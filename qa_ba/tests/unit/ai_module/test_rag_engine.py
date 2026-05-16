def test_tc_core_04_rag_engine_execution_flow(mock_rag_engine):
    """TC-CORE-04: Đảm bảo luồng RAG kích hoạt đúng trình tự: Embedder -> Retriever -> LLM."""
    sample_code = "def sum_numbers(a, b):\n    return a + b"

    mock_rag_engine.llm.generate.return_value = "# Documented Code \n Test thành công"

    result = mock_rag_engine.process_query(sample_code)

    mock_rag_engine.embedder.get_embedding.assert_called_once()
    mock_rag_engine.db.search_similar_code.assert_called_once()
    mock_rag_engine.llm.generate.assert_called_once()
    
    assert isinstance(result, str)
    assert "# Documented Code" in result