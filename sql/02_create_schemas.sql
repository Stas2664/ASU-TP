-- ==============================================================================
-- Создание схем (namespace) для логического разделения данных
-- База данных: asu_tp_db
-- ==============================================================================

-- Подключение к БД
\c asu_tp_db;

-- ==============================================================================
-- СХЕМА: core - Основные системные таблицы
-- ==============================================================================
CREATE SCHEMA IF NOT EXISTS core
    AUTHORIZATION postgres;
COMMENT ON SCHEMA core IS 'Основные системные таблицы и справочники';

-- ==============================================================================
-- СХЕМА: tech_params - Технологические параметры
-- ==============================================================================
CREATE SCHEMA IF NOT EXISTS tech_params
    AUTHORIZATION postgres;
COMMENT ON SCHEMA tech_params IS 'Технологические и диагностические параметры';

-- ==============================================================================
-- СХЕМА: controllers - Контроллеры и устройства
-- ==============================================================================
CREATE SCHEMA IF NOT EXISTS controllers
    AUTHORIZATION postgres;
COMMENT ON SCHEMA controllers IS 'Конфигурация контроллеров КУПРИ и других устройств';

-- ==============================================================================
-- СХЕМА: archive - Архивные данные
-- ==============================================================================
CREATE SCHEMA IF NOT EXISTS archive
    AUTHORIZATION postgres;
COMMENT ON SCHEMA archive IS 'Архивные данные и исторические значения';

-- ==============================================================================
-- СХЕМА: algorithms - Расчетные алгоритмы
-- ==============================================================================
CREATE SCHEMA IF NOT EXISTS algorithms
    AUTHORIZATION postgres;
COMMENT ON SCHEMA algorithms IS 'Расчетные алгоритмы и формулы';

-- ==============================================================================
-- СХЕМА: visualization - Визуализация
-- ==============================================================================
CREATE SCHEMA IF NOT EXISTS visualization
    AUTHORIZATION postgres;
COMMENT ON SCHEMA visualization IS 'Видеокадры и элементы визуализации';

-- ==============================================================================
-- СХЕМА: topology - Топология системы
-- ==============================================================================
CREATE SCHEMA IF NOT EXISTS topology
    AUTHORIZATION postgres;
COMMENT ON SCHEMA topology IS 'Узлы ПТК и топология системы';

-- ==============================================================================
-- СХЕМА: kross - Параметры платформы КРОСС
-- ==============================================================================
CREATE SCHEMA IF NOT EXISTS kross
    AUTHORIZATION postgres;
COMMENT ON SCHEMA kross IS 'Параметры запуска и функционирования ПО КРОСС';

-- ==============================================================================
-- СХЕМА: security - Безопасность и доступ
-- ==============================================================================
CREATE SCHEMA IF NOT EXISTS security
    AUTHORIZATION postgres;
COMMENT ON SCHEMA security IS 'Пользователи, роли, права доступа и аудит';

-- ==============================================================================
-- СХЕМА: events - События и тревоги
-- ==============================================================================
CREATE SCHEMA IF NOT EXISTS events
    AUTHORIZATION postgres;
COMMENT ON SCHEMA events IS 'События, тревоги и уведомления системы';

-- ==============================================================================
-- СХЕМА: reports - Отчеты
-- ==============================================================================
CREATE SCHEMA IF NOT EXISTS reports
    AUTHORIZATION postgres;
COMMENT ON SCHEMA reports IS 'Шаблоны и данные отчетов';

-- ==============================================================================
-- Установка search_path по умолчанию
-- ==============================================================================
ALTER DATABASE asu_tp_db SET search_path TO 
    core, tech_params, controllers, archive, algorithms, 
    visualization, topology, kross, security, events, reports, public;

-- Предоставление прав на схемы для public роли (будет уточнено в ролевой модели)
GRANT USAGE ON SCHEMA core TO PUBLIC;
GRANT USAGE ON SCHEMA tech_params TO PUBLIC;
GRANT USAGE ON SCHEMA controllers TO PUBLIC;
GRANT USAGE ON SCHEMA archive TO PUBLIC;
GRANT USAGE ON SCHEMA algorithms TO PUBLIC;
GRANT USAGE ON SCHEMA visualization TO PUBLIC;
GRANT USAGE ON SCHEMA topology TO PUBLIC;
GRANT USAGE ON SCHEMA kross TO PUBLIC;
GRANT USAGE ON SCHEMA security TO PUBLIC;
GRANT USAGE ON SCHEMA events TO PUBLIC;
GRANT USAGE ON SCHEMA reports TO PUBLIC;


