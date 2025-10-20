@echo off
chcp 65001 >nul
echo ============================================================
echo  ⏹️  Остановка БД АСУ ТП
echo ============================================================
echo.

REM Проверка Docker
docker --version >nul 2>&1
if %errorlevel% equ 0 (
    echo Остановка Docker контейнеров...
    docker-compose down
    
    if %errorlevel% equ 0 (
        echo ✅ Контейнеры остановлены
    ) else (
        echo ❌ Ошибка при остановке контейнеров
    )
    
    echo.
    echo Для удаления всех данных (ОСТОРОЖНО!) выполните:
    echo docker-compose down -v
) else (
    echo Docker не найден
    echo.
    echo Для остановки локального PostgreSQL используйте:
    echo   Windows Services → PostgreSQL → Остановить
    echo   или
    echo   pg_ctl stop -D "C:\Program Files\PostgreSQL\15\data"
)

echo.
echo ============================================================
pause

