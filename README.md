# DocGen VN — Hệ thống Tự động Sinh Tài liệu Mã nguồn Tiếng Việt

> Ứng dụng AI tự động phân tích mã nguồn và sinh tài liệu kỹ thuật bằng Tiếng Việt, hỗ trợ nhiều ngôn ngữ lập trình, tích hợp RAG Engine và Fine-tuned LLM.

---

## Tổng quan hệ thống

```
┌─────────────────────────────────────────────────────────────┐
│                        NGƯỜI DÙNG                           │
│              Flutter Web / Android / iOS                    │
└─────────────────────┬───────────────────────────────────────┘
                      │ HTTPS
┌─────────────────────▼───────────────────────────────────────┐
│                   NGINX (Reverse Proxy)                     │
│                   docgenvn.id.vn                            │
└──────┬──────────────────────────────────┬───────────────────┘
       │ /api/*                           │ /* (static)
┌──────▼──────────┐              ┌────────▼────────┐
│  FastAPI Backend│              │  Flutter Web    │
│  :8000          │              │  (build/web)    │
└──────┬──────────┘              └─────────────────┘
       │
┌──────▼──────────┐    ┌─────────────────────────────────────┐
│  PostgreSQL     │    │           AI Module                 │
│  + pgvector     │    │  RAG Engine + Embedder + LLM        │
│  :5435          │    │  (Groq Cloud / Kaggle Finetuned)    │
└─────────────────┘    └──────────────┬──────────────────────┘
                                      │
                       ┌──────────────▼──────────────────────┐
                       │         Apache Airflow              │
                       │   Pipeline huấn luyện tự động       │
                       └─────────────────────────────────────┘
```

---

## Cấu trúc thư mục

```
code-docs-generator/
├── docker-compose.yaml          # Orchestration production (tất cả services)
├── docker-compose.dev.yaml      # Orchestration development
├── run_dev.ps1                  # Script khởi động dev (Windows PowerShell)
│
├── frontend/                   # Flutter App (Web + Android + iOS)
├── backend/                    # FastAPI REST API
├── ai_module/                  # RAG Engine + LLM + Embedder
├── airflow/                    # Pipeline tự động hoá (Apache Airflow)
├── data/                       # Dataset huấn luyện & features
└── docker/                     # Scripts khởi tạo DB
```

---

## Các thành phần

### 1. Frontend (`frontend/`)

Giao diện người dùng xây dựng bằng **Flutter**, hỗ trợ Web, Android, iOS.

```
frontend/
├── lib/
│   ├── main_user.dart           # Entry point app người dùng
│   ├── main_admin.dart          # Entry point app quản trị
│   ├── core/
│   │   ├── api/                 # HTTP client, models, config
│   │   ├── auth/                # Riverpod auth state
│   │   ├── router/              # GoRouter (user + admin)
│   │   └── tokens/              # AppColors, Typography, Spacing
│   ├── features/
│   │   ├── auth/                # Đăng nhập, đăng ký, OTP, reset password
│   │   ├── generate/            # Sinh tài liệu, chọn model AI, kiểm tra syntax
│   │   ├── history/             # Lịch sử tài liệu đã sinh
│   │   ├── profile/             # Thông tin cá nhân, avatar
│   │   ├── admin/               # Dashboard, quản lý user & model AI
│   │   ├── landing/             # Trang chủ, splash screen
│   │   └── info/                # About, contact, terms, privacy
│   └── shared/
│       ├── layout/              # AppScaffold, Topbar, Sidebar
│       └── widgets/             # DgToast và các widget dùng chung
└── assets/
    ├── fonts/                   # Inter, JetBrainsMono
    └── icons/                   # App icon, logo SVG
```

**Công nghệ:** Flutter 3.22+, Dart 3.3+, Riverpod, GoRouter, flutter_markdown

---

### 2. Backend (`backend/`)

REST API xây dựng bằng **FastAPI**, kết nối PostgreSQL, tích hợp AI module.

```
backend/
├── main.py                      # Khởi tạo app, CORS, static files, seed data
├── database.py                  # SQLAlchemy engine + session
├── models.py                    # ORM models (User, Document, AIModel, ...)
├── schemas.py                   # Pydantic schemas request/response
├── auth_helpers.py              # JWT, bcrypt, OTP, middleware phân quyền
├── validators.py                # Kiểm tra syntax code (tree-sitter)
├── email_service.py             # Gửi OTP qua email
├── export_service.py            # Xuất tài liệu MD / PDF / DOCX
├── create_admin.py              # Script tạo tài khoản admin lần đầu
├── requirements.txt
├── Dockerfile
├── docker-compose.yaml          # Backend + PostgreSQL riêng
├── data/avatars/                # Ảnh đại diện người dùng (static files)
└── routers/
    ├── auth.py                  # /api/auth
    ├── profile.py               # /api/users
    ├── documents.py             # /api/docs
    ├── admin.py                 # /api/admin
    ├── feedback.py              # /api/feedback
    ├── public.py                # /api/public
    └── contact.py               # /api/contact
```

