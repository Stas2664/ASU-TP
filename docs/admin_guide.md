# Руководство администратора БД ПТК АСУ ТП

## Оглавление

1. [Установка и настройка](#установка-и-настройка)
2. [Инициализация базы данных](#инициализация-базы-данных)
3. [Управление пользователями](#управление-пользователями)
4. [Резервное копирование](#резервное-копирование)
5. [Мониторинг производительности](#мониторинг-производительности)
6. [Обслуживание БД](#обслуживание-бд)
7. [Устранение неполадок](#устранение-неполадок)

## Установка и настройка

### Системные требования

**Минимальные:**
- CPU: 4 ядра, 2.0 GHz
- RAM: 16 GB
- SSD: 500 GB
- ОС: Ubuntu 20.04 LTS / Windows Server 2019

**Рекомендуемые:**
- CPU: 8 ядер, 2.4 GHz
- RAM: 32 GB
- SSD: 1 TB для БД + 10 TB HDD для архивов
- ОС: Ubuntu 22.04 LTS / RHEL 8

### Установка PostgreSQL 15

#### Ubuntu/Debian:
```bash
# Добавление репозитория
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
sudo apt-get update

# Установка
sudo apt-get install postgresql-15 postgresql-client-15 postgresql-contrib-15

# Запуск и автозагрузка
sudo systemctl start postgresql
sudo systemctl enable postgresql
```

#### Windows:
1. Скачайте установщик с https://www.postgresql.org/download/windows/
2. Запустите установщик и следуйте инструкциям
3. Установите пароль для пользователя postgres
4. Добавьте PostgreSQL в PATH

### Настройка PostgreSQL

#### 1. Конфигурация postgresql.conf

Откройте файл `/etc/postgresql/15/main/postgresql.conf`:

```ini
# Память
shared_buffers = 4GB              # 25% от RAM
effective_cache_size = 12GB       # 75% от RAM
maintenance_work_mem = 1GB
work_mem = 32MB

# Соединения
max_connections = 200
superuser_reserved_connections = 5

# Производительность
random_page_cost = 1.1            # Для SSD
effective_io_concurrency = 200    # Для SSD
max_worker_processes = 8
max_parallel_workers = 8
max_parallel_workers_per_gather = 4

# Журналирование
wal_level = replica
max_wal_size = 4GB
min_wal_size = 1GB
checkpoint_completion_target = 0.9
archive_mode = on
archive_command = 'cp %p /backup/archive/%f'

# Логирование
logging_collector = on
log_directory = '/var/log/postgresql'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_connections = on
log_disconnections = on
log_duration = off
log_lock_waits = on
log_min_duration_statement = 1000  # Логировать запросы > 1 сек
log_temp_files = 0

# Статистика
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
pg_stat_statements.max = 10000
track_io_timing = on
```

#### 2. Конфигурация pg_hba.conf

Настройте аутентификацию в `/etc/postgresql/15/main/pg_hba.conf`:

```
# Локальные подключения
local   all             postgres                                peer
local   asu_tp_db       asu_tp_admin                           md5
local   asu_tp_db       asu_tp_engineer                        md5
local   asu_tp_db       asu_tp_operator                        md5
local   asu_tp_db       asu_tp_viewer                          md5
local   asu_tp_db       asu_tp_service                         md5

# Сетевые подключения (подсеть АСУ ТП)
host    asu_tp_db       all             192.168.1.0/24         md5
host    asu_tp_db       all             10.0.0.0/8             md5

# Репликация
host    replication     replicator      192.168.1.0/24         md5
```

#### 3. Перезапуск PostgreSQL

```bash
sudo systemctl restart postgresql
```

## Инициализация базы данных

### Автоматическая инициализация

#### Windows:
```cmd
cd scripts
init_database.bat
```

#### Linux:
```bash
cd scripts
chmod +x init_database.sh
./init_database.sh
```

### Ручная инициализация

```bash
# 1. Создание БД
psql -U postgres -f sql/01_create_database.sql

# 2. Создание схем
psql -U postgres -d asu_tp_db -f sql/02_create_schemas.sql

# 3. Создание таблиц
psql -U postgres -d asu_tp_db -f sql/03_create_tables.sql

# 4. Создание ролей
psql -U postgres -d asu_tp_db -f sql/05_create_roles.sql

# 5. Создание функций
psql -U postgres -d asu_tp_db -f sql/06_create_functions.sql

# 6. Создание триггеров
psql -U postgres -d asu_tp_db -f sql/07_create_triggers.sql

# 7. Загрузка данных
psql -U postgres -d asu_tp_db -f sql/08_initial_data.sql
```

### Проверка установки

```bash
# Тест подключения
psql -U postgres -d asu_tp_db -c "SELECT version();"

# Проверка схем
psql -U postgres -d asu_tp_db -c "SELECT schema_name FROM information_schema.schemata WHERE schema_name NOT IN ('pg_catalog', 'information_schema');"

# Тест Python
python scripts/test_connection.py
```

## Управление пользователями

### Создание пользователя

```sql
-- Создание пользователя в БД
INSERT INTO security.users (username, email, password_hash, full_name, position)
VALUES (
    'newuser',
    'newuser@example.com',
    crypt('SecurePassword123!', gen_salt('bf')),
    'Фамилия Имя Отчество',
    'Должность'
);

-- Назначение роли
INSERT INTO security.user_roles (user_id, role_id)
SELECT u.id, r.id
FROM security.users u, security.roles r
WHERE u.username = 'newuser' AND r.code = 'operator';
```

### Изменение пароля

```sql
-- Изменение пароля пользователя
UPDATE security.users
SET password_hash = crypt('NewPassword123!', gen_salt('bf')),
    password_changed_at = CURRENT_TIMESTAMP,
    must_change_password = false
WHERE username = 'username';
```

### Блокировка пользователя

```sql
-- Блокировка
UPDATE security.users
SET is_active = false,
    deactivated_at = CURRENT_TIMESTAMP,
    deactivated_by = (SELECT id FROM security.users WHERE username = 'admin')
WHERE username = 'username';

-- Разблокировка
UPDATE security.users
SET is_active = true,
    failed_login_attempts = 0,
    locked_until = NULL
WHERE username = 'username';
```

### Управление правами

```sql
-- Добавление специального разрешения
INSERT INTO security.object_permissions (user_id, object_type, object_id, permission_type)
SELECT 
    (SELECT id FROM security.users WHERE username = 'username'),
    'parameter',
    (SELECT id FROM tech_params.parameters WHERE tag = 'REACTOR.POWER'),
    'write';

-- Отзыв разрешения
DELETE FROM security.object_permissions
WHERE user_id = (SELECT id FROM security.users WHERE username = 'username')
AND object_type = 'parameter'
AND object_id = (SELECT id FROM tech_params.parameters WHERE tag = 'REACTOR.POWER');
```

## Резервное копирование

### Стратегия резервного копирования

| Тип | Частота | Команда | Хранение |
|-----|---------|---------|----------|
| Полное | Еженедельно | pg_basebackup | 4 недели |
| Логическое | Ежедневно | pg_dump | 7 дней |
| WAL | Непрерывно | archive_command | 7 дней |

### Полное резервное копирование

```bash
# Физическое копирование (pg_basebackup)
pg_basebackup -h localhost -U postgres -D /backup/full/$(date +%Y%m%d) -Ft -Xs -P -v

# Логическое копирование (pg_dump)
pg_dump -h localhost -U postgres -d asu_tp_db -Fc -b -v -f /backup/dump/asu_tp_db_$(date +%Y%m%d).dump
```

### Автоматизация через cron

```bash
# Добавьте в crontab
# Ежедневный дамп в 2:00
0 2 * * * /usr/bin/pg_dump -U postgres -d asu_tp_db -Fc -f /backup/daily/asu_tp_db_$(date +\%Y\%m\%d).dump

# Еженедельное полное копирование в воскресенье 3:00
0 3 * * 0 /usr/bin/pg_basebackup -U postgres -D /backup/weekly/$(date +\%Y\%m\%d) -Ft -Xs -P

# Очистка старых бэкапов (старше 30 дней)
0 4 * * * find /backup/daily -type f -mtime +30 -delete
```

### Восстановление

#### Из логического дампа:
```bash
# Восстановление всей БД
pg_restore -U postgres -d asu_tp_db -v /backup/dump/asu_tp_db_20250101.dump

# Восстановление отдельной схемы
pg_restore -U postgres -d asu_tp_db -n tech_params -v /backup/dump/asu_tp_db_20250101.dump
```

#### Из физического бэкапа:
```bash
# Остановка PostgreSQL
sudo systemctl stop postgresql

# Восстановление данных
rm -rf /var/lib/postgresql/15/main/*
tar -xf /backup/full/20250101/base.tar -C /var/lib/postgresql/15/main/

# Запуск PostgreSQL
sudo systemctl start postgresql
```

## Мониторинг производительности

### Основные метрики

#### 1. Активность БД
```sql
-- Текущие активные запросы
SELECT 
    pid,
    usename,
    application_name,
    client_addr,
    state,
    query,
    NOW() - query_start AS duration
FROM pg_stat_activity
WHERE state != 'idle'
ORDER BY duration DESC;

-- Количество соединений
SELECT 
    datname,
    numbackends,
    xact_commit,
    xact_rollback,
    tup_fetched,
    tup_inserted,
    tup_updated,
    tup_deleted
FROM pg_stat_database
WHERE datname = 'asu_tp_db';
```

#### 2. Производительность запросов
```sql
-- Топ медленных запросов
SELECT 
    calls,
    total_exec_time,
    mean_exec_time,
    max_exec_time,
    query
FROM pg_stat_statements
WHERE query NOT LIKE '%pg_stat_statements%'
ORDER BY mean_exec_time DESC
LIMIT 20;

-- Запросы с большим временем ожидания
SELECT 
    pid,
    usename,
    pg_blocking_pids(pid) AS blocked_by,
    query
FROM pg_stat_activity
WHERE cardinality(pg_blocking_pids(pid)) > 0;
```

#### 3. Использование индексов
```sql
-- Неиспользуемые индексы
SELECT 
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
AND idx_scan = 0
ORDER BY pg_relation_size(indexrelid) DESC;

-- Таблицы без индексов
SELECT 
    schemaname,
    tablename,
    n_live_tup,
    n_dead_tup,
    last_vacuum,
    last_autovacuum
FROM pg_stat_user_tables
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
AND NOT EXISTS (
    SELECT 1 FROM pg_indexes
    WHERE pg_indexes.schemaname = pg_stat_user_tables.schemaname
    AND pg_indexes.tablename = pg_stat_user_tables.tablename
);
```

### Настройка мониторинга

#### 1. Установка pg_stat_statements
```sql
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Сброс статистики
SELECT pg_stat_statements_reset();
```

#### 2. Автоматический сбор статистики
```bash
#!/bin/bash
# monitor_stats.sh

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTDIR="/var/log/postgresql/stats"

# Создание директории
mkdir -p $OUTDIR

# Сбор статистики
psql -U postgres -d asu_tp_db << EOF > $OUTDIR/stats_$TIMESTAMP.txt
\echo 'DATABASE STATISTICS'
SELECT * FROM pg_stat_database WHERE datname = 'asu_tp_db';

\echo 'ACTIVE QUERIES'
SELECT * FROM pg_stat_activity WHERE state != 'idle';

\echo 'TABLE STATISTICS'
SELECT * FROM pg_stat_user_tables;

\echo 'INDEX STATISTICS'
SELECT * FROM pg_stat_user_indexes;
EOF
```

## Обслуживание БД

### VACUUM и ANALYZE

#### Ручной запуск
```sql
-- Полный VACUUM (блокирует таблицу)
VACUUM FULL tech_params.historical_data;

-- Обычный VACUUM (не блокирует)
VACUUM ANALYZE tech_params.parameters;

-- Только анализ статистики
ANALYZE tech_params.current_values;
```

#### Настройка автоочистки
```sql
-- Для таблицы с частыми обновлениями
ALTER TABLE tech_params.current_values SET (
    autovacuum_vacuum_scale_factor = 0.05,
    autovacuum_analyze_scale_factor = 0.02,
    autovacuum_vacuum_cost_delay = 10
);

-- Для архивной таблицы
ALTER TABLE archive.historical_data SET (
    autovacuum_vacuum_scale_factor = 0.1,
    autovacuum_analyze_scale_factor = 0.05
);
```

### Управление партициями

#### Создание новых партиций
```sql
-- Создание партиции на следующий квартал
CREATE TABLE IF NOT EXISTS archive.historical_data_2026_q1
PARTITION OF archive.historical_data
FOR VALUES FROM ('2026-01-01') TO ('2026-04-01');

-- Создание индексов на новой партиции
CREATE INDEX idx_hist_2026_q1_param_time 
ON archive.historical_data_2026_q1(parameter_id, timestamp DESC);
```

#### Удаление старых партиций
```sql
-- Отсоединение партиции
ALTER TABLE archive.historical_data 
DETACH PARTITION archive.historical_data_2024_q1;

-- Архивирование
CREATE TABLE archive_backup.historical_data_2024_q1 AS 
SELECT * FROM archive.historical_data_2024_q1;

-- Удаление
DROP TABLE archive.historical_data_2024_q1;
```

### Оптимизация запросов

#### Анализ плана выполнения
```sql
-- Включение расширенной статистики
SET track_io_timing = on;

-- Анализ запроса
EXPLAIN (ANALYZE, BUFFERS, TIMING, VERBOSE) 
SELECT 
    p.tag,
    cv.value,
    cv.timestamp
FROM tech_params.parameters p
JOIN tech_params.current_values cv ON p.id = cv.parameter_id
WHERE p.parameter_type = 'analog'
AND cv.timestamp > CURRENT_TIMESTAMP - INTERVAL '1 hour';
```

#### Создание оптимизированных индексов
```sql
-- Составной индекс для частых запросов
CREATE INDEX idx_params_type_active 
ON tech_params.parameters(parameter_type, is_active) 
WHERE is_active = true;

-- Частичный индекс для архивов
CREATE INDEX idx_archive_recent 
ON archive.historical_data(parameter_id, timestamp DESC) 
WHERE timestamp > CURRENT_DATE - INTERVAL '7 days';
```

## Устранение неполадок

### Проблемы с подключением

#### Ошибка: "FATAL: password authentication failed"
```bash
# Проверка настроек pg_hba.conf
sudo nano /etc/postgresql/15/main/pg_hba.conf

# Перезагрузка конфигурации
sudo systemctl reload postgresql

# Сброс пароля postgres
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'new_password';"
```

#### Ошибка: "FATAL: too many connections"
```sql
-- Проверка текущих соединений
SELECT COUNT(*) FROM pg_stat_activity;

-- Завершение неактивных соединений
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE state = 'idle' 
AND state_change < CURRENT_TIMESTAMP - INTERVAL '10 minutes';

-- Увеличение лимита соединений
ALTER SYSTEM SET max_connections = 300;
SELECT pg_reload_conf();
```

### Проблемы производительности

#### Медленные запросы
```sql
-- Поиск блокировок
SELECT 
    blocked_locks.pid AS blocked_pid,
    blocked_activity.usename AS blocked_user,
    blocking_locks.pid AS blocking_pid,
    blocking_activity.usename AS blocking_user,
    blocked_activity.query AS blocked_query,
    blocking_activity.query AS blocking_query
FROM pg_catalog.pg_locks blocked_locks
JOIN pg_catalog.pg_stat_activity blocked_activity ON blocked_activity.pid = blocked_locks.pid
JOIN pg_catalog.pg_locks blocking_locks ON blocking_locks.locktype = blocked_locks.locktype
    AND blocking_locks.database IS NOT DISTINCT FROM blocked_locks.database
    AND blocking_locks.relation IS NOT DISTINCT FROM blocked_locks.relation
    AND blocking_locks.page IS NOT DISTINCT FROM blocked_locks.page
    AND blocking_locks.tuple IS NOT DISTINCT FROM blocked_locks.tuple
    AND blocking_locks.virtualxid IS NOT DISTINCT FROM blocked_locks.virtualxid
    AND blocking_locks.transactionid IS NOT DISTINCT FROM blocked_locks.transactionid
    AND blocking_locks.classid IS NOT DISTINCT FROM blocked_locks.classid
    AND blocking_locks.objid IS NOT DISTINCT FROM blocked_locks.objid
    AND blocking_locks.objsubid IS NOT DISTINCT FROM blocked_locks.objsubid
    AND blocking_locks.pid != blocked_locks.pid
JOIN pg_catalog.pg_stat_activity blocking_activity ON blocking_activity.pid = blocking_locks.pid
WHERE NOT blocked_locks.granted;

-- Снятие блокировки
SELECT pg_cancel_backend(pid); -- Мягкая отмена
SELECT pg_terminate_backend(pid); -- Жесткое завершение
```

#### Раздувание таблиц (bloat)
```sql
-- Проверка раздувания
WITH constants AS (
    SELECT current_database() AS db, schemaname, tablename, 
    pg_relation_size(schemaname||'.'||tablename) AS table_size
    FROM pg_tables
),
estimates AS (
    SELECT schemaname, tablename, 
    CEIL((cc.reltuples*
        ((datahdr + ma - CASE WHEN datahdr%ma=0 THEN ma ELSE datahdr%ma END)
        + nullhdr + 4)) / (bs-20)
    ) AS expected_pages,
    bs, table_size
    FROM (
        SELECT 
            ma, bs, schemaname, tablename,
            (datawidth + (hdr + ma - CASE WHEN hdr%ma=0 THEN ma ELSE hdr%ma END))::NUMERIC AS datahdr,
            (maxfracsum * (nullhdr + ma - CASE WHEN nullhdr%ma=0 THEN ma ELSE nullhdr%ma END)) AS nullhdr
        FROM (
            SELECT 
                schemaname, tablename, hdr, ma, bs,
                SUM((1-null_frac)*avg_width) AS datawidth,
                MAX(null_frac) AS maxfracsum,
                hdr + (
                    SELECT 1 + COUNT(*)::INT/8
                    FROM pg_stats s2
                    WHERE null_frac != 0 AND s2.schemaname = s.schemaname AND s2.tablename = s.tablename
                ) AS nullhdr
            FROM pg_stats s, (
                SELECT 
                    (SELECT current_setting('block_size')::INT) AS bs,
                    CASE WHEN SUBSTRING(v,12,3) IN ('8.0','8.1','8.2') THEN 27 ELSE 23 END AS hdr,
                    CASE WHEN v ~ 'mingw32' THEN 8 ELSE 4 END AS ma
                FROM (SELECT version() AS v) AS foo
            ) AS constants
            GROUP BY 1,2,3,4,5
        ) AS foo
    ) AS rs
    JOIN pg_class cc ON cc.relname = rs.tablename
    JOIN pg_namespace nn ON cc.relnamespace = nn.oid AND nn.nspname = rs.schemaname
)
SELECT 
    schemaname,
    tablename,
    pg_size_pretty(table_size) AS table_size,
    expected_pages * bs AS expected_size,
    CASE WHEN expected_pages * bs = 0 THEN 0
        ELSE ROUND(((table_size - (expected_pages * bs))::NUMERIC / table_size) * 100, 2)
    END AS bloat_pct
FROM estimates
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
AND table_size > 1000000
ORDER BY bloat_pct DESC;
```

### Восстановление после сбоя

#### Восстановление из WAL
```bash
# Проверка состояния
pg_controldata /var/lib/postgresql/15/main/

# Восстановление
pg_resetwal -f /var/lib/postgresql/15/main/

# Запуск в режиме восстановления
postgres -D /var/lib/postgresql/15/main/ --single

# Проверка целостности
postgres -D /var/lib/postgresql/15/main/ --single -P -c "VACUUM FULL;"
```

## Контакты поддержки

**Техническая поддержка PostgreSQL:**
- Документация: https://www.postgresql.org/docs/15/
- Сообщество: https://www.postgresql.org/community/

**Поддержка АСУ ТП:**
- Email: support@asu-tp.local
- Телефон: +7 (XXX) XXX-XX-XX
- Внутренний: 1234

---

**Версия документа:** 1.0.0  
**Дата:** 2025  
**Автор:** Администратор БД



