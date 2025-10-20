# 🚀 Инструкция по развертыванию БД АСУ ТП

## 📦 Вариант 1: Развертывание через Docker (РЕКОМЕНДУЕТСЯ)

### Шаг 1: Установка Docker Desktop
1. Скачайте Docker Desktop для Windows:
   https://www.docker.com/products/docker-desktop/
2. Запустите установщик и следуйте инструкциям
3. После установки перезагрузите компьютер
4. Запустите Docker Desktop

### Шаг 2: Создание файла .env
```bash
copy env.example .env
```

### Шаг 3: Запуск базы данных
```bash
docker-compose up -d
```

Это запустит:
- ✅ PostgreSQL 15 на порту 5432
- ✅ pgAdmin (веб-интерфейс) на http://localhost:5050
- ✅ Grafana (мониторинг) на http://localhost:3000

### Шаг 4: Инициализация БД (только при первом запуске)
```bash
docker-compose --profile init up db_init
```

### Проверка статуса
```bash
docker-compose ps
```

### Остановка
```bash
docker-compose down
```

### Удаление всех данных (ОСТОРОЖНО!)
```bash
docker-compose down -v
```

---

## 💻 Вариант 2: Локальная установка PostgreSQL

### Шаг 1: Установка PostgreSQL 15
1. Скачайте PostgreSQL 15 для Windows:
   https://www.postgresql.org/download/windows/
2. Запустите установщик
3. Запомните пароль для пользователя `postgres`
4. Установите все компоненты (включая pgAdmin 4)

### Шаг 2: Добавление PostgreSQL в PATH
1. Откройте "Система" → "Дополнительные параметры системы"
2. Нажмите "Переменные среды"
3. В "Path" добавьте: `C:\Program Files\PostgreSQL\15\bin`
4. Перезапустите командную строку

### Шаг 3: Запуск скрипта развертывания
```bash
cd "C:\Users\Admin\Desktop\асу тп"
scripts\init_database.bat
```

Или вручную:
```bash
cd "C:\Users\Admin\Desktop\асу тп\sql"

psql -U postgres -f 01_create_database.sql
psql -U postgres -d asu_tp_db -f 02_create_schemas.sql
psql -U postgres -d asu_tp_db -f 03_create_tables.sql
psql -U postgres -d asu_tp_db -f 04_create_indexes.sql
psql -U postgres -d asu_tp_db -f 05_create_roles.sql
psql -U postgres -d asu_tp_db -f 06_create_functions.sql
psql -U postgres -d asu_tp_db -f 07_create_triggers.sql
psql -U postgres -d asu_tp_db -f 08_initial_data.sql
```

---

## 🔐 Учетные данные по умолчанию

### PostgreSQL
- Хост: localhost
- Порт: 5432
- Пользователь: postgres
- Пароль: postgres (или SecurePassword123! если используете .env)
- База данных: asu_tp_db

### Пользователь приложения (после инициализации)
- Логин: admin
- Пароль: AdminPassword123!

### pgAdmin (только Docker)
- URL: http://localhost:5050
- Email: admin@asu-tp.local
- Пароль: AdminPassword123!

### Grafana (только Docker)
- URL: http://localhost:3000
- Логин: admin
- Пароль: GrafanaPassword123!

---

## 📊 Проверка развертывания

### Для Docker:
```bash
docker exec -it asu_tp_postgres psql -U postgres -d asu_tp_db -c "SELECT COUNT(*) FROM tech_params.parameters;"
```

### Для локальной установки:
```bash
psql -U postgres -d asu_tp_db -c "SELECT COUNT(*) FROM tech_params.parameters;"
```

---

## 🛠 Структура базы данных

После развертывания будут созданы следующие схемы:

- ✅ **core** - Основные системные таблицы и справочники
- ✅ **tech_params** - Технологические и диагностические параметры
- ✅ **controllers** - Конфигурация контроллеров КУПРИ
- ✅ **archive** - Архивные данные и исторические значения
- ✅ **algorithms** - Расчетные алгоритмы и формулы
- ✅ **visualization** - Видеокадры и элементы визуализации
- ✅ **topology** - Узлы ПТК и топология системы
- ✅ **kross** - Параметры платформы КРОСС
- ✅ **security** - Пользователи, роли, права доступа и аудит
- ✅ **events** - События, тревоги и уведомления
- ✅ **reports** - Шаблоны и данные отчетов

---

## 📝 Дополнительные команды

### Резервное копирование (Docker)
```bash
docker-compose --profile backup up backup
```

### Резервное копирование (локально)
```bash
pg_dump -U postgres -d asu_tp_db -Fc -f backup\asu_tp_db_backup.dump
```

### Восстановление
```bash
pg_restore -U postgres -d asu_tp_db backup\asu_tp_db_backup.dump
```

---

## ⚠️ ВАЖНО!

1. **Пароли по умолчанию** - обязательно измените все пароли в production!
2. **Настройки производительности** - в 01_create_database.sql есть настройки для 16GB RAM
3. **Локаль** - используется ru_RU.UTF-8 для поддержки русского языка
4. **Порты** - убедитесь что порты 5432, 5050, 3000 свободны

---

## 📞 Поддержка

При возникновении проблем проверьте:
- Логи Docker: `docker-compose logs postgres`
- Логи PostgreSQL: в папке `logs/postgres`
- Статус сервисов: `docker-compose ps`

---

**Дата создания**: 2025
**Проект**: АО "НИКИЭТ" / Платформа КРОСС
**Стандарты**: ГОСТ Р ИСО 9001-2015

