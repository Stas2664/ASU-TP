-- ==============================================================================
-- Загрузка начальных данных в БД ПТК АСУ ТП
-- База данных: asu_tp_db
-- Справочники, тестовые данные и примеры
-- ==============================================================================

\c asu_tp_db;

-- ==============================================================================
-- CORE SCHEMA - Справочные данные
-- ==============================================================================

-- Единицы измерения
INSERT INTO core.units (code, name, symbol, unit_type, conversion_factor) VALUES
    -- Температура
    ('CELSIUS', 'Градус Цельсия', '°C', 'temperature', 1.0),
    ('KELVIN', 'Кельвин', 'K', 'temperature', 1.0),
    ('FAHRENHEIT', 'Градус Фаренгейта', '°F', 'temperature', 1.0),
    
    -- Давление
    ('PA', 'Паскаль', 'Па', 'pressure', 1.0),
    ('KPA', 'Килопаскаль', 'кПа', 'pressure', 1000.0),
    ('MPA', 'Мегапаскаль', 'МПа', 'pressure', 1000000.0),
    ('BAR', 'Бар', 'бар', 'pressure', 100000.0),
    ('ATM', 'Атмосфера', 'атм', 'pressure', 101325.0),
    ('MMHG', 'Миллиметр ртутного столба', 'мм рт.ст.', 'pressure', 133.322),
    ('KGF_CM2', 'Килограмм-сила на см²', 'кгс/см²', 'pressure', 98066.5),
    
    -- Расход
    ('M3_H', 'Кубометр в час', 'м³/ч', 'flow', 1.0),
    ('M3_S', 'Кубометр в секунду', 'м³/с', 'flow', 3600.0),
    ('L_S', 'Литр в секунду', 'л/с', 'flow', 3.6),
    ('L_MIN', 'Литр в минуту', 'л/мин', 'flow', 0.06),
    ('T_H', 'Тонна в час', 'т/ч', 'flow_mass', 1.0),
    ('KG_S', 'Килограмм в секунду', 'кг/с', 'flow_mass', 3.6),
    
    -- Уровень
    ('MM', 'Миллиметр', 'мм', 'length', 0.001),
    ('CM', 'Сантиметр', 'см', 'length', 0.01),
    ('M', 'Метр', 'м', 'length', 1.0),
    
    -- Электрические
    ('V', 'Вольт', 'В', 'voltage', 1.0),
    ('KV', 'Киловольт', 'кВ', 'voltage', 1000.0),
    ('A', 'Ампер', 'А', 'current', 1.0),
    ('MA', 'Миллиампер', 'мА', 'current', 0.001),
    ('MW', 'Мегаватт', 'МВт', 'power', 1000000.0),
    ('KW', 'Киловатт', 'кВт', 'power', 1000.0),
    ('W', 'Ватт', 'Вт', 'power', 1.0),
    
    -- Частота
    ('HZ', 'Герц', 'Гц', 'frequency', 1.0),
    ('RPM', 'Оборотов в минуту', 'об/мин', 'frequency', 0.0166667),
    
    -- Процент и безразмерные
    ('PERCENT', 'Процент', '%', 'dimensionless', 1.0),
    ('PPM', 'Миллионная доля', 'ppm', 'dimensionless', 0.0001),
    ('UNIT', 'Единица', 'ед', 'dimensionless', 1.0),
    
    -- Время
    ('SEC', 'Секунда', 'с', 'time', 1.0),
    ('MIN', 'Минута', 'мин', 'time', 60.0),
    ('HOUR', 'Час', 'ч', 'time', 3600.0),
    ('DAY', 'Сутки', 'сут', 'time', 86400.0)
ON CONFLICT (code) DO NOTHING;

