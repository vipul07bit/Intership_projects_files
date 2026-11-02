-- Query refactoring experiments. Compare each version using EXPLAIN ANALYZE.
SET search_path TO retail, public;

-- Original: applying a function to the indexed timestamp column can make
-- a normal B-tree index less useful.
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, order_date, order_total
FROM orders
WHERE DATE_PART('year', order_date) = 2026;

-- Rewritten: half-open range preserves timestamp precision and is sargable.
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, order_date, order_total
FROM orders
WHERE order_date >= TIMESTAMP '2026-01-01'
  AND order_date <  TIMESTAMP '2027-01-01';

-- Original: SELECT * returns every column although the screen needs three.
EXPLAIN (ANALYZE, BUFFERS)
SELECT *
FROM orders
WHERE customer_id = 12345
ORDER BY order_date DESC
LIMIT 20;

-- Rewritten: avoid SELECT * when the application needs only a few columns.
EXPLAIN (ANALYZE, BUFFERS)
SELECT order_id, order_date, order_status
FROM orders
WHERE customer_id = 12345
ORDER BY order_date DESC
LIMIT 20;

-- Aggregation example: monthly delivered revenue.
EXPLAIN (ANALYZE, BUFFERS)
SELECT DATE_TRUNC('month', order_date) AS sales_month,
       COUNT(*) AS delivered_orders,
       SUM(order_total) AS revenue
FROM orders
WHERE order_status = 'DELIVERED'
  AND order_date >= TIMESTAMP '2026-01-01'
  AND order_date <  TIMESTAMP '2027-01-01'
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY sales_month;
