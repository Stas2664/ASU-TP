-- ==============================================================================
-- Создание оптимизированных индексов для ПТК АСУ ТП
-- База данных: asu_tp_db
-- Оптимизация производительности для работы в реальном времени
-- ==============================================================================

\c asu_tp_db;

-- ==============================================================================
-- CORE SCHEMA - Индексы для справочников
-- ==============================================================================

-- Индексы для units
CREATE INDEX IF NOT EXISTS idx_units_code ON core.units(code);
CREATE INDEX IF NOT EXISTS idx_units_type ON core.units(unit_type);
CREATE INDEX IF NOT EXISTS idx_units_base ON core.units(base_unit_id) WHERE base_unit_id IS NOT NULL;

-- Индексы для data_types
CREATE INDEX IF NOT EXISTS idx_data_types_code ON core.data_types(code);
CREATE INDEX IF NOT EXISTS idx_data_types_postgres ON core.data_types(postgres_type);

-- Индексы для statuses
CREATE INDEX IF NOT EXISTS idx_statuses_code ON core.statuses(code);
CREATE INDEX IF NOT EXISTS idx_statuses_group ON core.statuses(status_group);
CREATE INDEX IF NOT EXISTS idx_statuses_priority ON core.statuses(priority);

-- ==============================================================================
-- TECH_PARAMS SCHEMA - Индексы для параметров
-- ==============================================================================