-- Типы данных
INSERT INTO core.data_types (code, name, postgres_type, min_value, max_value, precision) VALUES
    ('BOOL', 'Логический', 'BOOLEAN', NULL, NULL, NULL),
    ('INT16', 'Целое 16 бит', 'SMALLINT', -32768, 32767, 0),
    ('INT32', 'Целое 32 бит', 'INTEGER', -2147483648, 2147483647, 0),
    ('INT64', 'Целое 64 бит', 'BIGINT', -9223372036854775808, 9223372036854775807, 0),
    ('UINT16', 'Беззнаковое 16 бит', 'INTEGER', 0, 65535, 0),
    ('UINT32', 'Беззнаковое 32 бит', 'BIGINT', 0, 4294967295, 0),
    ('FLOAT32', 'Вещественное 32 бит', 'REAL', NULL, NULL, 7),
    ('FLOAT64', 'Вещественное 64 бит', 'DOUBLE PRECISION', NULL, NULL, 15),
    ('STRING', 'Строка', 'TEXT', NULL, NULL, NULL),
    ('DATETIME', 'Дата и время', 'TIMESTAMP WITH TIME ZONE', NULL, NULL, NULL)
ON CONFLICT (code) DO NOTHING;

-- Статусы
INSERT INTO core.statuses (code, name, status_group, color_code, priority) VALUES
    -- Операционные статусы
    ('ONLINE', 'В сети', 'operational', '#00FF00', 100),
    ('OFFLINE', 'Не в сети', 'operational', '#808080', 90),
    ('RUNNING', 'Работает', 'operational', '#00FF00', 100),
    ('STOPPED', 'Остановлен', 'operational', '#FF0000', 80),
    ('STARTING', 'Запускается', 'operational', '#FFFF00', 95),
    ('STOPPING', 'Останавливается', 'operational', '#FFA500', 85),
    
    -- Статусы тревог
    ('NORMAL', 'Норма', 'alarm', '#00FF00', 100),
    ('WARNING', 'Предупреждение', 'alarm', '#FFFF00', 70),
    ('ALARM', 'Авария', 'alarm', '#FF0000', 50),
    ('CRITICAL', 'Критическая авария', 'alarm', '#FF00FF', 30),
    
    -- Статусы обслуживания
    ('ACTIVE', 'Активен', 'maintenance', '#00FF00', 100),
    ('MAINTENANCE', 'Обслуживание', 'maintenance', '#FFA500', 60),
    ('DISABLED', 'Отключен', 'maintenance', '#808080', 40),
    ('FAILED', 'Неисправен', 'maintenance', '#FF0000', 20)
ON CONFLICT (code) DO NOTHING;

-- ==============================================================================
-- TECH_PARAMS SCHEMA - Группы и параметры
-- ==============================================================================

-- Группы параметров (иерархия)
INSERT INTO tech_params.parameter_groups (code, name, description, parent_id, sort_order) VALUES
    ('ROOT', 'Корневая группа', 'Корневая группа всех параметров', NULL, 0),
    ('POWER', 'Энергоблок', 'Параметры энергоблока', (SELECT id FROM tech_params.parameter_groups WHERE code = 'ROOT'), 100),
    ('REACTOR', 'Реактор', 'Параметры реакторной установки', (SELECT id FROM tech_params.parameter_groups WHERE code = 'POWER'), 110),
    ('TURBINE', 'Турбина', 'Параметры турбинной установки', (SELECT id FROM tech_params.parameter_groups WHERE code = 'POWER'), 120),
    ('GENERATOR', 'Генератор', 'Параметры генератора', (SELECT id FROM tech_params.parameter_groups WHERE code = 'POWER'), 130),
    ('COOLING', 'Системы охлаждения', 'Параметры систем охлаждения', (SELECT id FROM tech_params.parameter_groups WHERE code = 'ROOT'), 200),
    ('PRIMARY', 'Первый контур', 'Параметры первого контура', (SELECT id FROM tech_params.parameter_groups WHERE code = 'COOLING'), 210),
    ('SECONDARY', 'Второй контур', 'Параметры второго контура', (SELECT id FROM tech_params.parameter_groups WHERE code = 'COOLING'), 220),
    ('AUXILIARY', 'Вспомогательные системы', 'Вспомогательные системы', (SELECT id FROM tech_params.parameter_groups WHERE code = 'ROOT'), 300)
ON CONFLICT (code) DO NOTHING;

