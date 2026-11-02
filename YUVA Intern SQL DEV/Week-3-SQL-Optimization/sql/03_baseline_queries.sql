-- Capture the complete EXPLAIN ANALYZE output for each query BEFORE adding
-- performance indexes. Run each query at least 5 times; report the median
-- execution time, and note whether the first run was a cold/warm-cache run.
SET search_path TO retail, public;

-- B1: Customer order history (business rule: show a customer's orders newest first)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT order_id, order_date, order_status, order_total
FROM orders
WHERE customer_id = 12345
ORDER BY order_date DESC
LIMIT 20;

-- B2: Product category browsing (active products only)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT product_id, product_name, unit_price
FROM products
WHERE category = 'Electronics' AND is_active = TRUE
ORDER BY product_name
LIMIT 100;

-- B3: Recent delivered sales in a date range
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT order_id, customer_id, order_date, order_total
FROM orders
WHERE order_status = 'DELIVERED'
  AND order_date >= TIMESTAMP '2026-01-01'
  AND order_date <  TIMESTAMP '2027-01-01'
ORDER BY order_date DESC;

-- B4: Join orders to customers for a customer-service lookup
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT o.order_id, o.order_date, o.order_status, c.first_name, c.last_name, c.email
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.customer_id = 23456
ORDER BY o.order_date DESC
LIMIT 25;

-- B5: Low-stock products (business rule: flag stock at or below reorder level)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT i.product_id, p.product_name, i.quantity_on_hand, i.reorder_level
FROM inventory i
JOIN products p ON p.product_id = i.product_id
WHERE i.quantity_on_hand <= i.reorder_level
ORDER BY i.quantity_on_hand ASC;

-- B6: Date filter written with a function (intentionally less index-friendly form)
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT order_id, order_date, order_total
FROM orders
WHERE DATE_PART('year', order_date) = 2026;

-- B7: Monthly delivered revenue (aggregation) for date-based sales reporting
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
