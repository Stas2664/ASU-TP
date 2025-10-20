-- ==============================================================================
-- Создание ролевой модели пользователей для ПТК АСУ ТП
-- База данных: asu_tp_db
-- Соответствие требованиям безопасности и многопользовательского доступа
-- ==============================================================================

\c asu_tp_db;

-- ==============================================================================
-- СОЗДАНИЕ РОЛЕЙ POSTGRESQL
-- ==============================================================================

-- Удаление существующих ролей (для разработки)
-- DROP ROLE IF EXISTS asu_tp_admin;
-- DROP ROLE IF EXISTS asu_tp_engineer;
-- DROP ROLE IF EXISTS asu_tp_operator;
-- DROP ROLE IF EXISTS asu_tp_viewer;
-- DROP ROLE IF EXISTS asu_tp_service;

-- ------------------------------------------------------------------------------
-- Роль: Администратор системы
-- ------------------------------------------------------------------------------
CREATE ROLE asu_tp_admin WITH
    LOGIN
    SUPERUSER
    CREATEDB
    CREATEROLE
    INHERIT
    REPLICATION
    CONNECTION LIMIT -1
    PASSWORD 'CHANGE_THIS_PASSWORD';

COMMENT ON ROLE asu_tp_admin IS 'Администратор АСУ ТП - полный доступ к системе';

-- ------------------------------------------------------------------------------
-- Роль: Инженер АСУ ТП
-- ------------------------------------------------------------------------------
CREATE ROLE asu_tp_engineer WITH
    LOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    INHERIT
    NOREPLICATION
    CONNECTION LIMIT 10
    PASSWORD 'CHANGE_THIS_PASSWORD';

COMMENT ON ROLE asu_tp_engineer IS 'Инженер АСУ ТП - настройка параметров и алгоритмов';

-- ------------------------------------------------------------------------------
-- Роль: Оператор
-- ------------------------------------------------------------------------------
CREATE ROLE asu_tp_operator WITH
    LOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    INHERIT
    NOREPLICATION
    CONNECTION LIMIT 20
    PASSWORD 'CHANGE_THIS_PASSWORD';

COMMENT ON ROLE asu_tp_operator IS 'Оператор АСУ ТП - управление технологическим процессом';

-- ------------------------------------------------------------------------------
-- Роль: Наблюдатель
-- ------------------------------------------------------------------------------
CREATE ROLE asu_tp_viewer WITH
    LOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    INHERIT
    NOREPLICATION
    CONNECTION LIMIT 50
    PASSWORD 'CHANGE_THIS_PASSWORD';

COMMENT ON ROLE asu_tp_viewer IS 'Наблюдатель - только просмотр данных';

-- ------------------------------------------------------------------------------
-- Роль: Сервисная учетная запись
-- ------------------------------------------------------------------------------
CREATE ROLE asu_tp_service WITH
    LOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    INHERIT
    NOREPLICATION
    CONNECTION LIMIT 5
    PASSWORD 'CHANGE_THIS_PASSWORD';

COMMENT ON ROLE asu_tp_service IS 'Сервисная учетная запись для внешних систем';

-- ==============================================================================
-- ПРЕДОСТАВЛЕНИЕ ПРАВ НА СХЕМЫ
-- ==============================================================================

-- Администратор - полный доступ ко всем схемам
GRANT ALL PRIVILEGES ON ALL SCHEMAS TO asu_tp_admin;

-- Инженер - полный доступ к техническим схемам
GRANT ALL ON SCHEMA tech_params TO asu_tp_engineer;
GRANT ALL ON SCHEMA controllers TO asu_tp_engineer;
GRANT ALL ON SCHEMA algorithms TO asu_tp_engineer;
GRANT ALL ON SCHEMA visualization TO asu_tp_engineer;
GRANT ALL ON SCHEMA topology TO asu_tp_engineer;
GRANT ALL ON SCHEMA kross TO asu_tp_engineer;
GRANT USAGE ON SCHEMA core TO asu_tp_engineer;
GRANT USAGE ON SCHEMA archive TO asu_tp_engineer;
GRANT USAGE ON SCHEMA events TO asu_tp_engineer;
GRANT USAGE ON SCHEMA security TO asu_tp_engineer;
GRANT USAGE ON SCHEMA reports TO asu_tp_engineer;