-- Пример технологических параметров
INSERT INTO tech_params.parameters (
    tag, name, short_name, description, 
    parameter_type, data_type_id, unit_id, group_id,
    min_value, max_value, nominal_value,
    alarm_low_low, alarm_low, alarm_high, alarm_high_high,
    is_archived, archive_interval_sec, scan_interval_ms,
    source_type, is_active
) VALUES
    -- Параметры реактора
    ('REACTOR.POWER', 'Тепловая мощность реактора', 'N реактора', 'Текущая тепловая мощность реакторной установки',
     'analog', (SELECT id FROM core.data_types WHERE code = 'FLOAT32'), 
     (SELECT id FROM core.units WHERE code = 'MW'),
     (SELECT id FROM tech_params.parameter_groups WHERE code = 'REACTOR'),
     0, 3200, 3000,
     500, 1000, 3100, 3150,
     true, 10, 1000, 'controller', true),
     
    ('REACTOR.TEMP_CORE', 'Температура активной зоны', 'T а.з.', 'Средняя температура в активной зоне',
     'analog', (SELECT id FROM core.data_types WHERE code = 'FLOAT32'),
     (SELECT id FROM core.units WHERE code = 'CELSIUS'),
     (SELECT id FROM tech_params.parameter_groups WHERE code = 'REACTOR'),
     0, 400, 320,
     280, 290, 340, 350,
     true, 5, 500, 'controller', true),
     
    -- Параметры первого контура
    ('PRIMARY.PRESSURE', 'Давление в первом контуре', 'P1к', 'Давление теплоносителя первого контура',
     'analog', (SELECT id FROM core.data_types WHERE code = 'FLOAT32'),
     (SELECT id FROM core.units WHERE code = 'MPA'),
     (SELECT id FROM tech_params.parameter_groups WHERE code = 'PRIMARY'),
     0, 20, 16,
     14, 14.5, 17, 17.5,
     true, 5, 500, 'controller', true),
     
    ('PRIMARY.TEMP_HOT', 'Температура горячей нитки', 'T гор', 'Температура теплоносителя на выходе из реактора',
     'analog', (SELECT id FROM core.data_types WHERE code = 'FLOAT32'),
     (SELECT id FROM core.units WHERE code = 'CELSIUS'),
     (SELECT id FROM tech_params.parameter_groups WHERE code = 'PRIMARY'),
     0, 350, 320,
     300, 310, 330, 335,
     true, 5, 500, 'controller', true),
     
    ('PRIMARY.TEMP_COLD', 'Температура холодной нитки', 'T хол', 'Температура теплоносителя на входе в реактор',
     'analog', (SELECT id FROM core.data_types WHERE code = 'FLOAT32'),
     (SELECT id FROM core.units WHERE code = 'CELSIUS'),
     (SELECT id FROM tech_params.parameter_groups WHERE code = 'PRIMARY'),
     0, 300, 280,
     260, 270, 290, 295,
     true, 5, 500, 'controller', true),
     
    ('PRIMARY.FLOW', 'Расход теплоносителя', 'G1к', 'Расход теплоносителя первого контура',
     'analog', (SELECT id FROM core.data_types WHERE code = 'FLOAT32'),
     (SELECT id FROM core.units WHERE code = 'T_H'),
     (SELECT id FROM tech_params.parameter_groups WHERE code = 'PRIMARY'),
     0, 20000, 17000,
     15000, 16000, 18000, 18500,
     true, 10, 1000, 'controller', true),
     
    -- Параметры турбины
    ('TURBINE.SPEED', 'Частота вращения турбины', 'n турб', 'Частота вращения ротора турбины',
     'analog', (SELECT id FROM core.data_types WHERE code = 'FLOAT32'),
     (SELECT id FROM core.units WHERE code = 'RPM'),
     (SELECT id FROM tech_params.parameter_groups WHERE code = 'TURBINE'),
     0, 3600, 3000,
     2850, 2900, 3100, 3150,
     true, 1, 100, 'controller', true),
     
    ('TURBINE.VIBRATION', 'Вибрация турбины', 'V турб', 'Уровень вибрации подшипников турбины',
     'analog', (SELECT id FROM core.data_types WHERE code = 'FLOAT32'),
     (SELECT id FROM core.units WHERE code = 'MM'),
     (SELECT id FROM tech_params.parameter_groups WHERE code = 'TURBINE'),
     0, 100, 30,
     NULL, NULL, 70, 90,
     true, 10, 1000, 'controller', true),
     
    -- Параметры генератора
    ('GENERATOR.POWER_ACTIVE', 'Активная мощность', 'P ген', 'Активная электрическая мощность генератора',
     'analog', (SELECT id FROM core.data_types WHERE code = 'FLOAT32'),
     (SELECT id FROM core.units WHERE code = 'MW'),
     (SELECT id FROM tech_params.parameter_groups WHERE code = 'GENERATOR'),
     0, 1200, 1000,
     100, 200, 1100, 1150,
     true, 5, 500, 'controller', true),
     
    ('GENERATOR.VOLTAGE', 'Напряжение генератора', 'U ген', 'Напряжение на выводах генератора',
     'analog', (SELECT id FROM core.data_types WHERE code = 'FLOAT32'),
     (SELECT id FROM core.units WHERE code = 'KV'),
     (SELECT id FROM tech_params.parameter_groups WHERE code = 'GENERATOR'),
     0, 25, 20,
     18, 19, 21, 22,
     true, 5, 500, 'controller', true),
     
    -- Дискретные параметры
    ('REACTOR.SCRAM', 'Аварийная защита реактора', 'АЗ', 'Состояние аварийной защиты',
     'discrete', (SELECT id FROM core.data_types WHERE code = 'BOOL'),
     NULL,
     (SELECT id FROM tech_params.parameter_groups WHERE code = 'REACTOR'),
     NULL, NULL, NULL,
     NULL, NULL, NULL, NULL,
     true, 60, 100, 'controller', true),
     
    ('PRIMARY.PUMP1.STATUS', 'ГЦН-1 Состояние', 'ГЦН-1', 'Состояние главного циркуляционного насоса №1',
     'discrete', (SELECT id FROM core.data_types WHERE code = 'BOOL'),
     NULL,
     (SELECT id FROM tech_params.parameter_groups WHERE code = 'PRIMARY'),
     NULL, NULL, NULL,
     NULL, NULL, NULL, NULL,
     true, 60, 100, 'controller', true),
     
    -- Расчетные параметры
    ('CALC.EFFICIENCY', 'КПД энергоблока', 'КПД', 'Расчетный КПД энергоблока',
     'calculated', (SELECT id FROM core.data_types WHERE code = 'FLOAT32'),
     (SELECT id FROM core.units WHERE code = 'PERCENT'),
     (SELECT id FROM tech_params.parameter_groups WHERE code = 'POWER'),
     0, 100, 33,
     28, 30, 36, 38,
     true, 60, 5000, 'calculated', true)
