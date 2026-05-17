# VietDocGen — Bộ Kiểm Thử QA/QC & Hệ Thống Giám Sát AI

Thư mục này chứa toàn bộ giải pháp kiểm thử tự động (Automation Testing), kiểm soát chất lượng dữ liệu (Data Quality), kiểm tra tính toàn vẹn cơ sở dữ liệu (Database Integrity) và hệ thống giám sát hiệu năng mô hình AI (AI Metrics Monitoring) thuộc phân hệ `qa_ba` của dự án **VietDocGen**.

---

## 🎯 Mục tiêu & Phạm vi kiểm thử

Hệ thống được thiết kế phân tầng giúp đảm bảo tính ổn định tối đa của mã nguồn trước khi tích hợp (CI/CD):

1. **Unit Test (Kiểm thử đơn vị):** Kiểm thử hộp trắng tập trung vào logic lõi độc lập của RAG Engine (`ai_module`) và các hàm xử lý dữ liệu của Backend API nhằm phát hiện lỗi sớm ở mức hàm/phương thức.
2. **Integration Test (Kiểm thử tích hợp):** Kiểm tra sự phối hợp, luồng dữ liệu và giao tiếp giữa các thành phần độc lập:
   - Xác thực quyền truy cập & Phân quyền hệ thống (`auth`, `admin`).
   - Luồng lưu trữ, truy xuất và quản lý lịch sử sinh tài liệu (`docs_history`).
   - Giao tiếp thời gian thực giữa API Endpoint và AI Module.
3. **Data & DB Quality (Chất lượng & Toàn vẹn dữ liệu):**
   - Kiểm tra cấu trúc bảng, khóa ngoại, ràng buộc dữ liệu trong cơ sở dữ liệu PostgreSQL.
   - Đo lường và đánh giá hiệu năng truy vấn không gian Vector của cơ sở dữ liệu mở rộng `pgvector`.
4. **AI Monitoring (Giám sát mô hình):** Hệ thống script chuyên biệt tính toán các chỉ số chất lượng tài liệu được sinh ra từ mô hình sinh (Llama) dựa trên dữ liệu đánh giá thực tế và tập dữ liệu mô phỏng (Mock Predictions).

---

## 📂 Cấu trúc thư mục QA/QC (`qa_ba/`)

```
qa_ba/
├── pytest.ini                  # Cấu hình Pytest (ẩn warning, định nghĩa đường dẫn)
├── ai_monitoring/              # Phân hệ giám sát hiệu năng và chỉ số mô hình AI
│   ├── metrics/
│   │   ├── evaluate_llama.py   # Định nghĩa thuật toán tính toán các chỉ số chất lượng (BLEU, ROUGE,...)
│   │   └── generate_mock_preds.py # Tạo dữ liệu dự đoán giả lập phục vụ kiểm thử hệ thống giám sát
│   └── scripts/
│       ├── evaluate_llama_metrics.py # Script thực thi đánh giá metrics của mô hình Llama
│       └── mock_llama_predictions.py  # Script sinh chuỗi kết quả giả lập từ mô hình
└── tests/                      # Bộ công cụ Test Suites chính sử dụng framework Pytest
    ├── conftest.py             # Khởi tạo Fixtures dùng chung (DB Session, Mock API Context, Auth Token)
    ├── data_and_db/            # Kiểm thử tầng dữ liệu, cấu trúc DB và Vector DB
    │   ├── test_data_quality.py       # Kiểm tra chất lượng dữ liệu đầu vào và phân tách dữ liệu
    │   ├── test_database_integrity.py # Kiểm tra ràng buộc và tính toàn vẹn của PostgreSQL
    │   ├── test_model.py              # Đảm bảo tính chính xác của dữ liệu ORM Models
    │   └── test_pgvector_retrieval.py # Kiểm tra độ chính xác của cơ chế tìm kiếm Vector
    ├── integration/            # Hệ thống kiểm thử tích hợp luồng API Endpoints
    │   ├── test_admin_sys_api.py      # Kiểm thử API dành cho quản trị viên hệ thống
    │   ├── test_ai_module.py          # Kiểm thử tích hợp luồng sinh tài liệu với AI module
    │   ├── test_api_integration.py    # Kiểm tra liên kết các API nghiệp vụ chung
    │   ├── test_auth_api.py           # Tích hợp luồng Đăng ký, Đăng nhập, OTP và Quên mật khẩu
    │   ├── test_data_module.py        # Kiểm thử tích hợp module xử lý và đồng bộ dữ liệu
    │   └── test_docs_history_api.py   # Kiểm thử luồng quản lý và xuất lịch sử tài liệu
    └── unit/                   # Hệ thống kiểm thử đơn vị độc lập (Unit Tests)
        ├── ai_module/
        │   └── test_rag_engine.py     # Unit test cấu trúc dữ liệu, phân đoạn văn bản và embedding
        └── backend/
            └── test_api.py            # Unit test các hàm bổ trợ, bộ kiểm định (validators) backend
```

