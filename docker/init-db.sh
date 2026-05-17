#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# Đặt file này vào cùng cấp với docker-compose.yaml
# Mount vào /docker-entrypoint-initdb.d/ của container postgres
# Container sẽ tự động chạy file này LẦN ĐẦU khởi tạo volume.
# ─────────────────────────────────────────────────────────────────────────────
set -e

echo "[*] Khởi tạo Database cho DocGen VN..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
    -- ── Tạo database web_and_app_db nếu chưa có ─────────────────────
    SELECT 'CREATE DATABASE web_and_app_db OWNER airflow'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'web_and_app_db')\gexec

    -- ── Cấp quyền ───────────────────────────────────────────────────
    GRANT ALL PRIVILEGES ON DATABASE web_and_app_db TO airflow;
EOSQL

# ── Bật pgvector extension trên database web_and_app_db ─────────────────────
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "web_and_app_db" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS vector;
EOSQL

# ── Bật pgvector trên database airflow (cho Airflow dùng pgvector nếu cần) ──
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "airflow" <<-EOSQL
    CREATE EXTENSION IF NOT EXISTS vector;
EOSQL

echo "[+] Đã khởi tạo xong: airflow + web_and_app_db (đều bật pgvector)"