ON CONFLICT (tag) DO NOTHING;

-- ==============================================================================
-- CONTROLLERS SCHEMA - Контроллеры и модули
-- ==============================================================================

-- Типы контроллеров
INSERT INTO controllers.controller_types (code, name, manufacturer, model, communication_protocol) VALUES
    ('KUPRI_V3', 'КУПРИ версия 3', 'НПП ВНИИЭМ', 'КУПРИ-3', 'Modbus TCP'),
    ('SIEMENS_S7_1500', 'Siemens S7-1500', 'Siemens', 'S7-1500', 'Profinet'),
    ('ALLEN_BRADLEY', 'Allen-Bradley ControlLogix', 'Rockwell', 'ControlLogix 5580', 'EtherNet/IP'),
    ('SCHNEIDER_M580', 'Schneider Modicon M580', 'Schneider Electric', 'M580', 'Modbus TCP')
ON CONFLICT (code) DO NOTHING;

-- Пример контроллеров
INSERT INTO controllers.controllers (
    name, controller_type_id, inventory_number,
    ip_address, location, status_id, is_online
) VALUES
    ('Контроллер реактора №1', 
     (SELECT id FROM controllers.controller_types WHERE code = 'KUPRI_V3'),
     'PLC-REACTOR-001', '192.168.1.101', 'Щит управления реактора, шкаф А1',
     (SELECT id FROM core.statuses WHERE code = 'ONLINE'), true),
     
    ('Контроллер турбины №1',
     (SELECT id FROM controllers.controller_types WHERE code = 'SIEMENS_S7_1500'),
     'PLC-TURBINE-001', '192.168.1.201', 'Машинный зал, щит управления турбины',
     (SELECT id FROM core.statuses WHERE code = 'ONLINE'), true),
     
    ('Контроллер ГЦН',
     (SELECT id FROM controllers.controller_types WHERE code = 'KUPRI_V3'),
     'PLC-PUMP-001', '192.168.1.301', 'Насосная станция, шкаф управления',
     (SELECT id FROM core.statuses WHERE code = 'ONLINE'), true)
