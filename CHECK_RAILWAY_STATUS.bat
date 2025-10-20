@echo off
chcp 65001 >nul
echo ============================================================
echo  🚂 Проверка статуса Railway БД АСУ ТП
echo ============================================================
echo.

echo Введите данные для подключения к Railway:
echo.
set /p PGHOST="Host (например, containers-us-west-xxx.railway.app): "
set /p PGPORT="Port (обычно 5432): "
set /p PGDATABASE="Database (обычно railway): "
set /p PGUSER="User (обычно postgres): "
set /p PGPASSWORD="Password: "

echo.
echo ============================================================
echo  Подключение к БД...
echo ============================================================
echo.

REM Проверка наличия psql
psql --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ psql не установлен!
    echo.
    echo Установи PostgreSQL Client:
    echo https://www.postgresql.org/download/windows/
    echo.
    echo Или используй Railway Data Tab в веб-интерфейсе
    pause
    exit /b 1
)

echo ✅ psql найден
echo.

REM Установка переменных окружения
set PGSSLMODE=require

echo ============================================================
echo  Проверка подключения...
echo ============================================================
echo.

psql -c "SELECT version();"
if %errorlevel% neq 0 (
    echo.
    echo ❌ Не удалось подключиться к БД!
    echo.
    echo Проверь:
    echo 1. Правильность данных подключения
    echo 2. Что Railway БД запущена
    echo 3. Firewall настройки
    echo 4. SSL подключение (должен быть включен)
    pause
    exit /b 1
)

echo ✅ Подключение успешно!
echo.

echo ============================================================
echo  Проверка схем...
echo ============================================================
echo.

psql -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('core', 'tech_params', 'controllers', 'archive', 'algorithms', 'visualization', 'topology', 'kross', 'security', 'events', 'reports') ORDER BY schema_name;"

echo.
echo ============================================================
echo  Статистика по таблицам...
echo ============================================================
echo.

psql -c "SELECT schemaname, COUNT(*) as table_count FROM pg_tables WHERE schemaname IN ('core', 'tech_params', 'controllers', 'archive', 'algorithms', 'visualization', 'topology', 'kross', 'security', 'events', 'reports') GROUP BY schemaname ORDER BY schemaname;"

echo.
echo ============================================================
echo  Пользователи системы...
echo ============================================================
echo.

psql -c "SELECT username, full_name, position, is_active FROM security.users;" 2>nul
if %errorlevel% neq 0 (
    echo ⚠️  Таблица пользователей еще не создана
)

echo.
echo ============================================================
echo  Роли системы...
echo ============================================================
echo.

psql -c "SELECT code, name, priority FROM security.roles ORDER BY priority DESC;" 2>nul
if %errorlevel% neq 0 (
    echo ⚠️  Таблица ролей еще не создана
)

echo.
echo ============================================================
echo  Размер базы данных...
echo ============================================================
echo.

psql -c "SELECT pg_size_pretty(pg_database_size(current_database())) as database_size;"

echo.
echo ============================================================
echo  Количество подключений...
echo ============================================================
echo.

psql -c "SELECT count(*) as active_connections FROM pg_stat_activity WHERE datname = current_database();"

echo.
echo ============================================================
echo  ✅ Проверка завершена!
echo ============================================================
echo.
echo Railway Dashboard: https://railway.app/dashboard
echo.

REM Очистка переменных
set PGHOST=
set PGPORT=
set PGDATABASE=
set PGUSER=
set PGPASSWORD=
set PGSSLMODE=

pause

