import os
import re
import uuid
import hashlib
import pandas as pd
import psycopg2
import shutil
from psycopg2.extras import execute_values
from psycopg2.extensions import ISOLATION_LEVEL_AUTOCOMMIT
from datetime import datetime
from dotenv import load_dotenv

load_dotenv()
RAW_DIR = 'data/raw'
PROCESSED_DIR = 'data/processed/cleaned_code'

DB_USER = os.getenv('DB_USER')
DB_PASS = os.getenv('DB_PASS')
DB_HOST = os.getenv('DB_HOST')
DB_PORT = os.getenv('DB_PORT')
DB_NAME = os.getenv('DB_NAME')
TABLE_NAME = 'code_snippets'


def setup_database_and_table():
    """Tạo Database nếu chưa có, và tạo Bảng với Ràng buộc Duy nhất (Unique Constraint)"""
    try:
        conn = psycopg2.connect(user=DB_USER, password=DB_PASS, host=DB_HOST, port=DB_PORT, database=DB_NAME)
        conn.set_isolation_level(ISOLATION_LEVEL_AUTOCOMMIT)
        cursor = conn.cursor()
        
        cursor.execute(f"SELECT 1 FROM pg_catalog.pg_database WHERE datname = '{DB_NAME}'")
        if not cursor.fetchone():
            cursor.execute(f"CREATE DATABASE {DB_NAME}")
        cursor.close()
        conn.close()

        # 2. Kết nối vào database vừa tạo để setup bảng
        conn = psycopg2.connect(user=DB_USER, password=DB_PASS, host=DB_HOST, port=DB_PORT, database=DB_NAME)
        cursor = conn.cursor()
        
        # Tạo bảng với khóa UNIQUE là snippet_hash để phục vụ cho tính năng UPSERT
        create_table_query = f"""
        CREATE TABLE IF NOT EXISTS {TABLE_NAME} (
            id VARCHAR(50) PRIMARY KEY,
            language VARCHAR(50),
            repo_name VARCHAR(255),
            file_name VARCHAR(255),
            code_snippet TEXT,
            snippet_hash VARCHAR(64) UNIQUE
        );
        """
        cursor.execute(create_table_query)
        conn.commit()
        cursor.close()
        conn.close()
    except Exception as e:
        print(f"[!] Lỗi khi setup Database/Table: {e}")

def extract_logic(content, lang):
    lang_key = lang.lower()
    patterns = {
        'python': r'((?:async\s+)?def\s+\w+\s*\(.*?\):(?:\n\s+.+)+)',
        'java': r'((?:public|private|protected|static)\s+[\w\<\>\[\]]+\s+\w+\s*\(.*?\)\s*\{[\s\S]*?\})',
        'c++': r'((?:virtual|inline|static)?\s*[\w\<\>\[\]]+\s+\w+\s*\(.*?\)\s*\{[\s\S]*?\})',
        'cpp': r'((?:virtual|inline|static)?\s*[\w\<\>\[\]]+\s+\w+\s*\(.*?\)\s*\{[\s\S]*?\})',
        'javascript': r'((?:async\s+)?function\s+\w+\s*\(.*?\)\s*\{[\s\S]*?\}|(?:const|let|var)\s+\w+\s*=\s*(?:async\s+)?\(.*?\)\s*=>\s*\{[\s\S]*?\})',
        'js': r'((?:async\s+)?function\s+\w+\s*\(.*?\)\s*\{[\s\S]*?\}|(?:const|let|var)\s+\w+\s*=\s*(?:async\s+)?\(.*?\)\s*=>\s*\{[\s\S]*?\})',
        'typescript': r'((?:async\s+)?function\s+\w+\s*\(.*?\)\s*(?::\s*[\w\<\>\[\]]+)?\s*\{[\s\S]*?\}|(?:const|let|var)\s+\w+\s*=\s*(?:async\s+)?\(.*?\)\s*(?::\s*[\w\<\>\[\]]+)?\s*=>\s*\{[\s\S]*?\})',
        'ts': r'((?:async\s+)?function\s+\w+\s*\(.*?\)\s*(?::\s*[\w\<\>\[\]]+)?\s*\{[\s\S]*?\}|(?:const|let|var)\s+\w+\s*=\s*(?:async\s+)?\(.*?\)\s*(?::\s*[\w\<\>\[\]]+)?\s*=>\s*\{[\s\S]*?\})',
        'rust': r'((?:pub\s+)?(?:async\s+)?fn\s+\w+\s*\(.*?\)\s*(?:->\s*[\w\<\>:]+\s*)?\{[\s\S]*?\})'
    }

    pattern = patterns.get(lang_key)
    if pattern:
        return re.findall(pattern, content)
    return []

