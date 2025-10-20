@echo off
chcp 65001 >nul
echo ============================================================
echo  📊 Открываю dbdiagram.io для экспорта
echo ============================================================
echo.
start https://dbdiagram.io/d
timeout /t 2 /nobreak >nul
notepad "%~dp0..\docs\acceptance\er_diagram.dbml"
echo.
echo ✅ Открыл dbdiagram.io и файл er_diagram.dbml в Notepad
echo.
echo ИНСТРУКЦИЯ:
echo 1. Скопируй всё из Notepad (Ctrl+A, Ctrl+C)
echo 2. В dbdiagram.io нажми Import → DBML → вставь (Ctrl+V)
echo 3. Export → PNG → сохрани как er_diagram.png в папку diagrams
echo 4. Export → PDF → сохрани как er_diagram.pdf в папку diagrams
echo.
pause

