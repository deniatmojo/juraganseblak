@echo off
rem ===== Saklar Graphify: OFF (assistant balik baca file mentah) =====
cd /d "%~dp0"
python tools\graphify_switch.py off
echo.
pause