-- Оператор - ограниченный доступ
GRANT USAGE ON SCHEMA tech_params TO asu_tp_operator;
GRANT USAGE ON SCHEMA controllers TO asu_tp_operator;
GRANT USAGE ON SCHEMA visualization TO asu_tp_operator;
GRANT USAGE ON SCHEMA events TO asu_tp_operator;
GRANT USAGE ON SCHEMA reports TO asu_tp_operator;
GRANT USAGE ON SCHEMA core TO asu_tp_operator;
GRANT USAGE ON SCHEMA archive TO asu_tp_operator;

-- Наблюдатель - только чтение
GRANT USAGE ON SCHEMA tech_params TO asu_tp_viewer;
GRANT USAGE ON SCHEMA controllers TO asu_tp_viewer;
GRANT USAGE ON SCHEMA visualization TO asu_tp_viewer;
GRANT USAGE ON SCHEMA topology TO asu_tp_viewer;
GRANT USAGE ON SCHEMA core TO asu_tp_viewer;
GRANT USAGE ON SCHEMA archive TO asu_tp_viewer;
GRANT USAGE ON SCHEMA events TO asu_tp_viewer;
GRANT USAGE ON SCHEMA reports TO asu_tp_viewer;

-- Сервисная учетная запись
GRANT USAGE ON SCHEMA tech_params TO asu_tp_service;
GRANT USAGE ON SCHEMA archive TO asu_tp_service;
GRANT USAGE ON SCHEMA core TO asu_tp_service;

-- ==============================================================================
-- ПРЕДОСТАВЛЕНИЕ ПРАВ НА ТАБЛИЦЫ
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Права для ИНЖЕНЕРА
-- ------------------------------------------------------------------------------

-- Полный доступ к техническим параметрам
GRANT ALL ON ALL TABLES IN SCHEMA tech_params TO asu_tp_engineer;
GRANT ALL ON ALL SEQUENCES IN SCHEMA tech_params TO asu_tp_engineer;

-- Полный доступ к контроллерам
GRANT ALL ON ALL TABLES IN SCHEMA controllers TO asu_tp_engineer;
GRANT ALL ON ALL SEQUENCES IN SCHEMA controllers TO asu_tp_engineer;

-- Полный доступ к алгоритмам
GRANT ALL ON ALL TABLES IN SCHEMA algorithms TO asu_tp_engineer;
GRANT ALL ON ALL SEQUENCES IN SCHEMA algorithms TO asu_tp_engineer;

-- Полный доступ к визуализации
GRANT ALL ON ALL TABLES IN SCHEMA visualization TO asu_tp_engineer;
GRANT ALL ON ALL SEQUENCES IN SCHEMA visualization TO asu_tp_engineer;

-- Полный доступ к топологии
GRANT ALL ON ALL TABLES IN SCHEMA topology TO asu_tp_engineer;
GRANT ALL ON ALL SEQUENCES IN SCHEMA topology TO asu_tp_engineer;

-- Чтение справочников
GRANT SELECT ON ALL TABLES IN SCHEMA core TO asu_tp_engineer;

-- Чтение архивов
GRANT SELECT ON ALL TABLES IN SCHEMA archive TO asu_tp_engineer;

-- Управление событиями
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA events TO asu_tp_engineer;
GRANT ALL ON ALL SEQUENCES IN SCHEMA events TO asu_tp_engineer;

-- ------------------------------------------------------------------------------
-- Права для ОПЕРАТОРА
-- ------------------------------------------------------------------------------

-- Чтение и изменение текущих значений параметров
GRANT SELECT ON tech_params.parameters TO asu_tp_operator;
GRANT SELECT ON tech_params.parameter_groups TO asu_tp_operator;
GRANT SELECT, UPDATE ON tech_params.current_values TO asu_tp_operator;

-- Чтение контроллеров
GRANT SELECT ON ALL TABLES IN SCHEMA controllers TO asu_tp_operator;

-- Чтение визуализации
GRANT SELECT ON ALL TABLES IN SCHEMA visualization TO asu_tp_operator;

-- Работа с событиями
GRANT SELECT ON events.event_classes TO asu_tp_operator;
GRANT SELECT, INSERT, UPDATE ON events.events TO asu_tp_operator;

-- Чтение архивов
GRANT SELECT ON ALL TABLES IN SCHEMA archive TO asu_tp_operator;

-- Генерация отчетов
GRANT SELECT ON reports.report_templates TO asu_tp_operator;
GRANT SELECT, INSERT ON reports.report_history TO asu_tp_operator;

-- Чтение справочников
GRANT SELECT ON ALL TABLES IN SCHEMA core TO asu_tp_operator;

