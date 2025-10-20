-- ==============================================================================
-- ПОЛНАЯ СХЕМА БД АСУ ТП ДЛЯ RAILWAY
-- Все компоненты в одном файле для удобной загрузки
-- ==============================================================================

-- ==============================================================================
-- ЧАСТЬ 1: СОЗДАНИЕ СХЕМ
-- ==============================================================================

DROP SCHEMA IF EXISTS core CASCADE;
DROP SCHEMA IF EXISTS tech_params CASCADE;
DROP SCHEMA IF EXISTS controllers CASCADE;
DROP SCHEMA IF EXISTS archive CASCADE;
DROP SCHEMA IF EXISTS algorithms CASCADE;
DROP SCHEMA IF EXISTS visualization CASCADE;
DROP SCHEMA IF EXISTS topology CASCADE;
DROP SCHEMA IF EXISTS kross CASCADE;
DROP SCHEMA IF EXISTS security CASCADE;
DROP SCHEMA IF EXISTS events CASCADE;
DROP SCHEMA IF EXISTS reports CASCADE;

CREATE SCHEMA core;
CREATE SCHEMA tech_params;
CREATE SCHEMA controllers;
CREATE SCHEMA archive;
CREATE SCHEMA algorithms;
CREATE SCHEMA visualization;
CREATE SCHEMA topology;
CREATE SCHEMA kross;
CREATE SCHEMA security;
CREATE SCHEMA events;
CREATE SCHEMA reports;

-- ==============================================================================
-- ЧАСТЬ 2: РАСШИРЕНИЯ
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- ЧАСТЬ 3: ОСНОВНЫЕ ТАБЛИЦЫ
-- ==============================================================================

-- CORE: Единицы измерения
CREATE TABLE core.units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    symbol VARCHAR(50),
    unit_type VARCHAR(100)
);

-- CORE: Статусы
CREATE TABLE core.statuses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    status_group VARCHAR(100),
    color_code VARCHAR(7),
    priority INTEGER DEFAULT 0
);

-- TECH_PARAMS: Группы параметров
CREATE TABLE tech_params.parameter_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id UUID REFERENCES tech_params.parameter_groups(id),
    code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true
);

-- TECH_PARAMS: Параметры (ОБНОВЛЯЕМ существующую таблицу)
DROP TABLE IF EXISTS public.parameters CASCADE;

CREATE TABLE tech_params.parameters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID REFERENCES tech_params.parameter_groups(id),
    tag VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(500) NOT NULL,
    parameter_type VARCHAR(50) DEFAULT 'analog',
    unit_id UUID REFERENCES core.units(id),
    min_value DECIMAL(20,10),
    max_value DECIMAL(20,10),
    nominal_value DECIMAL(20,10),
    alarm_low_low DECIMAL(20,10),
    alarm_low DECIMAL(20,10),
    alarm_high DECIMAL(20,10),
    alarm_high_high DECIMAL(20,10),
    is_archived BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- TECH_PARAMS: Текущие значения
CREATE TABLE tech_params.current_values (
    parameter_id UUID PRIMARY KEY REFERENCES tech_params.parameters(id),
    value TEXT NOT NULL,
    quality INTEGER DEFAULT 192,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    source VARCHAR(100),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- CONTROLLERS: Типы контроллеров
CREATE TABLE controllers.controller_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    manufacturer VARCHAR(255),
    model VARCHAR(255),
    communication_protocol VARCHAR(100)
);

-- CONTROLLERS: Контроллеры
CREATE TABLE controllers.controllers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    controller_type_id UUID REFERENCES controllers.controller_types(id),
    name VARCHAR(255) NOT NULL,
    ip_address INET,
    location VARCHAR(500),
    status_id UUID REFERENCES core.statuses(id),
    is_online BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ARCHIVE: Исторические данные
CREATE TABLE archive.historical_data (
    id BIGSERIAL PRIMARY KEY,
    parameter_id UUID NOT NULL REFERENCES tech_params.parameters(id),
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    value TEXT NOT NULL,
    quality INTEGER DEFAULT 192
);

-- ALGORITHMS: Алгоритмы
CREATE TABLE algorithms.algorithms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    language VARCHAR(50) DEFAULT 'sql',
    source_code TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- SECURITY: Роли
CREATE TABLE security.roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    priority INTEGER DEFAULT 100,
    is_system BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true
);

-- SECURITY: Пользователи
CREATE TABLE security.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE,
    password_hash TEXT NOT NULL,
    full_name VARCHAR(500),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- SECURITY: Связь пользователей и ролей
