-- Small sample dataset for manual testing and screenshots.
-- Run after schema.sql in a clean database.

INSERT INTO customers (full_name, email, phone) VALUES
('Aarav Shah', 'aarav.shah@example.com', '+91-9000000001'),
('Meera Joshi', 'meera.joshi@example.com', '+91-9000000002'),
('Kabir Rao', 'kabir.rao@example.com', '+91-9000000003');

INSERT INTO categories (category_name, description) VALUES
('Electronics', 'Electronic devices and accessories'),
('Home Office', 'Products used for home and office work'),
('Accessories', 'Useful add-ons and peripherals');

INSERT INTO products (category_id, sku, product_name, description, current_price) VALUES
((SELECT category_id FROM categories WHERE category_name = 'Electronics'), 'EL-LAP-001', 'Everyday Laptop', 'Sample laptop product', 45999.00),
((SELECT category_id FROM categories WHERE category_name = 'Accessories'), 'AC-MOU-001', 'Wireless Mouse', 'Sample wireless mouse', 899.00),
((SELECT category_id FROM categories WHERE category_name = 'Home Office'), 'HO-DSK-001', 'Desk Lamp', 'Sample desk lamp', 1299.00);

INSERT INTO suppliers (supplier_name, email, phone) VALUES
('Northstar Electronics', 'sales@northstar.example', '+91-8000000001'),
('Bright Office Supplies', 'contact@brightoffice.example', '+91-8000000002');

INSERT INTO product_suppliers (product_id, supplier_id, supplier_sku, supply_cost)
SELECT p.product_id, s.supplier_id, 'NS-LAP-01', 42000.00
FROM products p CROSS JOIN suppliers s
WHERE p.sku = 'EL-LAP-001' AND s.supplier_name = 'Northstar Electronics';

INSERT INTO product_suppliers (product_id, supplier_id, supplier_sku, supply_cost)
SELECT p.product_id, s.supplier_id, 'BO-LAMP-01', 900.00
FROM products p CROSS JOIN suppliers s
WHERE p.sku = 'HO-DSK-001' AND s.supplier_name = 'Bright Office Supplies';

INSERT INTO warehouses (warehouse_name, location_description) VALUES
('Mumbai Central', 'Primary sample warehouse'),
('Pune West', 'Secondary sample warehouse');

INSERT INTO inventory (product_id, warehouse_id, quantity_on_hand, reorder_level)
SELECT p.product_id, w.warehouse_id,
       CASE p.sku WHEN 'EL-LAP-001' THEN 12 WHEN 'AC-MOU-001' THEN 40 ELSE 8 END,
       CASE p.sku WHEN 'EL-LAP-001' THEN 3 WHEN 'AC-MOU-001' THEN 10 ELSE 4 END
FROM products p CROSS JOIN warehouses w
WHERE w.warehouse_name = 'Mumbai Central';

INSERT INTO inventory (product_id, warehouse_id, quantity_on_hand, reorder_level)
SELECT p.product_id, w.warehouse_id, 5, 2
FROM products p CROSS JOIN warehouses w
WHERE p.sku = 'EL-LAP-001' AND w.warehouse_name = 'Pune West';

-- Example order and line items.
INSERT INTO orders (customer_id, order_status, shipping_address)
SELECT customer_id, 'confirmed', 'Sample address, Mumbai, Maharashtra'
FROM customers WHERE email = 'aarav.shah@example.com';

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT o.order_id, p.product_id, 1, p.current_price
FROM orders o CROSS JOIN products p
WHERE o.customer_id = (SELECT customer_id FROM customers WHERE email = 'aarav.shah@example.com')
  AND p.sku = 'EL-LAP-001'
ORDER BY o.order_id DESC
LIMIT 1;

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT o.order_id, p.product_id, 2, p.current_price
FROM orders o CROSS JOIN products p
WHERE o.customer_id = (SELECT customer_id FROM customers WHERE email = 'aarav.shah@example.com')
  AND p.sku = 'AC-MOU-001'
ORDER BY o.order_id DESC
LIMIT 1;

INSERT INTO payments (order_id, amount, payment_method, payment_status, provider_reference)
SELECT o.order_id,
       (SELECT SUM(oi.quantity * oi.unit_price) FROM order_items oi WHERE oi.order_id = o.order_id),
       'upi', 'paid', 'SAMPLE-PAYMENT-0001'
FROM orders o
WHERE o.customer_id = (SELECT customer_id FROM customers WHERE email = 'aarav.shah@example.com')
ORDER BY o.order_id DESC
LIMIT 1;

INSERT INTO shipments (order_id, carrier_name, tracking_number, shipment_status, shipped_at)
SELECT o.order_id, 'Sample Courier', 'SAMPLE-TRACK-0001', 'shipped', CURRENT_TIMESTAMP
FROM orders o
WHERE o.customer_id = (SELECT customer_id FROM customers WHERE email = 'aarav.shah@example.com')
ORDER BY o.order_id DESC
LIMIT 1;
