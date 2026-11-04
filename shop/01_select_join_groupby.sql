SET search_path TO shop;

-- ===== 1. SELECT / WHERE / ORDER BY / LIMIT =====

-- 1.1 Топ-10 самых дорогих товаров (название, цена).
-- Вторым ключом сортировки идёт product_id (PK), чтобы порядок на границе 10-го места был стабильным.
SELECT product_name, price
FROM shop.products
ORDER BY price DESC, product_id
LIMIT 10;

-- 1.2 Клиенты из Юрмалы, зарегистрированные в 2025 году (список для рассылки).
-- Границы исключающие с обеих сторон: > 2024-12-31 и < 2026-01-01 = ровно 2025 год.
-- Для DATE работает. Для TIMESTAMP надёжнее идиома >= '2025-01-01' AND < '2026-01-01'.
-- LIMIT не ставим: для рассылки он молча отрезал бы часть списка.
SELECT first_name, last_name, city
FROM shop.customers
WHERE city = 'Jurmala'
  AND registration_date > '2024-12-31'
  AND registration_date < '2026-01-01';

-- 1.3 Отменённые заказы за сентябрь 2026 (оценка доли отмен).
-- order_ts это TIMESTAMP: начало периода включаем (>=), конец не включаем (<) и берём 1-е число следующего месяца.
-- '> 2026-08-31' захватил бы заказы 31 августа после 00:00:00.
SELECT order_id, customer_id, status
FROM shop.orders
WHERE order_ts >= '2026-09-01'
  AND order_ts <  '2026-10-01'
  AND status = 'cancelled';

-- 1.4 Сколько всего клиентов и сколько из Латвии (одним запросом, без GROUP BY).
SELECT count(*) AS all_customers,
       count(*) FILTER (WHERE country = 'Latvia') AS lv_customers
FROM shop.customers;

-- 1.5 Уникальные способы оплаты (для настройки платёжного шлюза).
SELECT DISTINCT payment_method
FROM shop.orders;

-- 1.6 Клиенты, у которых имя начинается на 'An'.
-- ILIKE = LIKE без учёта регистра (только PostgreSQL). Результат тот же, что у LIKE 'An%' (102 строки),
-- но ILIKE ловит и 'an', 'AN', если в данных регистр сломан. LIKE 'an%' дал бы 0.
SELECT first_name, last_name, city
FROM shop.customers
WHERE first_name ILIKE 'an%';
