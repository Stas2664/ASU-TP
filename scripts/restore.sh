#!/bin/bash
# ==============================================================================
# Скрипт восстановления БД ПТК АСУ ТП из резервной копии
# ==============================================================================

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Конфигурация
BACKUP_DIR="${BACKUP_DIR:-../backup}"
DB_NAME="${DB_NAME:-asu_tp_db}"
PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
PGUSER="${PGUSER:-postgres}"
BACKUP_FILE="${1}"

echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}  ВОССТАНОВЛЕНИЕ БД ПТК АСУ ТП ИЗ РЕЗЕРВНОЙ КОПИИ${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Функция выбора резервной копии
select_backup() {
    echo -e "${YELLOW}Доступные резервные копии:${NC}"
    echo
    
    # Поиск всех резервных копий
    local backups=()
    local i=1
    
    for dir in daily weekly monthly; do
        if [ -d "$BACKUP_DIR/$dir" ]; then
            for file in "$BACKUP_DIR/$dir"/${DB_NAME}_*.{dump,dump.gz,sql,sql.gz} 2>/dev/null; do
                if [ -f "$file" ]; then
                    size=$(du -h "$file" | cut -f1)
                    date=$(stat -c %y "$file" | cut -d' ' -f1)
                    backups+=("$file")
                    echo "  $i) $(basename "$file") - $size - $date"
                    ((i++))
                fi
            done
        fi
    done
    
    if [ ${#backups[@]} -eq 0 ]; then
        echo -e "${RED}Резервные копии не найдены в $BACKUP_DIR${NC}"
        exit 1
    fi
    
    echo
    read -p "Выберите номер резервной копии для восстановления (1-${#backups[@]}): " choice
    
    if [ "$choice" -ge 1 ] && [ "$choice" -le ${#backups[@]} ]; then
        BACKUP_FILE="${backups[$((choice-1))]}"
        echo -e "${GREEN}Выбрана: $(basename "$BACKUP_FILE")${NC}"
    else
        echo -e "${RED}Неверный выбор${NC}"
        exit 1
    fi
}

# Функция проверки контрольной суммы
verify_checksum() {
    local file=$1
    local checksum_file="${file}.sha256"
    
    if [ -f "$checksum_file" ]; then
        log "Проверка контрольной суммы..."
        if sha256sum -c "$checksum_file" &> /dev/null; then
            log "✓ Контрольная сумма верна"
            return 0
        else
            log "✗ Контрольная сумма не совпадает!"
            return 1
        fi
    else
        log "⚠ Файл контрольной суммы не найден"
        return 0
    fi
}

# Функция распаковки архива
decompress_backup() {
    local file=$1
    
    if [[ "$file" == *.gz ]]; then
        log "Распаковка архива..."
        gunzip -k "$file"
        echo "${file%.gz}"
    else
        echo "$file"
    fi
}

# Функция создания резервной копии текущей БД перед восстановлением
backup_current() {
    log "Создание резервной копии текущей БД перед восстановлением..."
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local safety_backup="$BACKUP_DIR/restore_safety_${DB_NAME}_${timestamp}.dump"
    
    if pg_dump -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$DB_NAME" -Fc -f "$safety_backup" 2>/dev/null; then
        log "✓ Резервная копия текущей БД создана: $safety_backup"
        return 0
    else
        log "⚠ Не удалось создать резервную копию текущей БД"
        return 1
    fi
}

# Функция восстановления БД
restore_database() {
    local backup_file=$1
    local restore_cmd=""
    
    # Определение типа файла и команды восстановления
    if [[ "$backup_file" == *.sql ]]; then
        restore_cmd="psql -h $PGHOST -p $PGPORT -U $PGUSER -d $DB_NAME -f $backup_file"
    else
        restore_cmd="pg_restore -h $PGHOST -p $PGPORT -U $PGUSER -d $DB_NAME -v $backup_file"
    fi
    
    log "Восстановление БД из $backup_file..."
    log "Команда: $restore_cmd"
    
    # Выполнение восстановления
    if $restore_cmd 2>&1 | tee restore_log.txt; then
        log "✓ База данных успешно восстановлена"
        return 0
    else
        log "✗ Ошибка при восстановлении базы данных"
        return 1
    fi
}

# Функция проверки восстановленной БД
verify_restore() {
    log "Проверка восстановленной БД..."
    
    # Проверка подключения
    if ! psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$DB_NAME" -c "SELECT 1;" &> /dev/null; then
        log "✗ Не удается подключиться к БД"
        return 1
    fi
    
    # Проверка схем
    local schemas=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name IN ('core', 'tech_params', 'controllers', 'archive', 'algorithms', 'visualization', 'topology', 'kross', 'security', 'events', 'reports');")
    
    if [ "$schemas" -ge 11 ]; then
        log "✓ Все схемы на месте ($schemas)"
    else
        log "⚠ Найдено только $schemas схем из 11"
    fi
    
    # Проверка таблиц
    local tables=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema IN ('core', 'tech_params', 'controllers', 'archive', 'algorithms', 'visualization', 'topology', 'kross', 'security', 'events', 'reports') AND table_type = 'BASE TABLE';")
    
    log "✓ Найдено таблиц: $tables"
    
    # Проверка параметров
    local params=$(psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM tech_params.parameters;")
    
    log "✓ Найдено параметров: $params"
    
    return 0
}

# Основной процесс
main() {
    # Проверка доступности БД
    if ! pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" &> /dev/null; then
        echo -e "${RED}ОШИБКА: База данных недоступна${NC}"
        exit 1
    fi
    
    # Выбор резервной копии если не указана
    if [ -z "$BACKUP_FILE" ]; then
        select_backup
    fi
    
    # Проверка существования файла
    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "${RED}ОШИБКА: Файл $BACKUP_FILE не найден${NC}"
        exit 1
    fi
    
    echo
    echo -e "${YELLOW}ВНИМАНИЕ! Восстановление БД приведет к потере текущих данных!${NC}"
    echo -e "Будет восстановлена резервная копия: ${BLUE}$(basename "$BACKUP_FILE")${NC}"
    echo
    read -p "Вы уверены что хотите продолжить? (yes/no): " confirm
    
    if [ "$confirm" != "yes" ]; then
        echo "Отменено пользователем"
        exit 0
    fi
    
    # Проверка контрольной суммы
    if ! verify_checksum "$BACKUP_FILE"; then
        echo -e "${YELLOW}Контрольная сумма не совпадает. Продолжить? (yes/no): ${NC}"
        read confirm
        if [ "$confirm" != "yes" ]; then
            exit 1
        fi
    fi
    
    # Создание резервной копии текущей БД
    echo
    echo -e "${YELLOW}Создать резервную копию текущей БД перед восстановлением? (yes/no): ${NC}"
    read backup_current
    if [ "$backup_current" == "yes" ]; then
        if ! backup_current; then
            echo -e "${YELLOW}Не удалось создать резервную копию. Продолжить? (yes/no): ${NC}"
            read confirm
            if [ "$confirm" != "yes" ]; then
                exit 1
            fi
        fi
    fi
    
    # Распаковка если нужно
    BACKUP_FILE=$(decompress_backup "$BACKUP_FILE")
    
    # Пересоздание БД
    log "Пересоздание базы данных..."
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -c "DROP DATABASE IF EXISTS ${DB_NAME};" 2>/dev/null || true
    psql -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" -c "CREATE DATABASE ${DB_NAME} WITH ENCODING='UTF8' LC_COLLATE='ru_RU.UTF-8' LC_CTYPE='ru_RU.UTF-8';"
    
    # Восстановление
    if restore_database "$BACKUP_FILE"; then
        # Проверка восстановления
        if verify_restore; then
            echo
            echo -e "${GREEN}================================================================================${NC}"
            echo -e "${GREEN}  ВОССТАНОВЛЕНИЕ ЗАВЕРШЕНО УСПЕШНО${NC}"
            echo -e "${GREEN}================================================================================${NC}"
            echo
            echo "База данных восстановлена из: $(basename "$BACKUP_FILE")"
            echo
            echo "Рекомендуется:"
            echo "  1. Проверить работоспособность системы"
            echo "  2. Обновить статистику: ANALYZE;"
            echo "  3. Перестроить индексы если нужно: REINDEX DATABASE ${DB_NAME};"
        else
            echo -e "${YELLOW}Восстановление выполнено с предупреждениями${NC}"
        fi
    else
        echo
        echo -e "${RED}================================================================================${NC}"
        echo -e "${RED}  ОШИБКА ВОССТАНОВЛЕНИЯ${NC}"
        echo -e "${RED}================================================================================${NC}"
        echo
        echo "Проверьте файл restore_log.txt для деталей"
        exit 1
    fi
}

# Запуск
main

exit 0



