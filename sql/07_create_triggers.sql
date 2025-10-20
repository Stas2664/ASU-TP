-- ==============================================================================
-- Создание триггеров для ПТК АСУ ТП
-- База данных: asu_tp_db
-- Автоматизация процессов и обеспечение целостности данных
-- ==============================================================================

\c asu_tp_db;

-- ==============================================================================
-- ТРИГГЕРЫ ДЛЯ АВТОМАТИЧЕСКОГО ОБНОВЛЕНИЯ ВРЕМЕННЫХ МЕТОК
-- ==============================================================================

-- Триггер для таблицы parameters
CREATE TRIGGER trg_parameters_updated_at
    BEFORE UPDATE ON tech_params.parameters
    FOR EACH ROW
    EXECUTE FUNCTION core.update_updated_at();

-- Триггер для таблицы parameter_groups  
CREATE TRIGGER trg_parameter_groups_updated_at
    BEFORE UPDATE ON tech_params.parameter_groups
    FOR EACH ROW
    EXECUTE FUNCTION core.update_updated_at();

-- Триггер для таблицы controllers
CREATE TRIGGER trg_controllers_updated_at
    BEFORE UPDATE ON controllers.controllers
    FOR EACH ROW
    EXECUTE FUNCTION core.update_updated_at();

-- Триггер для таблицы algorithms
CREATE TRIGGER trg_algorithms_updated_at
    BEFORE UPDATE ON algorithms.algorithms
    FOR EACH ROW
    EXECUTE FUNCTION core.update_updated_at();

-- Триггер для таблицы users
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON security.users
    FOR EACH ROW
    EXECUTE FUNCTION core.update_updated_at();

-- Триггер для таблицы screens
CREATE TRIGGER trg_screens_updated_at
    BEFORE UPDATE ON visualization.screens
    FOR EACH ROW
    EXECUTE FUNCTION core.update_updated_at();

-- Триггер для таблицы nodes
CREATE TRIGGER trg_nodes_updated_at
    BEFORE UPDATE ON topology.nodes
    FOR EACH ROW
    EXECUTE FUNCTION core.update_updated_at();

-- Триггер для таблицы report_templates
CREATE TRIGGER trg_report_templates_updated_at
    BEFORE UPDATE ON reports.report_templates
    FOR EACH ROW
    EXECUTE FUNCTION core.update_updated_at();

-- ==============================================================================
-- ТРИГГЕРЫ ДЛЯ ПРОВЕРКИ АВАРИЙНЫХ УСТАВОК
-- ==============================================================================

-- Функция проверки аварийных уставок при изменении значения параметра
CREATE OR REPLACE FUNCTION tech_params.check_alarm_limits()
RETURNS TRIGGER AS $$
DECLARE
    v_param RECORD;
    v_value DECIMAL;
    v_alarm_type VARCHAR;
    v_alarm_message TEXT;
    v_limit_value TEXT;
