-- ==============================================================================
-- Создание функций и процедур для ПТК АСУ ТП
-- База данных: asu_tp_db
-- Алгоритмы единовременного доступа и обработки данных
-- ==============================================================================

\c asu_tp_db;

-- ==============================================================================
-- ФУНКЦИИ ДЛЯ МНОГОПОЛЬЗОВАТЕЛЬСКОГО ДОСТУПА
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Функция получения блокировки на редактирование объекта
-- Реализует пессимистическую блокировку с таймаутом
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.acquire_object_lock(
    p_object_type VARCHAR,
    p_object_id UUID,
    p_user_id UUID,
    p_timeout_seconds INTEGER DEFAULT 30
) RETURNS BOOLEAN AS $$
DECLARE
    v_lock_acquired BOOLEAN := FALSE;
    v_lock_key BIGINT;
BEGIN
    -- Генерация уникального ключа блокировки на основе типа и ID объекта
    v_lock_key := hashtext(p_object_type || '::' || p_object_id::TEXT);
    
    -- Установка таймаута для попытки получения блокировки
    PERFORM set_config('lock_timeout', (p_timeout_seconds * 1000)::TEXT || 'ms', true);
    
    -- Попытка получения эксклюзивной блокировки
    BEGIN
        PERFORM pg_advisory_lock(v_lock_key);
        v_lock_acquired := TRUE;
        
        -- Логирование получения блокировки
        INSERT INTO security.audit_log (
            user_id, action_type, object_type, object_id, 
            object_name, success, timestamp
        ) VALUES (
            p_user_id, 'lock_acquired', p_object_type, p_object_id,
            p_object_type || '::' || p_object_id, TRUE, CURRENT_TIMESTAMP
        );
        
    EXCEPTION
        WHEN lock_not_available THEN
            v_lock_acquired := FALSE;
            
            -- Логирование неудачной попытки
            INSERT INTO security.audit_log (
                user_id, action_type, object_type, object_id,
                object_name, success, error_message, timestamp
            ) VALUES (
                p_user_id, 'lock_failed', p_object_type, p_object_id,
                p_object_type || '::' || p_object_id, FALSE,
                'Объект заблокирован другим пользователем', CURRENT_TIMESTAMP
            );
    END;
    
    RETURN v_lock_acquired;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- Функция освобождения блокировки объекта
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.release_object_lock(
    p_object_type VARCHAR,
    p_object_id UUID,
    p_user_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    v_lock_key BIGINT;
    v_lock_released BOOLEAN := FALSE;
BEGIN
    -- Генерация ключа блокировки
    v_lock_key := hashtext(p_object_type || '::' || p_object_id::TEXT);
    
    -- Освобождение блокировки
    v_lock_released := pg_advisory_unlock(v_lock_key);
    
    IF v_lock_released THEN
        -- Логирование освобождения блокировки
        INSERT INTO security.audit_log (
            user_id, action_type, object_type, object_id,
            object_name, success, timestamp
        ) VALUES (
            p_user_id, 'lock_released', p_object_type, p_object_id,
            p_object_type || '::' || p_object_id, TRUE, CURRENT_TIMESTAMP
        );
    END IF;
    
    RETURN v_lock_released;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- Функция проверки доступности объекта для редактирования
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.is_object_locked(
    p_object_type VARCHAR,
    p_object_id UUID
) RETURNS BOOLEAN AS $$
DECLARE
    v_lock_key BIGINT;
    v_is_locked BOOLEAN;
BEGIN
    v_lock_key := hashtext(p_object_type || '::' || p_object_id::TEXT);
    
    -- Проверка, установлена ли блокировка
    SELECT EXISTS(
        SELECT 1 FROM pg_locks 
        WHERE locktype = 'advisory' 
        AND objid = v_lock_key
    ) INTO v_is_locked;
    
    RETURN v_is_locked;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- ФУНКЦИИ ДЛЯ РАБОТЫ С ПАРАМЕТРАМИ
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Функция безопасной записи значения параметра с проверкой прав
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tech_params.write_parameter_value(
    p_parameter_id UUID,
    p_value TEXT,
    p_user_id UUID,
    p_source VARCHAR DEFAULT 'manual'
) RETURNS BOOLEAN AS $$
DECLARE
    v_parameter RECORD;
    v_has_permission BOOLEAN;
    v_old_value TEXT;
    v_success BOOLEAN := FALSE;
BEGIN
    -- Проверка прав доступа
    v_has_permission := security.check_permission(p_user_id, 'parameters', 'write_value');
    
    IF NOT v_has_permission THEN
        RAISE EXCEPTION 'Недостаточно прав для записи значения параметра';
    END IF;
    
    -- Получение информации о параметре
    SELECT * INTO v_parameter
    FROM tech_params.parameters
    WHERE id = p_parameter_id
    FOR UPDATE; -- Блокировка строки на время транзакции
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Параметр не найден: %', p_parameter_id;
    END IF;
    
    IF NOT v_parameter.is_active THEN
        RAISE EXCEPTION 'Параметр неактивен: %', v_parameter.tag;
    END IF;
    
    -- Проверка границ для аналоговых параметров
    IF v_parameter.parameter_type = 'analog' THEN
        IF v_parameter.min_value IS NOT NULL AND p_value::DECIMAL < v_parameter.min_value THEN
            RAISE EXCEPTION 'Значение % меньше минимального %', p_value, v_parameter.min_value;
        END IF;
        
        IF v_parameter.max_value IS NOT NULL AND p_value::DECIMAL > v_parameter.max_value THEN
            RAISE EXCEPTION 'Значение % больше максимального %', p_value, v_parameter.max_value;
        END IF;
    END IF;
    
    -- Сохранение старого значения для аудита
    SELECT value INTO v_old_value
    FROM tech_params.current_values
    WHERE parameter_id = p_parameter_id;
    
    -- Обновление или вставка нового значения
    INSERT INTO tech_params.current_values (
        parameter_id, value, quality, timestamp, source, updated_at
    ) VALUES (
        p_parameter_id, p_value, 192, CURRENT_TIMESTAMP, p_source, CURRENT_TIMESTAMP
    )
    ON CONFLICT (parameter_id) DO UPDATE SET
        value = EXCLUDED.value,
        quality = EXCLUDED.quality,
        timestamp = EXCLUDED.timestamp,
        source = EXCLUDED.source,
        updated_at = EXCLUDED.updated_at;
    
    -- Запись в архив если требуется
    IF v_parameter.is_archived THEN
        INSERT INTO archive.historical_data (parameter_id, timestamp, value, quality)
        VALUES (p_parameter_id, CURRENT_TIMESTAMP, p_value, 192);
    END IF;
    
    -- Логирование изменения
    INSERT INTO security.audit_log (
        user_id, action_type, object_type, object_id,
        object_name, old_values, new_values, success, timestamp
    ) VALUES (
        p_user_id, 'update', 'parameter', p_parameter_id,
        v_parameter.tag,
        jsonb_build_object('value', v_old_value),
        jsonb_build_object('value', p_value),
        TRUE, CURRENT_TIMESTAMP
    );
    
    v_success := TRUE;
    RETURN v_success;
    
EXCEPTION
    WHEN OTHERS THEN
        -- Логирование ошибки
        INSERT INTO security.audit_log (
            user_id, action_type, object_type, object_id,
            error_message, success, timestamp
        ) VALUES (
            p_user_id, 'update', 'parameter', p_parameter_id,
            SQLERRM, FALSE, CURRENT_TIMESTAMP
        );
        RAISE;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- Функция массового чтения параметров с оптимизацией
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tech_params.read_parameters_bulk(
    p_parameter_ids UUID[],
    p_user_id UUID
) RETURNS TABLE (
    parameter_id UUID,
    tag VARCHAR,
    name VARCHAR,
    value TEXT,
    quality INTEGER,
    timestamp TIMESTAMP WITH TIME ZONE,
    unit VARCHAR,
    status VARCHAR
) AS $$
BEGIN
    -- Проверка прав доступа
    IF NOT security.check_permission(p_user_id, 'parameters', 'read') THEN
        RAISE EXCEPTION 'Недостаточно прав для чтения параметров';
    END IF;
    
    RETURN QUERY
    SELECT
        p.id AS parameter_id,
        p.tag,
        p.name,
        cv.value,
        cv.quality,
        cv.timestamp,
        u.symbol AS unit,
        CASE
            WHEN cv.quality >= 192 THEN 'good'
            WHEN cv.quality >= 64 THEN 'uncertain'
            ELSE 'bad'
        END AS status
    FROM tech_params.parameters p
    LEFT JOIN tech_params.current_values cv ON p.id = cv.parameter_id
    LEFT JOIN core.units u ON p.unit_id = u.id
    WHERE p.id = ANY(p_parameter_ids)
    AND p.is_active = TRUE
    ORDER BY p.tag;
END;
$$ LANGUAGE plpgsql STABLE;

-- ==============================================================================
-- ФУНКЦИИ ДЛЯ РАБОТЫ С СОБЫТИЯМИ И ТРЕВОГАМИ
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Функция генерации события/тревоги
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION events.raise_event(
    p_source_type VARCHAR,
    p_source_id UUID,
    p_source_name VARCHAR,
    p_event_type VARCHAR,
    p_event_class_code VARCHAR,
    p_message TEXT,
    p_details JSONB DEFAULT NULL,
    p_actual_value TEXT DEFAULT NULL,
    p_limit_value TEXT DEFAULT NULL
) RETURNS BIGINT AS $$
DECLARE
    v_event_id BIGINT;
    v_event_class_id UUID;
BEGIN
    -- Получение класса события
    SELECT id INTO v_event_class_id
    FROM events.event_classes
    WHERE code = p_event_class_code;
    
    IF v_event_class_id IS NULL THEN
        RAISE EXCEPTION 'Неизвестный класс события: %', p_event_class_code;
    END IF;
    
    -- Создание события
    INSERT INTO events.events (
        event_class_id, source_type, source_id, source_name,
        event_type, message, details, actual_value, limit_value,
        event_time, is_active, is_acknowledged
    ) VALUES (
        v_event_class_id, p_source_type, p_source_id, p_source_name,
        p_event_type, p_message, p_details, p_actual_value, p_limit_value,
        CURRENT_TIMESTAMP, TRUE, FALSE
    ) RETURNING id INTO v_event_id;
    
    -- Уведомление подписчиков (асинхронно через NOTIFY)
    PERFORM pg_notify('new_event', jsonb_build_object(
        'event_id', v_event_id,
        'event_class', p_event_class_code,
        'source_type', p_source_type,
        'source_id', p_source_id,
        'message', p_message
    )::TEXT);
    
    RETURN v_event_id;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- Функция квитирования события
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION events.acknowledge_event(
    p_event_id BIGINT,
    p_user_id UUID,
    p_comment TEXT DEFAULT NULL
) RETURNS BOOLEAN AS $$
DECLARE
    v_success BOOLEAN := FALSE;
    v_event RECORD;
BEGIN
    -- Проверка прав
    IF NOT security.check_permission(p_user_id, 'events', 'acknowledge') THEN
        RAISE EXCEPTION 'Недостаточно прав для квитирования событий';
    END IF;
    
    -- Получение информации о событии с блокировкой
    SELECT * INTO v_event
    FROM events.events
    WHERE id = p_event_id
    FOR UPDATE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Событие не найдено: %', p_event_id;
    END IF;
    
    IF v_event.is_acknowledged THEN
        RAISE NOTICE 'Событие уже квитировано';
        RETURN FALSE;
    END IF;
    
    -- Квитирование
    UPDATE events.events
    SET is_acknowledged = TRUE,
        acknowledged_by = p_user_id,
        acknowledged_at = CURRENT_TIMESTAMP,
        acknowledgment_comment = p_comment
    WHERE id = p_event_id;
    
    -- Логирование
    INSERT INTO security.audit_log (
        user_id, action_type, object_type, object_id,
        object_name, details, success, timestamp
    ) VALUES (
        p_user_id, 'acknowledge', 'event', p_event_id::UUID,
        'Event #' || p_event_id,
        jsonb_build_object('comment', p_comment),
        TRUE, CURRENT_TIMESTAMP
    );
    
    v_success := TRUE;
    RETURN v_success;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- ФУНКЦИИ ДЛЯ РАБОТЫ С АЛГОРИТМАМИ
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Функция выполнения расчетного алгоритма
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION algorithms.execute_algorithm(
    p_algorithm_id UUID,
    p_input_values JSONB DEFAULT '{}'::JSONB
) RETURNS JSONB AS $$
DECLARE
    v_algorithm RECORD;
    v_result JSONB;
    v_execution_id BIGINT;
    v_start_time TIMESTAMP WITH TIME ZONE;
    v_end_time TIMESTAMP WITH TIME ZONE;
BEGIN
    v_start_time := CURRENT_TIMESTAMP;
    
    -- Получение алгоритма
    SELECT * INTO v_algorithm
    FROM algorithms.algorithms
    WHERE id = p_algorithm_id
    AND is_active = TRUE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Алгоритм не найден или неактивен: %', p_algorithm_id;
    END IF;
    
    -- Создание записи о выполнении
    INSERT INTO algorithms.execution_history (
        algorithm_id, started_at, status, input_values
    ) VALUES (
        p_algorithm_id, v_start_time, 'running', p_input_values
    ) RETURNING id INTO v_execution_id;
    
    -- Выполнение алгоритма в зависимости от языка
    BEGIN
        IF v_algorithm.language = 'sql' THEN
            -- Выполнение SQL алгоритма
            EXECUTE v_algorithm.source_code
            USING p_input_values
            INTO v_result;
        ELSE
            -- Для других языков потребуется внешний обработчик
            RAISE EXCEPTION 'Язык % пока не поддерживается', v_algorithm.language;
        END IF;
        
        v_end_time := CURRENT_TIMESTAMP;
        
        -- Обновление статуса выполнения
        UPDATE algorithms.execution_history
        SET completed_at = v_end_time,
            status = 'completed',
            output_values = v_result,
            execution_time_ms = EXTRACT(MILLISECOND FROM (v_end_time - v_start_time))
        WHERE id = v_execution_id;
        
        -- Обновление статистики алгоритма
        UPDATE algorithms.algorithms
        SET last_execution_time = v_end_time,
            last_execution_status = 'completed',
            execution_count = execution_count + 1
        WHERE id = p_algorithm_id;
        
    EXCEPTION
        WHEN OTHERS THEN
            -- Обработка ошибки
            UPDATE algorithms.execution_history
            SET completed_at = CURRENT_TIMESTAMP,
                status = 'failed',
                error_message = SQLERRM
            WHERE id = v_execution_id;
            
            UPDATE algorithms.algorithms
            SET last_execution_time = CURRENT_TIMESTAMP,
                last_execution_status = 'failed',
                error_count = error_count + 1
            WHERE id = p_algorithm_id;
            
            RAISE;
    END;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- ФУНКЦИИ ДЛЯ АРХИВИРОВАНИЯ ДАННЫХ
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Функция архивирования значений параметров
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION archive.archive_parameter_values()
RETURNS INTEGER AS $$
DECLARE
    v_archived_count INTEGER := 0;
    v_param RECORD;
BEGIN
    -- Перебор всех параметров, требующих архивирования
    FOR v_param IN
        SELECT p.id, p.tag, ac.archive_type, ac.interval_seconds, ac.deadband_value,
               cv.value, cv.timestamp
        FROM tech_params.parameters p
        JOIN archive.archive_configs ac ON p.id = ac.parameter_id
        JOIN tech_params.current_values cv ON p.id = cv.parameter_id
        WHERE p.is_archived = TRUE
        AND ac.is_active = TRUE
    LOOP
        -- Проверка необходимости архивирования
        IF archive.should_archive(
            v_param.id,
            v_param.archive_type,
            v_param.interval_seconds,
            v_param.deadband_value,
            v_param.value::DECIMAL
        ) THEN
            -- Вставка в архив
            INSERT INTO archive.historical_data (parameter_id, timestamp, value, quality)
            VALUES (v_param.id, CURRENT_TIMESTAMP, v_param.value, 192);
            
            v_archived_count := v_archived_count + 1;
        END IF;
    END LOOP;
    
    RETURN v_archived_count;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- Вспомогательная функция проверки необходимости архивирования
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION archive.should_archive(
    p_parameter_id UUID,
    p_archive_type VARCHAR,
    p_interval_seconds INTEGER,
    p_deadband DECIMAL,
    p_current_value DECIMAL
) RETURNS BOOLEAN AS $$
DECLARE
    v_last_archived RECORD;
    v_should_archive BOOLEAN := FALSE;
BEGIN
    -- Получение последней архивной записи
    SELECT value, timestamp INTO v_last_archived
    FROM archive.historical_data
    WHERE parameter_id = p_parameter_id
    ORDER BY timestamp DESC
    LIMIT 1;
    
    IF NOT FOUND THEN
        -- Первая запись - всегда архивируем
        RETURN TRUE;
    END IF;
    
    -- Проверка в зависимости от типа архивирования
    CASE p_archive_type
        WHEN 'periodic' THEN
            -- Архивирование по времени
            v_should_archive := (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_last_archived.timestamp)) >= p_interval_seconds);
            
        WHEN 'on_change' THEN
            -- Архивирование по изменению
            IF p_deadband IS NOT NULL THEN
                v_should_archive := (ABS(p_current_value - v_last_archived.value::DECIMAL) > p_deadband);
            ELSE
                v_should_archive := (p_current_value != v_last_archived.value::DECIMAL);
            END IF;
            
        WHEN 'both' THEN
            -- Комбинированное архивирование
            v_should_archive := (
                (EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - v_last_archived.timestamp)) >= p_interval_seconds)
                OR (p_deadband IS NOT NULL AND ABS(p_current_value - v_last_archived.value::DECIMAL) > p_deadband)
            );
    END CASE;
    
    RETURN v_should_archive;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- Функция сжатия архивных данных
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION archive.compress_old_data(
    p_days_to_keep INTEGER DEFAULT 30
) RETURNS INTEGER AS $$
DECLARE
    v_compressed_count INTEGER := 0;
    v_cutoff_date TIMESTAMP WITH TIME ZONE;
