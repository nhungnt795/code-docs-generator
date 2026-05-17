# Kiến trúc phân hệ AI 

Phân hệ AI đóng vai trò là lõi xử lý ngôn ngữ và suy luận của hệ thống, chịu trách nhiệm tích hợp các mô hình trí tuệ nhân tạo để thực hiện chức năng sinh tài liệu kỹ thuật tự động. Kiến trúc của phân hệ này được thiết kế theo hướng module hóa, phân tách rõ ràng các tầng logic bao gồm: kết nối dữ liệu, cấu hình mô hình, huấn luyện, đánh giá và triển khai phục vụ.

---

## 1. Cấu trúc thư mục

```text
ai_module/
├── data/
│   └── db_connector.py      # Module quản lý kết nối và truy vấn tới PostgreSQL/VectorDB
├── mlruns/                  # Thư mục hệ thống của MLflow
│   └── mlflow.db            # Cơ sở dữ liệu lưu trữ lịch sử tracking huấn luyện
├── model/
│   ├── base_llm.py          # Lớp định nghĩa và tải trọng số của mô hình ngôn ngữ lõi (Llama 3.1)
│   ├── embedder.py          # Lớp quản lý mô hình nhúng để chuyển hóa văn bản thành vector
│   └── rag_engine.py        # Động cơ tích hợp truy xuất dữ liệu và sinh văn bản 
├── serving/
│   ├── predict.py           # Script chạy dự đoán trên tập data/processed/test_data.jsonl để chuẩn bị cho việc đánh giá mô hình sau tinh chỉnh
│   └── predictions.jsonl    # Tệp lưu trữ kết quả dự đoán sinh ra từ tập dữ liệu kiểm thử
└── training/
    ├── evaluate.py          # Script tính toán các chỉ số độ chuẩn xác  so với tài liệu gốc
    └── train.py             # Script thực thi quá trình tinh chỉnh mô hình

```

---

## 2. Các thành phần chức năng cốt lõi

### Tầng mô hình và suy luận

Thư mục `model` chứa các thành phần trí tuệ nhân tạo nền tảng. Tệp `base_llm.py` chịu trách nhiệm khởi tạo Llama 3.1 cùng các cấu hình lượng tử hóa và kỹ thuật LoRA nhằm tối ưu hóa tài nguyên phần cứng. Tệp `rag_engine.py` đóng vai trò là bộ não điều phối, nhận truy vấn đầu vào, giao tiếp với `embedder.py` để nhúng truy vấn, sau đó gọi xuống cơ sở dữ liệu vector thông qua `db_connector.py` để lấy ngữ cảnh mã nguồn liên quan trước khi đưa vào mô hình ngôn ngữ sinh kết quả.

### Tầng quản trị huấn luyện 

Quá trình huấn luyện tinh chỉnh mô hình được kiểm soát tại thư mục `training`. Tệp `train.py` thực thi các vòng lặp cập nhật trọng số dựa trên tập dữ liệu đã được định dạng. Điểm đặc biệt của kiến trúc này là sự tích hợp chặt chẽ với MLflow. Toàn bộ siêu tham số, đường cong mất mát và lịch sử tốc độ học đều được theo dõi tự động và lưu trữ tại `mlruns/mlflow.db`, giúp dễ dàng so sánh hiệu năng giữa các phiên bản mô hình khác nhau.

### Tầng đánh giá và triển khai 

Tệp `predict.py` dùng để chạy mô hình dự đoán các câu test, các kết quả dự đoán được lưu ở `predictions.jsonl`, sau đó tệp `evaluate.py` được sử dụng để đánh giá kết quả của các dự đoán vừa rồi (sử dụng codebertscore), từ đó kết xuất các chỉ số độ tin cậy.

```