BEGIN
    -- Получение информации о параметре
    SELECT * INTO v_param
    FROM tech_params.parameters
    WHERE id = NEW.parameter_id;
    
    -- Проверка только для аналоговых параметров с уставками
    IF v_param.parameter_type = 'analog' THEN
        BEGIN
            v_value := NEW.value::DECIMAL;
        EXCEPTION
            WHEN OTHERS THEN
                -- Если значение не может быть преобразовано в число, пропускаем проверку
                RETURN NEW;
        END;
        
        -- Проверка нижней аварийной уставки (LL)
        IF v_param.alarm_low_low IS NOT NULL AND v_value <= v_param.alarm_low_low THEN
            v_alarm_type := 'alarm_low_low';
            v_alarm_message := format('Параметр %s: критически низкое значение %.2f (уставка LL: %.2f)',
                                    v_param.tag, v_value, v_param.alarm_low_low);
            v_limit_value := v_param.alarm_low_low::TEXT;
            
        -- Проверка нижней предупредительной уставки (L)
        ELSIF v_param.alarm_low IS NOT NULL AND v_value <= v_param.alarm_low THEN
            v_alarm_type := 'alarm_low';
            v_alarm_message := format('Параметр %s: низкое значение %.2f (уставка L: %.2f)',
                                    v_param.tag, v_value, v_param.alarm_low);
            v_limit_value := v_param.alarm_low::TEXT;
            
        -- Проверка верхней предупредительной уставки (H)
        ELSIF v_param.alarm_high IS NOT NULL AND v_value >= v_param.alarm_high THEN
            v_alarm_type := 'alarm_high';
            v_alarm_message := format('Параметр %s: высокое значение %.2f (уставка H: %.2f)',
                                    v_param.tag, v_value, v_param.alarm_high);
            v_limit_value := v_param.alarm_high::TEXT;
            
        -- Проверка верхней аварийной уставки (HH)
        ELSIF v_param.alarm_high_high IS NOT NULL AND v_value >= v_param.alarm_high_high THEN
            v_alarm_type := 'alarm_high_high';
            v_alarm_message := format('Параметр %s: критически высокое значение %.2f (уставка HH: %.2f)',
                                    v_param.tag, v_value, v_param.alarm_high_high);
            v_limit_value := v_param.alarm_high_high::TEXT;
        ELSE
            -- Проверяем, была ли активная тревога, которую нужно деактивировать
            UPDATE events.events
            SET is_active = FALSE
            WHERE source_type = 'parameter'
            AND source_id = NEW.parameter_id
            AND is_active = TRUE
            AND event_type LIKE 'alarm_%';
            
            RETURN NEW;
        END IF;
        
        -- Генерация события тревоги
        PERFORM events.raise_event(
            p_source_type := 'parameter',
            p_source_id := NEW.parameter_id,
            p_source_name := v_param.tag,
            p_event_type := v_alarm_type,
            p_event_class_code := CASE 
                WHEN v_alarm_type IN ('alarm_low_low', 'alarm_high_high') THEN 'critical_alarm'
                ELSE 'warning_alarm'
            END,
            p_message := v_alarm_message,
            p_actual_value := NEW.value,
            p_limit_value := v_limit_value
        );
        
        -- Отправка уведомления
        PERFORM pg_notify('alarm_triggered', jsonb_build_object(
            'parameter_id', NEW.parameter_id,
            'parameter_tag', v_param.tag,
            'alarm_type', v_alarm_type,
            'value', v_value,
            'limit', v_limit_value,
            'message', v_alarm_message
        )::TEXT);
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Создание триггера для проверки аварийных уставок
CREATE TRIGGER trg_check_alarm_limits
    AFTER INSERT OR UPDATE OF value ON tech_params.current_values
    FOR EACH ROW
    EXECUTE FUNCTION tech_params.check_alarm_limits();

-- ==============================================================================
-- ТРИГГЕРЫ ДЛЯ АУДИТА ИЗМЕНЕНИЙ
-- ==============================================================================

-- Функция для логирования изменений в критических таблицах
CREATE OR REPLACE FUNCTION security.audit_critical_changes()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
    v_old_values JSONB;
    v_new_values JSONB;
    v_action_type VARCHAR;
    v_object_name VARCHAR;