BEGIN
    v_cutoff_date := CURRENT_TIMESTAMP - (p_days_to_keep || ' days')::INTERVAL;
    
    -- Сжатие данных старше указанного периода
    INSERT INTO archive.compressed_data (
        parameter_id, start_time, end_time, samples_count,
        min_value, max_value, avg_value, std_deviation,
        compression_method, created_at
    )
    SELECT
        parameter_id,
        DATE_TRUNC('hour', MIN(timestamp)) AS start_time,
        DATE_TRUNC('hour', MAX(timestamp)) + INTERVAL '1 hour' AS end_time,
        COUNT(*) AS samples_count,
        MIN(value::DECIMAL) AS min_value,
        MAX(value::DECIMAL) AS max_value,
        AVG(value::DECIMAL) AS avg_value,
        STDDEV(value::DECIMAL) AS std_deviation,
        'hourly_aggregation' AS compression_method,
        CURRENT_TIMESTAMP
    FROM archive.historical_data
    WHERE timestamp < v_cutoff_date
    GROUP BY parameter_id, DATE_TRUNC('hour', timestamp)
    ON CONFLICT DO NOTHING;
    
    GET DIAGNOSTICS v_compressed_count = ROW_COUNT;
    
    -- Удаление сжатых данных из основного архива
    DELETE FROM archive.historical_data
    WHERE timestamp < v_cutoff_date
    AND parameter_id IN (
        SELECT DISTINCT parameter_id 
        FROM archive.compressed_data
        WHERE start_time <= timestamp 
        AND end_time > timestamp
    );
    
    RETURN v_compressed_count;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- ФУНКЦИИ ДЛЯ РАБОТЫ С КОНТРОЛЛЕРАМИ
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Функция проверки состояния контроллера
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION controllers.check_controller_status(
    p_controller_id UUID
) RETURNS TABLE (
    is_online BOOLEAN,
    last_seen TIMESTAMP WITH TIME ZONE,
    response_time_ms INTEGER,
    status_message TEXT
) AS $$
DECLARE
    v_controller RECORD;
    v_start_time TIMESTAMP WITH TIME ZONE;
    v_response_time INTEGER;
