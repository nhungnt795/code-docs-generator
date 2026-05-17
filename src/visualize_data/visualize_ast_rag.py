import os
import pandas as pd
import matplotlib.pyplot as plt
import networkx as nx
from dotenv import load_dotenv
from sqlalchemy import create_engine
import matplotlib.patches as mpatches

plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['font.sans-serif'] = ['Arial', 'Tahoma', 'DejaVu Sans']

load_dotenv()
engine_url = f"postgresql://{os.getenv('DB_USER')}:{os.getenv('DB_PASS')}@{os.getenv('DB_HOST')}:{os.getenv('DB_PORT')}/{os.getenv('DB_NAME')}"
engine = create_engine(engine_url)

def draw_macro_network():
    
    query = """
        SELECT ast_graph 
        FROM code_base 
        WHERE ast_graph IS NOT NULL 
          AND ast_graph ? 'dependencies' 
          AND jsonb_typeof(ast_graph->'dependencies') = 'array'
        LIMIT 150; 
    """
    df = pd.read_sql_query(query, engine)
    
    IGNORE_LIST = ['printf', 'print', 'cout', 'cin', 'console.log', 
                   'usleep', 'String', 'int', 'main', 'sleep', 'System.out.println']
    
    G = nx.Graph() 
    
    for index, row in df.iterrows():
        metadata = row['ast_graph']
        file_node = metadata.get('file_name', f'File_{index}')
        G.add_node(file_node, node_type='file')
        
        dependencies = metadata.get('dependencies', [])
        for dep in dependencies:
            if dep not in IGNORE_LIST and len(dep) > 2:
                G.add_node(dep, node_type='dependency')
                G.add_edge(file_node, dep)

    node_colors = []
    node_sizes = []
    degrees = dict(G.degree())
    
    color_map = {'file': '#cc0066',      
                 'dependency': '#004d99'} 
    
    for node, attr in G.nodes(data=True):
        degree = degrees[node]
        if attr.get('node_type') == 'file':
            node_colors.append(color_map['file']) 
            node_sizes.append(100)        
        else:
            node_colors.append(color_map['dependency']) 
            node_sizes.append(250 + degree * 250) 

    pos = nx.spring_layout(G, k=0.6, iterations=60)
    
    # Tạo figure lớn để đủ không gian
    plt.figure(figsize=(16, 12))
    
    plt.title("Đồ thị mạng lưới liên kết thuộc tính và logic mã nguồn", fontsize=18, pad=30, fontweight='bold')
    
    labels = {node: node if (attr.get('node_type') == 'dependency' and degrees[node] > 1) else '' for node, attr in G.nodes(data=True)}

    # Khởi tạo các thành phần đồ thị
    # Vẽ các đường nối (edges) trước
    nx.draw_networkx_edges(G, pos, edge_color='#cccccc', alpha=0.6)
    
    # Vẽ các hạt tròn (nodes) đè lên trên đường nối
    nx.draw_networkx_nodes(G, pos, node_size=node_sizes, node_color=node_colors, alpha=0.9)
    
    nx.draw_networkx_labels(G, pos, labels=labels, font_size=9, font_weight='bold', font_color='white')
            
    # Tắt cái trục tọa độ của matplotlib đi cho biểu đồ thoáng
    plt.gca().axis('off')
    

    patch_file = mpatches.Patch(color=color_map['file'], label='File mã nguồn')
    patch_dep = mpatches.Patch(color=color_map['dependency'], label='Thư viện/Hàm phụ thuộc (logic lõi)')
    
    # Ép Legend về góc dưới cùng bên TRÁI
    plt.legend(handles=[patch_file, patch_dep], loc='lower left', 
               fontsize=11, frameon=True, facecolor='white', edgecolor='black', shadow=True)
               
    # Ép Text Note về góc dưới cùng bên PHẢI 
    plt.gcf().text(0.65, 0.04, "*Kích thước node màu xanh tỷ lệ thuận với tần suất sử dụng", 
                   fontsize=11, style='italic', color='#444444')
    
    plt.tight_layout()
    # Nhấc nhẹ toàn bộ biểu đồ lên 1 chút xíu để chừa chỗ cho tiêu đề và ghi chú không bị lẹm viền
    plt.subplots_adjust(bottom=0.08, top=0.92) 
    plt.show()

draw_macro_network()