import sys
import os
import json
import pytest
import time

# CẤU HÌNH ĐƯỜNG DẪN HỆ THỐNG (MODULE RESOLUTION)
PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../'))
for path in [PROJECT_ROOT, os.path.join(PROJECT_ROOT, 'backend'), os.path.join(PROJECT_ROOT, 'ai_module')]:
    if path not in sys.path:
        sys.path.insert(0, path)

try:
    from rouge_score import rouge_scorer
    from nltk.translate.bleu_score import sentence_bleu, SmoothingFunction
except ImportError:
    pytest.skip("Thiếu thư viện rouge-score hoặc nltk. Yêu cầu cài đặt: pip install rouge-score nltk")

# KỊCH BẢN KIỂM THỬ MODEL QA (DATA-DRIVEN & A/B TESTING)

def test_tc_core_01_core_interface():
    """TC-CORE-01: Kiểm tra tính toàn vẹn của giao diện cấu trúc AI Module"""
    print("\n[INFO] Khởi chạy TC-CORE-01...")
    try:
        from ai_module.model.rag_engine import GraphRAGEngine
        from ai_module.model.embedder import CodeBERTEmbedder
        
        rag_engine = GraphRAGEngine()
        embedder = CodeBERTEmbedder()
        
        assert hasattr(rag_engine, 'process_query'), "Lỗi cấu trúc: GraphRAGEngine thiếu phương thức process_query"
        assert hasattr(embedder, 'get_embedding'), "Lỗi cấu trúc: CodeBERTEmbedder thiếu phương thức get_embedding"
        print("[SUCCESS] Cấu trúc giao diện các module đạt tiêu chuẩn.")
    except Exception as e:
        pytest.fail(f"[FAILURE] Quá trình khởi tạo phân hệ thất bại: {str(e)}")


def test_tc_core_02_metrics_from_log():
    """TC-CORE-02: Đánh giá định lượng hiệu năng mô hình ROUGE/BLEU"""
    print("\n[INFO] Khởi chạy TC-CORE-02...")
    
    import os
    import json
    from evaluate import load

    providers_config = {
        "KAGGlE (Fine-tuned)": os.path.join(PROJECT_ROOT, "ai_module/serving/predictions.jsonl"),
        "GROQ (Original)": os.path.join(PROJECT_ROOT, "ai_module/serving/predictions_groq.jsonl")
    }

    try:
        bleu_metric = load("bleu")
        rouge_metric = load("rouge")
    except Exception as e:
        pytest.fail(f"[FAILURE] Không thể nạp thư viện đánh giá Metric từ HuggingFace Hub: {e}")

    evaluated_count = 0

    for provider_name, file_path in providers_config.items():
        print(f"\n[PROCESS] Đang trích xuất và tính toán số liệu cho: {provider_name}...")
        
        if not os.path.exists(file_path):
            print(f"    [WARNING] Không tìm thấy tệp tin kết quả dữ liệu tại: {file_path}. Bỏ qua phân tích {provider_name}.")
            continue

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

        if len(predictions) == 0:
            print(f"    [ERROR] Tệp tin dữ liệu của {provider_name} rỗng hoặc không thể bóc tách cấu trúc văn bản.")
            continue

        bleu_refs = [[ref] for ref in references]
        bleu_results = bleu_metric.compute(predictions=predictions, references=bleu_refs)
        rouge_results = rouge_metric.compute(predictions=predictions, references=references)

        bleu_score = bleu_results['bleu'] * 100
        rouge1_score = rouge_results['rouge1'] * 100
        rouge2_score = rouge_results['rouge2'] * 100
        rougeL_score = rouge_results['rougeL'] * 100

        print(f"    [METRICS REPORT] KẾT QUẢ ĐỊNH LƯỢNG MÔ HÌNH {provider_name.upper()}:")
        print(f"    + BLEU Score:  {bleu_score:.2f}%")
        print(f"    + ROUGE-1:     {rouge1_score:.2f}%  (Mức độ trùng lặp token đơn)")
        print(f"    + ROUGE-2:     {rouge2_score:.2f}%  (Mức độ trùng lặp cụm từ vựng)")
        print(f"    + ROUGE-L:     {rougeL_score:.2f}%  (Độ tương đồng chuỗi ngữ nghĩa chung)")

        if "kaggle" in provider_name.lower():
            assert bleu_score > 20.0, f"[CRITICAL] Điểm chỉ số BLEU ({bleu_score:.2f}%) không đạt ngưỡng KPI cam kết hệ thống."
            assert rouge1_score > 40.0, f"[CRITICAL] Điểm chỉ số ROUGE-1 ({rouge1_score:.2f}%) quá thấp, sai lệch từ vựng chuyên ngành."
            assert rougeL_score > 35.0, f"[CRITICAL] Điểm chỉ số ROUGE-L ({rougeL_score:.2f}%) không đạt yêu cầu cấu trúc ngữ nghĩa ngữ cảnh."
            print("    [STATUS] Xác nhận mô hình Fine-tuned vượt qua tất cả các ngưỡng kiểm định KPI.")
        
        evaluated_count += 1

    if evaluated_count == 0:
        pytest.skip("[SKIP] Bỏ qua kịch bản kiểm thử định lượng do thiếu toàn bộ dữ liệu predictions đầu vào.")
    
    print("\n[SUCCESS] Hoàn thành toàn bộ quy trình kiểm thử định lượng hiệu năng TC-MODEL-02.")


