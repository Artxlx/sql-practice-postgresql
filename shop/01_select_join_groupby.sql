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


-- ===== 2. JOIN =====

-- 2.1 Последние 20 заказов с именем и фамилией клиента.
-- INNER JOIN: у каждого заказа есть клиент (customer_id NOT NULL + FK), LEFT дал бы те же 6000 строк.
-- «Последние» = ORDER BY order_ts DESC (order_id со временем не связан). Второй ключ order_id делает порядок стабильным.
SELECT o.order_id, o.order_ts, c.first_name, c.last_name
FROM shop.orders o
INNER JOIN shop.customers c ON c.customer_id = o.customer_id
ORDER BY o.order_ts DESC, o.order_id
LIMIT 20;

-- 2.2 Позиции заказов: номер заказа, товар, количество, цена на момент покупки (первые 30 строк).
-- INNER JOIN: у каждой позиции есть товар (product_id NOT NULL + FK), LEFT дал бы те же 15356 строк.
-- Третий ключ сортировки order_item_id (PK) нужен, потому что в одном заказе один товар может встретиться дважды
-- (таких пар order_id + product_id в базе 370), и без него порядок на этих строках не гарантирован.
SELECT oi.order_id, p.product_name, oi.quantity, oi.unit_price
FROM shop.order_items oi
INNER JOIN shop.products p ON p.product_id = oi.product_id
ORDER BY oi.order_id DESC, p.product_id, oi.order_item_id
LIMIT 30;

-- 2.3 Товары с категорией и поставщиком. Почему у двух товаров нет категории?
-- У товаров 13 и 41 category_id = NULL (ошибка данных), а NULL ничему не равно, поэтому пары в categories нет.
-- LEFT JOIN categories: 60 строк, у двух category_name = NULL. INNER JOIN дал бы 58 и молча потерял бы эти товары
-- (в отчёте «выручка по категориям» это занизило бы итог, см. 7.6).
-- suppliers: INNER JOIN достаточно (supplier_id NOT NULL + FK), LEFT дал бы те же 60 строк.
SELECT p.product_name, c.name AS category_name, s.name AS supplier_name
FROM shop.products p
INNER JOIN shop.suppliers s ON s.supplier_id = p.supplier_id
LEFT JOIN shop.categories c ON c.category_id = p.category_id
ORDER BY p.product_id;

-- 2.4 Клиенты, которые ни разу не делали заказ (для рассылки-напоминания).
-- Связь хранится в orders.customer_id. LEFT JOIN оставляет всех клиентов, а у тех, у кого пары в orders нет,
-- колонки orders = NULL. Фильтр IS NULL (не = NULL) оставляет только их. Проверять можно любую NOT NULL колонку orders:
-- customer_id (NOT NULL) и order_id (PK) дают те же 4 строки.
SELECT c.customer_id, c.first_name, c.last_name, c.email
FROM shop.customers c
LEFT JOIN shop.orders o ON o.customer_id = c.customer_id
WHERE o.customer_id IS NULL
ORDER BY c.customer_id;
