# Sử dụng môi trường Python 3.11 gọn nhẹ (chuẩn với dự án của bạn)
FROM python:3.11-slim

# Cài đặt các công cụ hệ thống cần thiết cho PostgreSQL (psycopg2)
RUN apt-get update && apt-get install -y libpq-dev gcc && rm -rf /var/lib/apt/lists/*

# Thiết lập thư mục làm việc bên trong Container
WORKDIR /app

# Copy file thư viện vào và cài đặt trước (giúp build nhanh hơn ở các lần sau)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy toàn bộ code backend vào Container
COPY . .

# Mở cổng 8000 để giao tiếp
EXPOSE 8000

# Lệnh khởi chạy FastAPI bằng Uvicorn
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]