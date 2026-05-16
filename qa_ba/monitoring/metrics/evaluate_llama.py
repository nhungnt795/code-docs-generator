import json
import os
import sys
import pandas as pd
import torch
import warnings
from rouge_score import rouge_scorer
import nltk
from nltk.translate.bleu_score import sentence_bleu, SmoothingFunction

warnings.filterwarnings("ignore")

# Tự động tải gói dữ liệu cần thiết của NLTK
packages = ['punkt', 'punkt_tab']
for pkg in packages:
    try:
        nltk.data.find(f'tokenizers/{pkg}')
    except LookupError:
        nltk.download(pkg, quiet=True)

# Khởi tạo kiểm tra thư viện CodeBERTScore
HAS_CODEBERT = False
try:
    import code_bert_score
    HAS_CODEBERT = True
except ImportError:
    pass

class LLMEvaluator:
    def __init__(self):
        self.rouge_scorer = rouge_scorer.RougeScorer(['rouge1', 'rouge2', 'rougeL'], use_stemmer=True)
        self.smoothie = SmoothingFunction().method4

    def compute_lexical_metrics(self, references: list, predictions: list) -> dict:
        """Tính toán điểm số BLEU và ROUGE trung bình."""
        total_bleu = 0
        total_rouge1 = 0
        total_rougeL = 0
        count = len(references)

        for ref, pred in zip(references, predictions):
            rouge_scores = self.rouge_scorer.score(ref, pred)
            total_rouge1 += rouge_scores['rouge1'].fmeasure
            total_rougeL += rouge_scores['rougeL'].fmeasure

            ref_tokens = [nltk.word_tokenize(ref.lower())]
            gen_tokens = nltk.word_tokenize(pred.lower())
            total_bleu += sentence_bleu(ref_tokens, gen_tokens, smoothing_function=self.smoothie)

        return {
            "bleu": (total_bleu / count) * 100 if count > 0 else 0,
            "rouge1": (total_rouge1 / count) * 100 if count > 0 else 0,
            "rougeL": (total_rougeL / count) * 100 if count > 0 else 0
        }

def parse_chat_format_jsonl(file_path):
    """Bóc tách dữ liệu hội thoại lồng nhau sang dạng danh sách phẳng."""
    inputs = []
    references = []
    
    with open(file_path, 'r', encoding='utf-8') as f:
        for line_idx, line in enumerate(f, start=1):
            if not line.strip():
                continue
            try:
                data = json.loads(line)
                messages = data.get("messages", [])
                
                user_content = ""
                assistant_content = ""
                
                for msg in messages:
                    if msg.get("role") == "user":
                        user_content = msg.get("content", "")
                    elif msg.get("role") == "assistant":
                        assistant_content = msg.get("content", "")
                
                # Chỉ lấy những dòng dữ liệu hợp lệ có đủ câu hỏi và đáp án mẫu
                if user_content and assistant_content:
                    inputs.append(user_content)
                    references.append(assistant_content)
            except Exception as e:
                print(f"  [!] Bỏ qua dòng {line_idx} do lỗi cú pháp JSON: {e}")
                
    return inputs, references

