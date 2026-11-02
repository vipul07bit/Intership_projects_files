-- Generates deterministic-scale synthetic retail data.
-- Target row counts: 500 suppliers, 50,000 customers, 10,000 products,
-- 200,000 orders, 600,000 order_items, 10,000 inventory rows.
-- Execute after 01_create_schema.sql.
SET search_path TO retail, public;

INSERT INTO suppliers (supplier_name, contact_email, city)
SELECT 'Supplier ' || g,
       'supplier' || g || '@example.test',
       (ARRAY['Mumbai','Pune','Delhi','Bengaluru','Chennai'])[1 + (g % 5)]
FROM generate_series(1,500) AS g;

INSERT INTO customers (first_name, last_name, email, city, state, created_at)
SELECT 'First' || g,
       'Last' || g,
       'customer' || g || '@example.test',
       (ARRAY['Mumbai','Pune','Delhi','Bengaluru','Chennai','Hyderabad'])[1 + (g % 6)],
       (ARRAY['Maharashtra','Delhi','Karnataka','Tamil Nadu','Telangana'])[1 + (g % 5)],
       TIMESTAMP '2023-01-01' + (g % 1200) * INTERVAL '1 day'
FROM generate_series(1,50000) AS g;

INSERT INTO products (supplier_id, product_name, category, unit_price, is_active)
SELECT 1 + (g % 500),
       'Product ' || g,
       (ARRAY['Electronics','Clothing','Home','Grocery','Books','Sports'])[1 + (g % 6)],
       ROUND((50 + random() * 4950)::numeric, 2),
       (g % 25 <> 0)
FROM generate_series(1,10000) AS g;

INSERT INTO orders (customer_id, order_date, order_status, order_total)
SELECT 1 + (g % 50000),
       TIMESTAMP '2024-01-01' + (random() * 1000) * INTERVAL '1 day',
       (ARRAY['PLACED','PROCESSING','SHIPPED','DELIVERED','CANCELLED'])[1 + (g % 5)],
       ROUND((200 + random() * 20000)::numeric, 2)
FROM generate_series(1,200000) AS g;

INSERT INTO order_items (order_id, product_id, quantity, unit_price)
SELECT 1 + ((g - 1) / 3),
       1 + ((g * 37) % 10000),
       1 + (g % 5),
       p.unit_price
FROM generate_series(1,600000) AS g
JOIN products p ON p.product_id = 1 + ((g * 37) % 10000);

INSERT INTO inventory (product_id, quantity_on_hand, reorder_level, last_updated)
SELECT product_id,
       (product_id * 13) % 250,
       10 + (product_id % 20),
       CURRENT_TIMESTAMP - ((product_id % 60) * INTERVAL '1 day')
FROM products;

ANALYZE;
