-- ============================================================
--  УЧЕБНАЯ БАЗА: интернет-магазин "ShopLV" (PostgreSQL 15/16, Supabase)
--  Схема: shop  (твои старые таблицы в public не трогаются)
--  Данные: ~1000 клиентов, ~6000 заказов, ~15000 позиций, ~750 возвратов
--  Период: 2024-01 ... 2026-09. Данные детерминированные: у всех одинаковые.
--  В данных нарочно спрятаны ошибки (как в реальной работе) — см. exercises.sql, раздел 7.
--
--  Запуск: Supabase -> SQL Editor -> вставить весь файл -> Run
--          DBeaver -> открыть файл -> Alt+X (Execute script)
--  Скрипт можно запускать повторно: он сам пересоздаёт схему shop.
-- ============================================================

DROP SCHEMA IF EXISTS shop CASCADE;
CREATE SCHEMA shop;
SET search_path TO shop;

-- ---------- Таблицы ----------

CREATE TABLE categories (
    category_id  SERIAL PRIMARY KEY,
    name         TEXT NOT NULL,
    parent_id    INT REFERENCES categories(category_id)   -- NULL = верхний уровень
);

CREATE TABLE suppliers (
    supplier_id  SERIAL PRIMARY KEY,
    name         TEXT NOT NULL,
    country      TEXT NOT NULL
);

