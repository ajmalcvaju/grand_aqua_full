@echo off
echo ============================================================
echo   Starting Grand Aqua Ecosystem Services (MongoDB rs0)
echo ============================================================

:: 1. Check MongoDB replica set on port 27018
netstat -ano | findstr 27018 >nul
if %errorlevel% neq 0 (
    echo [1/3] Starting MongoDB replica set rs0 on port 27018...
    start "MongoDB Replica Set" /min "C:\Program Files\MongoDB\Server\7.0\bin\mongod.exe" --port 27018 --dbpath "C:\Users\lenovo\mongo_data" --replSet rs0 --bind_ip 127.0.0.1
    timeout /t 3 >nul
) else (
    echo [1/3] MongoDB replica set rs0 is already running on port 27018.
)

:: 2. Start Unified Backend
echo [2/3] Starting Grand Aqua Unified Backend on port 4000...
start "Grand Aqua Backend" /d "D:\grand_aqua_full\grand-aqua\grand aqua backend" cmd /k "npm run start:dev"

:: 3. Inform user
echo [3/3] Backend is launching!
echo.
echo ============================================================
echo   Base REST API: http://192.168.29.44:4000/api/v1
echo   Swagger Docs:  http://192.168.29.44:4000/api/v1/docs
echo ============================================================
pause