def qc_monitor_all_metrics(test_jsonl_path, predictions_jsonl_path):
    print("\n📊 [MONITORING] GIÁM SÁT CHẤT LƯỢNG RAG (PGVECTOR + LLaMA 3.1) - BACKEND DATA")
    
    # 1. Kiểm tra sự tồn tại của các file dữ liệu
    if not os.path.exists(test_jsonl_path) or not os.path.exists(predictions_jsonl_path):
        print(f"❌ Thất bại: Không tìm thấy file tại:\n- {test_jsonl_path}\n- {predictions_jsonl_path}")
        return

    # 2. Đọc và phân tích dữ liệu hội thoại lồng nhau
    print("[*] Đang bóc tách dữ liệu hội thoại từ file JSONL chuẩn của Backend...")
    test_inputs, references = parse_chat_format_jsonl(test_jsonl_path)
    
    # Giả định file predictions của LLaMA cũng được bóc tách tương tự 
    # (Hoặc nếu predictions chỉ lưu danh sách tài liệu thuần túy, ta đọc trực tiếp)
    try:
        preds_df = pd.read_json(predictions_jsonl_path, lines=True)
        pred_col = 'generated_doc' if 'generated_doc' in preds_df.columns else preds_df.columns[-1]
        predictions = preds_df[pred_col].astype(str).tolist()
    except Exception:
        # Hỗ trợ fallback nếu file predictions cũng dùng chung định dạng messages hội thoại
        _, predictions = parse_chat_format_jsonl(predictions_jsonl_path)

    # Đồng bộ độ dài dữ liệu
    min_len = min(len(references), len(predictions))
    if len(references) != len(predictions):
        print(f"⚠️ Cảnh báo: Số lượng dòng không khớp! Cắt ngắn dữ liệu về {min_len} mẫu.")
        references = references[:min_len]
        predictions = predictions[:min_len]

    if min_len == 0:
        print("❌ Lỗi: Không có dữ liệu hợp lệ để tiến hành đánh giá!")
        return

    # 3. Tính toán các chỉ số truyền thống (BLEU / ROUGE)
    print(f"[*] Đang đo lường chỉ số từ vựng trên {min_len} mẫu...")
    evaluator = LLMEvaluator()
    lexical_scores = evaluator.compute_lexical_metrics(references, predictions)

    bert_p, bert_r, bert_f1 = None, None, None

    # 4. Tính toán CodeBERTScore
    if HAS_CODEBERT:
        print("[*] Phát hiện thư viện code_bert_score! Bắt đầu tính toán chỉ số ngữ nghĩa sâu...")
        device = "cuda" if torch.cuda.is_available() else "cpu"
        print(f"    -> Đang chạy trên thiết bị phần cứng: {device.upper()}")
        
        try:
            P, R, F1, F3 = code_bert_score.score(
                cands=predictions, 
                refs=references, 
                lang="python", 
                model_type="xlm-roberta-base", 
                device=device, 
                batch_size=32, 
                verbose=False
            )
            bert_p = P.mean().item() * 100
            bert_r = R.mean().item() * 100
            bert_f1 = F1.mean().item() * 100
        except Exception as e:
            print(f"  ⚠️ Lỗi phát sinh khi chạy CodeBERTScore: {e}")
    else:
        print("ℹ️ Gợi ý: Chạy lệnh 'pip install code-bert-score' để tự động kích hoạt tính năng đánh giá ngữ nghĩa sâu.")

    # 5. Gom toàn bộ chỉ số vào bảng báo cáo Pandas
    metrics_list = ["BLEU", "ROUGE-1", "ROUGE-L"]
    scores_list = [
        round(lexical_scores['bleu'], 2),
        round(lexical_scores['rouge1'], 2),
        round(lexical_scores['rougeL'], 2)
    ]
    thresholds_list = ["> 25.0", "> 45.0", "> 40.0"]
    alerts_list = [
        "🟢 Ổn định" if lexical_scores['bleu'] > 25 else "🔴 Cần Retrain",
        "🟢 Ổn định" if lexical_scores['rouge1'] > 45 else "🔴 Kiểm tra Token",
        "🟢 Ổn định" if lexical_scores['rougeL'] > 40 else "🔴 Lỗi Logic"
    ]

    if bert_p is not None:
        metrics_list.extend(["BERT-Precision", "BERT-Recall", "BERT-F1 Score"])
        scores_list.extend([round(bert_p, 2), round(bert_r, 2), round(bert_f1, 2)])
        thresholds_list.extend(["> 70.0", "> 70.0", "> 70.0"])
        alerts_list.extend([
            "🟢 Ổn định" if bert_p > 70 else "🔴 Lệch Từ vựng (Bị ảo)",
            "🟢 Ổn định" if bert_r > 70 else "🔴 Thiếu Ý Nghiệp Vụ",
            "🟢 Ổn định" if bert_f1 > 70 else "🔴 Cần Tinh Chỉnh Prompt"
        ])

    report = pd.DataFrame({
        "Metric": metrics_list,
        "Score": scores_list,
        "Ngưỡng An Toàn": thresholds_list,
        "Cảnh báo (Alert)": alerts_list
    })

    print("\n" + report.to_string(index=False))
    print("\n[+] Hoàn tất phiên giám sát chất lượng!")

if __name__ == "__main__":
    # Cấu hình chuẩn trỏ vào thư mục data/processed/ thực tế trên máy bạn
    test_data = "data/processed/test_data.jsonl"
    preds_data = "data/processed/llama_predictions.jsonl" 
    
    qc_monitor_all_metrics(test_data, preds_data)