-- Run after collecting baseline results. Indexes are hypotheses to test,
-- not a rule to index every column.
SET search_path TO retail, public;

-- Supports customer history filter + newest-first ordering.
CREATE INDEX idx_orders_customer_date
ON orders (customer_id, order_date DESC)
INCLUDE (order_status, order_total);

-- Supports delivered-order date range filtering.
CREATE INDEX idx_orders_status_date
ON orders (order_status, order_date DESC)
INCLUDE (customer_id, order_total);

-- Supports category browsing and active-product filtering.
CREATE INDEX idx_products_category_active_name
ON products (category, is_active, product_name);

-- Supports inventory reorder checks. Partial index stores only low-stock rows
-- at index creation time only if predicate is stable; quantity changes mean
-- rows enter/leave the index as updates occur.
CREATE INDEX idx_inventory_low_stock
ON inventory (quantity_on_hand, product_id)
WHERE quantity_on_hand <= reorder_level;

ANALYZE;

-- Optional but recommended before re-running 06 (index-only scans need a current
-- visibility map). Run it as a separate statement outside any transaction block:
--   VACUUM (ANALYZE) orders;