CREATE TABLE security.user_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES security.users(id) ON DELETE CASCADE,
    role_id UUID REFERENCES security.roles(id) ON DELETE CASCADE,
    UNIQUE(user_id, role_id)
);

-- EVENTS: Классы событий
CREATE TABLE events.event_classes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    severity VARCHAR(50),
    color VARCHAR(7),
    requires_acknowledgment BOOLEAN DEFAULT false
);

-- EVENTS: События
CREATE TABLE events.events (
    id BIGSERIAL PRIMARY KEY,
    event_class_id UUID REFERENCES events.event_classes(id),
    source_type VARCHAR(100) NOT NULL,
    source_id UUID,
    event_time TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    message TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    is_acknowledged BOOLEAN DEFAULT false
);

-- VISUALIZATION: Экраны
CREATE TABLE visualization.screens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    screen_type VARCHAR(50),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- TOPOLOGY: Узлы
CREATE TABLE topology.nodes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    ip_address INET,
    is_online BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- KROSS: Конфигурация платформы
CREATE TABLE kross.platform_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parameter_name VARCHAR(255) UNIQUE NOT NULL,
    parameter_value TEXT NOT NULL,
    parameter_type VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- REPORTS: Шаблоны отчетов
CREATE TABLE reports.report_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    report_type VARCHAR(50),
    is_active BOOLEAN DEFAULT true
);

-- ==============================================================================
-- ЧАСТЬ 4: ЗАГРУЗКА ДАННЫХ
-- ==============================================================================

-- Единицы измерения
INSERT INTO core.units (code, name, symbol, unit_type) VALUES
('CELSIUS', 'Градус Цельсия', '°C', 'temperature'),
('MPA', 'Мегапаскаль', 'МПа', 'pressure'),
('MW', 'Мегаватт', 'МВт', 'power'),
('KW', 'Киловатт', 'кВт', 'power'),
('PERCENT', 'Процент', '%', 'dimensionless'),
('M3_H', 'Кубометр в час', 'м³/ч', 'flow'),
('T_H', 'Тонна в час', 'т/ч', 'flow'),
('RPM', 'Оборотов в минуту', 'об/мин', 'frequency'),
('MM', 'Миллиметр', 'мм', 'length'),
('KV', 'Киловольт', 'кВ', 'voltage')
ON CONFLICT (code) DO NOTHING;

-- Статусы
INSERT INTO core.statuses (code, name, status_group, color_code, priority) VALUES
('ONLINE', 'В сети', 'operational', '#00FF00', 100),
('OFFLINE', 'Не в сети', 'operational', '#808080', 90),
('RUNNING', 'Работает', 'operational', '#00FF00', 100),
('STOPPED', 'Остановлен', 'operational', '#FF0000', 80),
('NORMAL', 'Норма', 'alarm', '#00FF00', 100),
('WARNING', 'Предупреждение', 'alarm', '#FFFF00', 70),
('ALARM', 'Авария', 'alarm', '#FF0000', 50),
('CRITICAL', 'Критическая авария', 'alarm', '#FF00FF', 30)
ON CONFLICT (code) DO NOTHING;

-- Группы параметров
INSERT INTO tech_params.parameter_groups (code, name, sort_order) VALUES
('REACTOR', 'Реактор', 100),
('TURBINE', 'Турбина', 200),
('GENERATOR', 'Генератор', 300),
('COOLING', 'Системы охлаждения', 400),
('AUXILIARY', 'Вспомогательные системы', 500)
ON CONFLICT (code) DO NOTHING;

-- Мигрируем существующие параметры в новую структуру
INSERT INTO tech_params.parameters (tag, name, nominal_value, unit_id, group_id, min_value, max_value)
SELECT 
    p.tag,
    p.name,
    p.value,
    u.id,
    pg.id,
    0,
    CASE 
        WHEN p.tag = 'REACTOR.POWER' THEN 3200
        WHEN p.tag = 'REACTOR.TEMP' THEN 400
        WHEN p.tag = 'TURBINE.SPEED' THEN 3600
        WHEN p.tag = 'GENERATOR.POWER' THEN 1200
    END
FROM public.parameters p
LEFT JOIN core.units u ON u.symbol = p.unit
LEFT JOIN tech_params.parameter_groups pg ON pg.code = SPLIT_PART(p.tag, '.', 1)
ON CONFLICT (tag) DO NOTHING;

-- Дополнительные параметры АСУ ТП
INSERT INTO tech_params.parameters (tag, name, parameter_type, nominal_value, min_value, max_value, unit_id, group_id, alarm_low, alarm_high)
SELECT 
    'REACTOR.PRESSURE', 
    'Давление в первом контуре', 
    'analog',
    16.2, 0, 20,
    (SELECT id FROM core.units WHERE code = 'MPA'),
    (SELECT id FROM tech_params.parameter_groups WHERE code = 'REACTOR'),
    14, 17.5
