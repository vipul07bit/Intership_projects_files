-- Sale is one atomic CALL statement. A raised exception aborts the statement,
-- including order/order_item inserts and inventory update.
CREATE OR REPLACE PROCEDURE retail.sp_process_sale(
  IN p_customer_id BIGINT,
  IN p_warehouse_id BIGINT,
  IN p_product_id BIGINT,
  IN p_quantity INTEGER,
  INOUT p_order_id BIGINT DEFAULT NULL
)
LANGUAGE plpgsql AS $$
DECLARE
  v_stock INTEGER;
  v_price NUMERIC(12,2);
BEGIN
  IF p_quantity IS NULL OR p_quantity <= 0 THEN
    RAISE EXCEPTION 'Quantity must be a positive integer' USING ERRCODE='22023';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM retail.customers WHERE customer_id=p_customer_id) THEN
    RAISE EXCEPTION 'Customer % does not exist', p_customer_id USING ERRCODE='23503';
  END IF;
  SELECT current_price INTO v_price
  FROM retail.products
  WHERE product_id=p_product_id AND is_active=TRUE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Active product % does not exist', p_product_id USING ERRCODE='23503';
  END IF;

  SELECT quantity_on_hand INTO v_stock
  FROM retail.inventory
  WHERE product_id=p_product_id AND warehouse_id=p_warehouse_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Inventory row missing for product % / warehouse %',
      p_product_id, p_warehouse_id USING ERRCODE='P0002';
  END IF;
  IF v_stock < p_quantity THEN
    RAISE EXCEPTION 'Insufficient stock: available %, requested %', v_stock, p_quantity
      USING ERRCODE='P0001';
  END IF;

  INSERT INTO retail.orders(customer_id, order_status)
  VALUES (p_customer_id, 'paid')
  RETURNING order_id INTO p_order_id;

  INSERT INTO retail.order_items(order_id, product_id, quantity, unit_price)
  VALUES (p_order_id, p_product_id, p_quantity, v_price);

  UPDATE retail.inventory
  SET quantity_on_hand = quantity_on_hand - p_quantity
  WHERE product_id=p_product_id AND warehouse_id=p_warehouse_id;
END;
$$;

CREATE OR REPLACE PROCEDURE retail.sp_capture_daily_inventory()
LANGUAGE plpgsql AS $$
DECLARE v_rows INTEGER;
BEGIN
  INSERT INTO retail.inventory_daily_snapshot
    (snapshot_date, product_id, warehouse_id, quantity_on_hand, unit_cost)
  SELECT CURRENT_DATE, i.product_id, i.warehouse_id, i.quantity_on_hand, p.unit_cost
  FROM retail.inventory i JOIN retail.products p USING(product_id)
  ON CONFLICT (snapshot_date, product_id, warehouse_id)
  DO UPDATE SET quantity_on_hand=EXCLUDED.quantity_on_hand,
                unit_cost=EXCLUDED.unit_cost;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  INSERT INTO retail.automation_log(process_name, finished_at, status, records_processed, details)
  VALUES ('daily_inventory_snapshot', clock_timestamp(), 'SUCCESS', v_rows,
          'Idempotent daily stock snapshot upsert.');
EXCEPTION WHEN OTHERS THEN
  INSERT INTO retail.automation_log(process_name, finished_at, status, details)
  VALUES ('daily_inventory_snapshot', clock_timestamp(), 'FAILED', SQLERRM);
  RAISE;
END;
$$;

-- Non-destructive archive: copies eligible rows, verifies count, retains source rows.
-- Physical deletion is deliberately excluded pending an approved retention policy.
CREATE OR REPLACE PROCEDURE retail.sp_archive_old_orders(IN p_retention_days INTEGER DEFAULT 365)
LANGUAGE plpgsql AS $$
DECLARE v_log BIGINT; v_orders INTEGER; v_items INTEGER;
BEGIN
  IF p_retention_days < 1 THEN
    RAISE EXCEPTION 'Retention days must be at least 1';
  END IF;
  INSERT INTO retail.automation_log(process_name, status, details)
  VALUES ('archive_old_orders','RUNNING',
          format('Retention threshold: %s days',p_retention_days))
  RETURNING log_id INTO v_log;

  INSERT INTO retail.orders_archive
  SELECT o.* FROM retail.orders o
  WHERE o.order_date < CURRENT_TIMESTAMP - make_interval(days => p_retention_days)
  ON CONFLICT (order_id) DO NOTHING;
  GET DIAGNOSTICS v_orders = ROW_COUNT;

  INSERT INTO retail.order_items_archive
  SELECT oi.* FROM retail.order_items oi
  JOIN retail.orders_archive oa ON oa.order_id=oi.order_id
  ON CONFLICT (order_item_id) DO NOTHING;
  GET DIAGNOSTICS v_items = ROW_COUNT;

  UPDATE retail.automation_log
  SET finished_at=clock_timestamp(), status='SUCCESS',
      records_processed=v_orders+v_items,
      details=format('Archived %s orders and %s items; source rows retained.',v_orders,v_items)
  WHERE log_id=v_log;
EXCEPTION WHEN OTHERS THEN
  IF v_log IS NOT NULL THEN
    UPDATE retail.automation_log
    SET finished_at=clock_timestamp(), status='FAILED', details=SQLERRM
    WHERE log_id=v_log;
  END IF;
  RAISE;
END;
$$;
