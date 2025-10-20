#!/bin/bash
# ==============================================================================
# Скрипт резервного копирования БД ПТК АСУ ТП
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
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS="${RETENTION_DAYS:-30}"

# Типы резервных копий
BACKUP_TYPE="${1:-full}"  # full, schema, data, custom

echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}  РЕЗЕРВНОЕ КОПИРОВАНИЕ БД ПТК АСУ ТП${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo

# Создание директории для бэкапов
mkdir -p "$BACKUP_DIR"
mkdir -p "$BACKUP_DIR/daily"
mkdir -p "$BACKUP_DIR/weekly" 
mkdir -p "$BACKUP_DIR/monthly"
mkdir -p "$BACKUP_DIR/logs"

# Функция логирования
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$BACKUP_DIR/logs/backup_${TIMESTAMP}.log"
}

# Функция создания резервной копии
create_backup() {
    local backup_type=$1
    local backup_file=""
    local backup_cmd=""
    
    case $backup_type in
        "full")
            backup_file="$BACKUP_DIR/daily/${DB_NAME}_full_${TIMESTAMP}.dump"
            backup_cmd="pg_dump -h $PGHOST -p $PGPORT -U $PGUSER -d $DB_NAME -Fc -b -v"
            log "Создание полной резервной копии..."
            ;;
        "schema")
            backup_file="$BACKUP_DIR/daily/${DB_NAME}_schema_${TIMESTAMP}.sql"
            backup_cmd="pg_dump -h $PGHOST -p $PGPORT -U $PGUSER -d $DB_NAME -s -v"
            log "Создание резервной копии схемы..."
            ;;
        "data")
            backup_file="$BACKUP_DIR/daily/${DB_NAME}_data_${TIMESTAMP}.dump"
            backup_cmd="pg_dump -h $PGHOST -p $PGPORT -U $PGUSER -d $DB_NAME -a -Fc -v"
            log "Создание резервной копии данных..."
            ;;
        "custom")
            # Кастомное резервное копирование отдельных схем
            for schema in core tech_params controllers archive algorithms visualization topology kross security events reports; do
                backup_file="$BACKUP_DIR/daily/${DB_NAME}_${schema}_${TIMESTAMP}.dump"
                log "Резервное копирование схемы $schema..."
                pg_dump -h $PGHOST -p $PGPORT -U $PGUSER -d $DB_NAME -n $schema -Fc -b -v -f "$backup_file" 2>&1 | tee -a "$BACKUP_DIR/logs/backup_${TIMESTAMP}.log"
                
                # Проверка размера файла
                if [ -f "$backup_file" ]; then
                    size=$(du -h "$backup_file" | cut -f1)
                    log "✓ Схема $schema сохранена ($size)"
                fi
            done
            return
            ;;
        *)
            echo -e "${RED}Неизвестный тип резервной копии: $backup_type${NC}"
            exit 1
            ;;
    esac
    
    # Выполнение резервного копирования
    log "Выполнение команды: $backup_cmd"
    
    if $backup_cmd -f "$backup_file" 2>&1 | tee -a "$BACKUP_DIR/logs/backup_${TIMESTAMP}.log"; then
        # Проверка размера файла
        if [ -f "$backup_file" ]; then
            size=$(du -h "$backup_file" | cut -f1)
            log "✓ Резервная копия создана: $backup_file ($size)"
            
            # Сжатие резервной копии
            if command -v gzip &> /dev/null && [ "$backup_type" != "schema" ]; then
                log "Сжатие резервной копии..."
                gzip -9 "$backup_file"
                backup_file="${backup_file}.gz"
                new_size=$(du -h "$backup_file" | cut -f1)
                log "✓ Резервная копия сжата ($new_size)"
            fi
            
            # Создание контрольной суммы
            if command -v sha256sum &> /dev/null; then
                sha256sum "$backup_file" > "${backup_file}.sha256"
                log "✓ Контрольная сумма создана"
            fi
            
            return 0
        else
            log "✗ Ошибка: файл резервной копии не создан"
            return 1
        fi
    else
        log "✗ Ошибка при создании резервной копии"
        return 1
    fi
}