WHERE NOT EXISTS (SELECT 1 FROM tech_params.parameters WHERE tag = 'REACTOR.PRESSURE');

INSERT INTO tech_params.parameters (tag, name, parameter_type, nominal_value, min_value, max_value, unit_id, group_id)
SELECT 
    'TURBINE.VIBRATION', 
    'Вибрация турбины', 
    'analog',
    30, 0, 100,
    (SELECT id FROM core.units WHERE code = 'MM'),
    (SELECT id FROM tech_params.parameter_groups WHERE code = 'TURBINE')
WHERE NOT EXISTS (SELECT 1 FROM tech_params.parameters WHERE tag = 'TURBINE.VIBRATION');

INSERT INTO tech_params.parameters (tag, name, parameter_type, nominal_value, min_value, max_value, unit_id, group_id)
SELECT 
    'GENERATOR.VOLTAGE', 
    'Напряжение генератора', 
    'analog',
    20, 0, 25,
    (SELECT id FROM core.units WHERE code = 'KV'),
    (SELECT id FROM tech_params.parameter_groups WHERE code = 'GENERATOR')
WHERE NOT EXISTS (SELECT 1 FROM tech_params.parameters WHERE tag = 'GENERATOR.VOLTAGE');

-- Текущие значения для всех параметров
INSERT INTO tech_params.current_values (parameter_id, value, quality)
SELECT 
    id,
    (nominal_value + (random() - 0.5) * 10)::TEXT,
    192
FROM tech_params.parameters
ON CONFLICT (parameter_id) DO UPDATE
SET value = EXCLUDED.value,
    timestamp = CURRENT_TIMESTAMP;

-- Типы контроллеров
INSERT INTO controllers.controller_types (code, name, manufacturer, model, communication_protocol) VALUES
('KUPRI_V3', 'КУПРИ версия 3', 'НПП ВНИИЭМ', 'КУПРИ-3', 'Modbus TCP'),
('SIEMENS_S7', 'Siemens S7-1500', 'Siemens', 'S7-1500', 'Profinet')
ON CONFLICT (code) DO NOTHING;

-- Контроллеры
INSERT INTO controllers.controllers (name, controller_type_id, ip_address, location, is_online, status_id)
VALUES
('Контроллер реактора №1', 
 (SELECT id FROM controllers.controller_types WHERE code = 'KUPRI_V3'),
 '192.168.1.101',
 'Щит управления реактора',
 true,
 (SELECT id FROM core.statuses WHERE code = 'ONLINE')),
('Контроллер турбины №1',
 (SELECT id FROM controllers.controller_types WHERE code = 'SIEMENS_S7'),
 '192.168.1.201', 
 'Машинный зал',
 true,
 (SELECT id FROM core.statuses WHERE code = 'ONLINE'));

-- Роли
INSERT INTO security.roles (code, name, priority, is_system) VALUES
('admin', 'Администратор', 1000, true),
('engineer', 'Инженер АСУ ТП', 800, true),
('operator', 'Оператор', 400, true),
('viewer', 'Наблюдатель', 200, true)
ON CONFLICT (code) DO NOTHING;

-- Пользователи
INSERT INTO security.users (username, email, password_hash, full_name)
VALUES 
('admin', 'admin@asu-tp.local', crypt('admin', gen_salt('bf')), 'Администратор системы'),
('engineer', 'engineer@asu-tp.local', crypt('Test123', gen_salt('bf')), 'Иванов И.И.'),
('operator', 'operator@asu-tp.local', crypt('Test123', gen_salt('bf')), 'Петров П.П.')
ON CONFLICT (username) DO NOTHING;

-- Связь пользователей и ролей
INSERT INTO security.user_roles (user_id, role_id)
SELECT u.id, r.id FROM security.users u, security.roles r
WHERE u.username = 'admin' AND r.code = 'admin'
ON CONFLICT DO NOTHING;

-- Классы событий
INSERT INTO events.event_classes (code, name, severity, color, requires_acknowledgment) VALUES
('INFO', 'Информационное', 'info', '#0000FF', false),
('WARNING_ALARM', 'Предупредительная сигнализация', 'warning', '#FFFF00', true),
('CRITICAL_ALARM', 'Аварийная сигнализация', 'critical', '#FF0000', true)
ON CONFLICT (code) DO NOTHING;