ON CONFLICT (inventory_number) DO NOTHING;

-- ==============================================================================
-- ALGORITHMS SCHEMA - Типы алгоритмов и примеры
-- ==============================================================================

-- Типы алгоритмов
INSERT INTO algorithms.algorithm_types (code, name, description) VALUES
    ('CALCULATION', 'Расчетный', 'Алгоритмы расчета производных параметров'),
    ('OPTIMIZATION', 'Оптимизационный', 'Алгоритмы оптимизации режимов'),
    ('DIAGNOSTIC', 'Диагностический', 'Алгоритмы диагностики оборудования'),
    ('PREDICTION', 'Прогнозный', 'Алгоритмы прогнозирования'),
    ('PROTECTION', 'Защитный', 'Алгоритмы защит и блокировок')
ON CONFLICT (code) DO NOTHING;

-- Пример алгоритма расчета КПД
INSERT INTO algorithms.algorithms (
    type_id, code, name, description,
    language, source_code, execution_interval_ms, priority, is_active
) VALUES
    ((SELECT id FROM algorithms.algorithm_types WHERE code = 'CALCULATION'),
     'CALC_EFFICIENCY', 'Расчет КПД энергоблока', 'Расчет текущего КПД энергоблока',
     'sql', 
     '
     WITH power_data AS (
         SELECT 
             (SELECT value::NUMERIC FROM tech_params.current_values 
              WHERE parameter_id = (SELECT id FROM tech_params.parameters WHERE tag = ''GENERATOR.POWER_ACTIVE'')) AS p_gen,
             (SELECT value::NUMERIC FROM tech_params.current_values 
              WHERE parameter_id = (SELECT id FROM tech_params.parameters WHERE tag = ''REACTOR.POWER'')) AS p_reactor
     )
     SELECT jsonb_build_object(
         ''efficiency'', 
         CASE 
             WHEN p_reactor > 0 THEN ROUND((p_gen / p_reactor) * 100, 2)
             ELSE 0
         END
     ) AS result
     FROM power_data;
     ',
     60000, 5, true)
ON CONFLICT (code) DO NOTHING;

-- ==============================================================================
-- EVENTS SCHEMA - Классы событий
-- ==============================================================================

-- Классы событий
INSERT INTO events.event_classes (code, name, severity, color, requires_acknowledgment, auto_acknowledge_timeout_min) VALUES
    ('INFO', 'Информационное', 'info', '#0000FF', false, NULL),
    ('WARNING_ALARM', 'Предупредительная сигнализация', 'warning', '#FFFF00', true, 60),
    ('CRITICAL_ALARM', 'Аварийная сигнализация', 'critical', '#FF0000', true, NULL),
    ('SYSTEM_EVENT', 'Системное событие', 'info', '#808080', false, NULL),
    ('OPERATOR_ACTION', 'Действие оператора', 'info', '#00FF00', false, NULL),
    ('EQUIPMENT_FAILURE', 'Отказ оборудования', 'major', '#FF8800', true, NULL),
    ('PROTECTION_TRIGGERED', 'Срабатывание защиты', 'critical', '#FF00FF', true, NULL)
ON CONFLICT (code) DO NOTHING;

-- ==============================================================================
-- TOPOLOGY SCHEMA - Типы узлов
-- ==============================================================================

