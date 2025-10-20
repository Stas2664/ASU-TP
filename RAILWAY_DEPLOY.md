# 🚂 Развертывание БД АСУ ТП на Railway

> Railway - это современная облачная платформа для быстрого развертывания PostgreSQL

---

## 🎯 Что такое Railway?

**Railway.app** - это PaaS платформа, которая позволяет:
- ✅ Развернуть PostgreSQL за 2 минуты
- ✅ Автоматическое резервное копирование
- ✅ SSL подключение из коробки
- ✅ Бесплатный план (5$ кредитов в месяц)
- ✅ Мониторинг и метрики
- ✅ Веб-интерфейс для управления

---

## 📋 Варианты развертывания

У тебя есть два SQL файла:

### 1️⃣ **railway_init.sql** (Упрощенная версия)
- Базовые таблицы для демо
- Быстрое развертывание (~30 сек)
- Подходит для тестирования

### 2️⃣ **FULL_ASU_TP_RAILWAY.sql** (Полная версия)
- Все 50+ таблиц
- Все функции и триггеры
- Подходит для production

---

## 🚀 Пошаговая инструкция

### Шаг 1: Регистрация на Railway

1. Перейди на https://railway.app
2. Нажми **"Start a New Project"**
3. Войди через GitHub (рекомендуется) или email

### Шаг 2: Создание PostgreSQL базы

1. После входа нажми **"New Project"**
2. Выбери **"Provision PostgreSQL"**
3. Railway автоматически создаст PostgreSQL базу данных
4. Дождись завершения (~30 секунд)

### Шаг 3: Получение данных для подключения

1. Кликни на созданную PostgreSQL базу
2. Перейди на вкладку **"Connect"**
3. Скопируй данные подключения:
   - **Host** (например: containers-us-west-xxx.railway.app)
   - **Port** (обычно 5432)
   - **Database** (обычно railway)
   - **User** (обычно postgres)
   - **Password** (автогенерированный)

Или скопируй готовую **Connection URL**:
```
postgresql://postgres:password@host:port/railway
```

### Шаг 4: Загрузка схемы БД

#### Вариант A: Через веб-интерфейс Railway (просто и быстро)

1. В Railway кликни на PostgreSQL
2. Перейди на вкладку **"Data"**
3. Нажми кнопку **"Query"**
4. Скопируй содержимое файла:
   - Для демо: `railway_init.sql`
   - Для полной версии: `FULL_ASU_TP_RAILWAY.sql`
5. Вставь в Query Editor
6. Нажми **"Execute"**
7. Готово! 🎉

#### Вариант B: Через psql (для продвинутых)

```bash
# Установи переменные окружения (замени на свои данные)
set PGHOST=containers-us-west-xxx.railway.app
set PGPORT=5432
set PGDATABASE=railway
set PGUSER=postgres
set PGPASSWORD=твой_пароль

# Загрузи схему (выбери один файл)
psql -f railway_init.sql
# или
psql -f FULL_ASU_TP_RAILWAY.sql
```

#### Вариант C: Через pgAdmin

1. Открой pgAdmin
2. **Add New Server**:
   - Name: `Railway ASU TP`
   - Host: скопируй из Railway
   - Port: 5432
   - Database: railway
   - Username: postgres
   - Password: из Railway
   - SSL Mode: **Require**
3. Подключись
4. Правый клик на database → **Query Tool**
5. Открой файл `railway_init.sql` или `FULL_ASU_TP_RAILWAY.sql`
6. Нажми **Execute** (F5)

---

## ✅ Проверка развертывания

### Через Railway Data Tab

1. Кликни на PostgreSQL в Railway
2. Вкладка **"Data"**
3. Выполни запрос:
```sql
-- Проверка схем
SELECT schema_name 
FROM information_schema.schemata 
WHERE schema_name IN (
    'core', 'tech_params', 'controllers', 'archive', 
    'algorithms', 'visualization', 'topology', 'kross', 
    'security', 'events', 'reports'
);

-- Проверка таблиц
SELECT schemaname, COUNT(*) as table_count
FROM pg_tables
WHERE schemaname IN (
    'core', 'tech_params', 'controllers', 'archive', 
    'algorithms', 'visualization', 'topology', 'kross', 
    'security', 'events', 'reports'
)
GROUP BY schemaname;

-- Проверка пользователей
SELECT username, full_name, position 
FROM security.users;
```

### Через наш скрипт

Запусти:
```bash
CHECK_RAILWAY_STATUS.bat
```

---

## 🔐 Подключение к Railway БД

### Connection String

```
postgresql://postgres:password@host:port/railway?sslmode=require
```

### Python (psycopg2)

```python
import psycopg2

conn = psycopg2.connect(
    host="containers-us-west-xxx.railway.app",
    port=5432,
    database="railway",
    user="postgres",
    password="твой_пароль",
    sslmode="require"
)
```

### Node.js (pg)

```javascript
const { Pool } = require('pg');

const pool = new Pool({
  host: 'containers-us-west-xxx.railway.app',
  port: 5432,
  database: 'railway',
  user: 'postgres',
  password: 'твой_пароль',
  ssl: { rejectUnauthorized: false }
});
```

### .NET (Npgsql)

```csharp
var connString = "Host=containers-us-west-xxx.railway.app;Port=5432;Database=railway;Username=postgres;Password=твой_пароль;SSL Mode=Require;Trust Server Certificate=true";
```

