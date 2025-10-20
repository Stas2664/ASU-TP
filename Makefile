# ==============================================================================
# Makefile для управления БД ПТК АСУ ТП
# ==============================================================================

.PHONY: help install init start stop restart status backup restore test clean docker-up docker-down docker-init docker-logs

# Цветной вывод
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
BLUE := \033[0;34m
NC := \033[0m

# Переменные
DB_NAME := asu_tp_db
POSTGRES_USER := postgres
POSTGRES_HOST := localhost
POSTGRES_PORT := 5432
PYTHON := python3
DOCKER_COMPOSE := docker-compose

# Помощь по умолчанию
help:
	@echo "$(BLUE)================================================================================$(NC)"
	@echo "$(BLUE)  Управление БД ПТК АСУ ТП$(NC)"
	@echo "$(BLUE)================================================================================$(NC)"
	@echo ""
	@echo "$(GREEN)Основные команды:$(NC)"
	@echo "  make install       - Установка зависимостей Python"
	@echo "  make init          - Инициализация БД (создание с нуля)"
	@echo "  make test          - Тестирование БД"
	@echo "  make backup        - Создание резервной копии"
	@echo "  make restore       - Восстановление из резервной копии"
	@echo "  make status        - Проверка статуса БД"
	@echo ""
	@echo "$(GREEN)Docker команды:$(NC)"
	@echo "  make docker-up     - Запуск контейнеров"
	@echo "  make docker-down   - Остановка контейнеров"
	@echo "  make docker-init   - Инициализация БД в Docker"
	@echo "  make docker-logs   - Просмотр логов"
	@echo "  make docker-backup - Резервное копирование Docker БД"
	@echo ""
	@echo "$(GREEN)PostgreSQL команды:$(NC)"
	@echo "  make psql          - Подключение к БД через psql"
	@echo "  make pg-status     - Статус PostgreSQL"
	@echo "  make pg-restart    - Перезапуск PostgreSQL"
	@echo "  make pg-vacuum     - Очистка и оптимизация БД"
	@echo "  make pg-analyze    - Обновление статистики БД"
	@echo ""
	@echo "$(GREEN)Разработка:$(NC)"
	@echo "  make dev-server    - Запуск сервера разработки"
	@echo "  make migrate       - Применение миграций"
	@echo "  make seed          - Загрузка тестовых данных"
	@echo "  make clean         - Очистка временных файлов"
	@echo ""

# Установка зависимостей
install:
	@echo "$(YELLOW)Установка зависимостей Python...$(NC)"
	@$(PYTHON) -m pip install --upgrade pip
	@$(PYTHON) -m pip install -r requirements.txt
	@echo "$(GREEN)✓ Зависимости установлены$(NC)"

# Инициализация БД
init:
	@echo "$(YELLOW)Инициализация базы данных...$(NC)"
	@if [ -f scripts/init_database.sh ]; then \
		cd scripts && chmod +x init_database.sh && ./init_database.sh; \
	elif [ -f scripts/init_database.bat ]; then \
		cd scripts && init_database.bat; \
	else \
		echo "$(RED)✗ Скрипт инициализации не найден$(NC)"; \
		exit 1; \
	fi

# Быстрая инициализация (без подтверждения)
init-force:
	@echo "$(YELLOW)Принудительная инициализация БД...$(NC)"
	@export PGPASSWORD=$(POSTGRES_PASSWORD) && \
	psql -h $(POSTGRES_HOST) -p $(POSTGRES_PORT) -U $(POSTGRES_USER) -c "DROP DATABASE IF EXISTS $(DB_NAME);"
	@for script in sql/*.sql; do \
		echo "$(YELLOW)Выполнение $$script...$(NC)"; \
		if [ "$$script" = "sql/01_create_database.sql" ]; then \
			psql -h $(POSTGRES_HOST) -p $(POSTGRES_PORT) -U $(POSTGRES_USER) -f $$script; \
		else \
			psql -h $(POSTGRES_HOST) -p $(POSTGRES_PORT) -U $(POSTGRES_USER) -d $(DB_NAME) -f $$script; \
		fi; \
	done
	@echo "$(GREEN)✓ База данных инициализирована$(NC)"

# Тестирование БД
test:
	@echo "$(YELLOW)Тестирование базы данных...$(NC)"
	@cd scripts && $(PYTHON) test_connection.py

# Резервное копирование
backup:
	@echo "$(YELLOW)Создание резервной копии...$(NC)"
	@cd scripts && chmod +x backup.sh && ./backup.sh full

# Восстановление БД
restore:
	@echo "$(YELLOW)Восстановление из резервной копии...$(NC)"
	@cd scripts && chmod +x restore.sh && ./restore.sh

# Проверка статуса БД
status:
	@echo "$(BLUE)================================================================================$(NC)"
	@echo "$(BLUE)  Статус БД$(NC)"
	@echo "$(BLUE)================================================================================$(NC)"
	@psql -h $(POSTGRES_HOST) -p $(POSTGRES_PORT) -U $(POSTGRES_USER) -d $(DB_NAME) -c "\
		SELECT 'Версия PostgreSQL:' as info, version() \
		UNION ALL \
		SELECT 'База данных:', current_database() \
		UNION ALL \
		SELECT 'Размер БД:', pg_size_pretty(pg_database_size(current_database())) \
		UNION ALL \
		SELECT 'Активных соединений:', COUNT(*)::text FROM pg_stat_activity WHERE datname = '$(DB_NAME)' \
		UNION ALL \
		SELECT 'Количество схем:', COUNT(*)::text FROM information_schema.schemata WHERE schema_name IN ('core', 'tech_params', 'controllers', 'archive', 'algorithms', 'visualization', 'topology', 'kross', 'security', 'events', 'reports') \
		UNION ALL \
		SELECT 'Количество таблиц:', COUNT(*)::text FROM information_schema.tables WHERE table_schema IN ('core', 'tech_params', 'controllers', 'archive', 'algorithms', 'visualization', 'topology', 'kross', 'security', 'events', 'reports') AND table_type = 'BASE TABLE' \
		UNION ALL \
		SELECT 'Количество параметров:', COUNT(*)::text FROM tech_params.parameters \
		UNION ALL \
		SELECT 'Количество пользователей:', COUNT(*)::text FROM security.users WHERE is_active = true;"

# Docker команды
docker-up:
	@echo "$(YELLOW)Запуск Docker контейнеров...$(NC)"
	@$(DOCKER_COMPOSE) up -d
	@echo "$(GREEN)✓ Контейнеры запущены$(NC)"

docker-down:
	@echo "$(YELLOW)Остановка Docker контейнеров...$(NC)"
	@$(DOCKER_COMPOSE) down
	@echo "$(GREEN)✓ Контейнеры остановлены$(NC)"

docker-init:
	@echo "$(YELLOW)Инициализация БД в Docker...$(NC)"
	@$(DOCKER_COMPOSE) --profile init up db_init
	@echo "$(GREEN)✓ БД инициализирована в Docker$(NC)"

docker-logs:
	@$(DOCKER_COMPOSE) logs -f --tail=100

docker-backup:
	@echo "$(YELLOW)Резервное копирование Docker БД...$(NC)"
	@$(DOCKER_COMPOSE) --profile backup up backup

docker-ps:
	@$(DOCKER_COMPOSE) ps

# PostgreSQL команды
psql:
	@psql -h $(POSTGRES_HOST) -p $(POSTGRES_PORT) -U $(POSTGRES_USER) -d $(DB_NAME)

pg-status:
	@systemctl status postgresql || service postgresql status || pg_ctl status

pg-restart:
	@echo "$(YELLOW)Перезапуск PostgreSQL...$(NC)"
	@sudo systemctl restart postgresql || sudo service postgresql restart
	@echo "$(GREEN)✓ PostgreSQL перезапущен$(NC)"

pg-vacuum:
	@echo "$(YELLOW)Очистка и оптимизация БД...$(NC)"
	@psql -h $(POSTGRES_HOST) -p $(POSTGRES_PORT) -U $(POSTGRES_USER) -d $(DB_NAME) -c "VACUUM ANALYZE;"
	@echo "$(GREEN)✓ Очистка завершена$(NC)"

pg-analyze:
	@echo "$(YELLOW)Обновление статистики БД...$(NC)"
	@psql -h $(POSTGRES_HOST) -p $(POSTGRES_PORT) -U $(POSTGRES_USER) -d $(DB_NAME) -c "ANALYZE;"
	@echo "$(GREEN)✓ Статистика обновлена$(NC)"

pg-reindex:
	@echo "$(YELLOW)Перестроение индексов...$(NC)"
	@psql -h $(POSTGRES_HOST) -p $(POSTGRES_PORT) -U $(POSTGRES_USER) -d $(DB_NAME) -c "REINDEX DATABASE $(DB_NAME);"
	@echo "$(GREEN)✓ Индексы перестроены$(NC)"

# Мониторинг
monitor:
	@watch -n 1 "psql -h $(POSTGRES_HOST) -p $(POSTGRES_PORT) -U $(POSTGRES_USER) -d $(DB_NAME) -c '\
		SELECT pid, usename, application_name, client_addr, state, \
		CASE WHEN state != '"'"'idle'"'"' THEN NOW() - query_start ELSE NULL END as duration, \
		LEFT(query, 60) as query \
		FROM pg_stat_activity \
		WHERE datname = '"'"'$(DB_NAME)'"'"' \
		ORDER BY duration DESC NULLS LAST;'"

# Показать медленные запросы
slow-queries:
	@psql -h $(POSTGRES_HOST) -p $(POSTGRES_PORT) -U $(POSTGRES_USER) -d $(DB_NAME) -c "\
		SELECT calls, total_exec_time, mean_exec_time, max_exec_time, \
		LEFT(query, 100) as query \
		FROM pg_stat_statements \
		WHERE query NOT LIKE '%pg_stat_statements%' \
		ORDER BY mean_exec_time DESC \
		LIMIT 20;"

# Размер таблиц
table-sizes:
	@psql -h $(POSTGRES_HOST) -p $(POSTGRES_PORT) -U $(POSTGRES_USER) -d $(DB_NAME) -c "\
		SELECT schemaname, tablename, \
		pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size, \
		pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) AS table_size, \
		pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename) - pg_relation_size(schemaname||'.'||tablename)) AS indexes_size \
		FROM pg_tables \
		WHERE schemaname NOT IN ('pg_catalog', 'information_schema') \
		ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC \
		LIMIT 20;"

# Загрузка тестовых данных
seed:
	@echo "$(YELLOW)Загрузка тестовых данных...$(NC)"
	@psql -h $(POSTGRES_HOST) -p $(POSTGRES_PORT) -U $(POSTGRES_USER) -d $(DB_NAME) -f sql/08_initial_data.sql
	@echo "$(GREEN)✓ Тестовые данные загружены$(NC)"

# Очистка
clean:
	@echo "$(YELLOW)Очистка временных файлов...$(NC)"
	@find . -type f -name "*.pyc" -delete
	@find . -type f -name "*.pyo" -delete
	@find . -type d -name "__pycache__" -delete
	@find . -type f -name ".DS_Store" -delete
	@rm -f scripts/*.log
	@rm -f restore_log.txt
	@echo "$(GREEN)✓ Очистка завершена$(NC)"

# Полная очистка (включая Docker volumes)
clean-all: clean docker-down
	@echo "$(YELLOW)Полная очистка включая Docker volumes...$(NC)"
	@docker volume rm asu_tp_postgres_data asu_tp_pgadmin_data asu_tp_grafana_data 2>/dev/null || true
	@rm -rf backup/*
	@echo "$(GREEN)✓ Полная очистка завершена$(NC)"

# Проверка конфигурации
check-config:
	@echo "$(BLUE)================================================================================$(NC)"
	@echo "$(BLUE)  Проверка конфигурации$(NC)"
	@echo "$(BLUE)================================================================================$(NC)"
	@echo "DB_NAME: $(DB_NAME)"
	@echo "POSTGRES_USER: $(POSTGRES_USER)"
	@echo "POSTGRES_HOST: $(POSTGRES_HOST)"
	@echo "POSTGRES_PORT: $(POSTGRES_PORT)"
	@echo ""
	@echo "Проверка файлов:"
	@ls -la sql/*.sql | wc -l | xargs echo "  SQL скриптов:"
	@ls -la scripts/*.sh scripts/*.bat scripts/*.py 2>/dev/null | wc -l | xargs echo "  Скриптов:"
	@ls -la docs/*.md 2>/dev/null | wc -l | xargs echo "  Документов:"
	@echo ""
	@echo "Проверка Docker:"
	@docker --version || echo "  Docker не установлен"
	@docker-compose --version || echo "  Docker Compose не установлен"
	@echo ""
	@echo "Проверка PostgreSQL:"
	@psql --version || echo "  psql не установлен"
	@pg_dump --version || echo "  pg_dump не установлен"
	@echo ""
	@echo "Проверка Python:"
	@$(PYTHON) --version || echo "  Python не установлен"

# Быстрый старт (все в одной команде)
quickstart: install docker-up docker-init test
	@echo "$(GREEN)================================================================================$(NC)"
	@echo "$(GREEN)  СИСТЕМА ГОТОВА К РАБОТЕ!$(NC)"
	@echo "$(GREEN)================================================================================$(NC)"
	@echo ""
	@echo "Доступы:"
	@echo "  PostgreSQL: $(POSTGRES_HOST):$(POSTGRES_PORT)"
	@echo "  pgAdmin: http://localhost:5050"
	@echo "  Grafana: http://localhost:3000"
	@echo ""
	@echo "Пользователи БД:"
	@echo "  admin / AdminPassword123!"
	@echo "  engineer / Test123!"
	@echo "  operator1 / Test123!"
	@echo ""

# Установка как systemd сервис (Linux)
install-service:
	@echo "$(YELLOW)Установка как systemd сервис...$(NC)"
	@sudo cp deployment/asu_tp_db.service /etc/systemd/system/
	@sudo systemctl daemon-reload
	@sudo systemctl enable asu_tp_db
	@echo "$(GREEN)✓ Сервис установлен$(NC)"
	@echo "Используйте: sudo systemctl start asu_tp_db"

.DEFAULT_GOAL := help