BEGIN
    -- Получение ID текущего пользователя (если установлен)
    BEGIN
        v_user_id := current_setting('app.current_user_id')::UUID;
    EXCEPTION
        WHEN OTHERS THEN
            v_user_id := NULL;
    END;
    
    -- Определение типа операции
    CASE TG_OP
        WHEN 'INSERT' THEN
            v_action_type := 'create';
            v_old_values := NULL;
            v_new_values := row_to_json(NEW)::JSONB;
            v_object_name := COALESCE(NEW.name, NEW.tag, NEW.code, 'unknown');
        WHEN 'UPDATE' THEN
            v_action_type := 'update';
            v_old_values := row_to_json(OLD)::JSONB;
            v_new_values := row_to_json(NEW)::JSONB;
            v_object_name := COALESCE(NEW.name, NEW.tag, NEW.code, OLD.name, OLD.tag, OLD.code, 'unknown');
        WHEN 'DELETE' THEN
            v_action_type := 'delete';
            v_old_values := row_to_json(OLD)::JSONB;
            v_new_values := NULL;
            v_object_name := COALESCE(OLD.name, OLD.tag, OLD.code, 'unknown');
    END CASE;
    
    -- Запись в журнал аудита
    INSERT INTO security.audit_log (
        user_id,
        action_type,
        object_type,
        object_id,
        object_name,
        old_values,
        new_values,
        success,
        timestamp
    ) VALUES (
        v_user_id,
        v_action_type,
        TG_TABLE_NAME,
        COALESCE(NEW.id, OLD.id),
        v_object_name,
        v_old_values,
        v_new_values,
        TRUE,
        CURRENT_TIMESTAMP
    );
    
    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- Создание триггеров аудита для критических таблиц
CREATE TRIGGER trg_audit_parameters
    AFTER INSERT OR UPDATE OR DELETE ON tech_params.parameters
    FOR EACH ROW
    EXECUTE FUNCTION security.audit_critical_changes();

CREATE TRIGGER trg_audit_controllers
    AFTER INSERT OR UPDATE OR DELETE ON controllers.controllers
    FOR EACH ROW
    EXECUTE FUNCTION security.audit_critical_changes();

CREATE TRIGGER trg_audit_algorithms
    AFTER INSERT OR UPDATE OR DELETE ON algorithms.algorithms
    FOR EACH ROW
    EXECUTE FUNCTION security.audit_critical_changes();

CREATE TRIGGER trg_audit_users
    AFTER INSERT OR UPDATE OR DELETE ON security.users
    FOR EACH ROW
    EXECUTE FUNCTION security.audit_critical_changes();

CREATE TRIGGER trg_audit_roles
    AFTER INSERT OR UPDATE OR DELETE ON security.roles
    FOR EACH ROW
    EXECUTE FUNCTION security.audit_critical_changes();

-- ==============================================================================
-- ТРИГГЕРЫ ДЛЯ АВТОМАТИЧЕСКОГО АРХИВИРОВАНИЯ
-- ==============================================================================

-- Функция для автоматического архивирования при изменении значения
CREATE OR REPLACE FUNCTION archive.auto_archive_value()
RETURNS TRIGGER AS $$
DECLARE
    v_should_archive BOOLEAN;
    v_archive_config RECORD;
BEGIN
    -- Получение конфигурации архивирования
    SELECT * INTO v_archive_config
    FROM archive.archive_configs
    WHERE parameter_id = NEW.parameter_id
    AND is_active = TRUE;
    
    IF FOUND THEN
        -- Проверка необходимости архивирования
        v_should_archive := archive.should_archive(
            NEW.parameter_id,
            v_archive_config.archive_type,
            v_archive_config.interval_seconds,
            v_archive_config.deadband_value,
            NEW.value::DECIMAL
        );
        
        IF v_should_archive THEN
            -- Вставка в архив
            INSERT INTO archive.historical_data (parameter_id, timestamp, value, quality)
            VALUES (NEW.parameter_id, NEW.timestamp, NEW.value, NEW.quality);
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Создание триггера для автоматического архивирования
CREATE TRIGGER trg_auto_archive
    AFTER INSERT OR UPDATE ON tech_params.current_values
    FOR EACH ROW
    WHEN (NEW.quality >= 192) -- Архивируем только качественные данные
    EXECUTE FUNCTION archive.auto_archive_value();

-- ==============================================================================
-- ТРИГГЕРЫ ДЛЯ КОНТРОЛЯ ЦЕЛОСТНОСТИ ДАННЫХ
-- ==============================================================================

-- Функция проверки циклических зависимостей в группах параметров
CREATE OR REPLACE FUNCTION tech_params.check_group_hierarchy()
RETURNS TRIGGER AS $$
DECLARE
    v_current_id UUID;
    v_iterations INTEGER := 0;
    v_max_depth INTEGER := 20;
