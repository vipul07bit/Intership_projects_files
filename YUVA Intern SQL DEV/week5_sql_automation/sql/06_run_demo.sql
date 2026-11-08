-- Execute after 00-05. One successful order: 2 wireless mice.
CALL retail.sp_process_sale(
  (SELECT customer_id FROM retail.customers WHERE email='week5.demo@example.test'),
  (SELECT warehouse_id FROM retail.warehouses WHERE warehouse_name='Demo Warehouse'),
  (SELECT product_id FROM retail.products WHERE sku='W5-DEMO-001'),
  2, NULL
);
-- Expected: inventory for W5-DEMO-001 decreases from 20 to 18.
-- Trigger records a movement. No low-stock alert because 18 > reorder level 10.
CALL retail.sp_capture_daily_inventory();
SELECT * FROM retail.inventory_movements ORDER BY movement_id DESC LIMIT 5;
SELECT * FROM retail.low_stock_alerts WHERE alert_status='OPEN';
SELECT * FROM retail.automation_log ORDER BY log_id DESC LIMIT 10;