-- Типы узлов
INSERT INTO topology.node_types (code, name, icon, color) VALUES
    ('SERVER', 'Сервер', 'server.png', '#0066CC'),
    ('WORKSTATION', 'АРМ оператора', 'workstation.png', '#00AA00'),
    ('PLC', 'Контроллер', 'plc.png', '#FF6600'),
    ('SWITCH', 'Коммутатор', 'switch.png', '#666666'),
    ('ROUTER', 'Маршрутизатор', 'router.png', '#996633'),
    ('HMI', 'Панель оператора', 'hmi.png', '#00CCCC'),
    ('HISTORIAN', 'Сервер истории', 'database.png', '#6600CC')
ON CONFLICT (code) DO NOTHING;

-- ==============================================================================
-- KROSS SCHEMA - Конфигурация платформы
-- ==============================================================================

-- Параметры конфигурации КРОСС
INSERT INTO kross.platform_config (parameter_name, parameter_value, parameter_type, category, description, requires_restart) VALUES
    ('system.name', 'ПТК АСУ ТП Энергоблок №1', 'string', 'system', 'Наименование системы', false),
    ('system.version', '1.0.0', 'string', 'system', 'Версия системы', false),
    ('database.pool.min', '10', 'integer', 'database', 'Минимальный размер пула соединений', true),
    ('database.pool.max', '200', 'integer', 'database', 'Максимальный размер пула соединений', true),
    ('archive.retention.days', '365', 'integer', 'archive', 'Срок хранения архивов (дней)', false),
    ('archive.compression.enabled', 'true', 'boolean', 'archive', 'Включить сжатие архивов', false),
    ('alarm.sound.enabled', 'true', 'boolean', 'alarm', 'Звуковая сигнализация', false),
    ('alarm.blink.rate', '500', 'integer', 'alarm', 'Частота мигания тревог (мс)', false),
    ('opc.server.port', '4840', 'integer', 'communication', 'Порт OPC UA сервера', true),
    ('modbus.timeout', '3000', 'integer', 'communication', 'Таймаут Modbus (мс)', false),
    ('log.level', 'INFO', 'string', 'logging', 'Уровень логирования', false),
    ('log.retention.days', '30', 'integer', 'logging', 'Срок хранения логов (дней)', false)
ON CONFLICT (parameter_name) DO NOTHING;

-- Модули КРОСС
INSERT INTO kross.modules (code, name, version, description, auto_start, start_order) VALUES
    ('CORE', 'Ядро системы', '1.0.0', 'Основной модуль платформы КРОСС', true, 1),
    ('DATA_ACQUISITION', 'Сбор данных', '1.0.0', 'Модуль сбора данных с контроллеров', true, 10),
    ('ARCHIVE', 'Архивирование', '1.0.0', 'Модуль архивирования данных', true, 20),
    ('ALARM', 'Тревоги и события', '1.0.0', 'Модуль обработки тревог', true, 30),
    ('CALCULATION', 'Расчеты', '1.0.0', 'Модуль выполнения алгоритмов', true, 40),
    ('VISUALIZATION', 'Визуализация', '1.0.0', 'Модуль визуализации', true, 50),
    ('REPORTING', 'Отчеты', '1.0.0', 'Модуль формирования отчетов', true, 60),
    ('OPC_SERVER', 'OPC UA Server', '1.0.0', 'OPC UA сервер', true, 70),
    ('WEB_SERVER', 'Web сервер', '1.0.0', 'Web интерфейс системы', true, 80)
ON CONFLICT (code) DO NOTHING;

-- ==============================================================================
-- VISUALIZATION SCHEMA - Проект визуализации
-- ==============================================================================

-- Проект визуализации
INSERT INTO visualization.projects (code, name, description, version, is_active) VALUES
    ('MAIN', 'Основной проект', 'Основной проект визуализации энергоблока', '1.0.0', true)
ON CONFLICT (code) DO NOTHING;

