# Backend image cho DocGen VN
FROM python:3.11-slim

# Thư viện hệ thống:
# - libpq-dev, gcc: để build psycopg2
# - libpango, libcairo, libgdk-pixbuf, fonts-dejavu: cho WeasyPrint xuất PDF
# - shared-mime-info: weasyprint cần
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    gcc \
    libpango-1.0-0 \
    libpangoft2-1.0-0 \
    libcairo2 \
    libgdk-pixbuf-2.0-0 \
    libffi-dev \
    shared-mime-info \
    fonts-dejavu \
    fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 8000

# uvicorn với reload tắt cho production
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