BEGIN
    -- Получение информации о контроллере
    SELECT * INTO v_controller
    FROM controllers.controllers
    WHERE id = p_controller_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Контроллер не найден: %', p_controller_id;
    END IF;
    
    v_start_time := CURRENT_TIMESTAMP;
    
    -- Здесь должна быть реальная проверка связи с контроллером
    -- Для примера используем простую проверку по времени последнего ответа
    IF v_controller.last_seen_at > CURRENT_TIMESTAMP - INTERVAL '1 minute' THEN
        is_online := TRUE;
        status_message := 'Контроллер в сети';
    ELSE
        is_online := FALSE;
        status_message := 'Контроллер не отвечает';
    END IF;
    
    last_seen := v_controller.last_seen_at;
    response_time_ms := EXTRACT(MILLISECOND FROM (CURRENT_TIMESTAMP - v_start_time));
    
    -- Обновление статуса в БД
    UPDATE controllers.controllers
    SET is_online = is_online,
        last_seen_at = CASE WHEN is_online THEN CURRENT_TIMESTAMP ELSE last_seen_at END
    WHERE id = p_controller_id;
    
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- ФУНКЦИИ ДЛЯ ГЕНЕРАЦИИ ОТЧЕТОВ
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Функция генерации отчета
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reports.generate_report(
    p_template_id UUID,
    p_parameters JSONB,
    p_user_id UUID
) RETURNS BIGINT AS $$
DECLARE
    v_report_id BIGINT;
    v_template RECORD;
    v_has_permission BOOLEAN;
