cd D:\Android_Studio_Project\code-docs-generator-Copy
Write-Host "--- Buoc 1: Tat Docker cu ---" -ForegroundColor Yellow
docker compose -f docker-compose.dev.yaml down -v
Write-Host "--- Buoc 2: Bat Database ---" -ForegroundColor Yellow
docker compose -f docker-compose.dev.yaml up -d
Write-Host "--- Doi 5 giay... ---" -ForegroundColor Cyan
Start-Sleep -Seconds 5
Write-Host "--- Buoc 3: Init DB ---" -ForegroundColor Yellow
Get-Content docker\init-db.sh | docker exec -i docgen-postgres-dev bash
Write-Host "--- Buoc 4: Bat FastAPI ---" -ForegroundColor Yellow
cd backend
.\venv\Scripts\Activate.ps1
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
