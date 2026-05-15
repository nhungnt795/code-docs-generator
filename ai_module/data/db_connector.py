import psycopg2
import json
import os
import sys
from dotenv import load_dotenv

load_dotenv()

class PGVectorConnector:
    def __init__(self):
        db_name = os.getenv("DB_NAME")
        db_user = os.getenv("DB_USER")
        db_pass = os.getenv("DB_PASS")
        db_host = os.getenv("DB_HOST")
        db_port = os.getenv("DB_PORT")

        print(f"[*] Đang kết nối tới database: {db_name} tại {db_host}:{db_port}...")
        
        try:
            self.conn = psycopg2.connect(
                dbname=db_name, 
                user=db_user, 
                password=db_pass, 
                host=db_host,
                port=db_port
            )
            self.cursor = self.conn.cursor()
            print("[+] Kết nối database thành công!")
        except Exception as e:
            print(f"[!] Không thể kết nối DB. Chi tiết: {e}")
            sys.exit(1) 

    def search_similar_code(self, query_vector, top_k=3):
        if hasattr(query_vector, 'tolist'):
            query_list = query_vector.tolist()
        else:
            query_list = list(query_vector)
            
        vector_str = "[" + ",".join(map(str, query_list)) + "]"
        
        query = """
            SELECT code_snippet, ast_graph, 1 - (embedding <=> %s::vector) AS similarity_score
            FROM code_base
            ORDER BY similarity_score DESC  -- Sửa thành DESC vì giờ điểm càng cao càng tốt
            LIMIT %s;
        """
        
        try:
            self.cursor.execute(query, (vector_str, top_k))
            results = self.cursor.fetchall()
            
            # Trả về kết quả sạch đẹp
            return [{"code": r[0], "graph": r[1], "score": round(r[2], 4)} for r in results]
        except Exception as e:
            print(f"[!] Lỗi khi truy vấn vector: {e}")
            return []
    
    def close(self):
        if hasattr(self, 'cursor') and self.cursor:
            self.cursor.close()
        if hasattr(self, 'conn') and self.conn:
            self.conn.close()
        print("[-] Đã đóng kết nối database an toàn.")

