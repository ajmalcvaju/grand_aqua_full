@echo off
echo ============================================================
echo   Launching Grand Aqua Web Applications
echo ============================================================

echo [1/2] Launching Super Admin Web App on port 3000...
start "Grand Aqua Admin Web" /d "D:\grand_aqua_full\grand-aqua\grand aqua super admin web app" cmd /k "npm run dev"

echo [2/2] Launching Salesman Web App on port 3001...
start "Grand Aqua Salesman Web" /d "D:\grand_aqua_full\grand-aqua\grand aqua salesman web app" cmd /k "npm run dev"

echo.
echo ============================================================
echo   Super Admin Web: http://localhost:3000
echo   Salesman Web:    http://localhost:3001
echo ============================================================
pause
