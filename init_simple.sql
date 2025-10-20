-- МИНИМАЛЬНАЯ БД АСУ ТП ДЛЯ RAILWAY
-- Выполни этот код любым способом

-- Создаем одну таблицу для теста
CREATE TABLE IF NOT EXISTS parameters (
    id SERIAL PRIMARY KEY,
    tag VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(500) NOT NULL,
    value DECIMAL(20,10),
    unit VARCHAR(50),
    created_at TIMESTAMP DEFAULT NOW()
);

-- Добавляем тестовые данные
INSERT INTO parameters (tag, name, value, unit) VALUES
('REACTOR.POWER', 'Мощность реактора', 2850.5, 'МВт'),
('REACTOR.TEMP', 'Температура', 315.2, '°C'),
('TURBINE.SPEED', 'Обороты турбины', 3000, 'об/мин'),
('GENERATOR.POWER', 'Мощность генератора', 950.0, 'МВт')
ON CONFLICT (tag) DO NOTHING;

-- Проверка
SELECT * FROM parameters;