-- Конфигурация КРОСС
INSERT INTO kross.platform_config (parameter_name, parameter_value, parameter_type) VALUES
('system.name', 'ПТК АСУ ТП Энергоблок №1', 'string'),
('system.version', '1.0.0', 'string'),
('archive.retention.days', '365', 'integer')
ON CONFLICT (parameter_name) DO NOTHING;

-- ==============================================================================
-- ЧАСТЬ 5: СОЗДАНИЕ ФУНКЦИЙ
-- ==============================================================================

-- Функция записи значения параметра
CREATE OR REPLACE FUNCTION tech_params.write_parameter_value(
    p_tag VARCHAR,
    p_value TEXT
) RETURNS BOOLEAN AS $$
DECLARE
    v_param_id UUID;
BEGIN
    SELECT id INTO v_param_id FROM tech_params.parameters WHERE tag = p_tag;
    
    IF v_param_id IS NULL THEN
        RETURN FALSE;
    END IF;
    
    INSERT INTO tech_params.current_values (parameter_id, value, timestamp)
    VALUES (v_param_id, p_value, CURRENT_TIMESTAMP)
    ON CONFLICT (parameter_id) DO UPDATE
    SET value = EXCLUDED.value,
        timestamp = EXCLUDED.timestamp,
        updated_at = EXCLUDED.timestamp;
    
    -- Архивирование
    INSERT INTO archive.historical_data (parameter_id, timestamp, value)
    VALUES (v_param_id, CURRENT_TIMESTAMP, p_value);
    
    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- Функция чтения всех параметров
CREATE OR REPLACE FUNCTION tech_params.get_all_parameters()
RETURNS TABLE (
    tag VARCHAR,
    name VARCHAR,
    value TEXT,
    unit VARCHAR,
    group_name VARCHAR,
    timestamp TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.tag,
        p.name,
        cv.value,
        u.symbol,
        pg.name,
        cv.timestamp
    FROM tech_params.parameters p
    LEFT JOIN tech_params.current_values cv ON p.id = cv.parameter_id
    LEFT JOIN core.units u ON p.unit_id = u.id
    LEFT JOIN tech_params.parameter_groups pg ON p.group_id = pg.id
    WHERE p.is_active = true
    ORDER BY pg.sort_order, p.tag;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- ЧАСТЬ 6: СОЗДАНИЕ ПРЕДСТАВЛЕНИЙ
-- ==============================================================================

-- Представление для мониторинга
CREATE OR REPLACE VIEW tech_params.monitoring_view AS
SELECT 
    pg.name as group_name,
    p.tag,
    p.name as parameter_name,
    cv.value,
    u.symbol as unit,
    CASE 
        WHEN p.alarm_low IS NOT NULL AND cv.value::NUMERIC < p.alarm_low THEN 'LOW_ALARM'
        WHEN p.alarm_high IS NOT NULL AND cv.value::NUMERIC > p.alarm_high THEN 'HIGH_ALARM'
        ELSE 'NORMAL'
    END as alarm_status,
    cv.timestamp as last_update,
    cv.quality
FROM tech_params.parameters p
LEFT JOIN tech_params.current_values cv ON p.id = cv.parameter_id
LEFT JOIN core.units u ON p.unit_id = u.id
LEFT JOIN tech_params.parameter_groups pg ON p.group_id = pg.id
WHERE p.is_active = true;

-- ==============================================================================
-- ФИНАЛЬНАЯ ПРОВЕРКА
-- ==============================================================================

DO $$
BEGIN
    RAISE NOTICE '=======================================================';
    RAISE NOTICE 'БД АСУ ТП УСПЕШНО СОЗДАНА!';
    RAISE NOTICE '=======================================================';
    RAISE NOTICE 'Схем создано: %', (SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name IN ('core','tech_params','controllers','archive','algorithms','visualization','topology','kross','security','events','reports'));
    RAISE NOTICE 'Таблиц создано: %', (SELECT COUNT(*) FROM information_schema.tables WHERE table_schema IN ('core','tech_params','controllers','archive','algorithms','visualization','topology','kross','security','events','reports'));
    RAISE NOTICE 'Параметров загружено: %', (SELECT COUNT(*) FROM tech_params.parameters);
    RAISE NOTICE 'Пользователей создано: %', (SELECT COUNT(*) FROM security.users);
    RAISE NOTICE '=======================================================';
END $$;

-- Показать итоговую статистику
SELECT 
    'ПОЛНАЯ БД АСУ ТП ЗАГРУЖЕНА В RAILWAY!' as status,
    (SELECT COUNT(*) FROM tech_params.parameters) as parameters,
    (SELECT COUNT(*) FROM security.users) as users,
    (SELECT COUNT(*) FROM controllers.controllers) as controllers;


