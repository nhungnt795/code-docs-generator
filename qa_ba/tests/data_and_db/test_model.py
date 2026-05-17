import sys
import os
import json
import pytest
import time

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../../'))
for path in [PROJECT_ROOT, os.path.join(PROJECT_ROOT, 'backend'), os.path.join(PROJECT_ROOT, 'ai_module')]:
    if path not in sys.path:
        sys.path.insert(0, path)

try:
    from rouge_score import rouge_scorer
    from nltk.translate.bleu_score import sentence_bleu, SmoothingFunction
except ImportError:
    pytest.skip("Thiếu thư viện rouge-score hoặc nltk.")

def test_tc_core_01_core_interface():
    print("\n[INFO] Khởi chạy TC-CORE-01...")
    try:
        from ai_module.model.rag_engine import GraphRAGEngine
        from ai_module.model.embedder import CodeBERTEmbedder
        rag_engine = GraphRAGEngine()
        embedder = CodeBERTEmbedder()
        assert hasattr(rag_engine, 'process_query')
        assert hasattr(embedder, 'get_embedding')
    except Exception as e:
        pytest.fail(f"[FAILURE] Khởi tạo thất bại: {str(e)}")

def test_tc_core_02_metrics_from_log():
    print("\n[INFO] Khởi chạy TC-CORE-02...")
    from evaluate import load
    providers_config = {
        "KAGGlE (Fine-tuned)": os.path.join(PROJECT_ROOT, "ai_module/serving/predictions.jsonl"),
        "GROQ (Original)": os.path.join(PROJECT_ROOT, "ai_module/serving/predictions_groq.jsonl")
    }
    try:
        bleu_metric = load("bleu")
        rouge_metric = load("rouge")
    except Exception as e:
        pytest.fail(f"[FAILURE] Lỗi nạp Metric Hub: {e}")
    evaluated_count = 0
    for provider_name, file_path in providers_config.items():
        if not os.path.exists(file_path): continue
        predictions = []
        references = []
        with open(file_path, "r", encoding="utf-8") as f:
            for line in f:
                if not line.strip(): continue
                item = json.loads(line.strip())
                pred = item.get("predicted_docstring", "")
                ref = ""
                for msg in item.get("original_messages", []):
                    if msg.get("role") == "assistant":
                        ref = msg.get("content", "")
                        break
                if pred and ref:
                    predictions.append(pred)
                    references.append(ref)
        if len(predictions) == 0: continue
        bleu_refs = [[ref] for ref in references]
        bleu_results = bleu_metric.compute(predictions=predictions, references=bleu_refs)
        rouge_results = rouge_metric.compute(predictions=predictions, references=references)
        bleu_score = bleu_results['bleu'] * 100
        if "kaggle" in provider_name.lower():
            assert bleu_score > 10.0
        evaluated_count += 1
    if evaluated_count == 0:
        pytest.skip("[SKIP] Thiếu dữ liệu đầu vào.")