import requests
import os

class LlamaDocstringGenerator:
    def __init__(self, api_key=None):
        # Lấy API Key từ biến môi trường
        self.api_key = api_key or os.getenv("GROQ_API_KEY")
        self.api_url = "https://api.groq.com/openai/v1/chat/completions"
        print("[*] Đang khởi tạo Llama 3.1 Engine qua Groq Cloud...")

    def generate(self, prompt: str) -> str:
        if not self.api_key:
            return "[!] Lỗi: Thiếu GROQ_API_KEY trong file .env"

        # Đảm bảo cấu hình payload đúng chuẩn API Groq
        payload = {
            "model": "llama-3.1-8b-instant",
            "messages": [
                {
                    "role": "system", 
                    "content": "Bạn là chuyên gia viết tài liệu kỹ thuật bằng Tiếng Việt. Chỉ trả về nội dung Markdown."
                },
                {"role": "user", "content": prompt}
            ],
            "temperature": 0.3, # Giảm xuống để kết quả ổn định hơn
            "max_tokens": 1024,
            "top_p": 1
        }
        
        headers = {
            "Authorization": f"Bearer {self.api_key}",
            "Content-Type": "application/json"
        }
        
        try:
            response = requests.post(self.api_url, json=payload, headers=headers, timeout=60)
            
            # Nếu không phải 200, trả về thông báo lỗi chi tiết để dễ debug
            if response.status_code != 200:
                return f"[!] Groq API Error {response.status_code}: {response.text}"
            
            result = response.json()
            return result['choices'][0]['message']['content'].strip()
            
        except requests.exceptions.RequestException as e:
            return f"[!] Lỗi kết nối hệ thống: {str(e)}"