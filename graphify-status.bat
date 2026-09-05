@echo off
rem ===== Saklar Graphify: CEK STATUS =====
cd /d "%~dp0"
python tools\graphify_switch.py status
echo.
pause
