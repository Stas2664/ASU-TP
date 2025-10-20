-- ==============================================================================
-- Создание таблиц для ПТК АСУ ТП
-- База данных: asu_tp_db
-- Соответствие требованиям ТЗ и ГОСТ Р ИСО 9001-2015
-- ==============================================================================

\c asu_tp_db;

-- ==============================================================================
-- CORE SCHEMA - Основные системные таблицы
-- ==============================================================================

-- Таблица единиц измерения
CREATE TABLE IF NOT EXISTS core.units (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    symbol VARCHAR(50),
    description TEXT,
    unit_type VARCHAR(100), -- температура, давление, расход и т.д.
    conversion_factor DECIMAL(20,10) DEFAULT 1.0,
    base_unit_id UUID REFERENCES core.units(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Таблица типов данных
CREATE TABLE IF NOT EXISTS core.data_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    postgres_type VARCHAR(100) NOT NULL,
    min_value DECIMAL(20,10),
    max_value DECIMAL(20,10),
    precision INTEGER,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Справочник статусов
CREATE TABLE IF NOT EXISTS core.statuses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(50) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    status_group VARCHAR(100), -- operational, alarm, maintenance
    color_code VARCHAR(7), -- HEX color
    priority INTEGER DEFAULT 0,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================================================
-- TECH_PARAMS SCHEMA - Технологические параметры
-- ==============================================================================

-- Группы параметров
CREATE TABLE IF NOT EXISTS tech_params.parameter_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id UUID REFERENCES tech_params.parameter_groups(id),
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Основная таблица технологических параметров
CREATE TABLE IF NOT EXISTS tech_params.parameters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    group_id UUID REFERENCES tech_params.parameter_groups(id),
    tag VARCHAR(255) NOT NULL UNIQUE, -- Уникальный тег параметра
    name VARCHAR(500) NOT NULL,
    short_name VARCHAR(100),
    description TEXT,
    parameter_type VARCHAR(50) NOT NULL CHECK (parameter_type IN ('analog', 'discrete', 'string', 'calculated')),
    data_type_id UUID REFERENCES core.data_types(id),
    unit_id UUID REFERENCES core.units(id),
    
    -- Границы для аналоговых параметров
    min_value DECIMAL(20,10),
    max_value DECIMAL(20,10),
    nominal_value DECIMAL(20,10),
    
    -- Уставки тревог
    alarm_low_low DECIMAL(20,10),
    alarm_low DECIMAL(20,10),
    alarm_high DECIMAL(20,10),
    alarm_high_high DECIMAL(20,10),
    
    -- Настройки архивирования
    is_archived BOOLEAN DEFAULT false,
    archive_interval_sec INTEGER DEFAULT 60,
    archive_deadband DECIMAL(20,10), -- Зона нечувствительности для архивирования
    
    -- Настройки обработки
    scan_interval_ms INTEGER DEFAULT 1000,
    filter_type VARCHAR(50), -- none, average, median
    filter_window_size INTEGER DEFAULT 1,
    
    -- Источник данных
    source_type VARCHAR(50) CHECK (source_type IN ('controller', 'calculated', 'manual', 'external')),
    source_address TEXT, -- Адрес в контроллере или формула
    
    -- Состояние
    is_active BOOLEAN DEFAULT true,
    is_simulated BOOLEAN DEFAULT false,
    simulation_value TEXT,
    
    -- Метаданные
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID,
    updated_by UUID
);

-- Диагностические параметры
CREATE TABLE IF NOT EXISTS tech_params.diagnostic_parameters (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parameter_id UUID REFERENCES tech_params.parameters(id),
    diagnostic_type VARCHAR(100) NOT NULL, -- sensor_failure, communication_error, range_error
    condition_expression TEXT, -- Условие диагностики
    message_template TEXT,
    severity VARCHAR(50) CHECK (severity IN ('info', 'warning', 'error', 'critical')),
    auto_acknowledge BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Текущие значения параметров
CREATE TABLE IF NOT EXISTS tech_params.current_values (
    parameter_id UUID PRIMARY KEY REFERENCES tech_params.parameters(id),
    value TEXT NOT NULL,
    quality INTEGER DEFAULT 192, -- OPC quality code
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    source VARCHAR(100),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================================================
-- CONTROLLERS SCHEMA - Контроллеры КУПРИ и оборудование
-- ==============================================================================

-- Типы контроллеров
CREATE TABLE IF NOT EXISTS controllers.controller_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    manufacturer VARCHAR(255),
    model VARCHAR(255),
    description TEXT,
    communication_protocol VARCHAR(100), -- Modbus, OPC, IEC-61850
    configuration_schema JSONB, -- JSON схема конфигурации
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Контроллеры КУПРИ
CREATE TABLE IF NOT EXISTS controllers.controllers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    controller_type_id UUID REFERENCES controllers.controller_types(id),
    node_id UUID, -- Ссылка на узел в топологии
    inventory_number VARCHAR(100) UNIQUE,
    serial_number VARCHAR(100),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    location VARCHAR(500),
    
    -- Сетевые настройки
    ip_address INET,
    mac_address MACADDR,
    port INTEGER,
    subnet_mask INET,
    gateway INET,
    dns_primary INET,
    dns_secondary INET,
    
    -- Конфигурация
    configuration JSONB, -- Специфичная конфигурация контроллера
    firmware_version VARCHAR(50),
    hardware_version VARCHAR(50),
    
    -- Состояние
    status_id UUID REFERENCES core.statuses(id),
    is_online BOOLEAN DEFAULT false,
    last_seen_at TIMESTAMP WITH TIME ZONE,
    
    -- Резервирование
    is_primary BOOLEAN DEFAULT true,
    redundant_controller_id UUID REFERENCES controllers.controllers(id),
    
    -- Метаданные
    commissioned_at DATE,
    decommissioned_at DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Модули контроллеров
CREATE TABLE IF NOT EXISTS controllers.controller_modules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    controller_id UUID REFERENCES controllers.controllers(id) ON DELETE CASCADE,
    slot_number INTEGER NOT NULL,
    module_type VARCHAR(100) NOT NULL, -- DI, DO, AI, AO
    model VARCHAR(255),
    serial_number VARCHAR(100),
    channels_count INTEGER NOT NULL,
    configuration JSONB,
    status_id UUID REFERENCES core.statuses(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(controller_id, slot_number)
);

-- Каналы ввода-вывода
CREATE TABLE IF NOT EXISTS controllers.io_channels (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    module_id UUID REFERENCES controllers.controller_modules(id) ON DELETE CASCADE,
    channel_number INTEGER NOT NULL,
    parameter_id UUID REFERENCES tech_params.parameters(id),
    channel_type VARCHAR(50) NOT NULL, -- input, output
    signal_type VARCHAR(50), -- 4-20mA, 0-10V, discrete
    
    -- Калибровка для аналоговых сигналов
    raw_min DECIMAL(20,10),
    raw_max DECIMAL(20,10),
    scaled_min DECIMAL(20,10),
    scaled_max DECIMAL(20,10),
    
    -- Настройки
    is_inverted BOOLEAN DEFAULT false,
    debounce_time_ms INTEGER DEFAULT 0,
    
    status_id UUID REFERENCES core.statuses(id),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(module_id, channel_number)
);

-- ==============================================================================
-- ARCHIVE SCHEMA - Архивирование данных
-- ==============================================================================

-- Конфигурация архивирования
CREATE TABLE IF NOT EXISTS archive.archive_configs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parameter_id UUID REFERENCES tech_params.parameters(id) UNIQUE,
    archive_type VARCHAR(50) NOT NULL CHECK (archive_type IN ('periodic', 'on_change', 'both')),
    interval_seconds INTEGER DEFAULT 60,
    deadband_value DECIMAL(20,10), -- Для архивирования по изменению
    retention_days INTEGER DEFAULT 365,
    compression_enabled BOOLEAN DEFAULT true,
    compression_algorithm VARCHAR(50), -- average, min_max, last_value
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Архивные данные (партиционированная таблица)
CREATE TABLE IF NOT EXISTS archive.historical_data (
    id BIGSERIAL,
    parameter_id UUID NOT NULL,
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    value TEXT NOT NULL,
    quality INTEGER DEFAULT 192,
    PRIMARY KEY (parameter_id, timestamp)
) PARTITION BY RANGE (timestamp);

-- Создание партиций для архивных данных (пример для текущего года)
CREATE TABLE IF NOT EXISTS archive.historical_data_2025_q1 
    PARTITION OF archive.historical_data
    FOR VALUES FROM ('2025-01-01') TO ('2025-04-01');

CREATE TABLE IF NOT EXISTS archive.historical_data_2025_q2 
    PARTITION OF archive.historical_data
    FOR VALUES FROM ('2025-04-01') TO ('2025-07-01');

CREATE TABLE IF NOT EXISTS archive.historical_data_2025_q3 
    PARTITION OF archive.historical_data
    FOR VALUES FROM ('2025-07-01') TO ('2025-10-01');

CREATE TABLE IF NOT EXISTS archive.historical_data_2025_q4 
    PARTITION OF archive.historical_data
    FOR VALUES FROM ('2025-10-01') TO ('2026-01-01');

-- Сжатые архивы (долгосрочное хранение)
CREATE TABLE IF NOT EXISTS archive.compressed_data (
    id BIGSERIAL PRIMARY KEY,
    parameter_id UUID NOT NULL REFERENCES tech_params.parameters(id),
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    samples_count INTEGER NOT NULL,
    min_value DECIMAL(20,10),
    max_value DECIMAL(20,10),
    avg_value DECIMAL(20,10),
    std_deviation DECIMAL(20,10),
    raw_data BYTEA, -- Сжатые данные
    compression_method VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================================================
-- ALGORITHMS SCHEMA - Расчетные алгоритмы
-- ==============================================================================

-- Типы алгоритмов
CREATE TABLE IF NOT EXISTS algorithms.algorithm_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Расчетные алгоритмы
CREATE TABLE IF NOT EXISTS algorithms.algorithms (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type_id UUID REFERENCES algorithms.algorithm_types(id),
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Определение алгоритма
    language VARCHAR(50) NOT NULL CHECK (language IN ('sql', 'python', 'javascript', 'lua')),
    source_code TEXT NOT NULL,
    compiled_code BYTEA, -- Для скомпилированных алгоритмов
    
    -- Параметры выполнения
    execution_interval_ms INTEGER DEFAULT 1000,
    timeout_ms INTEGER DEFAULT 5000,
    priority INTEGER DEFAULT 5,
    
    -- Состояние
    is_active BOOLEAN DEFAULT true,
    is_validated BOOLEAN DEFAULT false,
    last_execution_time TIMESTAMP WITH TIME ZONE,
    last_execution_status VARCHAR(50),
    execution_count BIGINT DEFAULT 0,
    error_count BIGINT DEFAULT 0,
    
    -- Версионирование
    version VARCHAR(20) DEFAULT '1.0.0',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID,
    approved_by UUID,
    approved_at TIMESTAMP WITH TIME ZONE
);

-- Входные параметры алгоритмов
CREATE TABLE IF NOT EXISTS algorithms.algorithm_inputs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    algorithm_id UUID REFERENCES algorithms.algorithms(id) ON DELETE CASCADE,
    parameter_id UUID REFERENCES tech_params.parameters(id),
    variable_name VARCHAR(100) NOT NULL,
    is_required BOOLEAN DEFAULT true,
    default_value TEXT,
    description TEXT,
    sort_order INTEGER DEFAULT 0,
    UNIQUE(algorithm_id, variable_name)
);

-- Выходные параметры алгоритмов
CREATE TABLE IF NOT EXISTS algorithms.algorithm_outputs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    algorithm_id UUID REFERENCES algorithms.algorithms(id) ON DELETE CASCADE,
    parameter_id UUID REFERENCES tech_params.parameters(id),
    variable_name VARCHAR(100) NOT NULL,
    description TEXT,
    UNIQUE(algorithm_id, variable_name)
);

-- История выполнения алгоритмов
CREATE TABLE IF NOT EXISTS algorithms.execution_history (
    id BIGSERIAL PRIMARY KEY,
    algorithm_id UUID REFERENCES algorithms.algorithms(id),
    started_at TIMESTAMP WITH TIME ZONE NOT NULL,
    completed_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(50) NOT NULL, -- running, completed, failed, timeout
    input_values JSONB,
    output_values JSONB,
    error_message TEXT,
    execution_time_ms INTEGER
);

-- ==============================================================================
-- VISUALIZATION SCHEMA - Видеокадры и визуализация
-- ==============================================================================

-- Проекты визуализации
CREATE TABLE IF NOT EXISTS visualization.projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    version VARCHAR(20) DEFAULT '1.0.0',
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Видеокадры (мнемосхемы)
CREATE TABLE IF NOT EXISTS visualization.screens (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES visualization.projects(id),
    parent_id UUID REFERENCES visualization.screens(id),
    code VARCHAR(100) NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    screen_type VARCHAR(50) NOT NULL CHECK (screen_type IN ('overview', 'detail', 'trend', 'alarm', 'report')),
    
    -- Размеры и позиционирование
    width INTEGER DEFAULT 1920,
    height INTEGER DEFAULT 1080,
    background_color VARCHAR(7),
    background_image TEXT,
    
    -- Конфигурация
    configuration JSONB, -- JSON с полной конфигурацией экрана
    
    -- Навигация
    is_home BOOLEAN DEFAULT false,
    sort_order INTEGER DEFAULT 0,
    
    -- Права доступа
    access_level INTEGER DEFAULT 0,
    
    -- Состояние
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(project_id, code)
);

-- Элементы видеокадров
CREATE TABLE IF NOT EXISTS visualization.screen_elements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    screen_id UUID REFERENCES visualization.screens(id) ON DELETE CASCADE,
    element_type VARCHAR(100) NOT NULL, -- text, value, button, valve, pump, tank, pipe, trend, alarm_list
    name VARCHAR(255),
    
    -- Позиционирование
    x_position INTEGER NOT NULL,
    y_position INTEGER NOT NULL,
    width INTEGER,
    height INTEGER,
    z_index INTEGER DEFAULT 0,
    rotation DECIMAL(5,2) DEFAULT 0,
    
    -- Стилизация
    style JSONB, -- CSS-like стили
    
    -- Привязка к данным
    parameter_id UUID REFERENCES tech_params.parameters(id),
    
    -- Конфигурация элемента
    configuration JSONB, -- Специфичная конфигурация для типа элемента
    
    -- Анимация
    animation_type VARCHAR(50), -- blink, rotate, color_change
    animation_config JSONB,
    
    -- Интерактивность
    is_interactive BOOLEAN DEFAULT false,
    on_click_action JSONB, -- Действие при клике
    on_hover_action JSONB, -- Действие при наведении
    
    -- Состояние
    is_visible BOOLEAN DEFAULT true,
    is_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Шаблоны элементов
CREATE TABLE IF NOT EXISTS visualization.element_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    category VARCHAR(100),
    element_type VARCHAR(100) NOT NULL,
    default_configuration JSONB,
    preview_image TEXT,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================================================
-- TOPOLOGY SCHEMA - Узлы ПТК и топология системы
-- ==============================================================================

-- Типы узлов
CREATE TABLE IF NOT EXISTS topology.node_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    icon VARCHAR(255),
    color VARCHAR(7),
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Узлы ПТК
CREATE TABLE IF NOT EXISTS topology.nodes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parent_id UUID REFERENCES topology.nodes(id),
    node_type_id UUID REFERENCES topology.node_types(id),
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- Физическое расположение
    location VARCHAR(500),
    building VARCHAR(255),
    floor VARCHAR(50),
    room VARCHAR(100),
    rack VARCHAR(50),
    position_in_rack INTEGER,
    
    -- Сетевая информация
    hostname VARCHAR(255),
    domain VARCHAR(255),
    ip_address INET,
    mac_address MACADDR,
    
    -- Характеристики
    manufacturer VARCHAR(255),
    model VARCHAR(255),
    serial_number VARCHAR(255),
    
    -- Состояние
    status_id UUID REFERENCES core.statuses(id),
    is_online BOOLEAN DEFAULT false,
    last_ping_time TIMESTAMP WITH TIME ZONE,
    
    -- Резервирование
    redundancy_type VARCHAR(50), -- none, hot_standby, cold_standby
    redundant_node_id UUID REFERENCES topology.nodes(id),
    
    -- Метаданные
    installed_at DATE,
    commissioned_at DATE,
    decommissioned_at DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Связи между узлами
CREATE TABLE IF NOT EXISTS topology.node_connections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    source_node_id UUID REFERENCES topology.nodes(id) ON DELETE CASCADE,
    target_node_id UUID REFERENCES topology.nodes(id) ON DELETE CASCADE,
    connection_type VARCHAR(100) NOT NULL, -- ethernet, serial, wireless, optical
    protocol VARCHAR(100), -- TCP/IP, Modbus, OPC, IEC-61850
    bandwidth_mbps INTEGER,
    latency_ms INTEGER,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(source_node_id, target_node_id, connection_type)
);

-- ==============================================================================
-- KROSS SCHEMA - Параметры платформы КРОСС
-- ==============================================================================

-- Конфигурация КРОСС
CREATE TABLE IF NOT EXISTS kross.platform_config (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    parameter_name VARCHAR(255) NOT NULL UNIQUE,
    parameter_value TEXT NOT NULL,
    parameter_type VARCHAR(50) NOT NULL, -- string, integer, boolean, json
    category VARCHAR(100),
    description TEXT,
    is_encrypted BOOLEAN DEFAULT false,
    is_readonly BOOLEAN DEFAULT false,
    requires_restart BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Модули КРОСС
CREATE TABLE IF NOT EXISTS kross.modules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    version VARCHAR(20) NOT NULL,
    description TEXT,
    
    -- Параметры запуска
    executable_path TEXT,
    working_directory TEXT,
    startup_arguments TEXT,
    environment_variables JSONB,
    
    -- Настройки выполнения
    auto_start BOOLEAN DEFAULT true,
    start_order INTEGER DEFAULT 100,
    stop_timeout_seconds INTEGER DEFAULT 30,
    restart_on_failure BOOLEAN DEFAULT true,
    max_restart_attempts INTEGER DEFAULT 3,
    
    -- Зависимости
    dependencies JSONB, -- Массив кодов модулей-зависимостей
    
    -- Состояние
    is_installed BOOLEAN DEFAULT true,
    is_enabled BOOLEAN DEFAULT true,
    is_running BOOLEAN DEFAULT false,
    pid INTEGER,
    started_at TIMESTAMP WITH TIME ZONE,
    
    -- Метрики
    cpu_usage_percent DECIMAL(5,2),
    memory_usage_mb INTEGER,
    disk_usage_mb INTEGER,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Лицензии КРОСС
CREATE TABLE IF NOT EXISTS kross.licenses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    license_key TEXT NOT NULL UNIQUE,
    product_name VARCHAR(255) NOT NULL,
    customer_name VARCHAR(500),
    
    -- Ограничения лицензии
    max_tags INTEGER,
    max_users INTEGER,
    max_clients INTEGER,
    allowed_modules JSONB, -- Массив разрешенных модулей
    
    -- Сроки действия
    issued_date DATE NOT NULL,
    expiration_date DATE,
    
    -- Состояние
    is_active BOOLEAN DEFAULT true,
    activation_date TIMESTAMP WITH TIME ZONE,
    last_check_date TIMESTAMP WITH TIME ZONE,
    
    -- Защита
    hardware_id VARCHAR(255),
    signature TEXT,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================================================
-- SECURITY SCHEMA - Пользователи и безопасность
-- ==============================================================================

-- Роли пользователей
CREATE TABLE IF NOT EXISTS security.roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    priority INTEGER DEFAULT 100, -- Приоритет роли для разрешения конфликтов
    is_system BOOLEAN DEFAULT false, -- Системная роль, не может быть удалена
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Пользователи системы
CREATE TABLE IF NOT EXISTS security.users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(100) NOT NULL UNIQUE,
    email VARCHAR(255) UNIQUE,
    password_hash TEXT NOT NULL, -- Хэш пароля (bcrypt)
    
    -- Персональные данные
    full_name VARCHAR(500),
    position VARCHAR(255),
    department VARCHAR(255),
    phone VARCHAR(50),
    
    -- Настройки безопасности
    must_change_password BOOLEAN DEFAULT false,
    password_changed_at TIMESTAMP WITH TIME ZONE,
    failed_login_attempts INTEGER DEFAULT 0,
    locked_until TIMESTAMP WITH TIME ZONE,
    
    -- Двухфакторная аутентификация
    two_factor_enabled BOOLEAN DEFAULT false,
    two_factor_secret TEXT,
    
    -- Состояние
    is_active BOOLEAN DEFAULT true,
    is_online BOOLEAN DEFAULT false,
    last_login_at TIMESTAMP WITH TIME ZONE,
    last_activity_at TIMESTAMP WITH TIME ZONE,
    last_ip_address INET,
    
    -- Метаданные
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES security.users(id),
    deactivated_at TIMESTAMP WITH TIME ZONE,
    deactivated_by UUID REFERENCES security.users(id)
);

-- Связь пользователей и ролей
CREATE TABLE IF NOT EXISTS security.user_roles (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES security.users(id) ON DELETE CASCADE,
    role_id UUID REFERENCES security.roles(id) ON DELETE CASCADE,
    granted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    granted_by UUID REFERENCES security.users(id),
    expires_at TIMESTAMP WITH TIME ZONE, -- Временная роль
    UNIQUE(user_id, role_id)
);

-- Разрешения (permissions)
CREATE TABLE IF NOT EXISTS security.permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(255) NOT NULL UNIQUE, -- например: parameters.read, parameters.write
    name VARCHAR(255) NOT NULL,
    resource VARCHAR(100) NOT NULL, -- parameters, controllers, reports
    action VARCHAR(50) NOT NULL, -- create, read, update, delete, execute
    description TEXT,
    is_system BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Связь ролей и разрешений
CREATE TABLE IF NOT EXISTS security.role_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    role_id UUID REFERENCES security.roles(id) ON DELETE CASCADE,
    permission_id UUID REFERENCES security.permissions(id) ON DELETE CASCADE,
    granted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(role_id, permission_id)
);

