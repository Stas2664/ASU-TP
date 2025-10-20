-- ==============================================================================
-- ИНИЦИАЛИЗАЦИЯ БД АСУ ТП НА RAILWAY
-- Все скрипты объединены в один файл для удобства
-- ==============================================================================

-- ==============================================================================
-- 1. СОЗДАНИЕ СХЕМ
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS tech_params;
CREATE SCHEMA IF NOT EXISTS controllers;
CREATE SCHEMA IF NOT EXISTS archive;
CREATE SCHEMA IF NOT EXISTS algorithms;
CREATE SCHEMA IF NOT EXISTS visualization;
CREATE SCHEMA IF NOT EXISTS topology;
CREATE SCHEMA IF NOT EXISTS kross;
CREATE SCHEMA IF NOT EXISTS security;
CREATE SCHEMA IF NOT EXISTS events;
CREATE SCHEMA IF NOT EXISTS reports;

-- ==============================================================================
-- 2. СОЗДАНИЕ РАСШИРЕНИЙ
-- ==============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 3. ОСНОВНЫЕ ТАБЛИЦЫ (упрощенная версия для демо)
-- ==============================================================================

-- Единицы измерения
CREATE TABLE IF NOT EXISTS core.units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    symbol VARCHAR(50)
);

-- Группы параметров
CREATE TABLE IF NOT EXISTS tech_params.parameter_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id UUID REFERENCES tech_params.parameter_groups(id),
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    sort_order INTEGER DEFAULT 0
);

-- Параметры
CREATE TABLE IF NOT EXISTS tech_params.parameters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID REFERENCES tech_params.parameter_groups(id),
    tag VARCHAR(255) NOT NULL UNIQUE,
    name VARCHAR(500) NOT NULL,
    parameter_type VARCHAR(50) NOT NULL,
    unit_id UUID REFERENCES core.units(id),
    min_value DECIMAL(20,10),
    max_value DECIMAL(20,10),
    nominal_value DECIMAL(20,10),
    alarm_low DECIMAL(20,10),
    alarm_high DECIMAL(20,10),
    is_archived BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Текущие значения
CREATE TABLE IF NOT EXISTS tech_params.current_values (
    parameter_id UUID PRIMARY KEY REFERENCES tech_params.parameters(id),
    value TEXT NOT NULL,
    quality INTEGER DEFAULT 192,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Исторические данные
CREATE TABLE IF NOT EXISTS archive.historical_data (
    id BIGSERIAL PRIMARY KEY,
    parameter_id UUID NOT NULL REFERENCES tech_params.parameters(id),
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    value TEXT NOT NULL,
    quality INTEGER DEFAULT 192
);

-- Роли
CREATE TABLE IF NOT EXISTS security.roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    priority INTEGER DEFAULT 100,
    is_active BOOLEAN DEFAULT true
);

-- Пользователи
CREATE TABLE IF NOT EXISTS security.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255) UNIQUE,
    password_hash TEXT NOT NULL,
    full_name VARCHAR(500),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- События
CREATE TABLE IF NOT EXISTS events.events (
    id BIGSERIAL PRIMARY KEY,
    source_type VARCHAR(100) NOT NULL,
    source_id UUID,
    event_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    event_type VARCHAR(100) NOT NULL,
    message TEXT NOT NULL,
    is_active BOOLEAN DEFAULT true,
    is_acknowledged BOOLEAN DEFAULT false
);

-- ==============================================================================
-- 4. НАЧАЛЬНЫЕ ДАННЫЕ
-- ==============================================================================

-- Единицы измерения
INSERT INTO core.units (code, name, symbol) VALUES
    ('CELSIUS', 'Градус Цельсия', '°C'),
    ('MPA', 'Мегапаскаль', 'МПа'),
    ('MW', 'Мегаватт', 'МВт'),
    ('PERCENT', 'Процент', '%'),
    ('M3_H', 'Кубометр в час', 'м³/ч'),
    ('RPM', 'Оборотов в минуту', 'об/мин')
ON CONFLICT (code) DO NOTHING;

-- Группы параметров
INSERT INTO tech_params.parameter_groups (code, name) VALUES
    ('REACTOR', 'Реактор'),
    ('TURBINE', 'Турбина'),
    ('GENERATOR', 'Генератор')
ON CONFLICT (code) DO NOTHING;

-- Параметры реактора
INSERT INTO tech_params.parameters (tag, name, parameter_type, group_id, unit_id, min_value, max_value, nominal_value)
SELECT 
    'REACTOR.POWER', 
    'Мощность реактора',
    'analog',
    (SELECT id FROM tech_params.parameter_groups WHERE code = 'REACTOR'),
    (SELECT id FROM core.units WHERE code = 'MW'),
    0, 3200, 3000
