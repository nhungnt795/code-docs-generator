import requests
import base64
import time
import os
from urllib.parse import quote
from dotenv import load_dotenv

load_dotenv()
GITHUB_TOKEN = os.getenv('GITHUB_TOKEN')
HEADERS = {'Authorization': f'token {GITHUB_TOKEN}', 'Accept': 'application/vnd.github.v3+json'}
RAW_DIR = 'data/raw'

TARGET_FILES_PER_LANG = 500
MAX_PAGES = 5

LANGS_CONFIG = {
    'python':     {'query': 'Parameters Returns docstring',  'ext': '.py'},
    'javascript': {'query': '@param @returns @description',  'ext': '.js'},
    'java':       {'query': '@param @return @throws',        'ext': '.java'},
    'cpp':        {'query': '@brief @param @return',         'ext': '.cpp'},
    'typescript': {'query': '@param @returns interface',     'ext': '.ts'},
    'rust':       {'query': 'Arguments Returns fn pub',      'ext': '.rs'},
}

def safe_get(url, retries=5):
    for i in range(retries):
        try:
            res = requests.get(url, headers=HEADERS, timeout=15)
            if res.status_code in [403, 429]:
                print("    [!] Rate limit — nghỉ 60 giây...")
                time.sleep(60)
                continue
            return res
        except requests.exceptions.RequestException as e:
            print(f"    [!] Lỗi kết nối lần {i+1}: {e}")
            time.sleep(5)
    return None

def crawl_all():
    summary = {}

    for lang, config in LANGS_CONFIG.items():
        print(f"\n{'='*50}")
        print(f"[*] {lang.upper()} — mục tiêu: {TARGET_FILES_PER_LANG} file")
        print(f"{'='*50}")

        lang_path = os.path.join(RAW_DIR, lang)
        os.makedirs(lang_path, exist_ok=True)

        saved_files = set()
        file_count = 0
        
        ext_filter = config['ext'].strip('.')

        for page in range(1, MAX_PAGES + 1):
            if file_count >= TARGET_FILES_PER_LANG:
                print(f"  [✓] Đủ {TARGET_FILES_PER_LANG} file, dừng sớm tại trang {page}")
                break

            encoded_query = quote(config['query'])
            
            url = (
                f"https://api.github.com/search/code"
                f"?q={encoded_query}+language:{lang}+extension:{ext_filter}"
                f"&per_page=100&page={page}"
            )
            
            res = safe_get(url)

            if not (res and res.status_code == 200):
                status = res.status_code if res else "Mất kết nối"
                print(f"  [!] Bỏ qua trang {page} — lỗi: {status}")
                continue

            items = res.json().get('items', [])
            if not items:
                print(f"  [!] Trang {page} trống, dừng {lang}")
                break

            for item in items:
                if file_count >= TARGET_FILES_PER_LANG:
                    break

                file_name = item['name']
                
                if not file_name.endswith(config['ext']):
                    continue

                repo_slug = item['repository']['full_name'].replace("/", "_")
                save_name = f"{repo_slug}_{file_name}"

                if save_name in saved_files:
                    continue

                f_res = safe_get(item['url'])
                if not (f_res and f_res.status_code == 200):
                    continue

                try:
                    content = base64.b64decode(
                        f_res.json()['content']
                    ).decode('utf-8', errors='ignore')

                    if not (500 < len(content) < 20000):
                        continue

                    with open(os.path.join(lang_path, save_name), 'w', encoding='utf-8') as f:
                        f.write(content)

                    saved_files.add(save_name)
                    file_count += 1

                except Exception as e:
                    print(f"    [!] Lỗi file {file_name}: {e}")

            print(f"  [+] Trang {page}/{MAX_PAGES} — {file_count}/{TARGET_FILES_PER_LANG} file")
            time.sleep(2)

        summary[lang] = file_count
        print(f"  [✓] {lang.upper()} xong: {file_count} file")

    print(f"\n{'='*50}")
    print("[TỔNG KẾT]")
    total = 0
    for lang, count in summary.items():
        bar = '█' * (count // 50)
        print(f"  {lang:<12}: {count:>4} file  {bar}")
        total += count
    print(f"  {'TOTAL':<12}: {total:>4} file")
    print(f"  Ước tính mẫu finetune: ~{total * 3}–{total * 4} cặp")
    print(f"{'='*50}")

if __name__ == "__main__":
    crawl_all()