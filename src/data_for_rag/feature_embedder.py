import os
import json
import psycopg2
from psycopg2.extras import execute_values
import pandas as pd
from dotenv import load_dotenv
from sentence_transformers import SentenceTransformer
from tree_sitter_languages import get_parser
from datetime import datetime  

load_dotenv()

# Không cần đọc file Parquet nữa, nhưng vẫn lưu feature ra file để backup
FEATURE_DIR = 'data/feature'
current_time = datetime.now().strftime("%Y%m%d_%H%M%S")
FEATURE_FILE = os.path.join(FEATURE_DIR, f'embedded_features_{current_time}.parquet')

def extract_dependencies(code_snippet, lang):
    lang_map = {
        'python': 'python', 'javascript': 'javascript', 'js': 'javascript',
        'typescript': 'typescript', 'ts': 'typescript', 'java': 'java',
        'c++': 'cpp', 'cpp': 'cpp', 'rust': 'rust'
    }
    ts_lang = lang_map.get(lang.lower())
    if not ts_lang: return []
    try:
        parser = get_parser(ts_lang)
        tree = parser.parse(bytes(code_snippet, "utf8"))
        root_node = tree.root_node
        called_functions = set()
        def walk_ast(node):
            if 'call' in node.type:
                for child in node.children:
                    if child.type == 'identifier':
                        called_functions.add(child.text.decode('utf8'))
            for child in node.children:
                walk_ast(child)
        walk_ast(root_node)
        return list(called_functions)
    except Exception as e:
        return []

def step1_generate_features():
    """Bước 1: Quét Database lấy code MỚI, chạy AI và lưu backup"""
    print(f"[*] BƯỚC 1: Đang quét Database tìm mã nguồn mới...")
    
    records = []
    try:
        conn = psycopg2.connect(
            dbname=os.getenv('DB_NAME'), user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASS'), host=os.getenv('DB_HOST'), port=os.getenv('DB_PORT')
        )
        cursor = conn.cursor()

        # Đảm bảo bảng code_base tồn tại trước khi LEFT JOIN để không bị lỗi
        cursor.execute("CREATE EXTENSION IF NOT EXISTS vector;")
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS code_base (
                id SERIAL PRIMARY KEY,
                snippet_hash VARCHAR(64) UNIQUE, -- Thêm cột Hash để đối chiếu
                code_snippet TEXT NOT NULL,
                ast_graph JSONB,
                embedding VECTOR(768)
            );
        """)
        conn.commit()

        query_get_new_code = """
            SELECT raw.id, raw.language, raw.repo_name, raw.file_name, raw.code_snippet, raw.snippet_hash
            FROM code_snippets raw
            LEFT JOIN code_base rag ON raw.snippet_hash = rag.snippet_hash
            WHERE rag.snippet_hash IS NULL;
        """
        cursor.execute(query_get_new_code)
        new_snippets = cursor.fetchall()
        
        cursor.close()
        conn.close()

        if not new_snippets:
            print("[+] Không có đoạn code mới nào cần nhúng. Pipeline hoàn tất sớm!")
            return False

        print(f"[*] Phát hiện {len(new_snippets)} đoạn code MỚI cần nhúng CodeBERT...")
        
        # Chuyển đổi dữ liệu SQL về dạng Dictionary cho dễ xử lý
        for row in new_snippets:
            records.append({
                "id": row[0], "language": row[1], "repo_name": row[2], 
                "file_name": row[3], "code_snippet": row[4], "snippet_hash": row[5]
            })

    except Exception as e:
        print(f"[!] Lỗi khi lấy data từ DB: {e}")
        return False

    print("[*] Tải mô hình CodeBERT...")
    embedder = SentenceTransformer('microsoft/codebert-base')
    
    feature_data = []
    documents = []
    
    for row in records:
        doc_id = str(row.get('id')) 
        repo = row.get('repo_name', 'Unknown')
        code = row.get('code_snippet', '')
        lang = row.get('language', 'Unknown')
        file_name = row.get('file_name', 'Unknown')
        snippet_hash = row.get('snippet_hash') # Lấy hash để tí nữa đẩy lên DB
        
        dependencies = extract_dependencies(code, lang)
        dep_str = ", ".join(dependencies) if dependencies else "Không gọi hàm ngoài"
        
        text_to_embed = f"Ngôn ngữ: {lang} | Dự án: {repo} | File: {file_name}\nĐồ thị phụ thuộc: [{dep_str}]\nCode:\n{code}"
        
        ast_graph_meta = json.dumps({
            "original_id": doc_id, "repo": repo, "language": lang,
            "file_name": file_name, "dependencies": dependencies
        })

        documents.append(text_to_embed)
        feature_data.append({
            "snippet_hash": snippet_hash, # Lưu hash vào feature data
            "code_snippet": code,
            "ast_graph": ast_graph_meta
        })

    print(f"[*] Đang chạy Embeddings cho {len(documents)} khối code...")
    embeddings = embedder.encode(documents).tolist()
    
    for i in range(len(feature_data)):
        feature_data[i]["embedding"] = embeddings[i]

    os.makedirs(FEATURE_DIR, exist_ok=True)
    feature_df = pd.DataFrame(feature_data)
    feature_df.to_parquet(FEATURE_FILE, engine='pyarrow')
    print(f"[+] Đã lưu file feature backup tại: {FEATURE_FILE}")
    return True

def step2_upload_to_postgres():
    """Bước 2: Đọc file feature và đẩy lên PostgreSQL (Bảng code_base)"""
    print(f"\n[*] BƯỚC 2: Tải features từ {FEATURE_FILE} lên PostgreSQL...")
    if not os.path.exists(FEATURE_FILE): 
        print("[!] Không tìm thấy file feature.")
        return
    
    df = pd.read_parquet(FEATURE_FILE)
    records = df.to_dict('records')

    try:
        conn = psycopg2.connect(
            dbname=os.getenv('DB_NAME'), user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASS'), host=os.getenv('DB_HOST'), port=os.getenv('DB_PORT')
        )
        cursor = conn.cursor()
        
        values_to_insert = []
        for row in records:
            # Ép kiểu embedding từ numpy.ndarray về lại List chuẩn của Python
            embedding_data = row['embedding']
            if hasattr(embedding_data, 'tolist'):
                embedding_list = embedding_data.tolist()
            else:
                embedding_list = list(embedding_data)
                
            # Đưa list đã chuẩn hóa vào tuple
            values_to_insert.append((
                row['snippet_hash'], 
                row['code_snippet'], 
                row['ast_graph'], 
                embedding_list # Dùng biến này thay vì row['embedding'] gốc
            ))
            
        print(f"[*] Đang đẩy {len(records)} dòng lên Database...")
        # Dùng ON CONFLICT DO NOTHING để chặn lỗi nếu nhỡ tay đẩy trùng
        insert_query = """
            INSERT INTO code_base (snippet_hash, code_snippet, ast_graph, embedding) 
            VALUES %s 
            ON CONFLICT (snippet_hash) DO NOTHING
        """
        execute_values(cursor, insert_query, values_to_insert)
        conn.commit()
        
        print(f"[THÀNH CÔNG] Đã đẩy {cursor.rowcount} records lên PostgreSQL bảng code_base!")
    except Exception as e:
        print(f"[!] Lỗi khi lưu DB: {e}")
        conn.rollback()
    finally:
        cursor.close()
        conn.close()

if __name__ == "__main__":
    # Nếu step 1 tìm thấy code mới và nhúng thành công thì mới chạy step 2
    #if step1_generate_features():
    step2_upload_to_postgres()