-- Пример видеокадров
INSERT INTO visualization.screens (
    project_id, code, name, screen_type, 
    width, height, is_home, sort_order
) VALUES
    ((SELECT id FROM visualization.projects WHERE code = 'MAIN'),
     'OVERVIEW', 'Общий вид', 'overview', 1920, 1080, true, 100),
    ((SELECT id FROM visualization.projects WHERE code = 'MAIN'),
     'REACTOR', 'Реакторная установка', 'detail', 1920, 1080, false, 200),
    ((SELECT id FROM visualization.projects WHERE code = 'MAIN'),
     'TURBINE', 'Турбинная установка', 'detail', 1920, 1080, false, 300),
    ((SELECT id FROM visualization.projects WHERE code = 'MAIN'),
     'TRENDS', 'Тренды', 'trend', 1920, 1080, false, 400),
    ((SELECT id FROM visualization.projects WHERE code = 'MAIN'),
     'ALARMS', 'Тревоги', 'alarm', 1920, 1080, false, 500)
ON CONFLICT (project_id, code) DO NOTHING;

-- ==============================================================================
-- REPORTS SCHEMA - Шаблоны отчетов
-- ==============================================================================

-- Шаблоны отчетов
INSERT INTO reports.report_templates (
    code, name, description, category, report_type, output_formats
) VALUES
    ('SHIFT_REPORT', 'Сменный журнал', 'Отчет за смену', 'operational', 'tabular', '["pdf", "excel"]'),
    ('DAILY_REPORT', 'Суточная ведомость', 'Суточный отчет о работе энергоблока', 'operational', 'combined', '["pdf", "excel"]'),
    ('ALARM_REPORT', 'Журнал тревог', 'Отчет по тревогам и событиям', 'events', 'tabular', '["pdf", "excel", "csv"]'),
    ('PARAMETER_TREND', 'График параметра', 'Тренд параметра за период', 'analytical', 'graphical', '["pdf", "png"]'),
    ('EFFICIENCY_REPORT', 'Отчет по КПД', 'Анализ эффективности работы', 'analytical', 'combined', '["pdf", "excel"]')
ON CONFLICT (code) DO NOTHING;

-- ==============================================================================
-- Инициализация текущих значений для примеров параметров
-- ==============================================================================

-- Генерация случайных текущих значений для демонстрации
INSERT INTO tech_params.current_values (parameter_id, value, quality, timestamp, source)
SELECT 
    id,
    CASE 
        WHEN parameter_type = 'analog' THEN
            ROUND((nominal_value + (random() - 0.5) * (max_value - min_value) * 0.1)::NUMERIC, 2)::TEXT
        WHEN parameter_type = 'discrete' THEN
            CASE WHEN random() > 0.5 THEN 'true' ELSE 'false' END
        WHEN parameter_type = 'calculated' THEN
            '33.5'
        ELSE '0'
    END,
    192,
    CURRENT_TIMESTAMP,
    'initial'
FROM tech_params.parameters
WHERE is_active = true
ON CONFLICT (parameter_id) DO UPDATE
SET value = EXCLUDED.value,
    quality = EXCLUDED.quality,
    timestamp = EXCLUDED.timestamp,
    source = EXCLUDED.source;

-- ==============================================================================
-- Создание тестовых пользователей (пароль для всех: Test123!)
-- ==============================================================================

INSERT INTO security.users (username, email, password_hash, full_name, position, is_active) VALUES
    ('engineer', 'engineer@asu-tp.local', crypt('Test123!', gen_salt('bf')), 'Иванов Иван Иванович', 'Инженер АСУ ТП', true),
    ('operator1', 'operator1@asu-tp.local', crypt('Test123!', gen_salt('bf')), 'Петров Петр Петрович', 'Оператор БЩУ', true),
    ('operator2', 'operator2@asu-tp.local', crypt('Test123!', gen_salt('bf')), 'Сидоров Сидор Сидорович', 'Оператор БЩУ', true),
    ('viewer', 'viewer@asu-tp.local', crypt('Test123!', gen_salt('bf')), 'Смирнов Алексей Николаевич', 'Начальник смены', true)
ON CONFLICT (username) DO NOTHING;

-- Назначение ролей пользователям
INSERT INTO security.user_roles (user_id, role_id)
SELECT u.id, r.id FROM security.users u, security.roles r
WHERE u.username = 'engineer' AND r.code = 'engineer'
ON CONFLICT DO NOTHING;

