@echo off
chcp 65001 >nul
echo ============================================================
echo  📊 Проверка статуса БД АСУ ТП
echo ============================================================
echo.

REM Проверка Docker
docker --version >nul 2>&1
if %errorlevel% equ 0 (
    echo ============================================================
    echo  Docker контейнеры
    echo ============================================================
    echo.
    docker-compose ps
    echo.
    
    echo ============================================================
    echo  Логи PostgreSQL (последние 20 строк)
    echo ============================================================
    echo.
    docker-compose logs --tail=20 postgres
    echo.
)

REM Проверка локальной установки PostgreSQL
psql --version >nul 2>&1
if %errorlevel% equ 0 (
    echo ============================================================
    echo  Локальная установка PostgreSQL
    echo ============================================================
    echo.
    
    set /p PGPASSWORD="Введите пароль postgres: "
    set PGPASSWORD=%PGPASSWORD%
    
    echo.
    echo Проверка подключения...
    psql -U postgres -d asu_tp_db -c "SELECT version();"
    
    echo.
    echo Статистика по схемам:
    psql -U postgres -d asu_tp_db -c "SELECT schemaname, COUNT(*) as table_count FROM pg_tables WHERE schemaname IN ('core', 'tech_params', 'controllers', 'archive', 'algorithms', 'visualization', 'topology', 'kross', 'security', 'events', 'reports') GROUP BY schemaname ORDER BY schemaname;"
    
    echo.
    echo Пользователи системы:
    psql -U postgres -d asu_tp_db -c "SELECT username, full_name, position, is_active FROM security.users;"
    
    echo.
    echo Роли системы:
    psql -U postgres -d asu_tp_db -c "SELECT code, name, priority FROM security.roles ORDER BY priority DESC;"
    
    set PGPASSWORD=
)

if %errorlevel% neq 0 (
    echo ❌ Ни Docker, ни PostgreSQL не найдены!
    echo.
    echo Установите один из вариантов:
    echo 1. Docker Desktop: https://www.docker.com/products/docker-desktop/
    echo 2. PostgreSQL 15: https://www.postgresql.org/download/windows/
)

echo.
echo ============================================================
pause