CREATE TABLE products (
    product_id    SERIAL PRIMARY KEY,
    product_name  TEXT NOT NULL,
    category_id   INT REFERENCES categories(category_id),  -- у пары товаров NULL (ошибка данных)
    supplier_id   INT NOT NULL REFERENCES suppliers(supplier_id),
    price         NUMERIC(10,2) NOT NULL,                   -- текущая цена продажи
    cost          NUMERIC(10,2) NOT NULL,                   -- закупочная цена
    is_active     BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE customers (
    customer_id          SERIAL PRIMARY KEY,
    first_name           TEXT NOT NULL,
    last_name            TEXT NOT NULL,
    email                TEXT NOT NULL,
    city                 TEXT,                              -- местами NULL
    country              TEXT NOT NULL,
    registration_date    DATE NOT NULL,
    acquisition_channel  TEXT NOT NULL                      -- откуда пришёл клиент
);

CREATE TABLE orders (
    order_id        SERIAL PRIMARY KEY,
    customer_id     INT NOT NULL REFERENCES customers(customer_id),
    order_ts        TIMESTAMP NOT NULL,
    status          TEXT NOT NULL,       -- delivered / shipped / pending / cancelled
    payment_method  TEXT NOT NULL,       -- card / paypal / bank_transfer / cash_on_delivery
    shipping_city   TEXT,
    total_amount    NUMERIC(12,2) NOT NULL
);

CREATE TABLE order_items (
    order_item_id  SERIAL PRIMARY KEY,
    order_id       INT NOT NULL REFERENCES orders(order_id),
    product_id     INT NOT NULL REFERENCES products(product_id),
    quantity       INT NOT NULL,
    unit_price     NUMERIC(10,2) NOT NULL,  -- цена на момент покупки
    discount_pct   INT NOT NULL DEFAULT 0   -- скидка в процентах
);

CREATE TABLE returns (
    return_id      SERIAL PRIMARY KEY,
    order_item_id  INT NOT NULL REFERENCES order_items(order_item_id),
    return_date    DATE NOT NULL,
    reason         TEXT NOT NULL,
    refund_amount  NUMERIC(10,2) NOT NULL
);

-- ---------- Вспомогательная функция: детерминированный "случайный" 0..1 ----------
CREATE FUNCTION rnd(a BIGINT, b BIGINT DEFAULT 0) RETURNS DOUBLE PRECISION
LANGUAGE sql IMMUTABLE AS $$
    SELECT (('x' || substr(md5(a::text || ':' || b::text), 1, 8))::bit(32)::bigint) / 4294967296.0
$$;

-- ---------- Справочники ----------

INSERT INTO categories (name, parent_id) VALUES
    ('Electronics', NULL), ('Home', NULL), ('Sports', NULL), ('Books', NULL);          -- 1..4
INSERT INTO categories (name, parent_id) VALUES
    ('Phones', 1), ('Audio', 1), ('Computers', 1),                                       -- 5..7
    ('Kitchen', 2), ('Furniture', 2),                                                    -- 8..9
    ('Fitness', 3), ('Outdoor', 3),                                                      -- 10..11
    ('Fiction', 4), ('Non-fiction', 4);                                                  -- 12..13

INSERT INTO suppliers (name, country) VALUES
    ('Nordic Tech', 'Sweden'), ('Baltic Goods', 'Latvia'), ('EuroHome', 'Germany'),
    ('FitLine', 'Poland'), ('PageTurner', 'Latvia'), ('SoundWave', 'Finland'),
    ('Kaunas Furniture', 'Lithuania'), ('Tallinn Gadgets', 'Estonia'),
    ('OutdoorPro', 'Germany'), ('KitchenKing', 'Italy'), ('BookHub', 'Estonia'), ('MobiPlus', 'China');

-- 60 товаров: 13 категорий-листьев задаются через массив
INSERT INTO products (product_name, category_id, supplier_id, price, cost, is_active)
SELECT
    (ARRAY['Phone','Headphones','Laptop','Blender','Chair','Dumbbell Set','Tent','Novel','Guide','Speaker','Tablet','Pan'])[1 + (g % 12)]
        || ' ' || (ARRAY['Basic','Plus','Pro','Max','Lite'])[1 + (g % 5)] || ' #' || g,
    (ARRAY[5,6,7,8,9,10,11,12,13,6,7,8])[1 + (g % 12)],
    1 + (g % 12),
    round((5 + rnd(g, 1) * 495)::numeric, 2),
    0,
    rnd(g, 2) > 0.08
FROM generate_series(1, 60) g;

UPDATE products SET cost = round((price * (0.45 + rnd(product_id, 3) * 0.3))::numeric, 2);

-- Ошибка данных: у двух товаров нет категории
UPDATE products SET category_id = NULL WHERE product_id IN (13, 41);

-- ---------- Клиенты ----------

INSERT INTO customers (first_name, last_name, email, city, country, registration_date, acquisition_channel)
SELECT
    fn, ln,
    lower(fn || '.' || ln || g || '@example.com'),
    city,
    CASE WHEN city IN ('Vilnius','Kaunas') THEN 'Lithuania'
         WHEN city IN ('Tallinn','Tartu')  THEN 'Estonia'
         ELSE 'Latvia' END,
    DATE '2024-01-01' + floor(power(rnd(g, 7), 0.8) * 880)::int,    -- 2024-01-01 .. ~2026-06
    (ARRAY['organic','google_ads','facebook','referral','email','instagram'])[1 + floor(rnd(g, 8) * 6)::int]
FROM (
    SELECT g,
        (ARRAY['Janis','Anna','Martins','Liga','Andris','Inese','Edgars','Laura','Kristaps','Evija',
               'Artis','Zane','Raimonds','Ilze','Maris','Dace','Toms','Sandra','Peteris','Agnese'])[1 + floor(rnd(g, 4) * 20)::int] AS fn,
        (ARRAY['Berzins','Kalnins','Ozols','Liepa','Krumins','Balodis','Eglitis','Zarins','Petersons','Vitols',
               'Jansons','Sprogis','Kravcenko','Ivanovs','Smits','Kuznecovs','Mikelsons','Rubenis','Vilks','Ziedins'])[1 + floor(rnd(g, 5) * 20)::int] AS ln,
        (ARRAY['Riga','Riga','Riga','Riga','Riga','Daugavpils','Liepaja','Jelgava','Jurmala','Ventspils',
               'Valmiera','Vilnius','Kaunas','Tallinn','Tartu'])[1 + floor(rnd(g, 6) * 15)::int] AS city
    FROM generate_series(1, 1000) g
) s;

-- Ошибки данных
UPDATE customers SET city = NULL WHERE rnd(customer_id, 9) < 0.03;                       -- ~3% без города
UPDATE customers c SET email = ' ' || upper(src.email) || ' '                           -- дубли e-mail (регистр + пробелы)
FROM customers src
WHERE c.customer_id IN (901, 917, 933, 948, 962, 977, 985, 991, 996, 1000)
  AND src.customer_id = c.customer_id - 500;

-- ---------- Заказы ----------

INSERT INTO orders (customer_id, order_ts, status, payment_method, shipping_city, total_amount)
SELECT
    c.customer_id,
    -- время заказа: после регистрации, до 2026-09-30
    (c.registration_date + floor(rnd(g, 11) * GREATEST(1, DATE '2026-09-30' - c.registration_date))::int)::timestamp
        + make_interval(secs => floor(rnd(g, 12) * 86400)::int),
    'tmp',
    (ARRAY['card','card','card','paypal','bank_transfer','cash_on_delivery'])[1 + floor(rnd(g, 13) * 6)::int],
    c.city,
    0
FROM generate_series(1, 6000) g
JOIN customers c ON c.customer_id = 1 + floor(power(rnd(g, 10), 1.3) * 1000)::int;   -- часть клиентов покупает чаще

-- Нумерация заказов по времени (удобнее читать)
UPDATE orders o SET status = CASE
        WHEN rnd(o.order_id, 14) < 0.07 THEN 'cancelled'
        WHEN o.order_ts > TIMESTAMP '2026-09-25' THEN 'pending'
        WHEN o.order_ts > TIMESTAMP '2026-09-18' THEN 'shipped'
        ELSE 'delivered' END;

-- Ошибка данных: 25 заказов раньше даты регистрации клиента
UPDATE orders o SET order_ts = (c.registration_date - (1 + floor(rnd(o.order_id, 15) * 20))::int)::timestamp + INTERVAL '12 hours'
FROM customers c
WHERE c.customer_id = o.customer_id AND o.order_id % 240 = 0;

-- ---------- Позиции заказов ----------

INSERT INTO order_items (order_id, product_id, quantity, unit_price, discount_pct)
SELECT
    o.order_id,
    p.product_id,
    1 + floor(power(rnd(o.order_id * 10 + k, 21), 2) * 3)::int,
    round((p.price * (0.9 + rnd(o.order_id * 10 + k, 22) * 0.2))::numeric, 2),
    (ARRAY[0,0,0,0,5,10,15,20])[1 + floor(rnd(o.order_id * 10 + k, 23) * 8)::int]
FROM orders o
CROSS JOIN LATERAL generate_series(1, 1 + floor(power(rnd(o.order_id, 20), 1.5) * 5)::int) k
JOIN products p ON p.product_id = 1 + floor(power(rnd(o.order_id * 10 + k, 24), 1.6) * 60)::int;

-- Ошибка данных: несколько позиций с quantity = 0
UPDATE order_items SET quantity = 0 WHERE order_item_id % 3000 = 7;

-- Суммы заказов считаются из позиций
UPDATE orders o SET total_amount = t.s
FROM (
    SELECT order_id, round(sum(quantity * unit_price * (1 - discount_pct / 100.0)), 2) AS s
    FROM order_items GROUP BY order_id
) t
WHERE t.order_id = o.order_id;


-- Ошибка данных: ~1% заказов с неправильным total_amount
UPDATE orders SET total_amount = round((total_amount * (0.5 + rnd(order_id, 30)))::numeric, 2)
WHERE order_id % 100 = 3;

-- ---------- Возвраты ----------

INSERT INTO returns (order_item_id, return_date, reason, refund_amount)
SELECT
    oi.order_item_id,
    (o.order_ts::date + 3 + floor(rnd(oi.order_item_id, 41) * 25)::int),
    (ARRAY['defective','wrong_size','not_as_described','changed_mind','late_delivery'])[1 + floor(rnd(oi.order_item_id, 42) * 5)::int],
    round(oi.quantity * oi.unit_price * (1 - oi.discount_pct / 100.0), 2)
FROM order_items oi
JOIN orders o ON o.order_id = oi.order_id
WHERE o.status = 'delivered'
  AND oi.quantity > 0
  AND o.order_ts < TIMESTAMP '2026-08-25'
  AND rnd(oi.order_item_id, 40) < 0.055;

-- ---------- Индексы ----------
CREATE INDEX idx_orders_customer   ON orders(customer_id);
CREATE INDEX idx_orders_ts         ON orders(order_ts);
CREATE INDEX idx_items_order       ON order_items(order_id);
CREATE INDEX idx_items_product     ON order_items(product_id);
CREATE INDEX idx_returns_item      ON returns(order_item_id);
CREATE INDEX idx_products_category ON products(category_id);

DROP FUNCTION rnd(BIGINT, BIGINT);

ANALYZE;

-- ---------- Проверка ----------
SELECT 'categories' AS table_name, count(*) AS rows FROM categories
UNION ALL SELECT 'suppliers',   count(*) FROM suppliers
UNION ALL SELECT 'products',    count(*) FROM products
UNION ALL SELECT 'customers',   count(*) FROM customers
UNION ALL SELECT 'orders',      count(*) FROM orders
UNION ALL SELECT 'order_items', count(*) FROM order_items
UNION ALL SELECT 'returns',     count(*) FROM returns;
