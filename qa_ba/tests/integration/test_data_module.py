import pytest
from unittest.mock import MagicMock, patch

def test_tc_data_07_pgvector_score_threshold(mock_rag_engine):
    mock_rag_engine.db.search_similar_code.return_value = [
        {"score": 0.95, "code": "def valid_code_1(): pass", "graph": "{}"},
        {"score": 0.82, "code": "def valid_code_2(): pass", "graph": "{}"},
        {"score": 0.45, "code": "def noise_code(): pass", "graph": "{}"}
    ]
    threshold = 0.8
    raw_results = mock_rag_engine.db.search_similar_code([0.1]*768, top_k=3)
    filtered_results = [res for res in raw_results if res["score"] >= threshold]
    assert len(filtered_results) == 2
    assert all(res["score"] >= 0.8 for res in filtered_results)

@patch("ai_module.data.db_connector.PGVectorConnector")
def test_tc_data_08_pgvector_empty_database(MockDBConnector):
    mock_db = MockDBConnector.return_value
    mock_db.search_similar_code.return_value = []
    from ai_module.model.rag_engine import GraphRAGEngine
    engine = GraphRAGEngine()
    engine.db = mock_db
    engine.llm.generate = MagicMock(return_value="# Tài liệu (Zero-shot)")
    result = engine.process_query("def simple_func(): return 1")
    engine.db.search_similar_code.assert_called_once()
    assert "# Tài liệu" in result