BEGIN
    -- Проверка прав доступа
    v_has_permission := security.check_permission(p_user_id, 'reports', 'generate');
    
    IF NOT v_has_permission THEN
        RAISE EXCEPTION 'Недостаточно прав для генерации отчетов';
    END IF;
    
    -- Получение шаблона
    SELECT * INTO v_template
    FROM reports.report_templates
    WHERE id = p_template_id
    AND is_active = TRUE;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Шаблон отчета не найден или неактивен: %', p_template_id;
    END IF;
    
    -- Создание записи о генерации отчета
    INSERT INTO reports.report_history (
        template_id, requested_by, request_time,
        parameters, status
    ) VALUES (
        p_template_id, p_user_id, CURRENT_TIMESTAMP,
        p_parameters, 'pending'
    ) RETURNING id INTO v_report_id;
    
    -- Запуск асинхронной генерации отчета
    PERFORM pg_notify('generate_report', jsonb_build_object(
        'report_id', v_report_id,
        'template_id', p_template_id,
        'parameters', p_parameters,
        'user_id', p_user_id
    )::TEXT);
    
    RETURN v_report_id;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Функция для автоматического обновления updated_at
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- Функция для валидации JSON схемы
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.validate_json_schema(
    p_data JSONB,
    p_schema JSONB
) RETURNS BOOLEAN AS $$
BEGIN
    -- Здесь должна быть реальная валидация JSON Schema
    -- Для примера возвращаем TRUE
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ------------------------------------------------------------------------------
-- Функция получения иерархии параметров
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION tech_params.get_parameter_hierarchy(
    p_group_id UUID DEFAULT NULL
) RETURNS TABLE (
    id UUID,
    parent_id UUID,
    level INTEGER,
    path TEXT,
    code VARCHAR,
    name VARCHAR,
    parameters_count BIGINT
) AS $$
WITH RECURSIVE hierarchy AS (
    -- Базовый уровень
    SELECT
        g.id,
        g.parent_id,
        0 AS level,
        g.code::TEXT AS path,
        g.code,
        g.name
    FROM tech_params.parameter_groups g
    WHERE (p_group_id IS NULL AND g.parent_id IS NULL)
       OR (p_group_id IS NOT NULL AND g.id = p_group_id)
    
    UNION ALL
    
    -- Рекурсивная часть
    SELECT
        g.id,
        g.parent_id,
        h.level + 1,
        h.path || '/' || g.code,
        g.code,
        g.name
    FROM tech_params.parameter_groups g
    JOIN hierarchy h ON g.parent_id = h.id
)
SELECT
    h.*,
    COUNT(p.id) AS parameters_count