---

## 🛠 Hướng dẫn thiết lập & Vận hành nhanh

### 1. Chuẩn bị môi trường
Di chuyển từ thư mục gốc của dự án vào phân hệ `qa_ba`, đảm bảo bạn đã kích hoạt môi trường ảo Python (`venv` hoặc `conda`) chứa các thư viện phụ thuộc của dự án (`pytest`, `pytest-mock`, `requests`, `psycopg2`,...):

```bash
cd qa_ba
```

### 2. Khởi thực thi Test Suites với Pytest

| Phạm vi kiểm thử | Câu lệnh thực thi / Đường dẫn | Mô tả chi tiết |
| :--- | :--- | :--- |
| **Toàn bộ hệ thống** | `pytest -v` | Quét và thực thi tất cả kịch bản test tự động có trong thư mục `tests/` |
| **Unit Test** | `pytest tests/unit/ -v` | Kiểm thử hộp trắng tập trung độc lập vào logic lõi của hàm và API bổ trợ |
| **Integration Test** | `pytest tests/integration/ -v` | Kiểm tra luồng dữ liệu liên thông giữa API Endpoints, Auth, Admin và AI Module |
| **Data & DB Quality** | `pytest tests/data_and_db/ -v` | Kiểm tra độ chính xác của cơ sở dữ liệu và hiệu năng truy vấn Vector Search |
| **Manual Test Cases** | [Đường dẫn tới Google Sheet](https://docs.google.com/spreadsheets/d/1yESikANsEdMLIGsqlwa7m6J5wx5rdYJv/edit?usp=sharing&ouid=115446633535621374148&rtpof=true&sd=true) | Tập hợp các kịch bản kiểm thử thủ công, ma trận phủ kiểm thử (Traceability Matrix) và kết quả chạy thử nghiệm |
---

## 📈 Hệ thống Giám sát Mô hình AI (AI Monitoring)

Phân hệ `ai_monitoring` dùng để chạy các quy trình tự động tính toán, mô phỏng dự đoán và đo lường chất lượng tài liệu được sinh ra bởi mô hình ngôn ngữ dựa trên dữ liệu thực tế:

```bash
# Thực thi chu trình tự động đánh giá các chỉ số (metrics) của mô hình Llama
python ai_monitoring/scripts/evaluate_llama_metrics.py
```

---

## ⚙️ Cấu hình Pytest (`pytest.ini`)

Tệp `pytest.ini` được thiết lập tối ưu để lọc bỏ các cảnh báo không ảnh hưởng trực tiếp đến logic hệ thống, giúp cải thiện tốc độ ghi nhận log và giữ màn hình console sạch sẽ:
```ini
[pytest]
filterwarnings =
    ignore::DeprecationWarning
    ignore::UserWarning
```

---

## 📝 Quy trình Đảm bảo Chất lượng & Đóng góp Code (QA/QC Workflow)

Để duy trì độ tin cậy và tính ổn định cao nhất cho hệ thống **VietDocGen**, mọi thành viên khi tham gia đóng góp mã nguồn (đặc biệt trên nhánh `feature_qa/qc`) cần tuân thủ nghiêm ngặt quy trình sau:

1. **Phát triển đi liền với Kiểm thử:** Khi viết thêm một API Endpoint mới (tại thư mục `backend/routers/`) hoặc tinh chỉnh cấu trúc thuật toán RAG, lập trình viên phối hợp cùng QA/QC bắt buộc phải bổ sung các kịch bản test case tương ứng vào phân hệ `tests/unit/` hoặc `tests/integration/`.
2. **Cô lập môi trường (Isolation & Mocking):** Tận dụng tối đa sức mạnh của các fixture được định nghĩa sẵn trong `tests/conftest.py` để mock dữ liệu kết nối tới database hoặc dịch vụ bên thứ ba (như Groq API, hệ thống SMTP gửi email), tuyệt đối không làm ảnh hưởng tới dữ liệu Staging/Production.