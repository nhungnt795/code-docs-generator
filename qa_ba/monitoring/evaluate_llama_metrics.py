import pandas as pd
from evaluate import load
import warnings
import os
import json
warnings.filterwarnings("ignore")

def qc_monitor_model_performance(test_jsonl_path, predictions_jsonl_path):
    print("\n📊 [MONITORING] GIÁM SÁT CHẤT LƯỢNG RAG (PGVECTOR + LLaMA 3.1)")
    
    if not os.path.exists(test_jsonl_path) or not os.path.exists(predictions_jsonl_path):
        print(f"❌ Thất bại: Không tìm thấy file tại:\n- {test_jsonl_path}\n- {predictions_jsonl_path}")
        return

    bleu_metric = load("bleu")
    rouge_metric = load("rouge")
    
    # 1. Đọc dữ liệu JSONL chuẩn của dự án (mỗi dòng là 1 chuỗi JSON)
    print("[*] Đang đọc dữ liệu JSONL...")
    test_df = pd.read_json(test_jsonl_path, lines=True)
    preds_df = pd.read_json(predictions_jsonl_path, lines=True)
    
    # 2. Tự động nội suy tên cột (Thường Data finetune LLaMA dùng key 'output' hoặc 'response')
    # QA Note: Có thể sửa cứng tên cột này nếu team Dev quy ước tên khác
    gt_col = 'output' if 'output' in test_df.columns else test_df.columns[-1]
    pred_col = 'generated_doc' if 'generated_doc' in preds_df.columns else preds_df.columns[-1]
    
    references = test_df[gt_col].astype(str).tolist() 
    predictions = preds_df[pred_col].astype(str).tolist()
    
    bleu_refs = [[ref] for ref in references]
    
    print("[*] Đang đo lường chỉ số BLEU và ROUGE...")
    bleu_results = bleu_metric.compute(predictions=predictions, references=bleu_refs)
    rouge_results = rouge_metric.compute(predictions=predictions, references=references)
    
    # 3. Tạo bảng báo cáo chất lượng
    report = pd.DataFrame({
        "Metric": ["BLEU", "ROUGE-1", "ROUGE-L"],
        "Score": [
            round(bleu_results['bleu'] * 100, 2),
            round(rouge_results['rouge1'] * 100, 2),
            round(rouge_results['rougeL'] * 100, 2)
        ],
        "Ngưỡng An Toàn": ["> 25.0", "> 45.0", "> 40.0"],
        "Cảnh báo (Alert)": [
            "🟢 Ổn định" if bleu_results['bleu'] * 100 > 25 else "🔴 Cần Retrain",
            "🟢 Ổn định" if rouge_results['rouge1'] * 100 > 45 else "🔴 Kiểm tra Token",
            "🟢 Ổn định" if rouge_results['rougeL'] * 100 > 40 else "🔴 Lỗi Logic"
        ]
    })
    
    print("\n" + report.to_string(index=False))
    print("\n[+] Hoàn tất phiên giám sát chất lượng!")

if __name__ == "__main__":
    # Cấu hình đường dẫn trỏ thẳng vào thư mục data thực tế của bạn
    test_data = "data/feature/processed/test_data.jsonl"
    preds_data = "data/feature/processed/llama_predictions.jsonl" # File do mô hình sinh ra
    
    qc_monitor_model_performance(test_data, preds_data)
    import pandas as pd
from evaluate import load
import warnings
import os
import json
warnings.filterwarnings("ignore")

def qc_monitor_model_performance(test_jsonl_path, predictions_jsonl_path):
    print("\n📊 [MONITORING] GIÁM SÁT CHẤT LƯỢNG RAG (PGVECTOR + LLaMA 3.1)")
    
    if not os.path.exists(test_jsonl_path) or not os.path.exists(predictions_jsonl_path):
        print(f"❌ Thất bại: Không tìm thấy file tại:\n- {test_jsonl_path}\n- {predictions_jsonl_path}")
        return

    bleu_metric = load("bleu")
    rouge_metric = load("rouge")
    
    # 1. Đọc dữ liệu JSONL chuẩn của dự án (mỗi dòng là 1 chuỗi JSON)
    print("[*] Đang đọc dữ liệu JSONL...")
    test_df = pd.read_json(test_jsonl_path, lines=True)
    preds_df = pd.read_json(predictions_jsonl_path, lines=True)
    
    # 2. Tự động nội suy tên cột (Thường Data finetune LLaMA dùng key 'output' hoặc 'response')
    # QA Note: Có thể sửa cứng tên cột này nếu team Dev quy ước tên khác
    gt_col = 'output' if 'output' in test_df.columns else test_df.columns[-1]
    pred_col = 'generated_doc' if 'generated_doc' in preds_df.columns else preds_df.columns[-1]
    
    references = test_df[gt_col].astype(str).tolist() 
    predictions = preds_df[pred_col].astype(str).tolist()
    
    bleu_refs = [[ref] for ref in references]
    
    print("[*] Đang đo lường chỉ số BLEU và ROUGE...")
    bleu_results = bleu_metric.compute(predictions=predictions, references=bleu_refs)
    rouge_results = rouge_metric.compute(predictions=predictions, references=references)
    
    # 3. Tạo bảng báo cáo chất lượng
    report = pd.DataFrame({
        "Metric": ["BLEU", "ROUGE-1", "ROUGE-L"],
        "Score": [
            round(bleu_results['bleu'] * 100, 2),
            round(rouge_results['rouge1'] * 100, 2),
            round(rouge_results['rougeL'] * 100, 2)
        ],
        "Ngưỡng An Toàn": ["> 25.0", "> 45.0", "> 40.0"],
        "Cảnh báo (Alert)": [
            "🟢 Ổn định" if bleu_results['bleu'] * 100 > 25 else "🔴 Cần Retrain",
            "🟢 Ổn định" if rouge_results['rouge1'] * 100 > 45 else "🔴 Kiểm tra Token",
            "🟢 Ổn định" if rouge_results['rougeL'] * 100 > 40 else "🔴 Lỗi Logic"
        ]
    })
    
    print("\n" + report.to_string(index=False))
    print("\n[+] Hoàn tất phiên giám sát chất lượng!")

    
    # BỔ SUNG: Trả về kết quả để Pytest có thể dùng lệnh assert
    return bleu_results['bleu'] * 100, rouge_results['rouge1'] * 100, rouge_results['rougeL'] * 100

if __name__ == "__main__":
    # Cấu hình đường dẫn trỏ thẳng vào thư mục data thực tế của bạn
    test_data = "data/feature/processed/test_data.jsonl"
    preds_data = "data/feature/processed/llama_predictions.jsonl" # File do mô hình sinh ra
    
    qc_monitor_model_performance(test_data, preds_data)
    
    