WHERE NOT EXISTS (SELECT 1 FROM tech_params.parameters WHERE tag = 'REACTOR.POWER');

INSERT INTO tech_params.parameters (tag, name, parameter_type, group_id, unit_id, min_value, max_value, nominal_value)
SELECT 
    'REACTOR.TEMP', 
    'Температура активной зоны',
    'analog',
    (SELECT id FROM tech_params.parameter_groups WHERE code = 'REACTOR'),
    (SELECT id FROM core.units WHERE code = 'CELSIUS'),
    0, 400, 320
WHERE NOT EXISTS (SELECT 1 FROM tech_params.parameters WHERE tag = 'REACTOR.TEMP');

-- Параметры турбины
INSERT INTO tech_params.parameters (tag, name, parameter_type, group_id, unit_id, min_value, max_value, nominal_value)
SELECT 
    'TURBINE.SPEED', 
    'Частота вращения турбины',
    'analog',
    (SELECT id FROM tech_params.parameter_groups WHERE code = 'TURBINE'),
    (SELECT id FROM core.units WHERE code = 'RPM'),
    0, 3600, 3000
WHERE NOT EXISTS (SELECT 1 FROM tech_params.parameters WHERE tag = 'TURBINE.SPEED');

-- Параметры генератора
INSERT INTO tech_params.parameters (tag, name, parameter_type, group_id, unit_id, min_value, max_value, nominal_value)
SELECT 
    'GENERATOR.POWER', 
    'Мощность генератора',
    'analog',
    (SELECT id FROM tech_params.parameter_groups WHERE code = 'GENERATOR'),
    (SELECT id FROM core.units WHERE code = 'MW'),
    0, 1200, 1000
WHERE NOT EXISTS (SELECT 1 FROM tech_params.parameters WHERE tag = 'GENERATOR.POWER');

-- Текущие значения
INSERT INTO tech_params.current_values (parameter_id, value)
SELECT id, (nominal_value + (random() - 0.5) * 100)::TEXT
FROM tech_params.parameters
ON CONFLICT (parameter_id) DO UPDATE 
SET value = EXCLUDED.value,
    timestamp = CURRENT_TIMESTAMP;

-- Роли по умолчанию
INSERT INTO security.roles (code, name, priority) VALUES
    ('admin', 'Администратор', 1000),
    ('engineer', 'Инженер', 800),
    ('operator', 'Оператор', 400),
    ('viewer', 'Наблюдатель', 200)
ON CONFLICT (code) DO NOTHING;

-- Пользователь по умолчанию (пароль: admin)
INSERT INTO security.users (username, email, password_hash, full_name)
VALUES (
    'admin',
    'admin@asu-tp.local',
    crypt('admin', gen_salt('bf')),
    'Администратор системы'
) ON CONFLICT (username) DO NOTHING;

-- ==============================================================================
-- 5. СОЗДАНИЕ ПРЕДСТАВЛЕНИЙ ДЛЯ УДОБСТВА
-- ==============================================================================

CREATE OR REPLACE VIEW tech_params.parameters_view AS
SELECT 
    p.tag,
    p.name,
    cv.value,
    u.symbol as unit,
    cv.timestamp,
    CASE 
        WHEN cv.quality >= 192 THEN 'Good'
        WHEN cv.quality >= 64 THEN 'Uncertain'
        ELSE 'Bad'
    END as quality_text
FROM tech_params.parameters p
LEFT JOIN tech_params.current_values cv ON p.id = cv.parameter_id
LEFT JOIN core.units u ON p.unit_id = u.id
WHERE p.is_active = true;

-- ==============================================================================
-- 6. ФУНКЦИЯ ДЛЯ ТЕСТИРОВАНИЯ
-- ==============================================================================

CREATE OR REPLACE FUNCTION test_database() 
RETURNS TABLE(
    test_name TEXT,
    result TEXT
) AS $$
BEGIN
    RETURN QUERY SELECT 'Schemas created', 
        (SELECT COUNT(*)::TEXT FROM information_schema.schemata 
         WHERE schema_name IN ('core','tech_params','security'));
    
    RETURN QUERY SELECT 'Tables created', 
        (SELECT COUNT(*)::TEXT FROM information_schema.tables 
         WHERE table_schema IN ('core','tech_params','security'));
    
    RETURN QUERY SELECT 'Parameters loaded', 
        (SELECT COUNT(*)::TEXT FROM tech_params.parameters);
    
    RETURN QUERY SELECT 'Current values', 
        (SELECT COUNT(*)::TEXT FROM tech_params.current_values);
    
    RETURN QUERY SELECT 'Users created', 
        (SELECT COUNT(*)::TEXT FROM security.users);
END;
$$ LANGUAGE plpgsql;

-- Запуск теста
SELECT * FROM test_database();

-- Показать параметры
SELECT * FROM tech_params.parameters_view;