def process_and_upload():
    setup_database_and_table()
    all_data = [] 
    
    if not os.path.exists(RAW_DIR):
        print(f"[!] Thư mục {RAW_DIR} không tồn tại.")
        return

    print("[*] Đang trích xuất dữ liệu từ thư mục raw...")
    for lang in os.listdir(RAW_DIR):
        lang_path = os.path.join(RAW_DIR, lang)
        if not os.path.isdir(lang_path): continue
        
        all_files = os.listdir(lang_path)

        for fname in all_files:
            repo_slug = fname.rsplit('.', 1)[0]

            try:
                with open(os.path.join(lang_path, fname), 'r', encoding='utf-8') as f:
                    content = f.read()
                    snippets = extract_logic(content, lang)
                    
                    for snip in snippets[:5]:
                        bare_code = snip.strip()
                        if len(bare_code) < 20: 
                            continue


                        snippet_hash = hashlib.sha256(bare_code.encode('utf-8')).hexdigest()

                        all_data.append((
                            str(uuid.uuid4()),  
                            lang,               
                            repo_slug,         
                            fname,             
                            bare_code,         
                            snippet_hash        
                        ))
            except Exception:
                pass

    if all_data:
        # 1. LƯU BACKUP RA FILE PARQUET ĐỂ LÀM DATA LAKE
        df = pd.DataFrame(all_data, columns=["id", "language", "repo_name", "file_name", "code_snippet", "snippet_hash"])
        os.makedirs(PROCESSED_DIR, exist_ok=True)
        current_time = datetime.now().strftime("%Y%m%d_%H%M%S")
        parquet_file = os.path.join(PROCESSED_DIR, f'cleaned_code_{current_time}.parquet')
        df.to_parquet(parquet_file, index=False, engine='pyarrow')
        print(f"[*] Đã lưu backup an toàn tại: {parquet_file}")

        # 2. PUSH LÊN POSTGRES 
        try:
            conn = psycopg2.connect(user=DB_USER, password=DB_PASS, host=DB_HOST, port=DB_PORT, database=DB_NAME)
            cursor = conn.cursor()

            insert_query = f"""
                INSERT INTO {TABLE_NAME} (id, language, repo_name, file_name, code_snippet, snippet_hash)
                VALUES %s
                ON CONFLICT (snippet_hash) DO NOTHING;
            """
            cursor.execute(f"SELECT COUNT(*) FROM {TABLE_NAME}")
            count_before = cursor.fetchone()[0]

            print(f"[*] Đang đẩy {len(all_data)} bản ghi lên PostgreSQL...")
            execute_values(cursor, insert_query, all_data)
            conn.commit()
            
            cursor.execute(f"SELECT COUNT(*) FROM {TABLE_NAME}")
            count_after = cursor.fetchone()[0]
            inserted_count = count_after - count_before

            print(f"[THÀNH CÔNG] Đã thêm mới {inserted_count} đoạn code vào Database.")

            # print("[*] Đang dọn dẹp vùng đệm...")
            # shutil.rmtree(RAW_DIR) 
            # os.makedirs(RAW_DIR, exist_ok=True) 
            # print("[+] Đã dọn dẹp xong! Thư mục data/raw đã trống để sẵn sàng cho lần cào code tiếp theo.")

        except Exception as db_err:
            print(f"[!] Lỗi khi đẩy lên Database: {db_err}")
            # Nếu lỗi sẽ không chạy đến lệnh xóa, giữ nguyên file cho lần chạy sau
        finally:
            if 'cursor' in locals() and cursor: cursor.close()
            if 'conn' in locals() and conn: conn.close()
    else:
        print("[!] Không có dữ liệu nào được trích xuất để lưu.")

if __name__ == "__main__":
    process_and_upload()