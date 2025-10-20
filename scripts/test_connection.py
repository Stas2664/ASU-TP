#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Скрипт тестирования подключения к БД ПТК АСУ ТП
Проверяет подключение и основные операции с базой данных
"""

import sys
import time
import psycopg2
from psycopg2.extras import RealDictCursor
from datetime import datetime
import json

# Конфигурация подключения
DB_CONFIG = {
    'host': 'localhost',
    'port': 5432,
    'database': 'asu_tp_db',
    'user': 'postgres',
    'password': 'postgres'  # Измените на ваш пароль
}

class DatabaseTester:
    def __init__(self, config):
        self.config = config
        self.connection = None
        self.cursor = None
        
    def connect(self):
        """Установка соединения с БД"""
        try:
            print(f"Подключение к {self.config['host']}:{self.config['port']}/{self.config['database']}...")
            self.connection = psycopg2.connect(**self.config)
            self.cursor = self.connection.cursor(cursor_factory=RealDictCursor)
            print("✓ Подключение установлено успешно")
            return True
        except Exception as e:
            print(f"✗ Ошибка подключения: {e}")
            return False
    
    def test_schemas(self):
        """Проверка наличия схем"""
        print("\n=== Проверка схем ===")
        try:
            self.cursor.execute("""
                SELECT schema_name 
                FROM information_schema.schemata 
                WHERE schema_name IN (
                    'core', 'tech_params', 'controllers', 'archive', 
                    'algorithms', 'visualization', 'topology', 'kross', 
                    'security', 'events', 'reports'
                )
                ORDER BY schema_name
            """)
            schemas = self.cursor.fetchall()
            
            expected_schemas = [
                'algorithms', 'archive', 'controllers', 'core', 'events', 
                'kross', 'reports', 'security', 'tech_params', 'topology', 'visualization'
            ]
            
            found_schemas = [s['schema_name'] for s in schemas]
            
            for schema in expected_schemas:
                if schema in found_schemas:
                    print(f"  ✓ Схема {schema} найдена")
                else:
                    print(f"  ✗ Схема {schema} НЕ найдена")
                    
            return len(found_schemas) == len(expected_schemas)
        except Exception as e:
            print(f"  ✗ Ошибка: {e}")
            return False
    
    def test_tables_count(self):
        """Подсчет таблиц в каждой схеме"""
        print("\n=== Количество таблиц в схемах ===")
        try:
            self.cursor.execute("""
                SELECT 
                    table_schema,
                    COUNT(*) as table_count
                FROM information_schema.tables
                WHERE table_schema IN (
                    'core', 'tech_params', 'controllers', 'archive', 
                    'algorithms', 'visualization', 'topology', 'kross', 
                    'security', 'events', 'reports'
                )
                AND table_type = 'BASE TABLE'
                GROUP BY table_schema
                ORDER BY table_schema
            """)
            
            results = self.cursor.fetchall()
            total_tables = 0
            
            for row in results:
                print(f"  {row['table_schema']}: {row['table_count']} таблиц")
                total_tables += row['table_count']
                
            print(f"\n  Всего таблиц: {total_tables}")
            return total_tables > 0
        except Exception as e:
            print(f"  ✗ Ошибка: {e}")
            return False
    
    def test_parameters(self):
        """Проверка параметров"""
        print("\n=== Проверка параметров ===")
        try:
            # Подсчет параметров
            self.cursor.execute("""
                SELECT 
                    parameter_type,
                    COUNT(*) as count
                FROM tech_params.parameters
                GROUP BY parameter_type
                ORDER BY parameter_type
            """)
            
            param_types = self.cursor.fetchall()
            total_params = 0
            
            print("  Типы параметров:")
            for pt in param_types:
                print(f"    {pt['parameter_type']}: {pt['count']}")
                total_params += pt['count']
            
            print(f"\n  Всего параметров: {total_params}")
            
            # Проверка текущих значений
            self.cursor.execute("""
                SELECT COUNT(*) as count
                FROM tech_params.current_values
            """)
            
            current_values = self.cursor.fetchone()
            print(f"  Текущих значений: {current_values['count']}")
            
            # Пример чтения параметра
            self.cursor.execute("""
                SELECT 
                    p.tag,
                    p.name,
                    cv.value,
                    cv.quality,
                    cv.timestamp,
                    u.symbol as unit
                FROM tech_params.parameters p
                LEFT JOIN tech_params.current_values cv ON p.id = cv.parameter_id
                LEFT JOIN core.units u ON p.unit_id = u.id
                WHERE p.tag = 'REACTOR.POWER'
            """)
            
            param = self.cursor.fetchone()
            if param:
                print(f"\n  Пример параметра:")
                print(f"    Тег: {param['tag']}")
                print(f"    Название: {param['name']}")
                print(f"    Значение: {param['value']} {param['unit']}")
                print(f"    Качество: {param['quality']}")
                print(f"    Время: {param['timestamp']}")
                
            return total_params > 0
        except Exception as e:
            print(f"  ✗ Ошибка: {e}")
            return False
    
    def test_users_and_roles(self):
        """Проверка пользователей и ролей"""
        print("\n=== Проверка пользователей и ролей ===")
        try:
            # Роли
            self.cursor.execute("""
                SELECT code, name
                FROM security.roles
                ORDER BY priority DESC
            """)
            
            roles = self.cursor.fetchall()
            print("  Роли в системе:")
            for role in roles:
                print(f"    - {role['code']}: {role['name']}")
            
            # Пользователи
            self.cursor.execute("""
                SELECT 
                    u.username,
                    u.full_name,
                    STRING_AGG(r.name, ', ') as roles
                FROM security.users u
                LEFT JOIN security.user_roles ur ON u.id = ur.user_id
                LEFT JOIN security.roles r ON ur.role_id = r.id
                WHERE u.is_active = true
                GROUP BY u.username, u.full_name
                ORDER BY u.username
            """)
            
            users = self.cursor.fetchall()
            print("\n  Активные пользователи:")
            for user in users:
                print(f"    {user['username']}: {user['full_name']} [{user['roles']}]")
                
            return len(users) > 0
        except Exception as e:
            print(f"  ✗ Ошибка: {e}")
            return False
    
    def test_write_parameter(self):
        """Тест записи значения параметра"""
        print("\n=== Тест записи параметра ===")
        try:
            # Получаем ID параметра
            self.cursor.execute("""
                SELECT id 
                FROM tech_params.parameters 
                WHERE tag = 'REACTOR.POWER'
            """)
            
            param = self.cursor.fetchone()
            if not param:
                print("  ✗ Параметр REACTOR.POWER не найден")
                return False
            
            param_id = param['id']
            new_value = '2850.5'
            
            # Записываем новое значение
            self.cursor.execute("""
                INSERT INTO tech_params.current_values 
                (parameter_id, value, quality, timestamp, source)
                VALUES (%s, %s, 192, %s, 'test')
                ON CONFLICT (parameter_id) 
                DO UPDATE SET 
                    value = EXCLUDED.value,
                    timestamp = EXCLUDED.timestamp,
                    source = EXCLUDED.source,
                    updated_at = CURRENT_TIMESTAMP
                RETURNING value, timestamp
            """, (param_id, new_value, datetime.now()))
            
            result = self.cursor.fetchone()
            self.connection.commit()
            
            print(f"  ✓ Значение записано: {result['value']} в {result['timestamp']}")
            
            return True
        except Exception as e:
            self.connection.rollback()
            print(f"  ✗ Ошибка: {e}")
            return False
    
    def test_archive_data(self):
        """Проверка архивных данных"""
        print("\n=== Проверка архивных данных ===")
        try:
            # Количество архивных записей
            self.cursor.execute("""
                SELECT 
                    COUNT(*) as total_records,
                    MIN(timestamp) as oldest,
                    MAX(timestamp) as newest
                FROM archive.historical_data
            """)
            
            archive_info = self.cursor.fetchone()
            
            if archive_info['total_records'] > 0:
                print(f"  Архивных записей: {archive_info['total_records']}")
                print(f"  Период: с {archive_info['oldest']} по {archive_info['newest']}")
            else:
                print("  Архивные данные отсутствуют")
            
            # Проверка партиций
            self.cursor.execute("""
                SELECT 
                    schemaname,
                    tablename
                FROM pg_tables
                WHERE schemaname = 'archive'
                AND tablename LIKE 'historical_data_%'
                ORDER BY tablename
            """)
            
            partitions = self.cursor.fetchall()
            
            if partitions:
                print(f"\n  Партиции архива ({len(partitions)}):")
                for p in partitions:
                    print(f"    - {p['tablename']}")
            
            return True
        except Exception as e:
            print(f"  ✗ Ошибка: {e}")
            return False
    
    def test_performance(self):
        """Тест производительности"""
        print("\n=== Тест производительности ===")
        try:
            # Тест чтения 1000 параметров
            start_time = time.time()
            
            self.cursor.execute("""
                SELECT 
                    p.tag,
                    cv.value,
                    cv.timestamp
                FROM tech_params.parameters p
                LEFT JOIN tech_params.current_values cv ON p.id = cv.parameter_id
                WHERE p.is_active = true
                LIMIT 1000
            """)
            
            results = self.cursor.fetchall()
            read_time = (time.time() - start_time) * 1000
            
            print(f"  Чтение 1000 параметров: {read_time:.2f} мс")
            print(f"  Скорость: {1000/read_time*1000:.0f} параметров/сек")
            
            # Тест записи
            start_time = time.time()
            
            for i in range(100):
                self.cursor.execute("""
                    UPDATE tech_params.current_values
                    SET value = %s, timestamp = CURRENT_TIMESTAMP
                    WHERE parameter_id = (
                        SELECT id FROM tech_params.parameters 
                        WHERE tag = 'REACTOR.POWER' LIMIT 1
                    )
                """, (str(2800 + i),))
            
            self.connection.commit()
            write_time = (time.time() - start_time) * 1000
            
            print(f"\n  Запись 100 значений: {write_time:.2f} мс")
            print(f"  Скорость: {100/write_time*1000:.0f} записей/сек")
            
            return True
        except Exception as e:
            self.connection.rollback()
            print(f"  ✗ Ошибка: {e}")
            return False
    
    def close(self):
        """Закрытие соединения"""
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()
        print("\n✓ Соединение закрыто")

def main():
    print("=" * 60)
    print("ТЕСТИРОВАНИЕ БАЗЫ ДАННЫХ ПТК АСУ ТП")
    print("=" * 60)
    
    tester = DatabaseTester(DB_CONFIG)
    
    if not tester.connect():
        sys.exit(1)
    
    tests = [
        ("Схемы", tester.test_schemas),
        ("Таблицы", tester.test_tables_count),
        ("Параметры", tester.test_parameters),
        ("Пользователи", tester.test_users_and_roles),
        ("Запись параметра", tester.test_write_parameter),
        ("Архивы", tester.test_archive_data),
        ("Производительность", tester.test_performance)
    ]
    
    results = {}
    
    for test_name, test_func in tests:
        try:
            results[test_name] = test_func()
        except Exception as e:
            print(f"\n✗ Критическая ошибка в тесте '{test_name}': {e}")
            results[test_name] = False
    
    print("\n" + "=" * 60)
    print("РЕЗУЛЬТАТЫ ТЕСТИРОВАНИЯ")
    print("=" * 60)
    
    passed = 0
    failed = 0
    
    for test_name, result in results.items():
        status = "✓ PASS" if result else "✗ FAIL"
        print(f"  {test_name}: {status}")
        if result:
            passed += 1
        else:
            failed += 1
    
    print("\n" + "-" * 60)
    print(f"Пройдено: {passed}/{len(tests)}")
    print(f"Провалено: {failed}/{len(tests)}")
    
    if failed == 0:
        print("\n✓ ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО!")
    else:
        print(f"\n✗ {failed} тестов провалено")
    
    tester.close()
    
    return 0 if failed == 0 else 1

if __name__ == "__main__":
    sys.exit(main())



