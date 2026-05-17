import json
import os
import sys

# Thiết lập PYTHONPATH để import được ai_module
current_dir = os.path.dirname(os.path.abspath(__file__))
project_root = os.path.abspath(os.path.join(current_dir, "../../../"))
if project_root not in sys.path:
    sys.path.insert(0, project_root)

# IMPORT THẬT: Gọi trực tiếp bộ não GraphRAG từ ai_module của dự án
try:
    from ai_module.model.rag_engine import GraphRAGEngine
    print("[+] Đã kết nối thành công với GraphRAGEngine của ai_module!")
except ImportError as e:
    print(f"❌ Không thể import ai_module. Lỗi: {e}")
    print("Mẹo: Đảm bảo bạn đang đứng ở thư mục gốc của dự án khi chạy script.")
    sys.exit(1)

def generate_real_predictions(test_path, preds_path):
    print("[*] Đang khởi tạo hệ thống GraphRAG thật...")
    # Khởi tạo Engine (hệ thống sẽ tự nạp CodeBERT, kết nối PGVector và LLM)
    rag_engine = GraphRAGEngine()
    
    print("[*] Đọc file test_data.jsonl để lấy mã nguồn chạy thử...")
    if not os.path.exists(test_path):
        print(f"❌ Không tìm thấy file test tại: {test_path}")
        return

    predictions = []
    
    # Để kiểm tra nhanh hiệu năng thực tế của model, ta sẽ lấy 5-10 mẫu để test trước 
    # (Tránh chạy hết cả 300 mẫu ngay lập tức vì sẽ mất nhiều thời gian kết nối API LLM)
    max_test_samples = 5 
    
    with open(test_path, 'r', encoding='utf-8') as f:
        lines = [line for line in f if line.strip()]
        
    print(f"[*] Bắt đầu chạy thử nghiệm thực tế trên {min(max_test_samples, len(lines))} mẫu dữ liệu...")
    
    for idx, line in enumerate(lines[:max_test_samples], start=1):
        try:
            data = json.loads(line)
            messages = data.get("messages", [])
            
            # Trích xuất đoạn code đầu vào (user) và ngôn ngữ
            code_snippet = ""
            language = "PYTHON"
            
            for msg in messages:
                if msg.get("role") == "user":
                    code_snippet = msg.get("content", "")
                elif msg.get("role") == "system":
                    # Lấy ngôn ngữ nếu cần thiết
                    pass
            
            if not code_snippet:
                continue
                
            print(f"  -> [{idx}/{max_test_samples}] Đang gửi code lên GraphRAGEngine để sinh tài liệu thực tế...")
            
            # GỌI LOGIC THẬT: Sử dụng hàm sinh tài liệu thật của ai_module
            # Lưu ý: Thay đổi tên hàm sinh tài liệu tương ứng với cấu trúc thật trong GraphRAGEngine của bạn
            # (Ví dụ: generate_docstring, generate_documentation, hoặc query...)
            real_gen_doc = rag_engine.process_query(code_snippet)
            
            predictions.append({
                "generated_doc": real_gen_doc
            })
            print(f"     [+] Sinh tài liệu thành công!")
            
        except Exception as e:
            print(f"  [🔴] Lỗi khi xử lý mẫu thứ {idx}: {e}")
            predictions.append({
                "generated_doc": ""
            })

    # Ghi kết quả thực tế từ ai_module ra file predictions
    os.makedirs(os.path.dirname(preds_path), exist_ok=True)
    with open(preds_path, 'w', encoding='utf-8') as f:
        for pred in predictions:
            f.write(json.dumps(pred, ensure_ascii=False) + "\n")
            
    print(f"🟢 Đã ghi nhận kết quả sinh thực tế từ ai_module tại: {preds_path}")

if __name__ == "__main__":
    test_file = "data/processed/test_data.jsonl"
    preds_file = "data/processed/llama_predictions.jsonl"
    generate_real_predictions(test_file, preds_file)