**Công nghệ:** FastAPI, SQLAlchemy, PostgreSQL + pgvector, tree-sitter, WeasyPrint, python-docx

---

### 3. AI Module (`ai_module/`)

Engine xử lý AI: RAG (Retrieval-Augmented Generation), embedder vector, giao tiếp với LLM.

```
ai_module/
├── model/
│   ├── base_llm.py              # Interface giao tiếp LLM (Groq / Kaggle)
│   ├── embedder.py              # Sentence embedding cho RAG
│   └── rag_engine.py            # RAG pipeline: embed → retrieve → generate
├── data/
│   └── db_connector.py          # Kết nối pgvector để lưu/truy vấn embeddings
├── serving/
│   └── predict.py               # Inference endpoint (được backend gọi vào)
├── training/
│   ├── train.py                 # Fine-tune LLM (Llama 3.1 trên Kaggle)
│   └── evaluate.py              # Đánh giá chất lượng model
└── mlruns/
    └── mlflow.db                # MLflow tracking experiments
```

**Mô hình AI hỗ trợ:**

| Tên | Loại | Trạng thái |
|-----|------|-----------|
| Llama 3.1 8B Instant | Groq Cloud API | Mặc định — luôn hoạt động |
| Llama 3.1 Finetuned | Kaggle (tự triển khai) | Tùy cấu hình admin |

**Công nghệ:** PyTorch, HuggingFace Transformers, Sentence-Transformers, MLflow

---

### 4. Data (`data/`)

Dataset dùng cho huấn luyện và fine-tuning model.

```
data/
├── feature/
│   └── embedded_features_20260505.parquet   # Vector embeddings đã tính sẵn
└── processed/
    ├── llama31_finetune_data_pro.jsonl       # Dữ liệu fine-tune Llama 3.1
    ├── train_val_data.jsonl                  # Tập train/validation
    ├── test_data.jsonl                       # Tập test
    └── cleaned_code/
        └── cleaned_code_20260505.parquet     # Mã nguồn đã làm sạch
```

---

### 5. Airflow (`airflow/`)

Pipeline tự động hoá quy trình xử lý dữ liệu và huấn luyện model.

```
airflow/
├── docker-compose.yaml          # Airflow standalone
└── dags/
    └── code_docs_pipeline.py    # DAG: crawl → clean → embed → train → deploy
```

**Các bước trong pipeline:**
1. Thu thập mã nguồn mới
2. Làm sạch và chuẩn hoá
3. Tính embeddings và lưu vào pgvector
4. Fine-tune lại model nếu đủ dữ liệu mới
5. Đánh giá và deploy model mới

---

## Cài đặt & Chạy

### Yêu cầu

- Docker & Docker Compose
- Python 3.11+
- Flutter SDK 3.22+ (chỉ nếu phát triển frontend)
- Git

### Chạy toàn bộ hệ thống (Production)

```bash
# 1. Clone repository
git clone <repo-url>
cd code-docs-generator

# 2. Tạo file .env cho backend
cp backend/.env.example backend/.env
# Chỉnh sửa backend/.env (xem mục Biến môi trường)

# 3. Khởi tạo database
bash docker/init-db.sh

# 4. Chạy tất cả services
docker compose up -d --build

# 5. Tạo tài khoản admin lần đầu
docker exec -it docgen-fastapi python create_admin.py
```

Sau khi chạy, hệ thống sẵn sàng tại:
- **API:** `http://localhost:8000`
- **Swagger UI:** `http://localhost:8000/docs`
- **Airflow UI:** `http://localhost:8080` (admin/admin)

### Chạy môi trường Development

```bash
# Windows
./run_dev.ps1

# Linux/Mac
docker compose -f docker-compose.dev.yaml up -d
```

### Chạy Frontend (Debug)

```bash
cd frontend
flutter pub get

# Web — dùng port cố định để tránh lỗi CORS
flutter run -t lib/main_user.dart -d chrome --web-port=8080

# Android
flutter run -t lib/main_user.dart -d android

# Admin panel
flutter run -t lib/main_admin.dart -d chrome --web-port=8081
```