# Функция ротации резервных копий
rotate_backups() {
    log "Ротация резервных копий..."
    
    # Перемещение недельных копий (каждое воскресенье)
    if [ $(date +%u) -eq 7 ]; then
        latest_daily=$(ls -t "$BACKUP_DIR/daily"/${DB_NAME}_full_*.dump* 2>/dev/null | head -1)
        if [ -n "$latest_daily" ]; then
            cp "$latest_daily" "$BACKUP_DIR/weekly/"
            log "✓ Недельная копия создана"
        fi
    fi
    
    # Перемещение месячных копий (первое число месяца)
    if [ $(date +%d) -eq 01 ]; then
        latest_weekly=$(ls -t "$BACKUP_DIR/weekly"/${DB_NAME}_full_*.dump* 2>/dev/null | head -1)
        if [ -n "$latest_weekly" ]; then
            cp "$latest_weekly" "$BACKUP_DIR/monthly/"
            log "✓ Месячная копия создана"
        fi
    fi
    
    # Удаление старых ежедневных копий
    find "$BACKUP_DIR/daily" -name "${DB_NAME}_*.dump*" -type f -mtime +$RETENTION_DAYS -delete
    find "$BACKUP_DIR/daily" -name "${DB_NAME}_*.sql*" -type f -mtime +$RETENTION_DAYS -delete
    log "✓ Старые ежедневные копии удалены (старше $RETENTION_DAYS дней)"
    
    # Удаление старых недельных копий (хранить 12 недель)
    find "$BACKUP_DIR/weekly" -name "${DB_NAME}_*.dump*" -type f -mtime +84 -delete
    log "✓ Старые недельные копии удалены (старше 12 недель)"
    
    # Удаление старых месячных копий (хранить 12 месяцев)
    find "$BACKUP_DIR/monthly" -name "${DB_NAME}_*.dump*" -type f -mtime +365 -delete
    log "✓ Старые месячные копии удалены (старше 12 месяцев)"
    
    # Удаление старых логов
    find "$BACKUP_DIR/logs" -name "*.log" -type f -mtime +30 -delete
}

# Функция проверки места на диске
check_disk_space() {
    local required_space=1000000  # 1GB в KB
    local available_space=$(df "$BACKUP_DIR" | tail -1 | awk '{print $4}')
    
    if [ "$available_space" -lt "$required_space" ]; then
        log "⚠ Предупреждение: мало места на диске (доступно: ${available_space}KB)"
        echo -e "${YELLOW}Мало места на диске! Доступно: ${available_space}KB${NC}"
    fi
}

# Функция отправки уведомления (заглушка)
send_notification() {
    local status=$1
    local message=$2
    
    # Здесь можно добавить отправку email или webhook
    log "Уведомление [$status]: $message"
}

# Основной процесс
main() {
    log "Начало резервного копирования"
    log "Тип: $BACKUP_TYPE"
    log "База данных: $DB_NAME"
    log "Сервер: $PGHOST:$PGPORT"
    
    # Проверка места на диске
    check_disk_space
    
    # Проверка доступности БД
    if ! pg_isready -h "$PGHOST" -p "$PGPORT" -U "$PGUSER" &> /dev/null; then
        log "✗ База данных недоступна"
        echo -e "${RED}ОШИБКА: База данных недоступна${NC}"
        send_notification "ERROR" "База данных недоступна для резервного копирования"
        exit 1
    fi
    
    # Создание резервной копии
    if create_backup "$BACKUP_TYPE"; then
        # Ротация старых копий
        rotate_backups
        
        # Статистика
        total_size=$(du -sh "$BACKUP_DIR" | cut -f1)
        total_files=$(find "$BACKUP_DIR" -name "${DB_NAME}_*.dump*" -o -name "${DB_NAME}_*.sql*" | wc -l)
        
        log "Статистика резервных копий:"
        log "  Общий размер: $total_size"
        log "  Количество файлов: $total_files"
        
        echo -e "${GREEN}================================================================================${NC}"
        echo -e "${GREEN}  РЕЗЕРВНОЕ КОПИРОВАНИЕ ЗАВЕРШЕНО УСПЕШНО${NC}"
        echo -e "${GREEN}================================================================================${NC}"
        echo -e "Общий размер резервных копий: ${BLUE}$total_size${NC}"
        echo -e "Количество файлов: ${BLUE}$total_files${NC}"
        
        send_notification "SUCCESS" "Резервное копирование БД $DB_NAME выполнено успешно"
    else
        echo -e "${RED}================================================================================${NC}"
        echo -e "${RED}  ОШИБКА РЕЗЕРВНОГО КОПИРОВАНИЯ${NC}"
        echo -e "${RED}================================================================================${NC}"
        
        send_notification "ERROR" "Ошибка резервного копирования БД $DB_NAME"
        exit 1
    fi
    
    log "Резервное копирование завершено"
}

# Запуск
main

exit 0



