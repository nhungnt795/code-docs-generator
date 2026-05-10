import os
import re
import json
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from tqdm import tqdm
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()
RAW_DIR = 'data/raw'
PROCESSED_DIR = 'data/processed'
JSONL_FILE = os.path.join(PROCESSED_DIR, 'llama31_finetune_data_pro.jsonl')

GEMINI_API_KEY = os.getenv('GEMINI_API_KEY')
if not GEMINI_API_KEY:
    print("[!] LỖI: Chưa có GEMINI_API_KEY trong file .env")
    exit(1)

genai.configure(api_key=GEMINI_API_KEY)
model = genai.GenerativeModel('gemini-2.5-flash')

BATCH_SIZE = 10
MAX_WORKERS = 5 # Chạy song song 5 luồng cùng lúc (Có thể tăng lên 10 nếu mạng khỏe)

def extract_logic(content, lang):
    lang_key = lang.lower()
    patterns = {
        'python': r'((?:async\s+)?def\s+\w+\s*\(.*?\):(?:\n\s+.+)+)',
        'java': r'((?:public|private|protected|static)\s+[\w\<\>\[\]]+\s+\w+\s*\(.*?\)\s*\{[\s\S]*?\})',
        'cpp': r'((?:virtual|inline|static)?\s*[\w\<\>\[\]]+\s+\w+\s*\(.*?\)\s*\{[\s\S]*?\})',
        'javascript': r'((?:async\s+)?function\s+\w+\s*\(.*?\)\s*\{[\s\S]*?\}|(?:const|let|var)\s+\w+\s*=\s*(?:async\s+)?\(.*?\)\s*=>\s*\{[\s\S]*?\})',
        'typescript': r'((?:async\s+)?function\s+\w+\s*\(.*?\)\s*(?::\s*[\w\<\>\[\]]+)?\s*\{[\s\S]*?\}|(?:const|let|var)\s+\w+\s*=\s*(?:async\s+)?\(.*?\)\s*(?::\s*[\w\<\>\[\]]+)?\s*=>\s*\{[\s\S]*?\})',
        'rust': r'((?:pub\s+)?(?:async\s+)?fn\s+\w+\s*\(.*?\)\s*(?:->\s*[\w\<\>:]+\s*)?\{[\s\S]*?\})'
    }
    pattern = patterns.get(lang_key)
    return re.findall(pattern, content) if pattern else []

def split_code_and_doc(code_snippet, lang):
    docstring = ""
    bare_code = code_snippet
    if lang.lower() == 'python':
        match = re.search(r'("""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\')', code_snippet)
        if match:
            docstring = match.group(1)
            bare_code = code_snippet.replace(docstring, '').strip()
    else:
        match = re.search(r'(/\*[\s\S]*?\*/)', code_snippet)
        if match:
            docstring = match.group(1)
            bare_code = code_snippet.replace(docstring, '').strip()
    return bare_code, docstring

def process_gemini_batch(batch_data, lang):
    """Xử lý API không có time.sleep mặc định, chỉ sleep khi gặp lỗi mạng/quota"""
    if not batch_data: return []

    prompt = f"""Bạn là Kỹ sư phần mềm chuyên về {lang.upper()}.
        Viết tài liệu kỹ thuật chuẩn Markdown bằng Tiếng Việt cho các đoạn mã nguồn trong mảng JSON đầu vào.

        YÊU CẦU:
        1. TRẢ VỀ ĐÚNG MẢNG JSON: [ {{"id": "id_code", "docstring": "khối_markdown"}} ]
        2. Cấu trúc Markdown bắt buộc (không dùng icon/emoji):
        ### Tên hàm/lớp
        **Mô tả:** Giới thiệu ngắn gọn chức năng.
        **Tham số:** Liệt kê các tham số và kiểu dữ liệu.
        **Trả về:** Kiểu dữ liệu và ý nghĩa kết quả.
        3. Giữ nguyên thuật ngữ tiếng Anh (API, thread, socket, UI/UX...).
        4. Không giải thích thêm ngoài JSON.

        Dữ liệu đầu vào:
        {json.dumps(batch_data, ensure_ascii=False)}
        """
    # Cơ chế Retry chuẩn: Thử tối đa 3 lần nếu mạng chập chờn
    for attempt in range(3):
        try:
            response = model.generate_content(
                prompt,
                generation_config=genai.types.GenerationConfig(
                    response_mime_type="application/json",
                )
            )
            return json.loads(response.text)
        except Exception as e:
            if "429" in str(e):
                # Bản trả phí rất khó dính 429, nhưng nếu dính thì chỉ cần nghỉ 5s (không phải 60s như free)
                time.sleep(5)
            else:
                time.sleep(2)
    return []

