-- Manual validation checklist for a fresh database.
-- Execute statements individually and confirm the expected result.
-- The failing INSERT examples are intentionally invalid and should be rejected.

-- A. Valid customer insertion should succeed:
-- INSERT INTO customers(full_name, email) VALUES ('Test User', 'test.user@example.com');

-- B. Duplicate email should fail because of UNIQUE:
-- INSERT INTO customers(full_name, email) VALUES ('Another User', 'test.user@example.com');

-- C. Invalid product price should fail because of CHECK:
-- INSERT INTO products(sku, product_name, current_price)
-- VALUES ('BAD-PRICE', 'Invalid Product', -1.00);

-- D. Zero quantity should fail because of CHECK:
-- INSERT INTO order_items(order_id, product_id, quantity, unit_price)
-- VALUES (1, 1, 0, 100.00);

-- E. An order using a nonexistent customer ID should fail due to FK:
-- INSERT INTO orders(customer_id, shipping_address)
-- VALUES (999999999, 'Invalid address');

-- F. Verify all order items refer to existing orders and products (should return 0 rows):
SELECT oi.order_item_id
FROM order_items oi
LEFT JOIN orders o ON o.order_id = oi.order_id
LEFT JOIN products p ON p.product_id = oi.product_id
WHERE o.order_id IS NULL OR p.product_id IS NULL;

-- G. Check for negative inventory (should return 0 rows):
SELECT product_id, warehouse_id, quantity_on_hand
FROM inventory
WHERE quantity_on_hand < 0;

-- H. Check for products without an SKU (should return 0 rows):
SELECT product_id FROM products WHERE sku IS NULL OR BTRIM(sku) = '';

-- I. Verify line totals can be calculated:
SELECT order_id, SUM(quantity * unit_price) AS calculated_total
FROM order_items
GROUP BY order_id
ORDER BY order_id;