---

## 💰 Тарифы Railway

### Developer Plan (Free Trial)
- **$5 кредитов в месяц** бесплатно
- PostgreSQL включен
- Подходит для:
  - ✅ Разработка
  - ✅ Тестирование
  - ✅ Малые проекты

### Hobby Plan ($5/месяц)
- **$5 кредитов + $5 за использование**
- Больше ресурсов
- Подходит для:
  - ✅ Средние проекты
  - ✅ Продакшн для небольших систем

### Pro Plan ($20/месяц)
- **$20 кредитов включено**
- Priority support
- Больше CPU/RAM
- Подходит для:
  - ✅ Production систем
  - ✅ Высоконагруженные приложения

**Расход:** ~$5-10/месяц для средней БД АСУ ТП

---

## 📊 Мониторинг

Railway предоставляет встроенный мониторинг:

1. **Metrics** - CPU, Memory, Disk usage
2. **Logs** - Все логи PostgreSQL
3. **Usage** - Расход кредитов

### Доступ к метрикам:
1. Открой проект в Railway
2. Кликни на PostgreSQL
3. Вкладка **"Metrics"**

---

## 🔄 Резервное копирование

Railway автоматически делает резервные копии, но можно делать свои:

### Экспорт БД

```bash
# Через pg_dump
pg_dump -h containers-us-west-xxx.railway.app \
        -p 5432 \
        -U postgres \
        -d railway \
        -Fc -b -v \
        -f asu_tp_backup.dump
```

### Импорт БД

```bash
pg_restore -h containers-us-west-xxx.railway.app \
           -p 5432 \
           -U postgres \
           -d railway \
           -v asu_tp_backup.dump
```

---

## 🔒 Безопасность

### ✅ Что уже настроено:
- SSL подключение обязательно
- Сильный пароль генерируется автоматически
- Доступ только через интернет (нет локального доступа)
- Автоматические обновления безопасности

### ⚠️ Рекомендации:
1. **Смени пароль admin** после развертывания:
```sql
UPDATE security.users 
SET password_hash = crypt('НовыйСложныйПароль!', gen_salt('bf'))
WHERE username = 'admin';
```

2. **Создай отдельных пользователей** для разных сервисов

3. **Используй переменные окружения** для хранения паролей, не храни в коде

4. **Настрой IP whitelist** если Railway поддерживает (в Pro плане)

---

## 🌐 Интеграция с приложением

### Переменные окружения (рекомендуется)

Создай `.env` файл:
```env
DATABASE_URL=postgresql://postgres:password@host:port/railway?sslmode=require
PGHOST=containers-us-west-xxx.railway.app
PGPORT=5432
PGDATABASE=railway
PGUSER=postgres
PGPASSWORD=твой_пароль
```

### Для КРОСС платформы

Настрой подключение в конфигурации КРОСС:
- Host: `containers-us-west-xxx.railway.app`
- Port: `5432`
- Database: `railway`
- SSL: `enabled`

---

## 📈 Масштабирование

### Увеличение производительности:

1. **Upgrade плана** в Railway (больше CPU/RAM)
2. **Добавь индексы** для часто используемых запросов
3. **Настрой connection pooling** в приложении
4. **Партиционируй большие таблицы** (archive.historical_data)

### Мониторинг производительности:

```sql
-- Медленные запросы
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Размер таблиц
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename))
FROM pg_tables 
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

---

## 🆘 Устранение проблем

### Проблема: Не могу подключиться

**Решение:**
1. Проверь правильность данных подключения
2. Убедись что SSL включен (`sslmode=require`)
3. Проверь firewall на твоей стороне
4. Проверь что Railway БД запущена (зайди в Dashboard)

### Проблема: Медленно работает

**Решение:**
1. Проверь метрики в Railway (CPU/Memory)
2. Добавь недостающие индексы
3. Оптимизируй запросы
4. Рассмотри апгрейд плана

### Проблема: Закончились кредиты

**Решение:**
1. Upgrade на платный план
2. Оптимизируй использование ресурсов
3. Используй connection pooling
4. Архивируй старые данные

---

## 📝 Чек-лист развертывания

- [ ] Зарегистрировался на Railway.app
- [ ] Создал PostgreSQL базу
- [ ] Скопировал данные подключения
- [ ] Загрузил SQL файл (railway_init.sql или FULL_ASU_TP_RAILWAY.sql)
- [ ] Проверил создание схем и таблиц
- [ ] Сменил пароль admin
- [ ] Создал пользователей системы
- [ ] Настроил подключение в приложении
- [ ] Проверил работу через тестовое подключение
- [ ] Настроил мониторинг
- [ ] Настроил резервное копирование (опционально)

---

## 🎉 Готово!

База данных АСУ ТП развернута на Railway!

### Что дальше?

1. Протестируй подключение из приложения
2. Импортируй параметры техпроцесса
3. Создай пользователей системы
4. Настрой интеграцию с КРОСС
5. Начинай эксплуатацию!

---

## 📞 Полезные ссылки

- **Railway Dashboard**: https://railway.app/dashboard
- **Railway Docs**: https://docs.railway.app
- **PostgreSQL Docs**: https://www.postgresql.org/docs/
- **Support**: https://help.railway.app

---

**Разработано для**: АО "НИКИЭТ"  
**Платформа**: КРОСС  
**Облако**: Railway

