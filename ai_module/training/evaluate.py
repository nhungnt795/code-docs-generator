import json
import code_bert_score
import torch

PREDICTIONS_FILE = "ai_module/serving/predictions.jsonl"

print("[*] Đang đọc file kết quả...")
predictions = []
references = []

with open(PREDICTIONS_FILE, 'r', encoding='utf-8') as f:
    for line in f:
        try:
            data = json.loads(line)
            pred_text = data.get("predicted_docstring", "").strip()
            
            ref_text = ""
            original_messages = data.get("original_messages", [])
            for msg in reversed(original_messages):
                if msg.get("role") == "assistant":
                    ref_text = msg.get("content", "").strip()
                    break
            
            # CHỐNG LỆCH MẢNG: Chỉ tóm những dòng có đủ cả 2 vế
            if pred_text and ref_text:
                predictions.append(pred_text)
                references.append(ref_text)
        except Exception as e:
            print(f"[!] Bỏ qua 1 dòng lỗi cú pháp JSON: {e}")

print(f"[*] Đã tải xong {len(predictions)} cặp câu hỏi - đáp án hợp lệ.")
print("[*] Bắt đầu chấm điểm CodeBERTScore...")

device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"[*] Đang chạy đánh giá trên thiết bị: {device.upper()}")

P, R, F1, F3 = code_bert_score.score(
    cands=predictions, 
    refs=references, 
    lang="python",                     
    model_type="xlm-roberta-base",     
    device=device,                     # Ép chạy GPU nếu có
    batch_size=32,                     # Chia nhỏ mỗi lần chấm 32 câu để chống tràn RAM
    verbose=True
)

print(f"- Precision trung bình: {P.mean().item():.4f}")
print(f"- Recall trung bình: {R.mean().item():.4f}")
print(f"- F1 Score trung bình: {F1.mean().item():.4f}")
print(f"- F3 Score trung bình: {F3.mean().item():.4f}") 