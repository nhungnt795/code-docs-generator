import sys
import os
import json
from tqdm import tqdm
from groq import Groq  # Thư viện gọi API của Groq

# Định nghĩa lại đường dẫn đúng cấu hình thư mục của bạn
TEST_FILE = "data/processed/test_data.jsonl"          
OUTPUT_FILE = "ai_module/serving/predictions_groq.jsonl"  # Đổi tên file để tránh ghi đè

def main():
    print("[*] Đang kết nối tới hạ tầng Groq Cloud...")
    
    # Lấy API Key từ môi trường hệ thống
    api_key = os.environ.get("GROQ_API_KEY")
    if not api_key:
        print("❌ LỖI: Thiếu biến môi trường GROQ_API_KEY. Hãy chạy lệnh set key trước!")
        return
        
    client = Groq(api_key=api_key)
    
    print(f"[*] Đang đọc file test đầu vào: {TEST_FILE}")
    if not os.path.exists(TEST_FILE):
        print(f"❌ LỖI: Không tìm thấy file {TEST_FILE}")
        return
        
    with open(TEST_FILE, 'r', encoding='utf-8') as f:
        test_data = [json.loads(line) for line in f][:100]
        
    print(f"[*] Tổng số mẫu cần dự đoán qua GROQ: {len(test_data)}")
    
    # Tạo thư mục lưu file nếu chưa có
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as out_f:
        # Quét qua tập dữ liệu test
        for data in tqdm(test_data, desc="GROQ đang sinh Docstring"):
            original_messages = data["messages"]
            
            # Lọc chỉ lấy tin nhắn của system và user để gửi prompt
            prompt_messages = [msg for msg in original_messages if msg["role"] in ["system", "user"]]
            
            try:
                # Bắn payload lên Groq Cloud dùng con Llama 3.1 8B gốc
                chat_completion = client.chat.completions.create(
                    messages=prompt_messages,
                    model="llama-3.1-8b-instant",  # Tên model chuẩn trên Groq Cloud
                    temperature=0.2,
                    top_p=0.9,
                    max_tokens=512
                )
                
                predicted_text = chat_completion.choices[0].message.content.strip()
                
                # Đóng gói đúng định dạng JSONL giống Dev để Pytest bốc được data
                result_obj = {
                    "predicted_docstring": predicted_text,
                    "original_messages": original_messages 
                }
                
                out_f.write(json.dumps(result_obj, ensure_ascii=False) + '\n')
                
            except Exception as e:
                print(f"\n⚠️ Lỗi API tại một mẫu dữ liệu: {e}")
                # Nếu dính Rate limit, nghỉ ngơi một chút rồi chạy tiếp
                import time
                time.sleep(5)
                
    print(f"\n[+] HOÀN TẤT ĐỐI CHỨNG! Đã lưu kết quả của Groq ra file: {OUTPUT_FILE}")

if __name__ == "__main__":
    main()