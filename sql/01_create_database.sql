-- ==============================================================================
-- Создание базы данных для ПТК АСУ ТП
-- Версия PostgreSQL: 15+
-- Проект: АО "НИКИЭТ" / КРОСС
-- Дата: 2025
-- ==============================================================================

-- Удаление существующей БД (для разработки, в продакшене закомментировать)
-- DROP DATABASE IF EXISTS asu_tp_db;

-- Создание базы данных
CREATE DATABASE asu_tp_db
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'ru_RU.UTF-8'
    LC_CTYPE = 'ru_RU.UTF-8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1
    IS_TEMPLATE = False;

-- Комментарий к базе данных
COMMENT ON DATABASE asu_tp_db IS 'База данных ПТК АСУ ТП на платформе КРОСС';

-- Подключение к созданной БД
\c asu_tp_db;

-- Создание расширений
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";      -- Для генерации UUID
CREATE EXTENSION IF NOT EXISTS "pgcrypto";       -- Для шифрования паролей
CREATE EXTENSION IF NOT EXISTS "pg_trgm";        -- Для нечеткого поиска
CREATE EXTENSION IF NOT EXISTS "btree_gin";      -- Для оптимизации индексов
CREATE EXTENSION IF NOT EXISTS "tablefunc";      -- Для кросс-табуляции
CREATE EXTENSION IF NOT EXISTS "pg_stat_statements"; -- Для мониторинга запросов

-- Настройки производительности для промышленных систем
ALTER SYSTEM SET shared_buffers = '4GB';
ALTER SYSTEM SET effective_cache_size = '12GB';
ALTER SYSTEM SET maintenance_work_mem = '1GB';
ALTER SYSTEM SET work_mem = '32MB';
ALTER SYSTEM SET max_connections = 200;
ALTER SYSTEM SET max_worker_processes = 8;
ALTER SYSTEM SET max_parallel_workers = 8;

-- Настройки журналирования
ALTER SYSTEM SET log_statement = 'all';
ALTER SYSTEM SET log_duration = on;
ALTER SYSTEM SET log_line_prefix = '%t [%p-%l] %q%u@%d ';
ALTER SYSTEM SET log_checkpoints = on;
ALTER SYSTEM SET log_connections = on;
ALTER SYSTEM SET log_disconnections = on;
ALTER SYSTEM SET log_lock_waits = on;
ALTER SYSTEM SET log_temp_files = 0;

-- Настройки для работы в реальном времени
ALTER SYSTEM SET synchronous_commit = on;
ALTER SYSTEM SET checkpoint_completion_target = 0.9;
ALTER SYSTEM SET wal_buffers = '16MB';
ALTER SYSTEM SET default_statistics_target = 100;

-- Применение настроек (требует перезапуска PostgreSQL)
-- SELECT pg_reload_conf();


