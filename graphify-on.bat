@echo off
rem ===== Saklar Graphify: ON (mode hemat token, MCP aktif) =====
cd /d "%~dp0"
python tools\graphify_switch.py on
echo.
pause
