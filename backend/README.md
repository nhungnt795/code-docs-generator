# Backend DocGen VN — Cụm 1

## 🎯 Đã xử lý

| Yêu cầu | Trạng thái | File |
|---|---|---|
| I.1 Xuất MD/PDF/DOCX | ✅ | `export_service.py`, `routers/documents.py` |
| I.5 Lưu đúng bản đã sửa | ✅ | `routers/documents.py` (PUT /api/docs/{id}) |
| I.6 Phân quyền lịch sử | ✅ | `routers/documents.py` (check `user_id`) |
| I.7 Timestamp đúng | ✅ | `models.Document.updated_at` cập nhật khi sửa |
| I.9 Dashboard mới: `pending_requests`, filter thời gian | ✅ | `routers/admin.py` |
| I.9 Lock/unlock + bulk + filter + search | ✅ | `routers/admin.py` |
| I.9 Xem usage & history từng user | ✅ | `GET /api/admin/users/{id}` |
| I.10 API gửi feedback | ✅ | `routers/feedback.py` |
| II Auth: OTP, reset password, xử lý lỗi chi tiết | ✅ | `routers/auth.py` |
| II Profile: đổi tên/email | ✅ | `routers/profile.py` |
| II Khóa tài khoản | ✅ | `POST /api/admin/users/{id}/lock` |
| II Check Syntax — không tự raise, có warning | ✅ | `validators.check_syntax` |
| II Quản lý Model AI: bật/tắt | ✅ | `routers/admin.py` + `public.py` |

## 📦 Endpoints

### Auth
- `POST /api/auth/register` — Đăng ký + gửi OTP
- `POST /api/auth/verify` — Xác thực OTP kích hoạt
- `POST /api/auth/login` — Đăng nhập (chặn nếu chưa kích hoạt / bị khóa)
- `POST /api/auth/resend-otp` — Gửi lại OTP (ACTIVATE | RESET_PASSWORD)
- `POST /api/auth/forgot-password` — Yêu cầu OTP đặt lại mật khẩu
- `POST /api/auth/reset-password` — Xác nhận OTP + mật khẩu mới

### Profile
- `GET  /api/users/{id}` — Lấy profile
- `PUT  /api/users/{id}/profile` — Đổi tên/email
- `PUT  /api/users/{id}/password` — Đổi mật khẩu
- `POST /api/users/{id}/avatar` — Upload avatar

### Documents
- `POST   /api/docs/generate?user_id=` — Sinh tài liệu (lưu vào DB)
- `POST   /api/docs/generate/guest` — Sinh cho khách (không lưu)
- `POST   /api/docs/check-syntax` — Check syntax riêng (trả warning)
- `GET    /api/docs/history/{user_id}` — Lịch sử
- `GET    /api/docs/{id}?user_id=` — Chi tiết + versions
- `PUT    /api/docs/{id}?user_id=` — Sửa (tạo version mới)
- `DELETE /api/docs/{id}?user_id=` — Xóa
- `GET    /api/docs/{id}/export?format=md|pdf|docx&user_id=` — Tải file
- `POST   /api/docs/export` — Xuất từ nội dung tự do (cho guest)

### Admin
- `GET  /api/admin/dashboard?admin_id=&range_key=today|week|month|year|custom|all`
- `GET  /api/admin/users?admin_id=&status=all|active|locked|inactive&search=`
- `GET  /api/admin/users/{id}?admin_id=` — Chi tiết + usage + history
- `POST /api/admin/users/{id}/lock?admin_id=`
- `POST /api/admin/users/{id}/unlock?admin_id=`
- `POST /api/admin/users/bulk?admin_id=` — body `{user_ids: [...], action: "LOCK|UNLOCK|DELETE"}`
- `POST /api/admin/promote/{id}?admin_id=`
- `GET  /api/admin/logs?admin_id=`
- `GET  /api/admin/models?admin_id=` — Danh sách model AI
- `PUT  /api/admin/models/{model_type}?admin_id=` — Bật/tắt model
- `GET  /api/admin/feedbacks?admin_id=&min_rating=`

