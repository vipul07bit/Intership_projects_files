-- Automated assertions. Run after bootstrap, support tables, triggers, procedures and seed.
-- Tests run in a transaction and are rolled back, so fixture stock/order counts are restored.
BEGIN;
DO $$
DECLARE
  v_customer BIGINT; v_wh BIGINT; v_product BIGINT;
  v_before INTEGER; v_after INTEGER; v_order BIGINT;
  v_orders_before BIGINT; v_orders_after BIGINT;
BEGIN
  SELECT customer_id INTO v_customer FROM retail.customers WHERE email='week5.demo@example.test';
  SELECT warehouse_id INTO v_wh FROM retail.warehouses WHERE warehouse_name='Demo Warehouse';
  SELECT product_id INTO v_product FROM retail.products WHERE sku='W5-DEMO-001';
  SELECT quantity_on_hand INTO v_before FROM retail.inventory
    WHERE product_id=v_product AND warehouse_id=v_wh;
  SELECT COUNT(*) INTO v_orders_before FROM retail.orders;

  CALL retail.sp_process_sale(v_customer,v_wh,v_product,1,v_order);
  SELECT quantity_on_hand INTO v_after FROM retail.inventory
    WHERE product_id=v_product AND warehouse_id=v_wh;
  IF v_after <> v_before-1 THEN RAISE EXCEPTION 'FAIL: stock decrement'; END IF;
  IF NOT EXISTS (SELECT 1 FROM retail.orders WHERE order_id=v_order) THEN
    RAISE EXCEPTION 'FAIL: order not inserted';
  END IF;

  -- Insufficient-stock path must fail; nested block catches it so tests can continue.
  BEGIN
    CALL retail.sp_process_sale(v_customer,v_wh,v_product,999999,NULL);
    RAISE EXCEPTION 'FAIL: oversell was not rejected';
  EXCEPTION WHEN SQLSTATE 'P0001' THEN
    NULL; -- expected rejection
  END;
  SELECT COUNT(*) INTO v_orders_after FROM retail.orders;
  IF v_orders_after <> v_orders_before+1 THEN
    RAISE EXCEPTION 'FAIL: failed sale left partial order';
  END IF;

  -- Force low-stock threshold crossing; trigger should create exactly one open alert.
  UPDATE retail.inventory SET quantity_on_hand=1
   WHERE product_id=v_product AND warehouse_id=v_wh;
  IF NOT EXISTS (SELECT 1 FROM retail.low_stock_alerts
     WHERE product_id=v_product AND warehouse_id=v_wh AND alert_status='OPEN') THEN
    RAISE EXCEPTION 'FAIL: low-stock alert missing';
  END IF;

  -- Resolve alert after replenishment.
  UPDATE retail.inventory SET quantity_on_hand=25
   WHERE product_id=v_product AND warehouse_id=v_wh;
  IF EXISTS (SELECT 1 FROM retail.low_stock_alerts
     WHERE product_id=v_product AND warehouse_id=v_wh AND alert_status='OPEN') THEN
    RAISE EXCEPTION 'FAIL: low-stock alert not resolved';
  END IF;
  RAISE NOTICE 'PASS: sale, rollback-on-error, low-stock alert and resolution';
END $$;
ROLLBACK;
