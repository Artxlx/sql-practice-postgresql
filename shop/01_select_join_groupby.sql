SET search_path TO shop;

-- ===== 1. SELECT / WHERE / ORDER BY / LIMIT =====

-- 1.1 Топ-10 самых дорогих товаров (название, цена).
-- Вторым ключом сортировки идёт product_id (PK), чтобы порядок на границе 10-го места был стабильным.
SELECT product_name, price
FROM shop.products
ORDER BY price DESC, product_id
LIMIT 10;
