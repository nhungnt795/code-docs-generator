from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta

default_args = {
    'owner': 'nhung',
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

with DAG('hus_code_mining_pipeline',
         default_args=default_args,
         description='Pipeline tự động crawl code, làm sạch, nhúng Graph RAG và lưu vào PostgreSQL',
         schedule_interval='@daily', # Tự động chạy hằng ngày
         start_date=datetime(2026, 4, 30), 
         catchup=False) as dag:

    # Task 1: Cào dữ liệu từ Github
    task_crawl = BashOperator(
        task_id='crawl_github',
        bash_command='cd /opt/airflow && python src/data_processing/github_crawler.py'
    )

    # Task 2: Làm sạch code thô và đẩy lên postgre database
    task_clean_load = BashOperator(
        task_id='clean_and_upload_postgres',
        bash_command='cd /opt/airflow && python src/data_processing/clean_and_upload.py'
    )

    # Task 3: Chạy Tree-sitter, CodeBERT và lưu vào postgre database
    task_vectorize = BashOperator(
        task_id='feature_embed_and_load',
        bash_command='cd /opt/airflow && python src/data_for_rag/feature_embedder.py'
    )

    # Thiết lập thứ tự chạy tuần tự
    task_crawl >> task_clean_load >> task_vectorize