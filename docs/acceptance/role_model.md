# Ролевая модель доступа (приемочный комплект)

Конфиденциально. Публикация без разрешения Заказчика запрещена (п.5.4 ТЗ).

## 1. Роли приложения (security.roles)
- admin — полный доступ
- engineer — параметры/контроллеры/алгоритмы (управление)
- senior_operator — управление процессом, квитирование
- operator — мониторинг и базовые операции
- viewer — только чтение
- service — системная интеграция (запись текущих значений, архив)

## 2. Матрица прав (перечень permissions)

| Ресурс | Действия | Роли |
|---|---|---|
| parameters | create, read, update, delete, write_value | admin, engineer (create/update/write), operator (read, write_value), viewer (read) |
| controllers | create, read, update, delete, command | admin, engineer (read/update/command), operator (read) |
| algorithms | create, read, update, delete, execute | admin, engineer (create/update/execute), senior_operator (read/execute), operator (read) |
| events | read, acknowledge, comment | admin, engineer (read/ack/comment), senior_operator (read/ack/comment), operator (read/comment), viewer (read) |
| reports | create, read, generate, schedule | admin, engineer (read/generate/schedule), operator (read) |
| users | create, read, update, delete, assign_roles | admin |

Полный перечень кодов прав см. `sql/05_create_roles.sql` (секция вставок в `security.permissions`).

## 3. Реализация в БД
- Связи ролей и прав: `security.role_permissions`
- Назначение ролей пользователям: `security.user_roles`
- Проверка прав: функции `security.check_permission` и `security.check_object_access`
- RLS включен:
  - `security.users` — пользователи видят только себя (либо администратор)
  - `security.object_permissions` — доступ по строковой политике

### Примеры политик RLS (фрагменты)
```sql
ALTER TABLE security.users ENABLE ROW LEVEL SECURITY;
CREATE POLICY users_self_view ON security.users
  FOR SELECT
  USING (id = current_setting('app.current_user_id')::uuid OR EXISTS (
    SELECT 1 FROM security.user_roles ur
    JOIN security.roles r ON r.id = ur.role_id
    WHERE ur.user_id = current_setting('app.current_user_id')::uuid AND r.code = 'admin'
  ));
```

## 4. Примеры проверок
```sql
SELECT security.check_permission(:user_id, 'parameters', 'update');
SELECT security.check_object_access(:user_id, 'screen', :screen_id, 'view');
```

## 5. Администратор по умолчанию
Пользователь `admin` создается и получает роль `admin`. Пароль должен быть изменен после развертывания (см. инструкцию по безопасности).

---

Статус: готово для приемки. Исходник прав — `sql/05_create_roles.sql`.


