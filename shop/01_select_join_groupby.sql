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
