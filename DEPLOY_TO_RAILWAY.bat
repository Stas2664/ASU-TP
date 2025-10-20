@echo off
chcp 65001 >nul
echo ╔═══════════════════════════════════════════════════════════╗
echo ║   🚂 Развертывание БД АСУ ТП на Railway                   ║
echo ╚═══════════════════════════════════════════════════════════╝
echo.

echo Этот скрипт поможет развернуть БД на Railway
echo.
echo ============================================================
echo  Шаг 1: Выбор SQL файла
echo ============================================================
echo.
echo Какой файл загрузить?
echo.
echo [1] railway_init.sql - Упрощенная версия (для демо/тестов)
echo     • Быстрое развертывание (~30 сек)
echo     • Базовые таблицы
echo     • Подходит для начала работы
echo.
echo [2] FULL_ASU_TP_RAILWAY.sql - Полная версия (для продакшн)
echo     • Полное развертывание (~2-3 мин)
echo     • Все 50+ таблиц
echo     • Все функции и триггеры
echo.
set /p CHOICE="Выбери вариант (1 или 2): "

if "%CHOICE%"=="1" (
    set SQL_FILE=railway_init.sql
    echo.
    echo ✅ Выбран: railway_init.sql
) else if "%CHOICE%"=="2" (
    set SQL_FILE=FULL_ASU_TP_RAILWAY.sql
    echo.
    echo ✅ Выбран: FULL_ASU_TP_RAILWAY.sql
) else (
    echo.
    echo ❌ Неверный выбор!
    pause
    exit /b 1
)

echo.
echo ============================================================
echo  Шаг 2: Данные подключения Railway
echo ============================================================
echo.
echo Получи данные из Railway:
echo 1. Открой https://railway.app/dashboard
echo 2. Выбери свой проект с PostgreSQL
echo 3. Кликни на PostgreSQL
echo 4. Вкладка "Connect"
echo 5. Скопируй данные сюда
echo.

set /p PGHOST="Host (например, containers-us-west-xxx.railway.app): "
set /p PGPORT="Port (обычно 5432): "
set /p PGDATABASE="Database (обычно railway): "
set /p PGUSER="User (обычно postgres): "
set /p PGPASSWORD="Password: "

echo.
echo ============================================================
echo  Шаг 3: Проверка psql
echo ============================================================
echo.

psql --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ psql не установлен!
    echo.
    echo У тебя два варианта:
    echo.
    echo ВАРИАНТ A: Установить PostgreSQL Client
    echo   1. Скачай: https://www.postgresql.org/download/windows/
    echo   2. Установи PostgreSQL
    echo   3. Добавь в PATH: C:\Program Files\PostgreSQL\15\bin
    echo   4. Перезапусти этот скрипт
    echo.
    echo ВАРИАНТ B: Использовать Railway веб-интерфейс
    echo   1. Открой Railway Dashboard
    echo   2. Кликни на PostgreSQL
    echo   3. Вкладка "Data"
    echo   4. Кнопка "Query"
    echo   5. Скопируй содержимое файла %SQL_FILE%
    echo   6. Вставь в Query Editor
    echo   7. Нажми "Execute"
    echo.
    pause
    exit /b 1
)

echo ✅ psql найден
echo.

echo ============================================================
echo  Шаг 4: Проверка подключения
echo ============================================================
echo.

set PGSSLMODE=require

psql -c "SELECT version();"
if %errorlevel% neq 0 (
    echo.
    echo ❌ Не удалось подключиться!
    echo.
    echo Проверь:
    echo • Правильность данных подключения
    echo • Что Railway БД запущена
    echo • Firewall не блокирует подключение
    echo.
    pause
    exit /b 1
)

echo ✅ Подключение успешно!
echo.

echo ============================================================
echo  Шаг 5: Загрузка схемы БД
echo ============================================================
echo.
echo Загружаю %SQL_FILE%...
echo Это может занять несколько минут...
echo.

psql -f %SQL_FILE%

if %errorlevel% neq 0 (
    echo.
    echo ❌ Ошибка при загрузке схемы!
    echo.
    echo Проверь:
    echo • Файл %SQL_FILE% существует
    echo • Правильность SQL синтаксиса
    echo • Логи выше для деталей ошибки
    echo.
    pause
    exit /b 1
)

echo.
echo ✅ Схема загружена!
echo.

echo ============================================================
echo  Шаг 6: Проверка развертывания
echo ============================================================
echo.

echo Проверяю созданные схемы...
psql -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name IN ('core', 'tech_params', 'controllers', 'archive', 'algorithms', 'visualization', 'topology', 'kross', 'security', 'events', 'reports') ORDER BY schema_name;"

echo.
echo Проверяю таблицы...
psql -c "SELECT schemaname, COUNT(*) as table_count FROM pg_tables WHERE schemaname IN ('core', 'tech_params', 'controllers', 'archive', 'algorithms', 'visualization', 'topology', 'kross', 'security', 'events', 'reports') GROUP BY schemaname ORDER BY schemaname;"

echo.
echo Проверяю пользователей...
psql -c "SELECT username, full_name FROM security.users;" 2>nul

echo.
echo ╔═══════════════════════════════════════════════════════════╗
echo ║   ✅ РАЗВЕРТЫВАНИЕ НА RAILWAY ЗАВЕРШЕНО!                  ║
echo ╚═══════════════════════════════════════════════════════════╝
echo.
echo 📍 Данные подключения:
echo.
echo   Host:     %PGHOST%
echo   Port:     %PGPORT%
echo   Database: %PGDATABASE%
echo   User:     %PGUSER%
echo   SSL:      required
echo.
echo 💡 Пользователь приложения (если загружен):
echo   Логин:    admin
echo   Пароль:   AdminPassword123!
echo.
echo   ⚠️  ВАЖНО: Смени пароль admin в production!
echo.
echo 🌐 Railway Dashboard:
echo   https://railway.app/dashboard
echo.
echo 📊 Мониторинг:
echo   Railway → PostgreSQL → вкладка "Metrics"
echo.
echo 📝 Connection String для приложения:
echo   postgresql://%PGUSER%:%PGPASSWORD%@%PGHOST%:%PGPORT%/%PGDATABASE%?sslmode=require
echo.
echo ============================================================
echo.

REM Сохранение конфигурации
echo # Railway БД конфигурация > .env.railway
echo # Создано: %date% %time% >> .env.railway
echo. >> .env.railway
echo PGHOST=%PGHOST% >> .env.railway
echo PGPORT=%PGPORT% >> .env.railway
echo PGDATABASE=%PGDATABASE% >> .env.railway
echo PGUSER=%PGUSER% >> .env.railway
echo PGPASSWORD=%PGPASSWORD% >> .env.railway
echo PGSSLMODE=require >> .env.railway
echo. >> .env.railway
echo DATABASE_URL=postgresql://%PGUSER%:%PGPASSWORD%@%PGHOST%:%PGPORT%/%PGDATABASE%?sslmode=require >> .env.railway

echo ✅ Конфигурация сохранена в .env.railway
echo.

REM Очистка переменных из памяти
set PGHOST=
set PGPORT=
set PGDATABASE=
set PGUSER=
set PGPASSWORD=
set PGSSLMODE=
set SQL_FILE=
set CHOICE=

pause

