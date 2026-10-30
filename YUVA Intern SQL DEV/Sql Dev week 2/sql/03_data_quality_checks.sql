-- Data-quality checks: run after staging import and before target loading.
-- Replace :batch_id with the current batch ID.

-- A. Blank required customer identifiers
SELECT source_customer_id, full_name, email
FROM etl.stg_customers
WHERE batch_id = :batch_id
  AND (NULLIF(TRIM(full_name),'') IS NULL OR NULLIF(TRIM(email),'') IS NULL);

-- B. Duplicate customer emails after case/space normalization
SELECT LOWER(TRIM(email)) AS normalized_email, COUNT(*) AS row_count
FROM etl.stg_customers
WHERE batch_id = :batch_id AND NULLIF(TRIM(email),'') IS NOT NULL
GROUP BY LOWER(TRIM(email))
HAVING COUNT(*) > 1;

-- C. Invalid or negative product prices
SELECT source_product_id, sku, current_price
FROM etl.stg_products
WHERE batch_id = :batch_id
  AND (TRIM(current_price) !~ '^[0-9]+([.][0-9]{1,2})?$'
       OR CASE WHEN TRIM(current_price) ~ '^-?[0-9]+([.][0-9]{1,2})?$'
               THEN TRIM(current_price)::numeric < 0 ELSE TRUE END);

-- D. Invalid order status (business-approved list)
SELECT source_order_id, order_status
FROM etl.stg_orders
WHERE batch_id = :batch_id
  AND LOWER(TRIM(order_status)) NOT IN
      ('pending','paid','processing','shipped','delivered','cancelled','refunded');

-- E. Invalid order-item quantities
SELECT source_order_id, sku, quantity
FROM etl.stg_order_items
WHERE batch_id = :batch_id
  AND (TRIM(quantity) !~ '^[0-9]+$' OR
       CASE WHEN TRIM(quantity) ~ '^[0-9]+$'
            THEN TRIM(quantity)::integer <= 0 ELSE TRUE END);

-- F. Inventory rows whose SKU does not exist in target products
SELECT s.sku, s.warehouse_name
FROM etl.stg_inventory s
LEFT JOIN products p ON p.sku = TRIM(s.sku)
WHERE s.batch_id = :batch_id AND p.product_id IS NULL;

-- G. Referential integrity check for staged orders (source customer key mapping
-- must exist in the source-to-target key map before loading).
