@echo off
chcp 65001 >nul
echo ============================================================
echo  🚀 Развертывание БД АСУ ТП (локальная установка)
echo ============================================================
echo.

REM Проверка установки PostgreSQL
psql --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ PostgreSQL не установлен или psql не в PATH!
    echo.
    echo Скачайте и установите PostgreSQL 15:
    echo https://www.postgresql.org/download/windows/
    echo.
    echo После установки добавьте в PATH:
    echo C:\Program Files\PostgreSQL\15\bin
    echo.
    pause
    exit /b 1
)

echo ✅ PostgreSQL установлен
echo.

REM Переход в директорию проекта
cd /d "%~dp0"

echo ============================================================
echo  Введите пароль пользователя postgres
echo ============================================================
echo.
set /p PGPASSWORD="Пароль: "
echo.

REM Установка переменной окружения
set PGPASSWORD=%PGPASSWORD%
set PGUSER=postgres
set PGHOST=localhost
set PGPORT=5432

echo ============================================================
echo  Запуск SQL скриптов...
echo ============================================================
echo.

echo [1/8] Создание базы данных...
psql -f sql\01_create_database.sql
if %errorlevel% neq 0 (
    echo ❌ Ошибка при создании базы данных
    pause
    exit /b 1
)
echo ✅ База данных создана
echo.

echo [2/8] Создание схем...
psql -d asu_tp_db -f sql\02_create_schemas.sql
if %errorlevel% neq 0 (
    echo ❌ Ошибка при создании схем
    pause
    exit /b 1
)
echo ✅ Схемы созданы
echo.

echo [3/8] Создание таблиц...
psql -d asu_tp_db -f sql\03_create_tables.sql
if %errorlevel% neq 0 (
    echo ❌ Ошибка при создании таблиц
    pause
    exit /b 1
)
echo ✅ Таблицы созданы
echo.

echo [4/8] Создание индексов...
psql -d asu_tp_db -f sql\04_create_indexes.sql
if %errorlevel% neq 0 (
    echo ❌ Ошибка при создании индексов
    pause
    exit /b 1
)
echo ✅ Индексы созданы
echo.

echo [5/8] Создание ролей...
psql -d asu_tp_db -f sql\05_create_roles.sql
if %errorlevel% neq 0 (
    echo ❌ Ошибка при создании ролей
    pause
    exit /b 1
)
echo ✅ Роли созданы
echo.

echo [6/8] Создание функций...
psql -d asu_tp_db -f sql\06_create_functions.sql
if %errorlevel% neq 0 (
    echo ❌ Ошибка при создании функций
    pause
    exit /b 1
)
echo ✅ Функции созданы
echo.

echo [7/8] Создание триггеров...
psql -d asu_tp_db -f sql\07_create_triggers.sql
if %errorlevel% neq 0 (
    echo ❌ Ошибка при создании триггеров
    pause
    exit /b 1
)
echo ✅ Триггеры созданы
echo.

echo [8/8] Загрузка начальных данных...
psql -d asu_tp_db -f sql\08_initial_data.sql
if %errorlevel% neq 0 (
    echo ❌ Ошибка при загрузке начальных данных
    pause
    exit /b 1
)
echo ✅ Начальные данные загружены
echo.

echo ============================================================
echo  ✅ Развертывание успешно завершено!
echo ============================================================
echo.
echo 📍 Параметры подключения:
echo.
echo   Хост:        localhost
echo   Порт:        5432
echo   Пользователь: postgres
echo   База данных: asu_tp_db
echo.
echo 💡 Пользователь приложения:
echo   ├─ Логин:    admin
echo   └─ Пароль:   AdminPassword123!
echo.
echo 📊 Проверка развертывания:
echo   psql -d asu_tp_db -c "SELECT COUNT(*) FROM tech_params.parameters;"
echo.
echo ============================================================
echo.

REM Очистка переменной с паролем
set PGPASSWORD=

pause

