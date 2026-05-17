import os
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.decomposition import PCA
import ast
from dotenv import load_dotenv
from sqlalchemy import create_engine

import matplotlib.pyplot as plt

# Thêm 2 dòng này để sửa lỗi font ô vuông
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['font.sans-serif'] = ['Arial', 'Tahoma', 'DejaVu Sans']

load_dotenv()

db_user = os.getenv("DB_USER")
db_pass = os.getenv("DB_PASS")
db_host = os.getenv("DB_HOST")
db_port = os.getenv("DB_PORT")
db_name = os.getenv("DB_NAME")

# Tạo đường dẫn kết nối chuẩn (URI)
engine_url = f"postgresql://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}"
engine = create_engine(engine_url)

def fetch_data():
    print("[*] Đang kết nối tới PostgreSQL...")
  
    query = "SELECT code_snippet, embedding FROM code_base LIMIT 500;"
    
    # Dùng engine thay vì conn
    df = pd.read_sql_query(query, engine)
    return df

# 2. Lấy dữ liệu
df = fetch_data()

# Các bước xử lý dưới đây giữ nguyên
df['embedding'] = df['embedding'].apply(lambda x: np.array(ast.literal_eval(x)) if isinstance(x, str) else np.array(x))

X = np.stack(df['embedding'].values)
print(f"[*] Kích thước dữ liệu gốc: {X.shape}")

print("[*] Đang chạy thuật toán PCA...")
pca = PCA(n_components=2)
X_pca = pca.fit_transform(X)

df['pca_x'] = X_pca[:, 0]
df['pca_y'] = X_pca[:, 1]

# Vẽ biểu đồ
plt.figure(figsize=(12, 8))
sns.scatterplot(x='pca_x', y='pca_y', data=df, alpha=0.7, s=100, color='teal')
plt.title("Trực quan hóa không gian Vector của RAG Database", fontsize=16)
plt.xlabel("PCA 1", fontsize=12)
plt.ylabel("PCA 2", fontsize=12)
plt.grid(True, linestyle='--', alpha=0.5)

for i in range(min(15, len(df))):
    plt.text(df['pca_x'].iloc[i] + 0.02, df['pca_y'].iloc[i], 
             str(df['code_snippet'].iloc[i])[:20] + '...', 
             fontsize=8)

plt.tight_layout()
plt.show()

import matplotlib.pyplot as plt

# Sửa lại lỗi font tiếng Việt cho biểu đồ
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['font.sans-serif'] = ['Arial', 'Tahoma', 'DejaVu Sans']

def draw_language_donut():
    languages = ['Python', 'C++', 'Java', 'JavaScript', 'TypeScript', 'Rust']
    counts = [1200, 850, 900, 1100, 750, 500] 
    
    colors = ['#ff9999','#66b3ff','#99ff99','#ffcc99', '#c2c2f0', '#ffb3e6']
    
    plt.figure(figsize=(10, 7))
    
    # Vẽ biểu đồ
    plt.pie(counts, labels=languages, colors=colors, autopct='%1.1f%%', 
            startangle=140, pctdistance=0.85, 
            wedgeprops={'edgecolor': 'white', 'linewidth': 2})
    
    # Khoét lỗ ở giữa để tạo thành hình Donut
    centre_circle = plt.Circle((0,0), 0.60, fc='white')
    fig = plt.gcf()
    fig.gca().add_artist(centre_circle)
    
    plt.title('Tỉ trọng dữ liệu theo Ngôn ngữ lập trình trong RAG Database', fontsize=16, fontweight='bold', pad=20)
    plt.tight_layout()
    plt.show()

# Chạy thử
draw_language_donut()