BEGIN
    IF NEW.parent_id IS NULL THEN
        RETURN NEW;
    END IF;
    
    -- Проверка, что группа не ссылается сама на себя
    IF NEW.id = NEW.parent_id THEN
        RAISE EXCEPTION 'Группа не может быть родителем самой себе';
    END IF;
    
    -- Проверка на циклические зависимости
    v_current_id := NEW.parent_id;
    
    WHILE v_current_id IS NOT NULL AND v_iterations < v_max_depth LOOP
        IF v_current_id = NEW.id THEN
            RAISE EXCEPTION 'Обнаружена циклическая зависимость в иерархии групп';
        END IF;
        
        SELECT parent_id INTO v_current_id
        FROM tech_params.parameter_groups
        WHERE id = v_current_id;
        
        v_iterations := v_iterations + 1;
    END LOOP;
    
    IF v_iterations >= v_max_depth THEN
        RAISE EXCEPTION 'Превышена максимальная глубина иерархии групп';
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Создание триггера для проверки иерархии групп
CREATE TRIGGER trg_check_group_hierarchy
    BEFORE INSERT OR UPDATE OF parent_id ON tech_params.parameter_groups
    FOR EACH ROW
    EXECUTE FUNCTION tech_params.check_group_hierarchy();

-- ==============================================================================
-- ТРИГГЕРЫ ДЛЯ УПРАВЛЕНИЯ СЕССИЯМИ
-- ==============================================================================

