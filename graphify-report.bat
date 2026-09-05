@echo off
rem ===== Laporan token Graphify (pass --reset sebagai argumen untuk mulai pengukuran baru) =====
cd /d "%~dp0"
python tools\token_report.py %*
echo.
pause