INSERT INTO security.user_roles (user_id, role_id)
SELECT u.id, r.id FROM security.users u, security.roles r
WHERE u.username = 'operator1' AND r.code = 'operator'
ON CONFLICT DO NOTHING;

INSERT INTO security.user_roles (user_id, role_id)
SELECT u.id, r.id FROM security.users u, security.roles r
WHERE u.username = 'operator2' AND r.code = 'operator'
ON CONFLICT DO NOTHING;

INSERT INTO security.user_roles (user_id, role_id)
SELECT u.id, r.id FROM security.users u, security.roles r
WHERE u.username = 'viewer' AND r.code = 'viewer'
ON CONFLICT DO NOTHING;

-- ==============================================================================
-- Генерация тестовых исторических данных
-- ==============================================================================

-- Генерация архивных данных за последние 24 часа для демонстрации
INSERT INTO archive.historical_data (parameter_id, timestamp, value, quality)
SELECT 
    p.id,
    generate_series(
        CURRENT_TIMESTAMP - INTERVAL '24 hours',
        CURRENT_TIMESTAMP,
        INTERVAL '5 minutes'
    ) AS ts,
    ROUND((p.nominal_value + (random() - 0.5) * (p.max_value - p.min_value) * 0.1)::NUMERIC, 2)::TEXT,
    192
FROM tech_params.parameters p
WHERE p.is_archived = true
AND p.parameter_type = 'analog'
LIMIT 10000  -- Ограничение для демо данных
ON CONFLICT DO NOTHING;

-- ==============================================================================
-- Создание примеров событий
-- ==============================================================================

-- Генерация примеров событий
INSERT INTO events.events (
    event_class_id, source_type, source_id, source_name,
    event_type, message, is_active, is_acknowledged
)
SELECT
    (SELECT id FROM events.event_classes WHERE code = 'INFO'),
    'system', 
    uuid_generate_v4(),
    'SYSTEM',
    'startup',
    'Система запущена успешно',
    false,
    true
UNION ALL
SELECT
    (SELECT id FROM events.event_classes WHERE code = 'OPERATOR_ACTION'),
    'user',
    (SELECT id FROM security.users WHERE username = 'operator1'),
    'operator1',
    'login',
    'Оператор вошел в систему',
    false,
    true;

-- ==============================================================================
-- Статистика загруженных данных
-- ==============================================================================

SELECT 'Загрузка начальных данных завершена' AS status;

SELECT 'Статистика загруженных данных:' AS info;

SELECT 
    'Единицы измерения' AS entity, 
    COUNT(*) AS count 
FROM core.units
UNION ALL
SELECT 'Типы данных', COUNT(*) FROM core.data_types
UNION ALL
SELECT 'Статусы', COUNT(*) FROM core.statuses
UNION ALL
SELECT 'Группы параметров', COUNT(*) FROM tech_params.parameter_groups
UNION ALL
SELECT 'Параметры', COUNT(*) FROM tech_params.parameters
UNION ALL
SELECT 'Типы контроллеров', COUNT(*) FROM controllers.controller_types
UNION ALL
SELECT 'Контроллеры', COUNT(*) FROM controllers.controllers
UNION ALL
SELECT 'Типы алгоритмов', COUNT(*) FROM algorithms.algorithm_types
UNION ALL
SELECT 'Алгоритмы', COUNT(*) FROM algorithms.algorithms
UNION ALL
SELECT 'Классы событий', COUNT(*) FROM events.event_classes
UNION ALL
SELECT 'Типы узлов', COUNT(*) FROM topology.node_types
UNION ALL
SELECT 'Параметры КРОСС', COUNT(*) FROM kross.platform_config
UNION ALL
SELECT 'Модули КРОСС', COUNT(*) FROM kross.modules
UNION ALL
SELECT 'Проекты визуализации', COUNT(*) FROM visualization.projects
UNION ALL
SELECT 'Видеокадры', COUNT(*) FROM visualization.screens
UNION ALL
SELECT 'Шаблоны отчетов', COUNT(*) FROM reports.report_templates
UNION ALL
SELECT 'Роли', COUNT(*) FROM security.roles
UNION ALL
SELECT 'Пользователи', COUNT(*) FROM security.users
ORDER BY 1;



