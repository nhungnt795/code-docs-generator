import json
import os

# Cấu hình đường dẫn trỏ thẳng vào thư mục data thực tế của bạn
test_file = "data/feature/processed/test_data.jsonl"
pred_file = "data/feature/processed/llama_predictions.jsonl"

print("🛠️ [QA MOCK] Đang tạo dữ liệu dự đoán giả lập để test luồng giám sát...")

# Lùi ra thư mục gốc để lấy đúng đường dẫn tương đối
base_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), '../../'))
test_path = os.path.join(base_dir, test_file)
pred_path = os.path.join(base_dir, pred_file)

if not os.path.exists(test_path):
    print(f"❌ Không tìm thấy file gốc tại {test_path}. Đang tạo một file test_data.jsonl mẫu...")
    # Nếu file test_data.jsonl thật của Dev bị rỗng hoặc chưa tải về, QA tự tạo luôn 2 dòng mẫu
    os.makedirs(os.path.dirname(test_path), exist_ok=True)
    sample_data = [
        {"input": "def add(a, b): return a + b", "output": "Hàm này tính tổng hai số a và b."},
        {"input": "def connect(): pass", "output": "Sử dụng để kết nối tới cơ sở dữ liệu."}
    ]
    with open(test_path, 'w', encoding='utf-8') as f:
        for item in sample_data:
            f.write(json.dumps(item, ensure_ascii=False) + '\n')

mock_predictions = []
with open(test_path, 'r', encoding='utf-8') as f:
    for line in f:
        data = json.loads(line.strip())
        
        # Lấy đáp án chuẩn (Ground Truth)
        original_text = data.get("output", data.get("response", ""))
        
        # Tạo "nhiễu" (Noise) giả lập LLaMA sinh câu trả lời hơi khác bản gốc một chút 
        # để điểm BLEU/ROUGE không bị 100% ảo tuyệt đối
        mock_text = original_text.replace("Hàm", "Phương thức").replace("Sử dụng", "Dùng") + " [LLaMA 3.1 sinh ra]"
        
        # Đóng gói vào chuẩn định dạng mới
        mock_data = data.copy()
        mock_data["generated_doc"] = mock_text
        mock_predictions.append(mock_data)

# Xuất file kết quả giả lập
with open(pred_path, 'w', encoding='utf-8') as f:
    for item in mock_predictions:
        f.write(json.dumps(item, ensure_ascii=False) + '\n')
        
print(f"✅ Đã tạo thành công file {pred_file}!")
print("🚀 Bây giờ bạn có thể chạy file evaluate_llama_metrics.py để nghiệm thu rồi nhé!")