-- Индексы для parameter_groups
CREATE INDEX IF NOT EXISTS idx_param_groups_parent ON tech_params.parameter_groups(parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_param_groups_code ON tech_params.parameter_groups(code);
CREATE INDEX IF NOT EXISTS idx_param_groups_active ON tech_params.parameter_groups(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_param_groups_sort ON tech_params.parameter_groups(sort_order, code);

-- Индексы для parameters (основные)
CREATE INDEX IF NOT EXISTS idx_parameters_tag ON tech_params.parameters(tag);
CREATE INDEX IF NOT EXISTS idx_parameters_group ON tech_params.parameters(group_id);
CREATE INDEX IF NOT EXISTS idx_parameters_type ON tech_params.parameters(parameter_type);
CREATE INDEX IF NOT EXISTS idx_parameters_source ON tech_params.parameters(source_type);
CREATE INDEX IF NOT EXISTS idx_parameters_active ON tech_params.parameters(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_parameters_archived ON tech_params.parameters(is_archived) WHERE is_archived = true;

-- Составные индексы для частых запросов
CREATE INDEX IF NOT EXISTS idx_parameters_group_type_active 
    ON tech_params.parameters(group_id, parameter_type, is_active);
CREATE INDEX IF NOT EXISTS idx_parameters_type_active 
    ON tech_params.parameters(parameter_type, is_active) WHERE is_active = true;

-- Индексы для поиска по тревогам
CREATE INDEX IF NOT EXISTS idx_parameters_alarm_low 
    ON tech_params.parameters(alarm_low) WHERE alarm_low IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_parameters_alarm_high 
    ON tech_params.parameters(alarm_high) WHERE alarm_high IS NOT NULL;

-- Индексы для current_values
CREATE INDEX IF NOT EXISTS idx_current_values_timestamp ON tech_params.current_values(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_current_values_quality ON tech_params.current_values(quality);
CREATE INDEX IF NOT EXISTS idx_current_values_source ON tech_params.current_values(source);
CREATE INDEX IF NOT EXISTS idx_current_values_updated ON tech_params.current_values(updated_at DESC);

-- Индексы для diagnostic_parameters
CREATE INDEX IF NOT EXISTS idx_diagnostic_params_parameter ON tech_params.diagnostic_parameters(parameter_id);
CREATE INDEX IF NOT EXISTS idx_diagnostic_params_type ON tech_params.diagnostic_parameters(diagnostic_type);
CREATE INDEX IF NOT EXISTS idx_diagnostic_params_severity ON tech_params.diagnostic_parameters(severity);
CREATE INDEX IF NOT EXISTS idx_diagnostic_params_active ON tech_params.diagnostic_parameters(is_active) WHERE is_active = true;

-- ==============================================================================
-- CONTROLLERS SCHEMA - Индексы для контроллеров
-- ==============================================================================

-- Индексы для controller_types
CREATE INDEX IF NOT EXISTS idx_controller_types_code ON controllers.controller_types(code);
CREATE INDEX IF NOT EXISTS idx_controller_types_protocol ON controllers.controller_types(communication_protocol);

-- Индексы для controllers
CREATE INDEX IF NOT EXISTS idx_controllers_type ON controllers.controllers(controller_type_id);
CREATE INDEX IF NOT EXISTS idx_controllers_node ON controllers.controllers(node_id) WHERE node_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_controllers_inventory ON controllers.controllers(inventory_number);
CREATE INDEX IF NOT EXISTS idx_controllers_ip ON controllers.controllers(ip_address) WHERE ip_address IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_controllers_status ON controllers.controllers(status_id);
CREATE INDEX IF NOT EXISTS idx_controllers_online ON controllers.controllers(is_online) WHERE is_online = true;
CREATE INDEX IF NOT EXISTS idx_controllers_primary ON controllers.controllers(is_primary) WHERE is_primary = true;

-- GIN индекс для JSONB конфигурации
CREATE INDEX IF NOT EXISTS idx_controllers_config ON controllers.controllers USING gin(configuration);

-- Индексы для controller_modules
CREATE INDEX IF NOT EXISTS idx_modules_controller ON controllers.controller_modules(controller_id);
CREATE INDEX IF NOT EXISTS idx_modules_type ON controllers.controller_modules(module_type);
CREATE INDEX IF NOT EXISTS idx_modules_status ON controllers.controller_modules(status_id);
CREATE INDEX IF NOT EXISTS idx_modules_active ON controllers.controller_modules(is_active) WHERE is_active = true;

-- Индексы для io_channels
CREATE INDEX IF NOT EXISTS idx_io_channels_module ON controllers.io_channels(module_id);
CREATE INDEX IF NOT EXISTS idx_io_channels_parameter ON controllers.io_channels(parameter_id) WHERE parameter_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_io_channels_type ON controllers.io_channels(channel_type);
CREATE INDEX IF NOT EXISTS idx_io_channels_signal ON controllers.io_channels(signal_type);
CREATE INDEX IF NOT EXISTS idx_io_channels_active ON controllers.io_channels(is_active) WHERE is_active = true;

-- ==============================================================================
-- ARCHIVE SCHEMA - Индексы для архивных данных
-- ==============================================================================

-- Индексы для archive_configs
CREATE INDEX IF NOT EXISTS idx_archive_configs_parameter ON archive.archive_configs(parameter_id);
CREATE INDEX IF NOT EXISTS idx_archive_configs_type ON archive.archive_configs(archive_type);
CREATE INDEX IF NOT EXISTS idx_archive_configs_active ON archive.archive_configs(is_active) WHERE is_active = true;

-- Индексы для historical_data (основная партиционированная таблица)
-- Создаются автоматически для каждой партиции
CREATE INDEX IF NOT EXISTS idx_historical_data_param_time 
    ON archive.historical_data(parameter_id, timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_historical_data_timestamp 
    ON archive.historical_data(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_historical_data_quality 
    ON archive.historical_data(quality) WHERE quality < 192;

-- BRIN индексы для больших партиций (эффективны для временных рядов)
CREATE INDEX IF NOT EXISTS idx_historical_data_timestamp_brin 
    ON archive.historical_data USING brin(timestamp);

-- Индексы для compressed_data
CREATE INDEX IF NOT EXISTS idx_compressed_data_parameter ON archive.compressed_data(parameter_id);
CREATE INDEX IF NOT EXISTS idx_compressed_data_time_range 
    ON archive.compressed_data(parameter_id, start_time, end_time);
CREATE INDEX IF NOT EXISTS idx_compressed_data_start ON archive.compressed_data(start_time);
CREATE INDEX IF NOT EXISTS idx_compressed_data_method ON archive.compressed_data(compression_method);

-- ==============================================================================
-- ALGORITHMS SCHEMA - Индексы для алгоритмов
-- ==============================================================================

-- Индексы для algorithm_types
CREATE INDEX IF NOT EXISTS idx_algorithm_types_code ON algorithms.algorithm_types(code);

-- Индексы для algorithms
CREATE INDEX IF NOT EXISTS idx_algorithms_type ON algorithms.algorithms(type_id);
CREATE INDEX IF NOT EXISTS idx_algorithms_code ON algorithms.algorithms(code);
CREATE INDEX IF NOT EXISTS idx_algorithms_language ON algorithms.algorithms(language);
CREATE INDEX IF NOT EXISTS idx_algorithms_active ON algorithms.algorithms(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_algorithms_validated ON algorithms.algorithms(is_validated) WHERE is_validated = true;
CREATE INDEX IF NOT EXISTS idx_algorithms_priority ON algorithms.algorithms(priority DESC);
CREATE INDEX IF NOT EXISTS idx_algorithms_last_exec ON algorithms.algorithms(last_execution_time DESC);

-- Индексы для algorithm_inputs
CREATE INDEX IF NOT EXISTS idx_algorithm_inputs_algorithm ON algorithms.algorithm_inputs(algorithm_id);
CREATE INDEX IF NOT EXISTS idx_algorithm_inputs_parameter ON algorithms.algorithm_inputs(parameter_id);
CREATE INDEX IF NOT EXISTS idx_algorithm_inputs_required ON algorithms.algorithm_inputs(is_required) WHERE is_required = true;

-- Индексы для algorithm_outputs
CREATE INDEX IF NOT EXISTS idx_algorithm_outputs_algorithm ON algorithms.algorithm_outputs(algorithm_id);
CREATE INDEX IF NOT EXISTS idx_algorithm_outputs_parameter ON algorithms.algorithm_outputs(parameter_id);

-- Индексы для execution_history
CREATE INDEX IF NOT EXISTS idx_execution_history_algorithm ON algorithms.execution_history(algorithm_id);
CREATE INDEX IF NOT EXISTS idx_execution_history_started ON algorithms.execution_history(started_at DESC);
CREATE INDEX IF NOT EXISTS idx_execution_history_status ON algorithms.execution_history(status);
CREATE INDEX IF NOT EXISTS idx_execution_history_failed 
    ON algorithms.execution_history(algorithm_id, started_at DESC) WHERE status = 'failed';

-- ==============================================================================
-- VISUALIZATION SCHEMA - Индексы для визуализации
-- ==============================================================================

-- Индексы для projects
CREATE INDEX IF NOT EXISTS idx_vis_projects_code ON visualization.projects(code);
CREATE INDEX IF NOT EXISTS idx_vis_projects_active ON visualization.projects(is_active) WHERE is_active = true;

-- Индексы для screens
CREATE INDEX IF NOT EXISTS idx_screens_project ON visualization.screens(project_id);
CREATE INDEX IF NOT EXISTS idx_screens_parent ON visualization.screens(parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_screens_code ON visualization.screens(code);
CREATE INDEX IF NOT EXISTS idx_screens_type ON visualization.screens(screen_type);
CREATE INDEX IF NOT EXISTS idx_screens_home ON visualization.screens(is_home) WHERE is_home = true;
CREATE INDEX IF NOT EXISTS idx_screens_active ON visualization.screens(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_screens_sort ON visualization.screens(sort_order, name);

-- GIN индекс для конфигурации экранов
CREATE INDEX IF NOT EXISTS idx_screens_config ON visualization.screens USING gin(configuration);

-- Индексы для screen_elements
CREATE INDEX IF NOT EXISTS idx_screen_elements_screen ON visualization.screen_elements(screen_id);
CREATE INDEX IF NOT EXISTS idx_screen_elements_type ON visualization.screen_elements(element_type);
CREATE INDEX IF NOT EXISTS idx_screen_elements_parameter ON visualization.screen_elements(parameter_id) WHERE parameter_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_screen_elements_position ON visualization.screen_elements(screen_id, z_index, x_position, y_position);
CREATE INDEX IF NOT EXISTS idx_screen_elements_interactive ON visualization.screen_elements(is_interactive) WHERE is_interactive = true;

-- GIN индексы для JSONB полей
CREATE INDEX IF NOT EXISTS idx_screen_elements_style ON visualization.screen_elements USING gin(style);
CREATE INDEX IF NOT EXISTS idx_screen_elements_config ON visualization.screen_elements USING gin(configuration);

-- Индексы для element_templates
CREATE INDEX IF NOT EXISTS idx_element_templates_code ON visualization.element_templates(code);
CREATE INDEX IF NOT EXISTS idx_element_templates_category ON visualization.element_templates(category);
CREATE INDEX IF NOT EXISTS idx_element_templates_type ON visualization.element_templates(element_type);

-- ==============================================================================
-- TOPOLOGY SCHEMA - Индексы для топологии
-- ==============================================================================

-- Индексы для node_types
CREATE INDEX IF NOT EXISTS idx_node_types_code ON topology.node_types(code);

-- Индексы для nodes
CREATE INDEX IF NOT EXISTS idx_nodes_parent ON topology.nodes(parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_nodes_type ON topology.nodes(node_type_id);
CREATE INDEX IF NOT EXISTS idx_nodes_code ON topology.nodes(code);
CREATE INDEX IF NOT EXISTS idx_nodes_status ON topology.nodes(status_id);
CREATE INDEX IF NOT EXISTS idx_nodes_online ON topology.nodes(is_online) WHERE is_online = true;
CREATE INDEX IF NOT EXISTS idx_nodes_ip ON topology.nodes(ip_address) WHERE ip_address IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_nodes_location ON topology.nodes(location);
CREATE INDEX IF NOT EXISTS idx_nodes_redundant ON topology.nodes(redundant_node_id) WHERE redundant_node_id IS NOT NULL;

-- Индексы для node_connections
CREATE INDEX IF NOT EXISTS idx_node_conn_source ON topology.node_connections(source_node_id);
CREATE INDEX IF NOT EXISTS idx_node_conn_target ON topology.node_connections(target_node_id);
CREATE INDEX IF NOT EXISTS idx_node_conn_type ON topology.node_connections(connection_type);
CREATE INDEX IF NOT EXISTS idx_node_conn_protocol ON topology.node_connections(protocol);
CREATE INDEX IF NOT EXISTS idx_node_conn_active ON topology.node_connections(is_active) WHERE is_active = true;

-- ==============================================================================
-- KROSS SCHEMA - Индексы для платформы КРОСС
-- ==============================================================================

-- Индексы для platform_config
CREATE INDEX IF NOT EXISTS idx_platform_config_name ON kross.platform_config(parameter_name);
CREATE INDEX IF NOT EXISTS idx_platform_config_category ON kross.platform_config(category);
CREATE INDEX IF NOT EXISTS idx_platform_config_type ON kross.platform_config(parameter_type);
CREATE INDEX IF NOT EXISTS idx_platform_config_restart ON kross.platform_config(requires_restart) WHERE requires_restart = true;

-- Индексы для modules
CREATE INDEX IF NOT EXISTS idx_kross_modules_code ON kross.modules(code);
CREATE INDEX IF NOT EXISTS idx_kross_modules_enabled ON kross.modules(is_enabled) WHERE is_enabled = true;
CREATE INDEX IF NOT EXISTS idx_kross_modules_running ON kross.modules(is_running) WHERE is_running = true;
CREATE INDEX IF NOT EXISTS idx_kross_modules_start_order ON kross.modules(start_order, code);

-- GIN индекс для зависимостей
CREATE INDEX IF NOT EXISTS idx_kross_modules_deps ON kross.modules USING gin(dependencies);

-- Индексы для licenses
CREATE INDEX IF NOT EXISTS idx_licenses_key ON kross.licenses(license_key);
CREATE INDEX IF NOT EXISTS idx_licenses_product ON kross.licenses(product_name);
CREATE INDEX IF NOT EXISTS idx_licenses_active ON kross.licenses(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_licenses_expiration ON kross.licenses(expiration_date) WHERE expiration_date IS NOT NULL;

-- ==============================================================================
-- SECURITY SCHEMA - Индексы для безопасности
-- ==============================================================================

-- Индексы для roles
CREATE INDEX IF NOT EXISTS idx_roles_code ON security.roles(code);
CREATE INDEX IF NOT EXISTS idx_roles_priority ON security.roles(priority DESC);
CREATE INDEX IF NOT EXISTS idx_roles_active ON security.roles(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_roles_system ON security.roles(is_system) WHERE is_system = true;

-- Индексы для users
CREATE INDEX IF NOT EXISTS idx_users_username ON security.users(username);
CREATE INDEX IF NOT EXISTS idx_users_email ON security.users(email) WHERE email IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_users_active ON security.users(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_users_online ON security.users(is_online) WHERE is_online = true;
CREATE INDEX IF NOT EXISTS idx_users_locked ON security.users(locked_until) WHERE locked_until > CURRENT_TIMESTAMP;
CREATE INDEX IF NOT EXISTS idx_users_department ON security.users(department);

-- Индексы для user_roles
CREATE INDEX IF NOT EXISTS idx_user_roles_user ON security.user_roles(user_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_role ON security.user_roles(role_id);
CREATE INDEX IF NOT EXISTS idx_user_roles_expires ON security.user_roles(expires_at) WHERE expires_at IS NOT NULL;

-- Индексы для permissions
CREATE INDEX IF NOT EXISTS idx_permissions_code ON security.permissions(code);
CREATE INDEX IF NOT EXISTS idx_permissions_resource ON security.permissions(resource);
CREATE INDEX IF NOT EXISTS idx_permissions_action ON security.permissions(action);
CREATE INDEX IF NOT EXISTS idx_permissions_resource_action ON security.permissions(resource, action);

-- Индексы для role_permissions
CREATE INDEX IF NOT EXISTS idx_role_permissions_role ON security.role_permissions(role_id);
CREATE INDEX IF NOT EXISTS idx_role_permissions_permission ON security.role_permissions(permission_id);

-- Индексы для object_permissions
CREATE INDEX IF NOT EXISTS idx_object_permissions_user ON security.object_permissions(user_id);
CREATE INDEX IF NOT EXISTS idx_object_permissions_object ON security.object_permissions(object_type, object_id);
CREATE INDEX IF NOT EXISTS idx_object_permissions_type ON security.object_permissions(permission_type);
CREATE INDEX IF NOT EXISTS idx_object_permissions_expires ON security.object_permissions(expires_at) WHERE expires_at IS NOT NULL;

-- Индексы для user_sessions
CREATE INDEX IF NOT EXISTS idx_sessions_user ON security.user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON security.user_sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_sessions_active ON security.user_sessions(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON security.user_sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_sessions_ip ON security.user_sessions(ip_address);

-- Индексы для audit_log (оптимизированы для быстрого поиска)
CREATE INDEX IF NOT EXISTS idx_audit_log_user ON security.audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_session ON security.audit_log(session_id) WHERE session_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp ON security.audit_log(timestamp DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_action ON security.audit_log(action_type);
CREATE INDEX IF NOT EXISTS idx_audit_log_object ON security.audit_log(object_type, object_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_success ON security.audit_log(success);
CREATE INDEX IF NOT EXISTS idx_audit_log_user_time ON security.audit_log(user_id, timestamp DESC);

-- BRIN индекс для больших объемов аудита
CREATE INDEX IF NOT EXISTS idx_audit_log_timestamp_brin ON security.audit_log USING brin(timestamp);

-- ==============================================================================
-- EVENTS SCHEMA - Индексы для событий
-- ==============================================================================

-- Индексы для event_classes
CREATE INDEX IF NOT EXISTS idx_event_classes_code ON events.event_classes(code);
CREATE INDEX IF NOT EXISTS idx_event_classes_severity ON events.event_classes(severity);
CREATE INDEX IF NOT EXISTS idx_event_classes_ack_required ON events.event_classes(requires_acknowledgment) WHERE requires_acknowledgment = true;

-- Индексы для events (критически важны для производительности)
CREATE INDEX IF NOT EXISTS idx_events_class ON events.events(event_class_id);
CREATE INDEX IF NOT EXISTS idx_events_source ON events.events(source_type, source_id);
CREATE INDEX IF NOT EXISTS idx_events_time ON events.events(event_time DESC);
CREATE INDEX IF NOT EXISTS idx_events_type ON events.events(event_type);
CREATE INDEX IF NOT EXISTS idx_events_active ON events.events(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_events_unacknowledged ON events.events(is_acknowledged) WHERE is_acknowledged = false;
CREATE INDEX IF NOT EXISTS idx_events_parent ON events.events(parent_event_id) WHERE parent_event_id IS NOT NULL;

-- Составной индекс для активных неквитированных тревог
CREATE INDEX IF NOT EXISTS idx_events_active_unack 
    ON events.events(event_time DESC) WHERE is_active = true AND is_acknowledged = false;

-- BRIN индекс для архива событий
CREATE INDEX IF NOT EXISTS idx_events_time_brin ON events.events USING brin(event_time);

-- Индексы для event_subscriptions
CREATE INDEX IF NOT EXISTS idx_event_subs_user ON events.event_subscriptions(user_id);
CREATE INDEX IF NOT EXISTS idx_event_subs_class ON events.event_subscriptions(event_class_id);
CREATE INDEX IF NOT EXISTS idx_event_subs_source ON events.event_subscriptions(source_type, source_id) WHERE source_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_event_subs_active ON events.event_subscriptions(is_active) WHERE is_active = true;

-- ==============================================================================
-- REPORTS SCHEMA - Индексы для отчетов
-- ==============================================================================

-- Индексы для report_templates
CREATE INDEX IF NOT EXISTS idx_report_templates_code ON reports.report_templates(code);
CREATE INDEX IF NOT EXISTS idx_report_templates_category ON reports.report_templates(category);
CREATE INDEX IF NOT EXISTS idx_report_templates_type ON reports.report_templates(report_type);
CREATE INDEX IF NOT EXISTS idx_report_templates_active ON reports.report_templates(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_report_templates_role ON reports.report_templates(required_role_id) WHERE required_role_id IS NOT NULL;

-- Индексы для report_schedules
CREATE INDEX IF NOT EXISTS idx_report_schedules_template ON reports.report_schedules(template_id);
CREATE INDEX IF NOT EXISTS idx_report_schedules_type ON reports.report_schedules(schedule_type);
CREATE INDEX IF NOT EXISTS idx_report_schedules_next_run ON reports.report_schedules(next_run_time) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_report_schedules_active ON reports.report_schedules(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_report_schedules_created_by ON reports.report_schedules(created_by);

-- Индексы для report_history
CREATE INDEX IF NOT EXISTS idx_report_history_template ON reports.report_history(template_id);
CREATE INDEX IF NOT EXISTS idx_report_history_schedule ON reports.report_history(schedule_id) WHERE schedule_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_report_history_user ON reports.report_history(requested_by);
CREATE INDEX IF NOT EXISTS idx_report_history_time ON reports.report_history(request_time DESC);
CREATE INDEX IF NOT EXISTS idx_report_history_status ON reports.report_history(status);
CREATE INDEX IF NOT EXISTS idx_report_history_pending ON reports.report_history(request_time) WHERE status = 'pending';

-- ==============================================================================
-- СПЕЦИАЛЬНЫЕ ИНДЕКСЫ ДЛЯ ПРОИЗВОДИТЕЛЬНОСТИ
-- ==============================================================================

-- Индексы для полнотекстового поиска
CREATE INDEX IF NOT EXISTS idx_parameters_search ON tech_params.parameters 
    USING gin(to_tsvector('russian', name || ' ' || COALESCE(description, '')));

CREATE INDEX IF NOT EXISTS idx_events_message_search ON events.events 
    USING gin(to_tsvector('russian', message));

-- Индексы для частичного соответствия (LIKE '%text%')
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_parameters_tag_trgm ON tech_params.parameters 
    USING gin(tag gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_users_fullname_trgm ON security.users 
    USING gin(full_name gin_trgm_ops);

-- ==============================================================================
-- СТАТИСТИКА ПО ИНДЕКСАМ
-- ==============================================================================

-- Обновление статистики для оптимизатора
ANALYZE;

-- Вывод информации о созданных индексах
SELECT 'Индексы созданы:' AS info;
SELECT 
    schemaname,
    tablename,
    COUNT(*) as index_count
FROM pg_indexes
WHERE schemaname IN (
    'core', 'tech_params', 'controllers', 'archive', 
    'algorithms', 'visualization', 'topology', 'kross', 
    'security', 'events', 'reports'
)
GROUP BY schemaname, tablename
ORDER BY schemaname, tablename;

-- Общее количество индексов
SELECT 'Всего индексов: ' || COUNT(*) AS total
FROM pg_indexes
WHERE schemaname IN (
    'core', 'tech_params', 'controllers', 'archive', 
    'algorithms', 'visualization', 'topology', 'kross', 
    'security', 'events', 'reports'
);



