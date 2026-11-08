-- Deterministic, idempotent demonstration data. Uses unique natural keys.
INSERT INTO retail.categories(category_name, description)
VALUES ('Electronics','Demo category'),('Home','Demo category')
ON CONFLICT(category_name) DO NOTHING;

INSERT INTO retail.customers(full_name,email)
VALUES ('Demo Customer','week5.demo@example.test')
ON CONFLICT(email) DO NOTHING;

INSERT INTO retail.warehouses(warehouse_name,location_description)
SELECT 'Demo Warehouse','Training fixture'
WHERE NOT EXISTS (SELECT 1 FROM retail.warehouses WHERE warehouse_name='Demo Warehouse');

INSERT INTO retail.products(category_id,sku,product_name,current_price,unit_cost,is_active)
SELECT c.category_id,'W5-DEMO-001','Wireless Mouse',799.00,420.00,TRUE
FROM retail.categories c WHERE c.category_name='Electronics'
ON CONFLICT(sku) DO UPDATE SET current_price=EXCLUDED.current_price,
 unit_cost=EXCLUDED.unit_cost,is_active=TRUE;

INSERT INTO retail.products(category_id,sku,product_name,current_price,unit_cost,is_active)
SELECT c.category_id,'W5-DEMO-002','Desk Lamp',1199.00,650.00,TRUE
FROM retail.categories c WHERE c.category_name='Home'
ON CONFLICT(sku) DO UPDATE SET current_price=EXCLUDED.current_price,
 unit_cost=EXCLUDED.unit_cost,is_active=TRUE;

INSERT INTO retail.inventory(product_id,warehouse_id,quantity_on_hand,reorder_level)
SELECT p.product_id,w.warehouse_id,
       CASE p.sku WHEN 'W5-DEMO-001' THEN 20 ELSE 40 END, 10
FROM retail.products p CROSS JOIN retail.warehouses w
WHERE p.sku IN ('W5-DEMO-001','W5-DEMO-002')
  AND w.warehouse_name='Demo Warehouse'
ON CONFLICT(product_id,warehouse_id) DO NOTHING;
