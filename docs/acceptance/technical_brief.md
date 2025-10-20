# Техническая справка: Схема единой БД ПТК АСУ ТП

Конфиденциально. Без письменного разрешения Заказчика публикация и распространение запрещены (п.5.4 ТЗ).

Статус: черновик для приемки. Основание: ТЗ АО «НИКИЭТ», разделы 2–5, 9.

## 1. Назначение
База данных предназначена для хранения технологических и диагностических параметров, конфигурации контроллеров КУПРИ, архивных данных, расчетных алгоритмов, видеокадров визуализации, топологии ПТК, параметров платформы КРОСС, событий/тревог, безопасности и отчетности.

## 2. Состав схем
В БД созданы следующие схемы:
- core — системные справочники (единицы, типы данных, статусы)
- tech_params — параметры, группы параметров, текущие значения, диагностика
- controllers — контроллеры, модули, каналы ввода/вывода
- archive — исторические/сжатые данные, конфигурация архивирования
- algorithms — алгоритмы, входы/выходы, история выполнения
- visualization — видеокадры, элементы, шаблоны
- topology — узлы ПТК, соединения
- kross — конфигурация платформы, модули, лицензии
- security — пользователи, роли, разрешения, сессии, аудит
- events — классы событий, события, подписки
- reports — шаблоны, расписания, история отчетов

## 3. Основные таблицы и связи (вкратце)
- tech_params.parameters (id, tag, name, parameter_type, unit_id, group_id, уставки, архивирование…) ↔ core.units (unit_id)
- tech_params.current_values (parameter_id PK/FK → parameters)
- controllers.controllers ↔ controllers.io_channels ↔ tech_params.parameters
- archive.historical_data (parameter_id, timestamp, value, quality) — партиционирование по времени рекомендуется/поддержано
- algorithms.algorithms ↔ algorithm_inputs/outputs (ссылки на tech_params.parameters)
- visualization.screens ↔ screen_elements (ссылки на параметры)
- topology.nodes ↔ node_connections
- security.users/roles/permissions/role_permissions/user_roles/object_permissions; включен RLS для критичных таблиц
- events.events (классы, ссылки на источники) с индексами по времени/активности
- reports.* для шаблонов, расписаний и истории генерации

## 4. Производительность и индексы
Созданы индексы для всех горячих таблиц, включая:
- GIN для JSONB конфигураций (controllers, visualization)
- BRIN для временных рядов (archive.historical_data, events.events)
- Частичные индексы по флагам активности/квитирования
- pg_trgm для поиска по тегам/ФИО
Выполняется ANALYZE после создания индексов.

## 5. Ролевая модель (кратко)
Роли PostgreSQL: asu_tp_admin, asu_tp_engineer, asu_tp_operator, asu_tp_viewer, asu_tp_service. 
Роли приложения (security.roles): admin, engineer, senior_operator, operator, viewer, service. 
Связывание ролей и разрешений — в `05_create_roles.sql`. Включен RLS на `security.users` и `security.object_permissions`.

## 6. Алгоритм единовременного доступа
Реализован на advisory locks:
- `core.acquire_object_lock(object_type, object_id, user_id, timeout)` — попытка захвата
- `core.release_object_lock(object_type, object_id, user_id)` — освобождение
Все операции логируются в `security.audit_log`.

## 7. Начальные данные
Загружаются единицы измерения, типы данных, статусы, роли/permissions и администратор по умолчанию (user admin).

## 8. Развертывание
Поддерживаются: локально (START_LOCAL.bat), Docker (START_DOCKER.bat), Railway (DEPLOY_TO_RAILWAY.bat). Скрипты SQL 01–08 выполняются последовательно.

## 9. Соответствие ТЗ (выдержка)
- Раздел 3.1.1 ТЗ: модель БД с необходимыми объектами — выполнено (11 схем).
- Ролевая модель и алгоритм единовременного доступа — выполнено.
- Документация/приемка — настоящий документ входит в комплект.

## 10. Нормативные документы и сокращения
- ГОСТ Р ИСО 9001-2015; ГОСТ 34.601-90; ГОСТ 34.602-89; ГОСТ 34.003-90; ГОСТ 19.201-78
- Сокращения: АСУ ТП, ПТК, СУБД, КРОСС, КУПРИ, RLS, GIN, BRIN, TRGM

## 11. Приложения
- ER‑диаграмма (см. `docs/acceptance/er_diagram.dbml` и экспорт PNG при наличии)
- Матрица ролей и прав (см. `docs/acceptance/role_model.md`)


