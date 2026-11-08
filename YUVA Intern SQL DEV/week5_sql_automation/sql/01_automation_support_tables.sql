CREATE TABLE IF NOT EXISTS retail.inventory_movements (
  movement_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  product_id BIGINT NOT NULL REFERENCES retail.products(product_id),
  warehouse_id BIGINT NOT NULL REFERENCES retail.warehouses(warehouse_id),
  quantity_before INTEGER NOT NULL,
  quantity_after INTEGER NOT NULL,
  change_quantity INTEGER NOT NULL,
  movement_reason VARCHAR(40) NOT NULL,
  reference_id BIGINT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp()
);
CREATE TABLE IF NOT EXISTS retail.low_stock_alerts (
  alert_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  product_id BIGINT NOT NULL REFERENCES retail.products(product_id),
  warehouse_id BIGINT NOT NULL REFERENCES retail.warehouses(warehouse_id),
  current_quantity INTEGER NOT NULL,
  reorder_level INTEGER NOT NULL,
  alert_status VARCHAR(20) NOT NULL DEFAULT 'OPEN'
    CHECK (alert_status IN ('OPEN','RESOLVED')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  resolved_at TIMESTAMPTZ
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_open_low_stock_alert
  ON retail.low_stock_alerts(product_id, warehouse_id)
  WHERE alert_status = 'OPEN';

CREATE TABLE IF NOT EXISTS retail.automation_log (
  log_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  process_name VARCHAR(100) NOT NULL,
  started_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
  finished_at TIMESTAMPTZ,
  status VARCHAR(20) NOT NULL CHECK (status IN ('RUNNING','SUCCESS','FAILED')),
  records_processed INTEGER NOT NULL DEFAULT 0,
  details TEXT
);
CREATE TABLE IF NOT EXISTS retail.orders_archive
  (LIKE retail.orders INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING GENERATED);
CREATE TABLE IF NOT EXISTS retail.order_items_archive
  (LIKE retail.order_items INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING GENERATED);
-- Preserve original primary keys in archive and prevent duplicate archive copies.
CREATE UNIQUE INDEX IF NOT EXISTS uq_orders_archive_id ON retail.orders_archive(order_id);
CREATE UNIQUE INDEX IF NOT EXISTS uq_order_items_archive_id ON retail.order_items_archive(order_item_id);

CREATE TABLE IF NOT EXISTS retail.inventory_daily_snapshot (
  snapshot_date DATE NOT NULL,
  product_id BIGINT NOT NULL REFERENCES retail.products(product_id),
  warehouse_id BIGINT NOT NULL REFERENCES retail.warehouses(warehouse_id),
  quantity_on_hand INTEGER NOT NULL,
  unit_cost NUMERIC(12,2),
  PRIMARY KEY(snapshot_date, product_id, warehouse_id)
);
