# DocGen VN — Backend API

Backend của hệ thống tự động sinh tài liệu mã nguồn Tiếng Việt, xây dựng bằng **FastAPI** + **PostgreSQL** + **AI/RAG Engine**.

---

## Yêu cầu hệ thống

- Python 3.11+
- PostgreSQL 13+ (có hỗ trợ pgvector)
- Docker & Docker Compose (khuyên dùng)
- pip

---

## Cấu trúc thư mục

```
backend/
├── main.py               # Khởi tạo FastAPI, CORS, static files, seed data
├── database.py           # Engine + session SQLAlchemy
├── models.py             # SQLAlchemy models (User, Document, ...)
├── schemas.py            # Pydantic schemas (request/response)
├── auth_helpers.py       # Bcrypt password, OTP, require_admin/user
├── validators.py         # Kiểm tra syntax code (tree-sitter)
├── email_service.py      # Gửi OTP qua email (template HTML)
├── export_service.py     # Xuất tài liệu MD / PDF / DOCX
├── requirements.txt
├── Dockerfile
├── docker-compose.yaml
├── data/
│   └── avatars/          # Ảnh đại diện người dùng (static files)
└── routers/
    ├── auth.py           # /api/auth — đăng ký, đăng nhập, OTP, reset password
    ├── profile.py        # /api/users — đổi tên, email, mật khẩu, avatar
    ├── documents.py      # /api/docs — sinh, sửa, xuất tài liệu
    ├── admin.py          # /api/admin — dashboard, quản lý user & model AI
    ├── feedback.py       # /api/feedback — gửi đánh giá
    ├── public.py         # /api/public — danh sách model AI đang hoạt động
    └── contact.py        # /api/contact — liên hệ
```

---

## Cài đặt & Chạy

### Cách 1 — Docker Compose (khuyên dùng)

```bash
# 1. Tạo file .env từ mẫu
cp .env.example .env
# Chỉnh sửa .env cho phù hợp (xem mục Biến môi trường bên dưới)

# 2. Build và chạy
docker compose up -d --build

# 3. Tạo tài khoản admin lần đầu
docker exec -it docgen-fastapi python create_admin.py

# API sẵn sàng tại http://localhost:8000
```

### Cách 2 — Chạy trực tiếp (local dev)

```bash
# 1. Tạo virtual environment
python -m venv venv
source venv/bin/activate        # Linux/Mac
venv\Scripts\activate           # Windows

# 2. Cài dependencies
pip install -r requirements.txt

# 3. Tạo file .env và điền thông tin
cp .env.example .env

# 4. Khởi động server
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

---

## Biến môi trường (.env)

```env
# Database
DB_USER=postgres
DB_PASS=yourpassword
DB_NAME=docgen
DB_HOST=localhost

DATABASE_URL=postgresql+psycopg2://postgres:yourpassword@localhost:5432/docgen

# JWT
SECRET_KEY=your-secret-key-here
ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=60

# Email (để gửi OTP)
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your@gmail.com
SMTP_PASS=your-app-password

# AI Model — Groq Cloud
GROQ_API_KEY=your-groq-api-key

# AI Model — Kaggle (nếu dùng)
KAGGLE_API_URL=https://...
KAGGLE_API_KEY=your-kaggle-key
```

---

## API Endpoints chính

| Method | Endpoint                   | Mô tả                         | Auth  |
| ------ | -------------------------- | ----------------------------- | ----- |
| POST   | `/api/auth/register`       | Đăng ký tài khoản             | Không |
| POST   | `/api/auth/login`          | Đăng nhập, nhận JWT           | Không |
| POST   | `/api/auth/verify-otp`     | Xác thực OTP email            | Không |
| POST   | `/api/auth/reset-password` | Đặt lại mật khẩu              | Không |
| GET    | `/api/users/me`            | Thông tin tài khoản hiện tại  | User  |
| PUT    | `/api/users/me`            | Cập nhật tên, email           | User  |
| POST   | `/api/users/{id}/avatar`   | Upload ảnh đại diện (max 5MB) | User  |
| POST   | `/api/docs/generate`       | Sinh tài liệu từ mã nguồn     | User  |
| GET    | `/api/docs/`               | Lịch sử tài liệu              | User  |
| POST   | `/api/docs/check-syntax`   | Kiểm tra syntax code          | User  |
| GET    | `/api/docs/{id}/export`    | Xuất tài liệu MD/PDF/DOCX     | User  |
| GET    | `/api/public/models`       | Danh sách model AI active     | Không |
| GET    | `/api/admin/dashboard`     | Thống kê hệ thống             | Admin |
| GET    | `/api/admin/users`         | Quản lý người dùng            | Admin |
| PUT    | `/api/admin/models/{id}`   | Bật/tắt model AI              | Admin |

> Tài liệu Swagger đầy đủ: `http://localhost:8000/docs`

---

## Deploy trên AWS Ubuntu (production)

```bash
# 1. SSH vào server
ssh ubuntu@<your-ip>

# 2. Cập nhật code
cd ~/code-docs-generator-Sever/backend
git pull  # hoặc upload file mới qua WinSCP

# 3. Restart backend
docker compose down
docker compose up -d --build

# Kiểm tra logs
docker compose logs -f api
```

### Nginx config mẫu

```nginx
server {
    listen 80;
    server_name docgenvn.id.vn;

    location /api/ {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /data/ {
        proxy_pass http://localhost:8000;
    }

    location / {
        root /var/www/html;
        try_files $uri $uri/ /index.html;
    }
}
```

---

## Ngôn ngữ hỗ trợ kiểm tra syntax

Python, JavaScript, TypeScript, Java, C++, Rust

---

## Lưu ý CORS

File `main.py` liệt kê rõ các origin được phép. Khi thêm domain mới hoặc port debug mới, cập nhật danh sách `allow_origins` và restart backend.

```python
allow_origins=[
    "https://docgenvn.id.vn",
    "http://localhost:8080",   # flutter run --web-port=8080
]
```