---

## Biến môi trường (`backend/.env`)

```env
# Database
DB_USER=postgres
DB_PASS=yourpassword
DB_NAME=docgen
DB_HOST=postgres
DATABASE_URL=postgresql+psycopg2://postgres:yourpassword@postgres:5432/docgen

# JWT
SECRET_KEY=your-very-secret-key
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60

# Email (OTP)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your@gmail.com
SMTP_PASS=your-app-password

# AI — Groq Cloud
GROQ_API_KEY=gsk_...

# AI — Kaggle Finetuned (tùy chọn)
KAGGLE_API_URL=https://...
KAGGLE_API_KEY=...
```

---

## Deploy lên AWS Ubuntu

### 1. Chuẩn bị server

```bash
# Cài Docker
sudo apt update && sudo apt install -y docker.io docker-compose
sudo usermod -aG docker ubuntu
```

### 2. Upload & chạy backend

```bash
# Upload code qua WinSCP vào ~/code-docs-generator-Sever/
# SSH vào server
ssh ubuntu@<ip>

cd ~/code-docs-generator-Sever
docker compose up -d --build

# Kiểm tra logs
docker compose logs -f backend
```

### 3. Build & deploy frontend

```bash
# Build trên máy local
cd frontend
flutter build web --release -t lib/main_user.dart
cd build/web && zip -r ../../docgen_web.zip .

# Upload docgen_web.zip lên server qua WinSCP
# SSH vào server
sudo unzip -o ~/docgen_web.zip -d /var/www/html/
sudo systemctl reload nginx
```

### 4. Cấu hình Nginx

```nginx
server {
    listen 80;
    server_name docgenvn.id.vn;

    # API Backend
    location /api/ {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # Static files (avatar, export)
    location /data/ {
        proxy_pass http://localhost:8000;
    }

    # Flutter Web
    location / {
        root /var/www/html;
        try_files $uri $uri/ /index.html;
    }
}
```

---

## API Endpoints

| Method | Endpoint | Mô tả | Phân quyền |
|--------|----------|-------|-----------|
| POST | `/api/auth/register` | Đăng ký | Public |
| POST | `/api/auth/login` | Đăng nhập | Public |
| POST | `/api/auth/verify-otp` | Xác thực OTP | Public |
| POST | `/api/auth/reset-password` | Đặt lại mật khẩu | Public |
| GET | `/api/users/me` | Thông tin tài khoản | User |
| POST | `/api/users/{id}/avatar` | Upload avatar (≤5MB) | User |
| POST | `/api/docs/generate` | Sinh tài liệu | User |
| POST | `/api/docs/check-syntax` | Kiểm tra syntax | User |
| GET | `/api/docs/` | Lịch sử tài liệu | User |
| GET | `/api/docs/{id}/export` | Xuất MD/PDF/DOCX | User |
| GET | `/api/public/models` | Danh sách model AI | Public |
| GET | `/api/admin/dashboard` | Thống kê hệ thống | Admin |
| GET | `/api/admin/users` | Quản lý người dùng | Admin |
| PUT | `/api/admin/models/{id}` | Bật/tắt model AI | Admin |

> Tài liệu đầy đủ: `http://localhost:8000/docs`

---

## Ngôn ngữ lập trình hỗ trợ

Python · JavaScript · TypeScript · Java · C++ · Rust

---

## Tính năng nổi bật

- Sinh tài liệu kỹ thuật Tiếng Việt tự động từ mã nguồn
- Kiểm tra syntax trước khi sinh, cảnh báo lỗi và cho phép bỏ qua
- Hai mô hình AI: Groq Cloud (luôn online) và Kaggle Finetuned (tùy admin)
- Xuất tài liệu nhiều định dạng: Markdown, PDF, Word (DOCX)
- Xác thực OTP qua email, phân quyền User/Admin
- Pipeline Airflow tự động hoá huấn luyện lại model theo dữ liệu mới
- Giao diện hỗ trợ dark mode, responsive Web + Mobile

---

## Lưu ý phát triển

**CORS khi debug local:** Backend chỉ chấp nhận các origin được liệt kê trong `backend/main.py`. Luôn dùng port cố định khi chạy Flutter web:

```bash
flutter run -d chrome --web-port=8080
```

**Không commit `.env`** — file này chứa secret keys, đã được thêm vào `.gitignore`.

**Không commit thư mục `venv/`** — cài lại bằng `pip install -r requirements.txt`.
