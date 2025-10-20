# 🏭 База данных ПТК АСУ ТП

> Единая база данных для программно-технического комплекса автоматизированной системы управления технологическими процессами на базе платформы КРОСС

<div align="center">

**АО "НИКИЭТ"** | **PostgreSQL 15+** | **ГОСТ Р ИСО 9001-2015**

[Быстрый старт](#-быстрый-старт) • [Установка](#-установка) • [Структура](#-структура-базы-данных) • [Документация](#-документация)

</div>

---

## 🚀 Быстрый старт

### Вариант 1: Docker (рекомендуется) 🐳

```bash
# 1. Запусти один файл
START_DOCKER.bat

# 2. Открой браузер
# pgAdmin:  http://localhost:5050
# Grafana:  http://localhost:3000
```

### Вариант 2: Локальная установка 💻

```bash
# 1. Установи PostgreSQL 15+
# 2. Запусти
START_LOCAL.bat
```

### Проверка

```bash
CHECK_STATUS.bat
```

**Готово!** База данных развернута со всеми 11 схемами и 50+ таблицами! ✅

---

## 📦 Что включено

После развертывания ты получишь полнофункциональную БД:

| Компонент | Описание | Статус |
|-----------|----------|--------|
| **11 схем** | Логическое разделение данных | ✅ |
| **50+ таблиц** | Полная структура для АСУ ТП | ✅ |
| **200+ индексов** | Оптимизация производительности | ✅ |
| **Роли (5 шт)** | Разграничение доступа | ✅ |
| **Функции** | Бизнес-логика в БД | ✅ |
| **Триггеры** | Автоматизация процессов | ✅ |
| **Справочники** | Начальные данные | ✅ |

---

## 🗂️ Структура базы данных

```
asu_tp_db
│
├── 📁 core              - Системные таблицы и справочники
│   ├── units                (единицы измерения)
│   ├── data_types           (типы данных)
│   └── statuses             (статусы)
│
├── 📁 tech_params       - Технологические параметры
│   ├── parameters           (параметры)
│   ├── parameter_groups     (группы параметров)
│   ├── current_values       (текущие значения)
│   └── diagnostic_parameters (диагностика)
│
├── 📁 controllers       - Контроллеры КУПРИ
│   ├── controllers          (контроллеры)
│   ├── controller_modules   (модули)
│   └── io_channels          (каналы ввода/вывода)
│
├── 📁 archive          - Архивные данные
│   ├── historical_data      (исторические данные)
│   ├── compressed_data      (сжатые данные)
│   └── archive_configs      (настройки архивации)
│
├── 📁 algorithms       - Расчетные алгоритмы
│   ├── algorithms           (алгоритмы)
│   ├── algorithm_inputs     (входы)
│   ├── algorithm_outputs    (выходы)
│   └── execution_history    (история выполнения)
│
├── 📁 visualization    - Визуализация
│   ├── screens              (видеокадры)
│   ├── screen_elements      (элементы экранов)
│   └── element_templates    (шаблоны элементов)
│
├── 📁 topology         - Топология системы
│   ├── nodes                (узлы ПТК)
│   ├── node_types           (типы узлов)
│   └── node_connections     (связи между узлами)
│
├── 📁 kross            - Платформа КРОСС
│   ├── platform_config      (конфигурация)
│   ├── modules              (модули платформы)
│   └── licenses             (лицензии)
│
├── 📁 security         - Безопасность
│   ├── users                (пользователи)
│   ├── roles                (роли)
│   ├── permissions          (разрешения)
│   ├── user_sessions        (сессии)
│   └── audit_log            (журнал аудита)
│
├── 📁 events           - События и тревоги
│   ├── events               (события)
│   ├── event_classes        (классы событий)
│   └── event_subscriptions  (подписки)
│
└── 📁 reports          - Отчеты
    ├── report_templates     (шаблоны отчетов)
    ├── report_schedules     (расписание)
    └── report_history       (история генерации)
```

---

## 🔐 Роли и права доступа

| Роль | Код | Описание | Приоритет |
|------|-----|----------|-----------|
| **Администратор** | `admin` | Полный доступ к системе | 1000 |
| **Инженер АСУ ТП** | `engineer` | Настройка и конфигурирование | 800 |
| **Старший оператор** | `senior_operator` | Управление + квитирование | 600 |
| **Оператор** | `operator` | Мониторинг и управление | 400 |
| **Наблюдатель** | `viewer` | Только просмотр | 200 |
| **Сервисный** | `service` | Для внешних систем | 100 |

---

## 🛠️ Установка

### Требования

**Docker (рекомендуется):**
- Docker Desktop для Windows
- 8GB RAM минимум
- 20GB свободного места

**Локальная установка:**
- PostgreSQL 15+
- Windows 10/11 или Windows Server
- 16GB RAM рекомендуется

### Быстрая установка

#### Docker

```bash
# 1. Клонируй или распакуй проект
cd "C:\Users\Admin\Desktop\асу тп"

# 2. Запусти
START_DOCKER.bat

# Всё! База данных готова к работе
```

#### Локально

```bash
# 1. Установи PostgreSQL 15
# Скачай: https://www.postgresql.org/download/windows/

# 2. Добавь psql в PATH
# C:\Program Files\PostgreSQL\15\bin

# 3. Запусти
START_LOCAL.bat
```

### Подробная инструкция

Смотри [INSTALLATION.md](INSTALLATION.md) для пошаговых инструкций

---

## 📊 Управление

### Запуск

```bash
START_DOCKER.bat      # Запуск через Docker
START_LOCAL.bat       # Локальная установка
```

### Проверка статуса

```bash
CHECK_STATUS.bat      # Проверка состояния БД
```

### Остановка

```bash
STOP_ALL.bat          # Остановка всех сервисов
```

### Резервное копирование

```bash
# Docker
docker-compose --profile backup up backup

# Локально
cd scripts
backup.bat
```

---

## 🔌 Подключение к БД

### Параметры подключения

```
Host:     localhost
Port:     5432
Database: asu_tp_db
User:     postgres
Password: postgres  (или из .env)
```

### Connection String

```
postgresql://postgres:postgres@localhost:5432/asu_tp_db
```

### Python (psycopg2)

```python
import psycopg2

conn = psycopg2.connect(
    host="localhost",
    port=5432,
    database="asu_tp_db",
    user="postgres",
    password="postgres"
)
```

### Node.js (pg)

```javascript
const { Pool } = require('pg');

const pool = new Pool({
  host: 'localhost',
  port: 5432,
  database: 'asu_tp_db',
  user: 'postgres',
  password: 'postgres'
});
```

---

## 📁 Структура проекта

```
асу_тп/
│
├── 📄 START_DOCKER.bat          - Запуск через Docker
├── 📄 START_LOCAL.bat           - Локальная установка
├── 📄 CHECK_STATUS.bat          - Проверка статуса
├── 📄 STOP_ALL.bat              - Остановка сервисов
├── 📄 INSTALLATION.md           - Подробная инструкция
├── 📄 QUICK_START.md            - Быстрый старт
│
├── 📁 sql/                      - SQL скрипты
│   ├── 01_create_database.sql   - Создание БД
│   ├── 02_create_schemas.sql    - Создание схем
│   ├── 03_create_tables.sql     - Создание таблиц
│   ├── 04_create_indexes.sql    - Создание индексов
│   ├── 05_create_roles.sql      - Роли и права
│   ├── 06_create_functions.sql  - Функции
│   ├── 07_create_triggers.sql   - Триггеры
│   └── 08_initial_data.sql      - Начальные данные
│
├── 📁 docs/                     - Документация
│   ├── technical_specification.md
│   ├── database_model.md
│   └── admin_guide.md
│
├── 📁 scripts/                  - Вспомогательные скрипты
│   ├── backup.sh
│   ├── restore.sh
│   └── test_connection.py
│
├── 📁 backup/                   - Резервные копии
├── 📁 logs/                     - Логи
│
├── 🐳 docker-compose.yml        - Docker конфигурация
├── 🐳 Dockerfile                - Docker образ
├── 📄 .env                      - Настройки окружения
├── 📄 env.example               - Пример настроек
└── 📄 requirements.txt          - Python зависимости
```

---

## 📚 Документация

| Документ | Описание |
|----------|----------|
| [QUICK_START.md](QUICK_START.md) | Быстрый старт |
| [INSTALLATION.md](INSTALLATION.md) | Подробная установка |
| [technical_specification.md](docs/technical_specification.md) | Техническая спецификация |
| [database_model.md](docs/database_model.md) | Модель базы данных |
| [admin_guide.md](docs/admin_guide.md) | Руководство администратора |

---

## 🎯 Основные возможности

### ✅ Многопользовательский доступ
- Ролевая модель с 6 ролями
- Разграничение прав доступа
- Row Level Security (RLS)
- Аудит всех действий

### ✅ Производительность
- 200+ оптимизированных индексов
- BRIN индексы для временных рядов
- Партиционирование архивных таблиц
- Настройки для работы в реальном времени

### ✅ Надежность
- Автоматическое резервное копирование
- Репликация (опционально)
- Health checks
- Логирование всех операций

### ✅ Масштабируемость
- Партиционирование по времени
- Сжатие архивных данных
- Оптимизация для больших объемов
- Поддержка горизонтального масштабирования

---

## 🔧 Настройка производительности

База данных оптимизирована для:
- **RAM**: 16GB (рекомендуется)
- **CPU**: 4+ ядер
- **Диск**: SSD (настройки random_page_cost=1.1)
- **Подключения**: до 200 одновременных

Настройки в:
- `sql/01_create_database.sql`
- `docker-compose.yml`
- `.env`

---

## 🐛 Устранение неполадок

### Docker не запускается
```bash
# Проверь статус Docker Desktop
docker --version
docker-compose --version
```

### PostgreSQL не подключается
```bash
# Проверь статус сервиса
docker-compose ps
# или для локальной установки
pg_isready -h localhost -p 5432
```

### Ошибки при выполнении SQL
- Проверь версию PostgreSQL (должна быть 15+)
- Убедись что предыдущие скрипты выполнились успешно
- Проверь логи: `logs/postgres/`

---

## 📈 Мониторинг

### Docker (включено)
- **Grafana**: http://localhost:3000
- **pgAdmin**: http://localhost:5050

### Запросы для мониторинга

```sql
-- Активные подключения
SELECT count(*) FROM pg_stat_activity;

-- Размер базы данных
SELECT pg_size_pretty(pg_database_size('asu_tp_db'));

-- Статистика по таблицам
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables 
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

---

## 🔒 Безопасность

### Важно!
1. **Измени пароли по умолчанию** в production!
2. Используй SSL для удаленных подключений
3. Настрой firewall для порта 5432
4. Регулярно обновляй PostgreSQL
5. Настрой автоматическое резервное копирование

### Пароли по умолчанию
```
PostgreSQL:  postgres/postgres
Admin:       admin/AdminPassword123!
pgAdmin:     admin@asu-tp.local/AdminPassword123!
Grafana:     admin/GrafanaPassword123!
```

---

## 📄 Лицензия

Все права защищены. Конфиденциальная информация АО "НИКИЭТ".

---

## 👥 Команда

**Заказчик**: АО "НИКИЭТ"  
**Платформа**: КРОСС  
**Стандарты**: ГОСТ Р ИСО 9001-2015  
**Дата**: 2025

---

## 📞 Поддержка

Для получения поддержки:
1. Проверь [INSTALLATION.md](INSTALLATION.md)
2. Посмотри логи: `docker-compose logs` или `logs/postgres/`
3. Запусти `CHECK_STATUS.bat`

---

<div align="center">

**Сделано с ❤️ для промышленной автоматизации**

[⬆ Наверх](#-база-данных-птк-асу-тп)

</div>

