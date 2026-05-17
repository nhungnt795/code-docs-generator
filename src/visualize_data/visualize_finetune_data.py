import json
import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import matplotlib.patches as mpatches

plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['font.sans-serif'] = ['Arial', 'Tahoma', 'DejaVu Sans']

file_path = "data/processed/train_val_data.jsonl"

def load_finetune_data(path):
    print(f"[*] Đang nạp và bóc tách cấu trúc Chat-Messages: {path}")
    parsed_data = []
    
    with open(path, 'r', encoding='utf-8') as f:
        for line in f:
            if line.strip():
                obj = json.loads(line)
                if 'messages' in obj and isinstance(obj['messages'], list):
                    source_code = ""
                    ground_truth = ""
                    for msg in obj['messages']:
                        if msg.get('role') == 'user':
                            source_code = msg.get('content', '')
                        elif msg.get('role') == 'assistant':
                            ground_truth = msg.get('content', '')
                    parsed_data.append({
                        'source_code': source_code,
                        'ground_truth': ground_truth
                    })
                else:
                    parsed_data.append(obj)
    
    df = pd.DataFrame(parsed_data)
    if 'source_code' not in df.columns:
        if 'prompt' in df.columns: df['source_code'] = df['prompt']
        if 'output' in df.columns: df['ground_truth'] = df['output']

    df['code_len'] = df['source_code'].apply(lambda x: len(str(x).split()))
    df['doc_len'] = df['ground_truth'].apply(lambda x: len(str(x).split()))
    return df

try:
    df = load_finetune_data(file_path)
    total_samples = len(df)
    
    # Tính toán số mẫu theo tỉ lệ 9:1
    train_count = int(total_samples * 0.9)
    val_count = total_samples - train_count
    
    print(f"[INFO] Giải mã thành công! Tổng: {total_samples} (Train: {train_count} | Val: {val_count})")

    fig, axes = plt.subplots(1, 2, figsize=(16, 7))
    

    split_sizes = [train_count, val_count]
    colors = ['#004d99', '#cc0066'] 
    
    wedges, _, autotexts = axes[0].pie(
        split_sizes, 
        colors=colors, 
        autopct='%1.1f%%', 
        startangle=90, 
        pctdistance=0.7, 
        textprops=dict(fontweight='bold', fontsize=12),
        wedgeprops=dict(edgecolor='white', linewidth=3)
    )
    
    # Ép chữ số phần trăm hiển thị màu trắng cho nổi bật
    for autotext in autotexts:
        autotext.set_color('white')
        
    centre_circle = plt.Circle((0,0), 0.55, fc='white')
    axes[0].add_artist(centre_circle)
    axes[0].set_title("Cơ cấu phân chia tập dữ liệu huấn luyện (Tỉ lệ 9:1)", fontsize=13, fontweight='bold', pad=20)
    
    # Đưa toàn bộ thông tin số lượng mẫu vào hẳn trong hộp chú thích cho sạch sẽ
    patch_train = mpatches.Patch(color='#004d99', label=f'Tập huấn luyện (Train) - 90% ({train_count} mẫu)')
    patch_val = mpatches.Patch(color='#cc0066', label=f'Tập thẩm định (Validation) - 10% ({val_count} mẫu)')
    
    axes[0].legend(handles=[patch_train, patch_val], loc='lower left', 
                   frameon=True, shadow=True, facecolor='white', edgecolor='black', fontsize=10)

   
    sns.histplot(df['code_len'], kde=True, color='#004d99', label='Mã nguồn đầu vào (User)', ax=axes[1], bins=20, alpha=0.6)
    sns.histplot(df['doc_len'], kde=True, color='#cc0066', label='Tài liệu mẫu chuẩn (Assistant)', ax=axes[1], bins=20, alpha=0.6)
    
    axes[1].set_title("Phân bố mật độ độ dài từ vựng tập dữ liệu Fine-tune", fontsize=13, fontweight='bold', pad=20)
    axes[1].set_xlabel("Số lượng từ trong một mẫu (Word Count)", fontsize=11)
    axes[1].set_ylabel("Tần suất xuất hiện (Count)", fontsize=11)
    axes[1].grid(True, linestyle='--', alpha=0.5)
    axes[1].legend(loc='upper right', frameon=True, shadow=True, edgecolor='black')

    # Tiêu đề tổng của toàn bộ biểu đồ ghép
    plt.suptitle("Biểu đồ phân tích đặc trưng phân phối cấu trúc tập dữ liệu Fine-tune", fontsize=16, fontweight='bold', y=0.98)
    
    # Chú thích nguồn đặt ở góc phải bên dưới độc lập
    plt.gcf().text(0.60, 0.03, f"*Phân tích dựa trên tổng thể mẫu định dạng Chat-Completion của Llama 3.1", 
                   fontsize=11, style='italic', color='#444444')

    plt.subplots_adjust(bottom=0.12, top=0.86, wspace=0.22)
    
    # Xuất file ảnh mới đè lên file cũ
    plt.savefig("data_processed_finetune_analysis.png", dpi=300, bbox_inches='tight')
    plt.show()
    print("[SUCCESS] Đã cập nhật và xuất biểu đồ Fine-tune phiên bản chuẩn không tì vết!")

except Exception as e:
    print(f"[!] Gặp lỗi xử lý dữ liệu: {str(e)}")