-- Права доступа к конкретным объектам
CREATE TABLE IF NOT EXISTS security.object_permissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES security.users(id) ON DELETE CASCADE,
    object_type VARCHAR(100) NOT NULL, -- parameter, screen, report
    object_id UUID NOT NULL,
    permission_type VARCHAR(50) NOT NULL, -- read, write, delete
    granted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    granted_by UUID REFERENCES security.users(id),
    expires_at TIMESTAMP WITH TIME ZONE,
    UNIQUE(user_id, object_type, object_id, permission_type)
);

-- Сессии пользователей
CREATE TABLE IF NOT EXISTS security.user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES security.users(id) ON DELETE CASCADE,
    token_hash TEXT NOT NULL UNIQUE,
    
    -- Информация о сессии
    ip_address INET NOT NULL,
    user_agent TEXT,
    client_type VARCHAR(50), -- web, mobile, desktop, api
    
    -- Время жизни
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    
    -- Состояние
    is_active BOOLEAN DEFAULT true,
    terminated_at TIMESTAMP WITH TIME ZONE,
    termination_reason VARCHAR(100) -- logout, timeout, admin_action, password_change
);

-- Аудит действий пользователей
CREATE TABLE IF NOT EXISTS security.audit_log (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID REFERENCES security.users(id),
    session_id UUID REFERENCES security.user_sessions(id),
    
    -- Действие
    action_type VARCHAR(100) NOT NULL, -- login, logout, create, update, delete, execute
    object_type VARCHAR(100),
    object_id UUID,
    object_name VARCHAR(500),
    
    -- Детали
    old_values JSONB,
    new_values JSONB,
    
    -- Контекст
    ip_address INET,
    user_agent TEXT,
    
    -- Результат
    success BOOLEAN DEFAULT true,
    error_message TEXT,
    
    -- Время
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================================================
-- EVENTS SCHEMA - События и тревоги
-- ==============================================================================

-- Классы событий
CREATE TABLE IF NOT EXISTS events.event_classes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    severity VARCHAR(50) NOT NULL CHECK (severity IN ('info', 'warning', 'minor', 'major', 'critical')),
    color VARCHAR(7),
    sound_file VARCHAR(255),
    requires_acknowledgment BOOLEAN DEFAULT false,
    auto_acknowledge_timeout_min INTEGER,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- События системы
CREATE TABLE IF NOT EXISTS events.events (
    id BIGSERIAL PRIMARY KEY,
    event_class_id UUID REFERENCES events.event_classes(id),
    
    -- Источник события
    source_type VARCHAR(100) NOT NULL, -- parameter, controller, system, user
    source_id UUID,
    source_name VARCHAR(500),
    
    -- Детали события
    event_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    event_type VARCHAR(100) NOT NULL, -- alarm_activated, alarm_deactivated, value_change, system_error
    message TEXT NOT NULL,
    details JSONB,
    
    -- Значения для аварий
    actual_value TEXT,
    limit_value TEXT,
    
    -- Состояние
    is_active BOOLEAN DEFAULT true, -- Для аварий - активна ли еще
    is_acknowledged BOOLEAN DEFAULT false,
    acknowledged_by UUID REFERENCES security.users(id),
    acknowledged_at TIMESTAMP WITH TIME ZONE,
    acknowledgment_comment TEXT,
    
    -- Связанные события
    parent_event_id BIGINT REFERENCES events.events(id),
    
    -- Индексы для быстрого поиска
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Подписки на события
CREATE TABLE IF NOT EXISTS events.event_subscriptions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES security.users(id) ON DELETE CASCADE,
    event_class_id UUID REFERENCES events.event_classes(id),
    
    -- Фильтры
    source_type VARCHAR(100),
    source_id UUID,
    severity_threshold VARCHAR(50),
    
    -- Способы уведомления
    email_enabled BOOLEAN DEFAULT false,
    sms_enabled BOOLEAN DEFAULT false,
    push_enabled BOOLEAN DEFAULT true,
    
    -- Расписание
    schedule JSONB, -- Расписание когда активна подписка
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- ==============================================================================
-- REPORTS SCHEMA - Отчеты
-- ==============================================================================

-- Шаблоны отчетов
CREATE TABLE IF NOT EXISTS reports.report_templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    code VARCHAR(100) NOT NULL UNIQUE,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    
    -- Тип и формат
    report_type VARCHAR(50) NOT NULL CHECK (report_type IN ('tabular', 'graphical', 'combined')),
    output_formats JSONB DEFAULT '["pdf", "excel", "html"]'::jsonb,
    
    -- Определение отчета
    sql_query TEXT,
    template_file TEXT, -- Путь к файлу шаблона
    configuration JSONB, -- Конфигурация отчета
    
    -- Параметры отчета
    parameters_schema JSONB, -- JSON Schema параметров
    
    -- Права доступа
    required_role_id UUID REFERENCES security.roles(id),
    
    -- Состояние
    is_active BOOLEAN DEFAULT true,
    version VARCHAR(20) DEFAULT '1.0.0',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES security.users(id)
);

-- Расписания отчетов
CREATE TABLE IF NOT EXISTS reports.report_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    template_id UUID REFERENCES reports.report_templates(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    
    -- Расписание (cron-like)
    schedule_type VARCHAR(50) NOT NULL CHECK (schedule_type IN ('once', 'hourly', 'daily', 'weekly', 'monthly', 'custom')),
    cron_expression VARCHAR(255), -- Для custom расписания
    next_run_time TIMESTAMP WITH TIME ZONE,
    
    -- Параметры генерации
    parameters JSONB,
    output_format VARCHAR(20) NOT NULL,
    
    -- Доставка
    delivery_type VARCHAR(50) NOT NULL CHECK (delivery_type IN ('email', 'file', 'both')),
    email_recipients TEXT[], -- Массив email адресов
    file_path TEXT,
    
    -- Состояние
    is_active BOOLEAN DEFAULT true,
    last_run_time TIMESTAMP WITH TIME ZONE,
    last_run_status VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_by UUID REFERENCES security.users(id)
);

-- История генерации отчетов
CREATE TABLE IF NOT EXISTS reports.report_history (
    id BIGSERIAL PRIMARY KEY,
    template_id UUID REFERENCES reports.report_templates(id),
    schedule_id UUID REFERENCES reports.report_schedules(id),
    
    -- Запрос
    requested_by UUID REFERENCES security.users(id),
    request_time TIMESTAMP WITH TIME ZONE NOT NULL,
    parameters JSONB,
    
    -- Выполнение
    start_time TIMESTAMP WITH TIME ZONE,
    end_time TIMESTAMP WITH TIME ZONE,
    status VARCHAR(50) NOT NULL, -- pending, running, completed, failed
    error_message TEXT,
    
    -- Результат
    output_format VARCHAR(20),
    file_size_bytes BIGINT,
    file_path TEXT,
    rows_count INTEGER,
    
    -- Доставка
    delivered_at TIMESTAMP WITH TIME ZONE,
    delivery_status VARCHAR(50)
);

-- ==============================================================================
-- Создание индексов для оптимизации производительности
-- ==============================================================================

-- Индексы для tech_params
CREATE INDEX idx_parameters_tag ON tech_params.parameters(tag);
CREATE INDEX idx_parameters_group ON tech_params.parameters(group_id);
CREATE INDEX idx_parameters_type ON tech_params.parameters(parameter_type);
CREATE INDEX idx_parameters_active ON tech_params.parameters(is_active) WHERE is_active = true;
CREATE INDEX idx_current_values_timestamp ON tech_params.current_values(timestamp);

-- Индексы для archive
CREATE INDEX idx_historical_data_param_time ON archive.historical_data(parameter_id, timestamp DESC);
CREATE INDEX idx_compressed_data_param_time ON archive.compressed_data(parameter_id, start_time, end_time);

-- Индексы для events
CREATE INDEX idx_events_time ON events.events(event_time DESC);
CREATE INDEX idx_events_source ON events.events(source_type, source_id);
CREATE INDEX idx_events_active ON events.events(is_active) WHERE is_active = true;
CREATE INDEX idx_events_unacknowledged ON events.events(is_acknowledged) WHERE is_acknowledged = false;

-- Индексы для security
CREATE INDEX idx_audit_log_user ON security.audit_log(user_id);
CREATE INDEX idx_audit_log_time ON security.audit_log(timestamp DESC);
CREATE INDEX idx_audit_log_object ON security.audit_log(object_type, object_id);
CREATE INDEX idx_sessions_token ON security.user_sessions(token_hash);
CREATE INDEX idx_sessions_active ON security.user_sessions(is_active) WHERE is_active = true;

-- ==============================================================================
-- Комментарии к таблицам
-- ==============================================================================

COMMENT ON TABLE tech_params.parameters IS 'Основная таблица технологических и диагностических параметров системы';
COMMENT ON TABLE controllers.controllers IS 'Контроллеры КУПРИ и другое оборудование АСУ ТП';
COMMENT ON TABLE archive.historical_data IS 'Архивные данные параметров (партиционированная таблица)';
COMMENT ON TABLE algorithms.algorithms IS 'Расчетные алгоритмы для обработки данных';
COMMENT ON TABLE visualization.screens IS 'Видеокадры (мнемосхемы) для визуализации';
COMMENT ON TABLE topology.nodes IS 'Узлы ПТК - физическая и логическая топология системы';
COMMENT ON TABLE kross.platform_config IS 'Конфигурация платформы КРОСС';
COMMENT ON TABLE security.users IS 'Пользователи системы АСУ ТП';
COMMENT ON TABLE events.events IS 'События и тревоги системы';
COMMENT ON TABLE reports.report_templates IS 'Шаблоны отчетов для генерации';