### Feedback (user)
- `POST /api/feedback?user_id=` — body `{rating: 1-5, content?: ""}`
- `GET  /api/feedback/my?user_id=`

### Public
- `GET /api/public/models` — Frontend lấy list model active để hiện cho user chọn

## 🚀 Deploy

### Local (dev)

```bash
cd backend
cp .env.example .env  # rồi điền giá trị
docker compose up --build
```

### AWS EC2 (production)

1. Copy thư mục `backend/` lên server (qua WinSCP).
2. Tạo file `.env` từ `.env.example`, điền `DB_USER`, `DB_PASS`, `DB_NAME`, `SMTP_*`.
3. Chạy:

```bash
cd backend
docker compose down       # nếu đang chạy bản cũ
docker compose up -d --build
docker compose logs -f api
```

Nginx đã sẵn proxy `/api/` → `localhost:8000` thì không cần thay đổi gì thêm.

## 🛠 Migration từ bản cũ

Schema cũ → mới có thêm 4 cột vào `users`, 2 bảng mới (`document_versions`,
`ai_model_configs`, `feedbacks`), và 1 cột vào `documents` (`ai_model`).

Có 2 cách:

### Cách 1: Xóa DB cũ làm lại (đơn giản, mất data)

```bash
docker compose down -v   # -v xóa volume luôn
docker compose up -d --build
```

### Cách 2: ALTER bảng (giữ data) — chạy trong psql:

```sql
-- users: thêm cột
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS otp_purpose VARCHAR(20),
  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Set is_active = TRUE cho user cũ (vì chưa kích hoạt được hồi tố)
UPDATE users SET is_active = TRUE WHERE is_active IS NULL OR is_active = FALSE;

-- documents: thêm cột ai_model
ALTER TABLE documents
  ADD COLUMN IF NOT EXISTS ai_model VARCHAR(30) DEFAULT 'GROQ_LLAMA3' NOT NULL;

-- Bảng mới (SQLAlchemy create_all sẽ tự tạo khi khởi động lại)
-- Hoặc tạo tay:
CREATE TABLE IF NOT EXISTS document_versions (
  version_id     SERIAL PRIMARY KEY,
  doc_id         INT NOT NULL REFERENCES documents(doc_id) ON DELETE CASCADE,
  version_number INT NOT NULL,
  content_md     TEXT NOT NULL,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_model_configs (
  id           SERIAL PRIMARY KEY,
  model_type   VARCHAR(30) UNIQUE NOT NULL,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  display_name VARCHAR(100),
  description  VARCHAR(255),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS feedbacks (
  id         SERIAL PRIMARY KEY,
  user_id    INT NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
  rating     INT NOT NULL,
  content    TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

## 🧪 Test nhanh sau khi deploy

```bash
# Health
curl http://15.135.219.188:8000/health

# Register
curl -X POST http://15.135.219.188:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@x.com","password":"123456","full_name":"Test"}'

# Lấy list model
curl http://15.135.219.188:8000/api/public/models
```

Truy cập Swagger UI: `http://15.135.219.188:8000/docs`

## 📋 Lưu ý

- **SMTP chưa cấu hình**: OTP sẽ in ra console (xem `docker compose logs api`). 
  Frontend vẫn chạy được trong chế độ dev — copy OTP từ log để test.
- **AI Model URL/Key**: hiện chưa được sử dụng trong RAG engine của bạn. Khi Cụm 3 
  hoàn thiện UI chọn model, sẽ wire vào `routers/documents.py::generate_document`.
- **WeasyPrint** cần thư viện hệ thống (đã thêm vào Dockerfile). Nếu chạy ngoài Docker,
  cài: `apt install libpango-1.0-0 libcairo2 libgdk-pixbuf-2.0-0 fonts-dejavu`.