-- ------------------------------------------------------------------------------
-- Права для НАБЛЮДАТЕЛЯ
-- ------------------------------------------------------------------------------

-- Только чтение всех данных
GRANT SELECT ON ALL TABLES IN SCHEMA tech_params TO asu_tp_viewer;
GRANT SELECT ON ALL TABLES IN SCHEMA controllers TO asu_tp_viewer;
GRANT SELECT ON ALL TABLES IN SCHEMA visualization TO asu_tp_viewer;
GRANT SELECT ON ALL TABLES IN SCHEMA topology TO asu_tp_viewer;
GRANT SELECT ON ALL TABLES IN SCHEMA core TO asu_tp_viewer;
GRANT SELECT ON ALL TABLES IN SCHEMA archive TO asu_tp_viewer;
GRANT SELECT ON ALL TABLES IN SCHEMA events TO asu_tp_viewer;
GRANT SELECT ON ALL TABLES IN SCHEMA reports TO asu_tp_viewer;

-- ------------------------------------------------------------------------------
-- Права для СЕРВИСНОЙ учетной записи
-- ------------------------------------------------------------------------------

-- Чтение параметров и запись текущих значений
GRANT SELECT ON tech_params.parameters TO asu_tp_service;
GRANT SELECT, INSERT, UPDATE ON tech_params.current_values TO asu_tp_service;

-- Запись архивных данных
GRANT INSERT ON archive.historical_data TO asu_tp_service;

-- Чтение справочников
GRANT SELECT ON ALL TABLES IN SCHEMA core TO asu_tp_service;

-- ==============================================================================
-- СОЗДАНИЕ ПОЛИТИК БЕЗОПАСНОСТИ (Row Level Security)
-- ==============================================================================

-- Включение RLS для таблицы пользователей
ALTER TABLE security.users ENABLE ROW LEVEL SECURITY;

-- Политика: пользователи видят только свою информацию
CREATE POLICY users_self_view ON security.users
    FOR SELECT
    USING (id = current_setting('app.current_user_id')::UUID OR 
           EXISTS (SELECT 1 FROM security.user_roles ur
                   JOIN security.roles r ON ur.role_id = r.id
                   WHERE ur.user_id = current_setting('app.current_user_id')::UUID
                   AND r.code = 'admin'));

-- Включение RLS для таблицы object_permissions
ALTER TABLE security.object_permissions ENABLE ROW LEVEL SECURITY;

-- Политика: доступ к объектам согласно разрешениям
CREATE POLICY object_access_policy ON security.object_permissions
    FOR ALL
    USING (user_id = current_setting('app.current_user_id')::UUID OR
           EXISTS (SELECT 1 FROM security.user_roles ur
                   JOIN security.roles r ON ur.role_id = r.id
                   WHERE ur.user_id = current_setting('app.current_user_id')::UUID
                   AND r.code = 'admin'));

-- ==============================================================================
-- ВСТАВКА НАЧАЛЬНЫХ ДАННЫХ О РОЛЯХ В ТАБЛИЦЫ ПРИЛОЖЕНИЯ
-- ==============================================================================

-- Вставка системных ролей
INSERT INTO security.roles (code, name, description, priority, is_system) VALUES
    ('admin', 'Администратор', 'Полный доступ к системе', 1000, true),
    ('engineer', 'Инженер АСУ ТП', 'Настройка и конфигурирование системы', 800, true),
    ('senior_operator', 'Старший оператор', 'Управление процессом и квитирование аварий', 600, true),
    ('operator', 'Оператор', 'Мониторинг и базовое управление', 400, true),
    ('viewer', 'Наблюдатель', 'Только просмотр данных', 200, true),
    ('service', 'Сервисный аккаунт', 'Для внешних систем и интеграций', 100, true)
ON CONFLICT (code) DO NOTHING;

