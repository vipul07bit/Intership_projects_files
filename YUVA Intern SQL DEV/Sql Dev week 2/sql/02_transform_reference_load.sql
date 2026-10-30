-- Example load sequence for the Week 1 retail model.
-- Assumes Week 1 target tables already exist with the documented columns.
-- CSV files are imported into etl.stg_* first (see README for COPY instructions).
-- Create a batch row and replace :batch_id with its returned numeric ID in your SQL client.

BEGIN;

-- 1) Categories: trim and normalize names; upsert by unique category_name.
INSERT INTO categories (category_name)
SELECT DISTINCT INITCAP(LOWER(TRIM(category_name)))
FROM etl.stg_products
WHERE batch_id = :batch_id
  AND NULLIF(TRIM(category_name), '') IS NOT NULL
ON CONFLICT (category_name) DO NOTHING;

-- 2) Customers: normalize email, trim name/phone, retain NULL for optional phone.
-- Exact duplicate source rows collapse; email conflict updates contact details.
INSERT INTO customers (full_name, email, phone, created_at)
SELECT DISTINCT ON (LOWER(TRIM(email)))
       TRIM(full_name),
       LOWER(TRIM(email)),
       NULLIF(TRIM(phone), ''),
       COALESCE(NULLIF(TRIM(created_at), '')::timestamp, CURRENT_TIMESTAMP)
FROM etl.stg_customers
WHERE batch_id = :batch_id
  AND NULLIF(TRIM(full_name), '') IS NOT NULL
  AND NULLIF(TRIM(email), '') IS NOT NULL
ORDER BY LOWER(TRIM(email)), extracted_at
ON CONFLICT (email) DO UPDATE
SET full_name = EXCLUDED.full_name,
    phone = COALESCE(EXCLUDED.phone, customers.phone);

-- 3) Products: reject invalid prices before insert; map category by normalized name.
INSERT INTO products (category_id, sku, product_name, current_price, is_active)
SELECT c.category_id, TRIM(s.sku), TRIM(s.product_name),
       TRIM(s.current_price)::numeric(12,2),
       LOWER(TRIM(s.is_active)) IN ('true','1','yes')
FROM etl.stg_products s
JOIN categories c
  ON c.category_name = INITCAP(LOWER(TRIM(s.category_name)))
WHERE s.batch_id = :batch_id
  AND NULLIF(TRIM(s.sku), '') IS NOT NULL
  AND NULLIF(TRIM(s.product_name), '') IS NOT NULL
  AND TRIM(s.current_price) ~ '^[0-9]+([.][0-9]{1,2})?$'
  AND TRIM(s.current_price)::numeric >= 0
ON CONFLICT (sku) DO UPDATE
SET product_name = EXCLUDED.product_name,
    category_id = EXCLUDED.category_id,
    current_price = EXCLUDED.current_price,
    is_active = EXCLUDED.is_active;

COMMIT;

-- Orders and order_items require mapping source IDs/SKUs to generated target IDs.
-- A production implementation should maintain etl.source_key_map(source_system,
-- entity_name, source_key, target_id) or use a stable external_id column.
-- Do not assume source IDs equal PostgreSQL identity IDs.
