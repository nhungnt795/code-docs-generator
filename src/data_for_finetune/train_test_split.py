import pandas as pd
from sklearn.model_selection import train_test_split
import re

INPUT_FILE = "./data/processed/llama31_finetune_data_pro.jsonl"
TRAIN_VAL_FILE = "train_val_data.jsonl"
TEST_FILE = "test_data.jsonl"

def extract_language_from_system(messages):
    """
    Móc nối thông tin ngôn ngữ từ nội dung tin nhắn System
    Cấu trúc: 'Bạn là một chuyên gia phần mềm ngôn ngữ [LANG]'
    """
    try:
        # Lấy nội dung tin nhắn role: system
        system_content = messages[0]['content']
        
        # Dùng Regex để tìm từ khóa đứng sau cụm "ngôn ngữ "
        match = re.search(r"ngôn ngữ (\w+)", system_content, re.IGNORECASE)
        if match:
            lang = match.group(1).lower()
            # Chuẩn hóa một số tên gọi
            if lang in ['cpp', 'c++']: return 'cpp'
            return lang
    except Exception:
        pass
    return "unknown"

print("[*] Đang đọc dữ liệu từ file JSONL...")
df = pd.read_json(INPUT_FILE, lines=True)

print("[*] Đang phân tích ngôn ngữ dựa trên System Prompt...")
df['temp_lang'] = df['messages'].apply(extract_language_from_system)

print("\n[+] Thống kê số lượng mẫu theo ngôn ngữ tìm được:")
print(df['temp_lang'].value_counts())

print("\n[*] Đang chia tập dữ liệu theo tỷ lệ đồng đều...")
train_val_df, test_df = train_test_split(
    df, 
    test_size=300, 
    random_state=42, 
    stratify=df['temp_lang']
)

# 5. Dọn dẹp và Lưu file
# Xóa cột tạm trước khi lưu để giữ đúng định dạng JSONL cho Llama
train_val_df = train_val_df.drop(columns=['temp_lang'])
test_df = test_df.drop(columns=['temp_lang'])

train_val_df.to_json(TRAIN_VAL_FILE, orient="records", lines=True, force_ascii=False)
test_df.to_json(TEST_FILE, orient="records", lines=True, force_ascii=False)

print(f"\n[THÀNH CÔNG]")
print(f"-> File huấn luyện (vác lên Kaggle): {TRAIN_VAL_FILE} ({len(train_val_df)} dòng)")
print(f"-> File kiểm thử (giữ lại máy local): {TEST_FILE} ({len(test_df)} dòng)")