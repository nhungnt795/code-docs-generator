import requests
import os

class LlamaDocstringGenerator:
    def __init__(self, api_url=None):
        print("[*] Đang khởi tạo kết nối tới LLM Engine trên Kaggle (qua Cloudflare)...")
        self.api_url = api_url or os.getenv("KAGGLE_API_URL", "https://streams-surprising-dawn-nevada.trycloudflare.com/generate_docstring")

    def generate(self, prompt: str) -> str:
        payload = {
            "prompt": prompt 
        }
        
        # Code giờ chỉ còn gọn gàng thế này thôi, không cần lách header nữa
        headers = {
            "Content-Type": "application/json"
        }
        
        try:
            response = requests.post(
                self.api_url,
                json=payload,
                headers=headers,
                timeout=240  # Vẫn để 4 phút cho LLM có thời gian "suy nghĩ"
            )
            
            response.raise_for_status() 
            
            try:
                result = response.json()
            except ValueError:
                return f"[!] Lỗi Decode: Server trả về không phải JSON. Nội dung thực tế: {response.text[:200]}"
            
            return result.get("docstring", "[!] Cảnh báo: JSON trả về không có trường 'docstring'.")
            
        except requests.exceptions.Timeout:
            return "[!] Lỗi: Server Kaggle phản hồi quá lâu (Timeout)."
        except requests.exceptions.RequestException as e:
            return f"[!] Lỗi kết nối API Kaggle: {str(e)}"
        