def process_to_jsonl():
    if not os.path.exists(RAW_DIR):
        return

    os.makedirs(PROCESSED_DIR, exist_ok=True)
    dataset = []

    for lang in os.listdir(RAW_DIR):
        lang_path = os.path.join(RAW_DIR, lang)
        if not os.path.isdir(lang_path): continue
        
        print(f"\n[*] Đang trích xuất code ngôn ngữ: {lang.upper()}")
        all_files = os.listdir(lang_path)
        
        # 1. Gom toàn bộ code thành các mẻ (batches) trước
        batches = []
        current_batch = []
        
        for fname in all_files:
            if fname.endswith('README.md'): continue 
            try:
                with open(os.path.join(lang_path, fname), 'r', encoding='utf-8') as f:
                    snippets = extract_logic(f.read(), lang)
                    for snip in snippets[:3]: 
                        bare_code, _ = split_code_and_doc(snip.strip(), lang)
                        if len(bare_code) < 10: continue

                        current_batch.append({
                            "id": f"{fname}_{len(current_batch)}",
                            "code": bare_code
                        })

                        if len(current_batch) >= BATCH_SIZE:
                            batches.append(current_batch)
                            current_batch = []
            except Exception:
                pass 
                
        if current_batch:
            batches.append(current_batch)

        if not batches:
            continue

        # 2. Đẩy mẻ lên API xử lý đa luồng (Multithreading) + Hiện thanh tiến độ
        print(f"[*] Bắt đầu gọi API cho {len(batches)} mẻ (Chạy {MAX_WORKERS} luồng song song)...")
        
        with ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
            # Khởi tạo các luồng chạy
            future_to_batch = {executor.submit(process_gemini_batch, b, lang): b for b in batches}
            
            # tqdm tạo thanh tiến độ siêu mượt
            for future in tqdm(as_completed(future_to_batch), total=len(batches), desc=f"Tiến độ {lang.upper()}", unit="mẻ"):
                original_batch = future_to_batch[future]
                try:
                    gemini_results = future.result()
                    
                    # Ghép kết quả vào dataset
                    for res in gemini_results:
                        original_item = next((item for item in original_batch if item["id"] == res.get("id")), None)
                        if original_item and res.get("docstring"):
                            dataset.append({
                                "messages": [
                                    {
                                        "role": "system",
                                        "content": f"Bạn là một chuyên gia phần mềm ngôn ngữ {lang.upper()}. Viết tài liệu kỹ thuật chuẩn Markdown bằng Tiếng Việt cho mã nguồn được cung cấp. Tuyệt đối không sử dụng icon/emoji. Chỉ trả về khối tài liệu."
                                    },
                                    {
                                        "role": "user",
                                        "content": f"Viết tài liệu kỹ thuật cho đoạn code {lang.upper()} sau:\n\n{original_item['code']}"
                                    },
                                    {
                                        "role": "assistant",
                                        "content": res["docstring"]
                                    }
                                ]
                            })
                except Exception as e:
                    pass

    # 3. Ghi ra file
    if dataset:
        with open(JSONL_FILE, 'w', encoding='utf-8') as f:
            for item in dataset:
                f.write(json.dumps(item, ensure_ascii=False) + '\n')
        print(f"\n[THÀNH CÔNG] Đã tạo dataset gồm {len(dataset)} CẶP.")
    else:
        print("\n[!] Không tạo được mẫu dữ liệu nào.")

if __name__ == "__main__":
    process_to_jsonl()