@pytest.mark.parametrize("model_provider", ["groq", "kaggle"])
def test_tc_core_03_edge_cases_from_json(model_provider):
    """TC-CORE-03: Kiểm thử hộp đen dựa trên dữ liệu biên dị thường."""
    print(f"\n[INFO] Khởi chạy TC-CORE-03. Nền tảng thực thi: {model_provider.upper()}")
    
    if model_provider == "groq":
        os.environ["GROQ_API_KEY"] = "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"
        os.environ["USE_KAGGLE"] = "false"
    else:
        os.environ["USE_KAGGLE"] = "true"
    
    edge_case_path = os.path.join(PROJECT_ROOT, "qa_ba/tests/data/edge_cases.json")
    
    if os.path.exists(edge_case_path):
        with open(edge_case_path, "r", encoding="utf-8") as f:
            cases = json.load(f)
        assert len(cases) > 0, "Tệp cấu hình edge cases không được để trống dữ liệu"
    else:
        print("[WARNING] Không tìm thấy tệp cấu hình qc_edge_cases.json. Bỏ qua kịch bản dữ liệu biên.")
        cases = []

    from ai_module.model.rag_engine import GraphRAGEngine
    engine = GraphRAGEngine()
    
    failed_cases = []

    for case in cases:
        input_data = case.get("code", "")
        test_id = case.get("test_id", "UNKNOWN")
        expected_keywords = case.get("expected_keywords", [])

        result = None
        max_retries = 3
        retry_delay = 10  # Thời gian chờ cơ sở ban đầu (10 giây)
        is_rate_limited = False

        print(f"\n[EXEC] [{model_provider.upper()}] Tiến hành kiểm thử kịch bản: {test_id}...")

        # VÒNG LẶP TỰ ĐỘNG THỬ LẠI KHI DÍNH RATE LIMIT (RETRY PIPELINE)
        for attempt in range(max_retries + 1):
            try:
                is_rate_limited = False
                result = engine.process_query(input_data)
                result_text = str(result).lower()
                
                # Bẫy trường hợp ngoại lệ nghẽn tải dạng văn bản chuỗi do framework nuốt mã lỗi HTTP
                if "rate_limit_exceeded" in result_text or "429" in result_text:
                    is_rate_limited = True
                    raise Exception("rate_limit_exceeded")
                
                # Nếu lệnh gọi thành công, thoát khỏi vòng lặp thử lại
                break

            except Exception as e:
                err_msg = str(e).lower()
                if "429" in err_msg or "rate limit" in err_msg or is_rate_limited:
                    if attempt < max_retries:
                        print(f"    [WARNING] Phát hiện nghẽn tải API (Rate Limit 429). Tiến hành thử lại lần {attempt + 1}/{max_retries} sau {retry_delay} giây...")
                        time.sleep(retry_delay)
                        retry_delay *= 2  # Giãn cách lũy thừa để giải phóng cửa sổ thời gian trượt (Exponential Backoff)
                        continue
                    else:
                        print(f"    [CRITICAL] Vượt quá giới hạn số lần thử lại cho phép tại kịch bản {test_id}.")
                        failed_cases.append(f"[{test_id}] Lỗi hạ tầng: Vượt ngưỡng băng thông API sau {max_retries} lần thử lại.")
                        result = None
                        break
                elif "maintenance" in err_msg or "403" in err_msg or "expired" in err_msg:
                    print(f"    [ALERT] Cảnh báo nghiệp vụ: Nhà cung cấp {model_provider.upper()} đang bảo trì hoặc ngừng hoạt động.")
                    failed_cases.append(f"[{test_id}] Cảnh báo từ Hệ thống: Nhà cung cấp {model_provider.upper()} đang bảo trì.")
                    result = None
                    break
                else:
                    print(f"    [SYSTEM ERROR] Lỗi không xác định phát sinh tại kịch bản {test_id}: {e}")
                    failed_cases.append(f"[{test_id}] Lỗi Backend Runtime: {e}")
                    result = None
                    break

        # Nếu không lấy được kết quả do lỗi hạ tầng phần cứng, chuyển sang kịch bản tiếp theo
        if result is None:
            continue

        # PHÂN ĐOẠN ĐÁNH GIÁ LOGIC VÀ KIỂM ĐỊNH TỪ KHÓA (ASSERTIONS LAYER)
        try:
            print(f"    [OUTPUT] Đoạn trích văn bản phản hồi đầu tiên từ {test_id}:\n{result[:100]}\n")
            
            # ÉP LUẬT NEGATIVE TESTING CHO QC_EDGE_07
            if test_id == "QC_EDGE_07":
                forbidden_keywords = [
                    "cấu trúc chương trình", "giao diện chương trình", "mã nguồn",
                    "ngôn ngữ lập trình", "thực hiện chương trình", "python được cài đặt",
                    "đoạn code", "hàm", "biến", "chạy chương trình", "dữ liệu đầu vào" # <--- THÊM CÁC TỪ NÀY VÀO
                ]
                detected_forbidden = [word for word in forbidden_keywords if word in result_text]
                assert not detected_forbidden, (
                    f"[HALLUCINATION DETECTED] AI dính ảo giác nghiêm trọng ở case {test_id}! "
                    f"Từ khóa vi phạm phát hiện: {detected_forbidden}"
                )

            # ÉP LUẬT KIỂM TRA XUNG ĐỘT NGÔN NGỮ 
            elif test_id == "QC_EDGE_11":
                # Nếu hệ thống đang ép vai JavaScript/Java nhưng kết quả trả về vẫn chứa từ khóa đặc thù của code C++
                cpp_keywords_detected = any(w in result_text for w in ["do_death_spell", "player_ptr", "spell", "spellprocesstype"])
                
                # Kiểm tra xem AI có dòng nào chủ động báo lỗi cấu hình hay không
                has_system_error_msg = any(w in result_text for w in ["sai cấu hình", "không khớp ngôn ngữ", "ngôn ngữ không hợp lệ"])
                
                # Nếu AI thản nhiên phân tích code C++ mà KHÔNG hề có thông báo từ chối/báo sai cấu hình
                if cpp_keywords_detected and not has_system_error_msg:
                    assert False, (
                        f"[CROSS-LANGUAGE ERROR] Lỗ hổng nhất quán: Hệ thống đang ép cấu hình ngôn ngữ khác "
                        f"nhưng mô hình vẫn cố chấp xử lý mã nguồn C++ thay vì đưa ra cảnh báo từ chối."
                    )
            # CÁC EDGE CASES CÒN LẠI TIẾP TỤC KIỂM TRA THEO TỪ KHÓA KỲ VỌNG
            elif expected_keywords:
                for kw in expected_keywords:
                    if isinstance(kw, list):
                        match_or = any(sub_kw.lower() in result_text for sub_kw in kw)
                        assert match_or, f"Không tìm thấy bất kỳ từ khóa nào thuộc nhóm điều kiện HOẶC {kw}"
                    else:
                        kw_lower = kw.lower()
                        extended_or_group = [kw_lower]
                        
                        if kw_lower == "lỗi cú pháp":
                            extended_or_group.extend(["lỗi", "cú pháp", "syntax error", "syntax", "hỏng"])
                        elif kw_lower == "trống":
                            extended_or_group.extend(["chưa được implement", "chưa implement", "chưa triển khai", "chưa được viết", "implement sau"])
                        
                        match_extended_or = any(sub_kw in result_text for sub_kw in extended_or_group)
                        assert match_extended_or, f"Không tìm thấy từ khóa bắt buộc '{kw}' hoặc các biến thể đồng nghĩa tương đương: {extended_or_group}"

            if test_id not in ["QC_EDGE_07", "QC_EDGE_11"]:
                print(f"    [PASSED] [{model_provider.upper()}] Khớp nối chính xác quy tắc nghiệp vụ cho kịch bản {test_id}")
            
        except AssertionError as ae:
            print(f"    [FAILED] [{model_provider.upper()}] Xác nhận kịch bản {test_id} không vượt qua tiêu chuẩn chất lượng.")
            failed_cases.append(f"[{test_id}] {str(ae)}")

        # Giãn cách an toàn tối thiểu giữa các kịch bản biên độc lập
        time.sleep(2)

    if failed_cases:
        error_summary = "\n".join(failed_cases)
        pytest.fail(f"[FAILURE] [{model_provider.upper()}] Phát hiện lỗi kiểm định chất lượng tại {len(failed_cases)} kịch bản biên:\n{error_summary}")