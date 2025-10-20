#!/bin/bash
# ==============================================================================
# Скрипт инициализации базы данных ПТК АСУ ТП
# Для Linux/Unix систем
# ==============================================================================

set -e  # Остановка при ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "================================================================================"
echo "  ИНИЦИАЛИЗАЦИЯ БАЗЫ ДАННЫХ ПТК АСУ ТП"
echo "  Платформа: КРОСС"
echo "  СУБД: PostgreSQL 15+"
echo "================================================================================"
echo

# Настройки подключения (можно переопределить через переменные окружения)
PGHOST=${PGHOST:-localhost}
PGPORT=${PGPORT:-5432}
PGUSER=${PGUSER:-postgres}
PGDATABASE=${PGDATABASE:-postgres}

echo "Настройки подключения:"
echo "  Сервер: $PGHOST:$PGPORT"
echo "  Пользователь: $PGUSER"
echo

# Проверка наличия psql
if ! command -v psql &> /dev/null; then
    echo -e "${RED}ОШИБКА: PostgreSQL клиент (psql) не найден!${NC}"
    echo "Установите PostgreSQL: sudo apt-get install postgresql-client"
    exit 1
fi

# Проверка подключения к PostgreSQL
echo "Проверка подключения к PostgreSQL..."
if ! psql -c "SELECT version();" &> /dev/null; then
    echo -e "${RED}ОШИБКА: Не удается подключиться к PostgreSQL!${NC}"
    echo "Проверьте, что сервер запущен и настройки подключения верны"
    exit 1
fi

echo
echo -e "${YELLOW}ВНИМАНИЕ! Этот скрипт создаст новую базу данных asu_tp_db${NC}"
echo -e "${YELLOW}Если база данных уже существует, она будет УДАЛЕНА!${NC}"
echo
read -p "Продолжить? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Отменено пользователем"
    exit 0
fi

# Функция выполнения SQL скрипта с обработкой ошибок
run_sql() {
    local script=$1
    local description=$2
    local database=${3:-$PGDATABASE}
    
    echo
    echo "================================================================================"
    echo "$description"
    echo "================================================================================"
    
    if [ -f "../sql/$script" ]; then
        if psql -d "$database" -f "../sql/$script"; then
            echo -e "${GREEN}✓ Успешно выполнено${NC}"
        else
            echo -e "${RED}✗ Ошибка при выполнении $script${NC}"
            exit 1
        fi
    else
        echo -e "${YELLOW}Файл $script не найден, пропускаем...${NC}"
        return 1
    fi
}

# Запуск скриптов по порядку
run_sql "01_create_database.sql" "Шаг 1/8: Создание базы данных..."

# Для остальных скриптов используем созданную БД
PGDATABASE="asu_tp_db"

run_sql "02_create_schemas.sql" "Шаг 2/8: Создание схем..." "asu_tp_db"
run_sql "03_create_tables.sql" "Шаг 3/8: Создание таблиц..." "asu_tp_db"
run_sql "04_create_indexes.sql" "Шаг 4/8: Создание индексов..." "asu_tp_db"
run_sql "05_create_roles.sql" "Шаг 5/8: Создание ролей и прав доступа..." "asu_tp_db"
run_sql "06_create_functions.sql" "Шаг 6/8: Создание функций..." "asu_tp_db"
run_sql "07_create_triggers.sql" "Шаг 7/8: Создание триггеров..." "asu_tp_db"
run_sql "08_initial_data.sql" "Шаг 8/8: Загрузка начальных данных..." "asu_tp_db"

# Проверка результата
echo
echo "================================================================================"
echo "  Проверка установки..."
echo "================================================================================"

# Подсчет объектов
SCHEMAS=$(psql -d asu_tp_db -t -c "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name IN ('core', 'tech_params', 'controllers', 'archive', 'algorithms', 'visualization', 'topology', 'kross', 'security', 'events', 'reports');")
TABLES=$(psql -d asu_tp_db -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema IN ('core', 'tech_params', 'controllers', 'archive', 'algorithms', 'visualization', 'topology', 'kross', 'security', 'events', 'reports') AND table_type = 'BASE TABLE';")
FUNCTIONS=$(psql -d asu_tp_db -t -c "SELECT COUNT(*) FROM information_schema.routines WHERE routine_schema IN ('core', 'tech_params', 'controllers', 'archive', 'algorithms', 'visualization', 'topology', 'kross', 'security', 'events', 'reports');")
INDEXES=$(psql -d asu_tp_db -t -c "SELECT COUNT(*) FROM pg_indexes WHERE schemaname IN ('core', 'tech_params', 'controllers', 'archive', 'algorithms', 'visualization', 'topology', 'kross', 'security', 'events', 'reports');")

echo -e "Создано объектов:"
echo -e "  Схем: ${GREEN}$SCHEMAS${NC}"
echo -e "  Таблиц: ${GREEN}$TABLES${NC}"
echo -e "  Функций: ${GREEN}$FUNCTIONS${NC}"
echo -e "  Индексов: ${GREEN}$INDEXES${NC}"

echo
echo "================================================================================"
echo -e "  ${GREEN}ИНИЦИАЛИЗАЦИЯ ЗАВЕРШЕНА УСПЕШНО!${NC}"
echo "================================================================================"
echo
echo "Информация о базе данных:"
echo "  База данных: asu_tp_db"
echo "  Схемы: core, tech_params, controllers, archive, algorithms,"
echo "         visualization, topology, kross, security, events, reports"
echo
echo "Пользователи по умолчанию:"
echo "  admin / AdminPassword123!    (Администратор)"
echo "  engineer / Test123!          (Инженер)"
echo "  operator1 / Test123!         (Оператор)"
echo "  operator2 / Test123!         (Оператор)"
echo "  viewer / Test123!            (Наблюдатель)"
echo
echo -e "${YELLOW}ВАЖНО: Обязательно смените пароли по умолчанию!${NC}"
echo
echo "Для проверки подключения выполните:"
echo "  psql -d asu_tp_db -U $PGUSER"
echo
echo "Для тестирования БД запустите:"
echo "  python3 test_connection.py"
echo

exit 0



