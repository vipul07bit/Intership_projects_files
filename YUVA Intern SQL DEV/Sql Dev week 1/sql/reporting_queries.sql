-- Useful retail reporting queries (PostgreSQL)

-- 1. Customer order history
SELECT o.order_id, o.order_date, o.order_status,
       COALESCE(SUM(oi.quantity * oi.unit_price), 0) AS order_total
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.customer_id = 1
GROUP BY o.order_id, o.order_date, o.order_status
ORDER BY o.order_date DESC;

-- 2. Product sales summary (quantity and line revenue)
SELECT p.sku, p.product_name,
       SUM(oi.quantity) AS units_sold,
       SUM(oi.quantity * oi.unit_price) AS line_revenue
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
JOIN orders o ON o.order_id = oi.order_id
WHERE o.order_status NOT IN ('cancelled', 'refunded')
GROUP BY p.product_id, p.sku, p.product_name
ORDER BY line_revenue DESC;

-- 3. Inventory below reorder level
SELECT w.warehouse_name, p.sku, p.product_name,
       i.quantity_on_hand, i.reorder_level
FROM inventory i
JOIN products p ON p.product_id = i.product_id
JOIN warehouses w ON w.warehouse_id = i.warehouse_id
WHERE i.quantity_on_hand <= i.reorder_level
ORDER BY w.warehouse_name, p.product_name;

-- 4. Payment records by order
SELECT o.order_id, pay.payment_id, pay.amount,
       pay.payment_method, pay.payment_status, pay.provider_reference
FROM orders o
JOIN payments pay ON pay.order_id = o.order_id
ORDER BY pay.created_at DESC;

-- 5. Order count and value by status
SELECT o.order_status,
       COUNT(DISTINCT o.order_id) AS order_count,
       COALESCE(SUM(line_totals.order_total), 0) AS total_order_value
FROM orders o
LEFT JOIN (
    SELECT order_id, SUM(quantity * unit_price) AS order_total
    FROM order_items
    GROUP BY order_id
) line_totals ON line_totals.order_id = o.order_id
GROUP BY o.order_status
ORDER BY order_count DESC;
