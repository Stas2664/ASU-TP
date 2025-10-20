@echo off
chcp 65001 >nul
echo ============================================================
echo  🚀 Запуск БД АСУ ТП через Docker
echo ============================================================
echo.

REM Проверка установки Docker
docker --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Docker не установлен!
    echo.
    echo Скачайте и установите Docker Desktop:
    echo https://www.docker.com/products/docker-desktop/
    echo.
    pause
    exit /b 1
)

echo ✅ Docker установлен
echo.

REM Переход в директорию проекта
cd /d "%~dp0"

REM Проверка наличия .env файла
if not exist ".env" (
    echo 📝 Создание файла .env из env.example...
    copy env.example .env
    echo ✅ Файл .env создан
    echo.
)

echo ============================================================
echo  Запуск контейнеров...
echo ============================================================
echo.

docker-compose up -d

if %errorlevel% neq 0 (
    echo.
    echo ❌ Ошибка при запуске контейнеров!
    pause
    exit /b 1
)

echo.
echo ✅ Контейнеры запущены!
echo.

echo ============================================================
echo  Ожидание готовности PostgreSQL...
echo ============================================================
echo.

timeout /t 15 /nobreak >nul

echo ============================================================
echo  Инициализация базы данных...
echo ============================================================
echo.

docker-compose --profile init up db_init

if %errorlevel% neq 0 (
    echo.
    echo ⚠️  Возможно база уже инициализирована
    echo    Это нормально если вы запускаете повторно
    echo.
)

echo.
echo ============================================================
echo  ✅ Развертывание завершено!
echo ============================================================
echo.
echo 📍 Доступные сервисы:
echo.
echo   PostgreSQL:  localhost:5432
echo   ├─ Логин:    postgres
echo   ├─ Пароль:   postgres
echo   └─ БД:       asu_tp_db
echo.
echo   pgAdmin:     http://localhost:5050
echo   ├─ Email:    admin@asu-tp.local
echo   └─ Пароль:   AdminPassword123!
echo.
echo   Grafana:     http://localhost:3000
echo   ├─ Логин:    admin
echo   └─ Пароль:   GrafanaPassword123!
echo.
echo 💡 Пользователь приложения:
echo   ├─ Логин:    admin
echo   └─ Пароль:   AdminPassword123!
echo.
echo ============================================================
echo.

pause

