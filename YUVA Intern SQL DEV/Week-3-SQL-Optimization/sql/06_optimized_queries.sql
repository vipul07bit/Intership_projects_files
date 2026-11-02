-- Re-run exactly the same business questions AFTER indexes and query rewrites.
-- Compare actual execution time, buffers, scan type, rows and plan shape.
SET search_path TO retail, public;

-- B1
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT order_id, order_date, order_status, order_total
FROM orders
WHERE customer_id = 12345
ORDER BY order_date DESC
LIMIT 20;

-- B2
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT product_id, product_name, unit_price
FROM products
WHERE category = 'Electronics' AND is_active = TRUE
ORDER BY product_name
LIMIT 100;

-- B3
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT order_id, customer_id, order_date, order_total
FROM orders
WHERE order_status = 'DELIVERED'
  AND order_date >= TIMESTAMP '2026-01-01'
  AND order_date <  TIMESTAMP '2027-01-01'
ORDER BY order_date DESC;

-- B4
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT o.order_id, o.order_date, o.order_status, c.first_name, c.last_name, c.email
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.customer_id = 23456
ORDER BY o.order_date DESC
LIMIT 25;

-- B5
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT i.product_id, p.product_name, i.quantity_on_hand, i.reorder_level
FROM inventory i
JOIN products p ON p.product_id = i.product_id
WHERE i.quantity_on_hand <= i.reorder_level
ORDER BY i.quantity_on_hand ASC;

-- B6 (rewritten, sargable range)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT order_id, order_date, order_total
FROM orders
WHERE order_date >= TIMESTAMP '2026-01-01'
  AND order_date <  TIMESTAMP '2027-01-01';

-- B7: monthly delivered revenue. After VACUUM (ANALYZE) orders, the covering index
-- idx_orders_status_date can serve this as an Index Only Scan (see report BM-07).
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT DATE_TRUNC('month', order_date) AS sales_month,
       COUNT(*)                        AS delivered_orders,
       SUM(order_total)                AS revenue
FROM orders
WHERE order_status = 'DELIVERED'
  AND order_date >= TIMESTAMP '2026-01-01'
  AND order_date <  TIMESTAMP '2027-01-01'
GROUP BY DATE_TRUNC('month', order_date)
ORDER BY sales_month;
