# Kiến trúc phân hệ Dữ liệu 
Phân hệ này có 2 folder riêng biệt gồm data và src.

Phân hệ này chịu trách nhiệm toàn bộ cho vòng đời của dữ liệu trong hệ thống sinh tài liệu kỹ thuật tự động. Thiết kế của phân hệ tuân thủ nguyên tắc tách biệt mối quan tâm: cô lập hoàn toàn không gian lưu trữ dữ liệu (`data/`) khỏi các tập lệnh xử lý logic (`src/`).

Quy trình bao quát từ việc cào mã nguồn thô, làm sạch, bóc tách AST, cho đến việc xây dựng Vector Database phục vụ RAG và chuẩn bị tập dữ liệu format Chat-Completion để fine-tune Llama 3.1.

---

## 1. Cấu trúc lưu trữ (`data/`)
Thư mục này chỉ dùng để chứa file dữ liệu tĩnh qua từng giai đoạn xử lý, tuyệt đối không chứa code logic.

```text
data/
├── raw/  # Dữ liệu mã nguồn thô cào từ GitHub, chia theo 6 ngôn ngữ, kích thước lớn nên không đẩy lên github mà lưu ở local
│   ├── cpp/
│   ├── java/
│   ├── javascript/
│   ├── python/
│   ├── rust/
│   └── typescript/
├── processed/                          # Dữ liệu sau khi đã được tiền xử lý và chuẩn hóa
│   ├── cleaned_code/                   # Mã nguồn đã lọc bỏ comment rác và format chuẩn
│   ├── llama31_finetune_data_pro.jsonl # Dữ liệu nháp trước khi split
│   ├── train_val_data.jsonl            # Tập train/validation format chuẩn Llama 3.1
│   └── test_data.jsonl                 # Tập test độc lập dùng để evaluate
└── feature/                            # Chứa các vector embeddings lưu tại local
    └── embedded_features_ngaythangnam_giophutgiay.parquet       # Tệp lưu trữ vector đặc trưng của RAG Database

```

---

## 2. Cấu trúc Source Code (`src/`)

Thư mục này chứa các script Python thực thi data pipeline. Được module hóa theo từng mục đích cụ thể.

```text
src/
├── data_processing/                # Nhóm script thu thập và làm sạch
│   ├── github_crawler.py           # Script tự động cào repo từ Github theo ngôn ngữ
│   └── clean_and_upload.py         # Lọc nhiễu, chuẩn hóa code và đẩy lên cơ sở dữ liệu
├── data_for_rag/                   # Nhóm script xây dựng DB cho RAG
│   └── feature_embedder.py         # Nhúng (embed) mã nguồn & AST thành vector 768 chiều
├── data_for_finetune/              # Nhóm script chuẩn bị data cho model Llama 3.1
│   ├── prepare_finetune_data.py    # Map dữ liệu về định dạng Chat-Completion (messages)
│   └── train_test_split.py         # Chia tách tập dữ liệu thành Train/Val và Test
└── visualize_data/                 # Nhóm script trực quan hóa phân tích dữ liệu phục vụ báo cáo
    ├── visualize_ast_rag.py        # Vẽ đồ thị mạng lưới dependencies và AST của RAG
    ├── visualize_finetune_pro.jsonl# Biểu đồ phân bố độ dài và cơ cấu tập Fine-tune
    └── visualize_pca_rag.py        # Giảm chiều PCA trực quan hóa không gian Vector

```

---

## 3. Luồng thực thi tiêu chuẩn

Để build lại toàn bộ dữ liệu từ đầu, các script trong `src/` cần được chạy theo thứ tự tuyến tính sau:

1. **Thu thập dữ liệu:** Chạy `github_crawler.py` để kéo code về `data/raw/`.
2. **Tiền xử lý:** Chạy `clean_and_upload.py` để dọn dẹp code, đẩy kết quả ra `data/processed/cleaned_code/` và lưu thông tin vào bảng `code_base` trong PostgreSQL.
3. **Đóng gói RAG:** Chạy `feature_embedder.py` để sinh vector nhúng cho code và lưu cục bộ tại `data/feature/` để tối ưu tốc độ query.
4. **Chuẩn bị Fine-tune:** Chạy tuần tự các file trong `data_for_finetune/` để tạo format `jsonl` chuẩn, sau đó split ra thành tập huấn luyện và kiểm thử.
5. **Kiểm soát chất lượng:** Sử dụng các script trong `visualize_data/` để kiểm tra phân phối dữ liệu và mật độ vector trước khi nạp vào AI Module.

```

