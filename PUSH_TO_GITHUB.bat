@echo off
chcp 65001 >nul
echo ============================================================
echo  📤 Пуш проекта АСУ ТП на GitHub
echo ============================================================
echo.

REM Проверка git
git --version >nul 2>&1
if %errorlevel% neq 0 (
    echo ❌ Git не установлен!
    echo.
    echo Скачай и установи Git для Windows:
    echo https://git-scm.com/download/win
    echo.
    echo После установки перезапусти этот скрипт
    pause
    exit /b 1
)

echo ✅ Git установлен
echo.

REM Инициализация репозитория
if not exist ".git" (
    echo Инициализация git репозитория...
    git init
    echo ✅ Git инициализирован
    echo.
)

REM Добавление remote
echo Добавление remote origin...
git remote remove origin 2>nul
git remote add origin https://github.com/Stas2664/ASU-TP.git
echo ✅ Remote добавлен
echo.

REM Добавление файлов
echo Добавление файлов в git...
git add .
echo ✅ Файлы добавлены
echo.

REM Коммит
echo Создание коммита...
git commit -m "Проект АСУ ТП: полная структура БД + документация + развертывание (100%% под ключ)"
echo ✅ Коммит создан
echo.

REM Переименование ветки
echo Переименование ветки в main...
git branch -M main
echo ✅ Ветка переименована
echo.

REM Пуш
echo ============================================================
echo  Отправка на GitHub...
echo ============================================================
echo.
echo Может потребоваться авторизация GitHub:
echo  • Введи username/password
echo  • Или используй Personal Access Token
echo.

git push -u origin main

if %errorlevel% equ 0 (
    echo.
    echo ╔═══════════════════════════════════════════════════════════╗
    echo ║   ✅ ПРОЕКТ УСПЕШНО ЗАГРУЖЕН НА GITHUB!                   ║
    echo ╚═══════════════════════════════════════════════════════════╝
    echo.
    echo 🌐 Репозиторий: https://github.com/Stas2664/ASU-TP
    echo.
) else (
    echo.
    echo ❌ Ошибка при пуше!
    echo.
    echo Возможные причины:
    echo  • Нужна авторизация GitHub
    echo  • Репозиторий не существует
    echo  • Нет прав доступа
    echo.
    echo Решение:
    echo  1. Создай репозиторий https://github.com/new
    echo  2. Настрой авторизацию (Personal Access Token)
    echo  3. Повтори пуш
    echo.
)

pause