-- Функция автоматической очистки истекших сессий
CREATE OR REPLACE FUNCTION security.cleanup_expired_sessions()
RETURNS TRIGGER AS $$
BEGIN
    -- Деактивация истекших сессий
    UPDATE security.user_sessions
    SET is_active = FALSE,
        terminated_at = CURRENT_TIMESTAMP,
        termination_reason = 'timeout'
    WHERE is_active = TRUE
    AND expires_at < CURRENT_TIMESTAMP;
    
    -- Обновление статуса пользователей с истекшими сессиями
    UPDATE security.users
    SET is_online = FALSE
    WHERE id IN (
        SELECT DISTINCT user_id
        FROM security.user_sessions
        WHERE is_active = FALSE
        AND terminated_at >= CURRENT_TIMESTAMP - INTERVAL '1 minute'
    )
    AND NOT EXISTS (
        SELECT 1
        FROM security.user_sessions s
        WHERE s.user_id = users.id
        AND s.is_active = TRUE
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Триггер для очистки сессий при каждом входе
CREATE TRIGGER trg_cleanup_sessions
    BEFORE INSERT ON security.user_sessions
    FOR EACH STATEMENT
    EXECUTE FUNCTION security.cleanup_expired_sessions();

-- ==============================================================================
-- ТРИГГЕРЫ ДЛЯ ОБРАБОТКИ СОБЫТИЙ
-- ==============================================================================

-- Функция для автоматического квитирования событий по таймауту
CREATE OR REPLACE FUNCTION events.auto_acknowledge_events()
RETURNS void AS $$
DECLARE
    v_event RECORD;
BEGIN
    FOR v_event IN
        SELECT e.id, ec.auto_acknowledge_timeout_min
        FROM events.events e
        JOIN events.event_classes ec ON e.event_class_id = ec.id
        WHERE e.is_active = TRUE
        AND e.is_acknowledged = FALSE
        AND ec.auto_acknowledge_timeout_min IS NOT NULL
        AND e.event_time < CURRENT_TIMESTAMP - (ec.auto_acknowledge_timeout_min || ' minutes')::INTERVAL
    LOOP
        UPDATE events.events
        SET is_acknowledged = TRUE,
            acknowledged_at = CURRENT_TIMESTAMP,
            acknowledgment_comment = 'Автоматическое квитирование по таймауту'
        WHERE id = v_event.id;
        
        -- Логирование
        INSERT INTO security.audit_log (
            action_type, object_type, object_id,
            object_name, success, timestamp
        ) VALUES (
            'auto_acknowledge', 'event', v_event.id::UUID,
            'Event #' || v_event.id, TRUE, CURRENT_TIMESTAMP
        );
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- ТРИГГЕРЫ ДЛЯ ВАЛИДАЦИИ ДАННЫХ
-- ==============================================================================

-- Функция валидации email адреса
CREATE OR REPLACE FUNCTION security.validate_email()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.email IS NOT NULL AND NEW.email !~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        RAISE EXCEPTION 'Неверный формат email адреса: %', NEW.email;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Создание триггера для валидации email
CREATE TRIGGER trg_validate_email
    BEFORE INSERT OR UPDATE OF email ON security.users
    FOR EACH ROW
    EXECUTE FUNCTION security.validate_email();

-- ==============================================================================
-- ТРИГГЕРЫ ДЛЯ РЕЗЕРВНОГО КОПИРОВАНИЯ КРИТИЧЕСКИХ ИЗМЕНЕНИЙ
-- ==============================================================================

-- Функция для создания резервных копий удаляемых алгоритмов
CREATE OR REPLACE FUNCTION algorithms.backup_deleted_algorithm()
RETURNS TRIGGER AS $$
BEGIN
    -- Сохранение удаляемого алгоритма в архивную таблицу
    INSERT INTO algorithms.algorithms_backup (
        original_id, type_id, code, name, description,
        language, source_code, version, created_at,
        deleted_at, deleted_by
    ) VALUES (
        OLD.id, OLD.type_id, OLD.code, OLD.name, OLD.description,
        OLD.language, OLD.source_code, OLD.version, OLD.created_at,
        CURRENT_TIMESTAMP, current_setting('app.current_user_id')::UUID
    );
    
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

-- Создание архивной таблицы для алгоритмов
CREATE TABLE IF NOT EXISTS algorithms.algorithms_backup (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    original_id UUID NOT NULL,
    type_id UUID,
    code VARCHAR(100),
    name VARCHAR(255),
    description TEXT,
    language VARCHAR(50),
    source_code TEXT,
    version VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE,
    deleted_at TIMESTAMP WITH TIME ZONE,
    deleted_by UUID
);

-- Создание триггера для резервного копирования алгоритмов
CREATE TRIGGER trg_backup_algorithm
    BEFORE DELETE ON algorithms.algorithms
    FOR EACH ROW
    EXECUTE FUNCTION algorithms.backup_deleted_algorithm();

-- ==============================================================================
-- ТРИГГЕРЫ ДЛЯ ОБНОВЛЕНИЯ СТАТИСТИКИ
-- ==============================================================================

-- Функция обновления счетчиков параметров в группах
CREATE OR REPLACE FUNCTION tech_params.update_group_counters()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        -- Увеличение счетчика при добавлении параметра
        UPDATE tech_params.parameter_groups
        SET parameters_count = COALESCE(parameters_count, 0) + 1
        WHERE id = NEW.group_id;
        
    ELSIF TG_OP = 'DELETE' THEN
        -- Уменьшение счетчика при удалении параметра
        UPDATE tech_params.parameter_groups
        SET parameters_count = GREATEST(COALESCE(parameters_count, 0) - 1, 0)
        WHERE id = OLD.group_id;
        
    ELSIF TG_OP = 'UPDATE' AND OLD.group_id IS DISTINCT FROM NEW.group_id THEN
        -- Обновление счетчиков при перемещении параметра
        UPDATE tech_params.parameter_groups
        SET parameters_count = GREATEST(COALESCE(parameters_count, 0) - 1, 0)
        WHERE id = OLD.group_id;
        
        UPDATE tech_params.parameter_groups
        SET parameters_count = COALESCE(parameters_count, 0) + 1
        WHERE id = NEW.group_id;
    END IF;
    
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- Добавление поля для счетчика в таблицу групп (если его нет)
ALTER TABLE tech_params.parameter_groups 
ADD COLUMN IF NOT EXISTS parameters_count INTEGER DEFAULT 0;

-- Создание триггера для обновления счетчиков
CREATE TRIGGER trg_update_group_counters
    AFTER INSERT OR DELETE OR UPDATE OF group_id ON tech_params.parameters
    FOR EACH ROW
    EXECUTE FUNCTION tech_params.update_group_counters();

-- ==============================================================================
-- ТРИГГЕРЫ ДЛЯ УВЕДОМЛЕНИЙ В РЕАЛЬНОМ ВРЕМЕНИ
-- ==============================================================================

-- Функция отправки уведомлений при изменении значения параметра
CREATE OR REPLACE FUNCTION tech_params.notify_parameter_change()
RETURNS TRIGGER AS $$
DECLARE
    v_param_info RECORD;
BEGIN
    -- Получение информации о параметре
    SELECT p.tag, p.name, u.symbol AS unit
    INTO v_param_info
    FROM tech_params.parameters p
    LEFT JOIN core.units u ON p.unit_id = u.id
    WHERE p.id = NEW.parameter_id;
    
    -- Отправка уведомления
    PERFORM pg_notify('parameter_changed', jsonb_build_object(
        'parameter_id', NEW.parameter_id,
        'tag', v_param_info.tag,
        'name', v_param_info.name,
        'value', NEW.value,
        'unit', v_param_info.unit,
        'quality', NEW.quality,
        'timestamp', NEW.timestamp
    )::TEXT);
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Создание триггера для уведомлений об изменении параметров
CREATE TRIGGER trg_notify_parameter_change
    AFTER INSERT OR UPDATE ON tech_params.current_values
    FOR EACH ROW
    WHEN (NEW.quality >= 192)
    EXECUTE FUNCTION tech_params.notify_parameter_change();

-- ==============================================================================
-- ПЛАНИРОВЩИК ЗАДАЧ (используя pg_cron или внешний scheduler)
-- ==============================================================================

-- Создание таблицы для планировщика задач
CREATE TABLE IF NOT EXISTS core.scheduled_jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    job_name VARCHAR(255) NOT NULL UNIQUE,
    job_function VARCHAR(255) NOT NULL,
    schedule VARCHAR(100) NOT NULL, -- Cron expression
    is_active BOOLEAN DEFAULT true,
    last_run TIMESTAMP WITH TIME ZONE,
    next_run TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Вставка стандартных задач
INSERT INTO core.scheduled_jobs (job_name, job_function, schedule) VALUES
    ('archive_compression', 'archive.compress_old_data()', '0 2 * * *'), -- Ежедневно в 2:00
    ('session_cleanup', 'security.cleanup_expired_sessions()', '*/15 * * * *'), -- Каждые 15 минут
    ('auto_acknowledge', 'events.auto_acknowledge_events()', '*/5 * * * *'), -- Каждые 5 минут
    ('archive_parameters', 'archive.archive_parameter_values()', '*/1 * * * *') -- Каждую минуту
ON CONFLICT (job_name) DO NOTHING;

-- ==============================================================================
-- Вывод информации о созданных триггерах
-- ==============================================================================

SELECT 'Триггеры созданы:' AS info;
SELECT 
    n.nspname AS schema_name,
    c.relname AS table_name,
    t.tgname AS trigger_name,
    CASE t.tgtype & 2 WHEN 2 THEN 'BEFORE' ELSE 'AFTER' END AS timing,
    CASE 
        WHEN t.tgtype & 4 = 4 THEN 'INSERT'
        WHEN t.tgtype & 8 = 8 THEN 'DELETE'
        WHEN t.tgtype & 16 = 16 THEN 'UPDATE'
        WHEN t.tgtype & 28 = 28 THEN 'INSERT OR DELETE OR UPDATE'
    END AS event
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE n.nspname IN ('tech_params', 'controllers', 'archive', 'security', 'events', 'algorithms')
AND NOT t.tgisinternal
ORDER BY n.nspname, c.relname, t.tgname;