-- Вставка базовых разрешений
INSERT INTO security.permissions (code, name, resource, action, is_system) VALUES
    -- Параметры
    ('parameters.create', 'Создание параметров', 'parameters', 'create', true),
    ('parameters.read', 'Чтение параметров', 'parameters', 'read', true),
    ('parameters.update', 'Изменение параметров', 'parameters', 'update', true),
    ('parameters.delete', 'Удаление параметров', 'parameters', 'delete', true),
    ('parameters.write_value', 'Запись значений параметров', 'parameters', 'write_value', true),
    
    -- Контроллеры
    ('controllers.create', 'Создание контроллеров', 'controllers', 'create', true),
    ('controllers.read', 'Чтение конфигурации контроллеров', 'controllers', 'read', true),
    ('controllers.update', 'Изменение контроллеров', 'controllers', 'update', true),
    ('controllers.delete', 'Удаление контроллеров', 'controllers', 'delete', true),
    ('controllers.command', 'Отправка команд контроллерам', 'controllers', 'command', true),
    
    -- Алгоритмы
    ('algorithms.create', 'Создание алгоритмов', 'algorithms', 'create', true),
    ('algorithms.read', 'Просмотр алгоритмов', 'algorithms', 'read', true),
    ('algorithms.update', 'Изменение алгоритмов', 'algorithms', 'update', true),
    ('algorithms.delete', 'Удаление алгоритмов', 'algorithms', 'delete', true),
    ('algorithms.execute', 'Выполнение алгоритмов', 'algorithms', 'execute', true),
    
    -- События
    ('events.read', 'Просмотр событий', 'events', 'read', true),
    ('events.acknowledge', 'Квитирование событий', 'events', 'acknowledge', true),
    ('events.comment', 'Комментирование событий', 'events', 'comment', true),
    
    -- Отчеты
    ('reports.create', 'Создание отчетов', 'reports', 'create', true),
    ('reports.read', 'Просмотр отчетов', 'reports', 'read', true),
    ('reports.generate', 'Генерация отчетов', 'reports', 'generate', true),
    ('reports.schedule', 'Планирование отчетов', 'reports', 'schedule', true),
    
    -- Пользователи
    ('users.create', 'Создание пользователей', 'users', 'create', true),
    ('users.read', 'Просмотр пользователей', 'users', 'read', true),
    ('users.update', 'Изменение пользователей', 'users', 'update', true),
    ('users.delete', 'Удаление пользователей', 'users', 'delete', true),
    ('users.assign_roles', 'Назначение ролей', 'users', 'assign_roles', true)
ON CONFLICT (code) DO NOTHING;

-- ==============================================================================
-- СВЯЗЫВАНИЕ РОЛЕЙ С РАЗРЕШЕНИЯМИ
-- ==============================================================================

-- Администратор - все разрешения
INSERT INTO security.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM security.roles r
CROSS JOIN security.permissions p
WHERE r.code = 'admin'
ON CONFLICT DO NOTHING;

-- Инженер
INSERT INTO security.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM security.roles r
CROSS JOIN security.permissions p
WHERE r.code = 'engineer'
AND p.code IN (
    'parameters.create', 'parameters.read', 'parameters.update', 'parameters.write_value',
    'controllers.read', 'controllers.update', 'controllers.command',
    'algorithms.create', 'algorithms.read', 'algorithms.update', 'algorithms.execute',
    'events.read', 'events.acknowledge', 'events.comment',
    'reports.read', 'reports.generate', 'reports.schedule'
)
ON CONFLICT DO NOTHING;

-- Старший оператор
INSERT INTO security.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM security.roles r
CROSS JOIN security.permissions p
WHERE r.code = 'senior_operator'
AND p.code IN (
    'parameters.read', 'parameters.write_value',
    'controllers.read', 'controllers.command',
    'algorithms.read', 'algorithms.execute',
    'events.read', 'events.acknowledge', 'events.comment',
    'reports.read', 'reports.generate'
)
ON CONFLICT DO NOTHING;

-- Оператор
INSERT INTO security.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM security.roles r
CROSS JOIN security.permissions p
WHERE r.code = 'operator'
AND p.code IN (
    'parameters.read', 'parameters.write_value',
    'controllers.read',
    'events.read', 'events.comment',
    'reports.read'
)
ON CONFLICT DO NOTHING;

-- Наблюдатель
INSERT INTO security.role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM security.roles r
CROSS JOIN security.permissions p
WHERE r.code = 'viewer'
AND p.code IN (
    'parameters.read',
    'controllers.read',
    'events.read',
    'reports.read'
)
ON CONFLICT DO NOTHING;

-- ==============================================================================
-- СОЗДАНИЕ ФУНКЦИЙ ДЛЯ УПРАВЛЕНИЯ ДОСТУПОМ
-- ==============================================================================

-- Функция проверки разрешения пользователя
CREATE OR REPLACE FUNCTION security.check_permission(
    p_user_id UUID,
    p_resource VARCHAR,
    p_action VARCHAR
) RETURNS BOOLEAN AS $$
DECLARE
    v_has_permission BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1
        FROM security.user_roles ur
        JOIN security.role_permissions rp ON ur.role_id = rp.role_id
        JOIN security.permissions p ON rp.permission_id = p.id
        WHERE ur.user_id = p_user_id
        AND p.resource = p_resource
        AND p.action = p_action
    ) INTO v_has_permission;
    
    RETURN v_has_permission;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Функция проверки доступа к объекту