FROM hierarchy h
LEFT JOIN tech_params.parameters p ON p.group_id = h.id
GROUP BY h.id, h.parent_id, h.level, h.path, h.code, h.name
ORDER BY h.path;
$$ LANGUAGE sql STABLE;

-- ==============================================================================
-- ФУНКЦИИ ДЛЯ МОНИТОРИНГА ПРОИЗВОДИТЕЛЬНОСТИ
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Функция анализа производительности запросов
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION core.analyze_query_performance()
RETURNS TABLE (
    query_rank INTEGER,
    total_calls BIGINT,
    total_time NUMERIC,
    mean_time NUMERIC,
    max_time NUMERIC,
    query_text TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        ROW_NUMBER() OVER (ORDER BY total_exec_time DESC) AS query_rank,
        calls AS total_calls,
        ROUND(total_exec_time::NUMERIC, 2) AS total_time,
        ROUND(mean_exec_time::NUMERIC, 2) AS mean_time,
        ROUND(max_exec_time::NUMERIC, 2) AS max_time,
        LEFT(query, 100) AS query_text
    FROM pg_stat_statements
    WHERE userid = (SELECT usesysid FROM pg_user WHERE usename = CURRENT_USER)
    ORDER BY total_exec_time DESC
    LIMIT 20;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- СОЗДАНИЕ УВЕДОМЛЕНИЙ О СИСТЕМНЫХ СОБЫТИЯХ
-- ==============================================================================

-- Канал для новых тревог
NOTIFY new_alarm, 'Channel for new alarms';

-- Канал для изменения параметров
NOTIFY parameter_changed, 'Channel for parameter value changes';

-- Канал для системных событий
NOTIFY system_event, 'Channel for system events';

-- ==============================================================================
-- Вывод информации о созданных функциях
-- ==============================================================================

SELECT 'Функции созданы:' AS info;
SELECT 
    n.nspname AS schema_name,
    p.proname AS function_name,
    pg_get_function_result(p.oid) AS result_type,
    pg_get_function_arguments(p.oid) AS arguments
FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname IN ('core', 'tech_params', 'events', 'algorithms', 'archive', 'controllers', 'reports', 'security')
ORDER BY n.nspname, p.proname;



