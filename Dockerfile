# ==============================================================================
# Dockerfile для БД ПТК АСУ ТП
# Базовый образ: PostgreSQL 15 Alpine
# ==============================================================================

FROM postgres:15-alpine

# Метаданные
LABEL maintainer="АСУ ТП Team"
LABEL description="База данных ПТК АСУ ТП на платформе КРОСС"
LABEL version="1.0.0"

# Установка дополнительных пакетов
RUN apk add --no-cache \
    # Для поддержки русской локали
    musl-locales \
    musl-locales-lang \
    # Утилиты
    bash \
    curl \
    wget \
    # Для резервного копирования
    gzip \
    bzip2 \
    # Для мониторинга
    htop \
    iotop \
    # Python для скриптов
    python3 \
    py3-pip \
    py3-psycopg2 \
    # Для отладки
    postgresql-contrib \
    # Временная зона
    tzdata

# Установка часового пояса
ENV TZ=Europe/Moscow
RUN cp /usr/share/zoneinfo/$TZ /etc/localtime && \
    echo $TZ > /etc/timezone

# Установка русской локали
ENV LANG=ru_RU.UTF-8
ENV LC_ALL=ru_RU.UTF-8

# Создание директорий
RUN mkdir -p /docker-entrypoint-initdb.d \
    && mkdir -p /backup \
    && mkdir -p /logs \
    && mkdir -p /scripts \
    && mkdir -p /monitoring

# Копирование SQL скриптов для инициализации
COPY sql/01_create_database.sql /docker-entrypoint-initdb.d/01_create_database.sql
COPY sql/02_create_schemas.sql /docker-entrypoint-initdb.d/02_create_schemas.sql
COPY sql/03_create_tables.sql /docker-entrypoint-initdb.d/03_create_tables.sql
COPY sql/04_create_indexes.sql /docker-entrypoint-initdb.d/04_create_indexes.sql
COPY sql/05_create_roles.sql /docker-entrypoint-initdb.d/05_create_roles.sql
COPY sql/06_create_functions.sql /docker-entrypoint-initdb.d/06_create_functions.sql
COPY sql/07_create_triggers.sql /docker-entrypoint-initdb.d/07_create_triggers.sql
COPY sql/08_initial_data.sql /docker-entrypoint-initdb.d/08_initial_data.sql

# Копирование скриптов управления
COPY scripts/backup.sh /scripts/backup.sh
COPY scripts/restore.sh /scripts/restore.sh
COPY scripts/test_connection.py /scripts/test_connection.py

# Установка прав на скрипты
RUN chmod +x /scripts/*.sh

# Копирование конфигурации PostgreSQL
COPY <<EOF /etc/postgresql/postgresql.conf
# Настройки производительности
shared_buffers = 2GB
effective_cache_size = 6GB
maintenance_work_mem = 512MB
work_mem = 32MB
max_connections = 200
max_worker_processes = 8
max_parallel_workers = 8
max_parallel_workers_per_gather = 4

# Настройки для SSD
random_page_cost = 1.1
effective_io_concurrency = 200

# WAL настройки
wal_level = replica
max_wal_size = 2GB
min_wal_size = 512MB
checkpoint_completion_target = 0.9
archive_mode = on
archive_command = 'cp %p /backup/archive/%f'

# Логирование
logging_collector = on
log_directory = '/logs'
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 100MB
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_checkpoints = on
log_connections = on
log_disconnections = on
log_lock_waits = on
log_min_duration_statement = 1000
log_statement = 'all'
log_duration = on

# Статистика
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
pg_stat_statements.max = 10000
track_io_timing = on

# Локализация
lc_messages = 'ru_RU.UTF-8'
lc_monetary = 'ru_RU.UTF-8'
lc_numeric = 'ru_RU.UTF-8'
lc_time = 'ru_RU.UTF-8'
default_text_search_config = 'pg_catalog.russian'

# Настройки для реального времени
synchronous_commit = on
EOF

# Создание скрипта health check
COPY <<'EOF' /scripts/health_check.sh
#!/bin/bash
pg_isready -U $POSTGRES_USER -d asu_tp_db
EOF
RUN chmod +x /scripts/health_check.sh

# Создание скрипта автоматического резервного копирования
COPY <<'EOF' /scripts/auto_backup.sh
#!/bin/bash
while true; do
    sleep 86400  # 24 часа
    /scripts/backup.sh full
    # Удаление старых бэкапов (старше 30 дней)
    find /backup -name "*.dump*" -mtime +30 -delete
done
EOF
RUN chmod +x /scripts/auto_backup.sh

# Установка Python зависимостей
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install --no-cache-dir psycopg2-binary pandas numpy

# Создание entrypoint скрипта
COPY <<'EOF' /usr/local/bin/docker-entrypoint-custom.sh
#!/bin/bash
set -e

# Запуск оригинального entrypoint
/usr/local/bin/docker-entrypoint.sh postgres &

# Ожидание запуска PostgreSQL
sleep 10

# Запуск автоматического резервного копирования в фоне
/scripts/auto_backup.sh &

# Ожидание процесса postgres
wait
EOF
RUN chmod +x /usr/local/bin/docker-entrypoint-custom.sh

# Переменные окружения по умолчанию
ENV POSTGRES_USER=postgres
ENV POSTGRES_PASSWORD=postgres
ENV POSTGRES_DB=postgres
ENV POSTGRES_INITDB_ARGS="--encoding=UTF8 --locale=ru_RU.UTF-8"

# Порты
EXPOSE 5432

# Volumes для персистентности данных
VOLUME ["/var/lib/postgresql/data", "/backup", "/logs"]

# Health check
HEALTHCHECK --interval=10s --timeout=5s --start-period=30s --retries=3 \
    CMD /scripts/health_check.sh || exit 1

# Точка входа
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-custom.sh"]

# Команда по умолчанию
CMD ["postgres", "-c", "config_file=/etc/postgresql/postgresql.conf"]