CREATE OR REPLACE FUNCTION security.check_object_access(
    p_user_id UUID,
    p_object_type VARCHAR,
    p_object_id UUID,
    p_permission_type VARCHAR
) RETURNS BOOLEAN AS $$
DECLARE
    v_has_access BOOLEAN;
BEGIN
    -- Проверка прямого доступа к объекту
    SELECT EXISTS (
        SELECT 1
        FROM security.object_permissions op
        WHERE op.user_id = p_user_id
        AND op.object_type = p_object_type
        AND op.object_id = p_object_id
        AND op.permission_type = p_permission_type
        AND (op.expires_at IS NULL OR op.expires_at > CURRENT_TIMESTAMP)
    ) INTO v_has_access;
    
    -- Если прямого доступа нет, проверяем роль администратора
    IF NOT v_has_access THEN
        SELECT EXISTS (
            SELECT 1
            FROM security.user_roles ur
            JOIN security.roles r ON ur.role_id = r.id
            WHERE ur.user_id = p_user_id
            AND r.code = 'admin'
        ) INTO v_has_access;
    END IF;
    
    RETURN v_has_access;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ==============================================================================
-- СОЗДАНИЕ ПРЕДСТАВЛЕНИЙ ДЛЯ УДОБНОЙ РАБОТЫ С ПРАВАМИ
-- ==============================================================================

-- Представление: права текущего пользователя
CREATE OR REPLACE VIEW security.my_permissions AS
SELECT DISTINCT
    p.code,
    p.name,
    p.resource,
    p.action
FROM security.permissions p
JOIN security.role_permissions rp ON p.id = rp.permission_id
JOIN security.user_roles ur ON rp.role_id = ur.role_id
WHERE ur.user_id = current_setting('app.current_user_id')::UUID;

-- Представление: доступные объекты для текущего пользователя
CREATE OR REPLACE VIEW security.my_accessible_objects AS
SELECT
    op.object_type,
    op.object_id,
    op.permission_type,
    op.granted_at,
    op.expires_at
FROM security.object_permissions op
WHERE op.user_id = current_setting('app.current_user_id')::UUID
AND (op.expires_at IS NULL OR op.expires_at > CURRENT_TIMESTAMP);

-- ==============================================================================
-- СОЗДАНИЕ ПОЛЬЗОВАТЕЛЯ ПО УМОЛЧАНИЮ (АДМИНИСТРАТОР)
-- ==============================================================================

-- Создание первого администратора системы
INSERT INTO security.users (username, email, password_hash, full_name, position, is_active)
VALUES (
    'admin',
    'admin@asu-tp.local',
    crypt('AdminPassword123!', gen_salt('bf')), -- Использование bcrypt для хэширования
    'Системный администратор',
    'Администратор АСУ ТП',
    true
) ON CONFLICT (username) DO NOTHING;

-- Назначение роли администратора
INSERT INTO security.user_roles (user_id, role_id)
SELECT u.id, r.id
FROM security.users u
CROSS JOIN security.roles r
WHERE u.username = 'admin'
AND r.code = 'admin'
ON CONFLICT DO NOTHING;

-- ==============================================================================
-- НАСТРОЙКА ПАРАМЕТРОВ БЕЗОПАСНОСТИ
-- ==============================================================================

-- Настройка параметров паролей
ALTER SYSTEM SET password_encryption = 'scram-sha-256';

-- Настройка SSL
-- ALTER SYSTEM SET ssl = on;
-- ALTER SYSTEM SET ssl_cert_file = 'server.crt';
-- ALTER SYSTEM SET ssl_key_file = 'server.key';

-- Применение настроек
SELECT pg_reload_conf();

-- ==============================================================================
-- ВЫВОД ИНФОРМАЦИИ О СОЗДАННЫХ РОЛЯХ
-- ==============================================================================

SELECT 'Роли PostgreSQL созданы:' AS info;
SELECT rolname, rolsuper, rolinherit, rolcreaterole, rolcreatedb, rolcanlogin 
FROM pg_roles 
WHERE rolname LIKE 'asu_tp_%'
ORDER BY rolname;

SELECT 'Роли приложения созданы:' AS info;
SELECT code, name, priority, is_system 
FROM security.roles 
ORDER BY priority DESC;



