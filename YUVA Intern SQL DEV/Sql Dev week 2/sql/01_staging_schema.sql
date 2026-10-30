-- Week 2 ETL: raw landing/staging structures.
-- Run in a dedicated schema/database. Raw values are TEXT intentionally:
-- source formatting problems must be captured before validation.
CREATE SCHEMA IF NOT EXISTS etl;
CREATE TABLE IF NOT EXISTS etl.batch_control (
    batch_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    source_name TEXT NOT NULL,
    started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'RUNNING'
        CHECK (status IN ('RUNNING','SUCCEEDED','FAILED','PARTIAL')),
    extracted_rows INTEGER NOT NULL DEFAULT 0,
    loaded_rows INTEGER NOT NULL DEFAULT 0,
    rejected_rows INTEGER NOT NULL DEFAULT 0,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS etl.stg_customers (
    batch_id BIGINT NOT NULL REFERENCES etl.batch_control(batch_id),
    source_customer_id TEXT,
    full_name TEXT, email TEXT, phone TEXT, created_at TEXT,
    extracted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS etl.stg_products (
    batch_id BIGINT NOT NULL REFERENCES etl.batch_control(batch_id),
    source_product_id TEXT, sku TEXT, product_name TEXT,
    category_name TEXT, current_price TEXT, is_active TEXT,
    extracted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS etl.stg_orders (
    batch_id BIGINT NOT NULL REFERENCES etl.batch_control(batch_id),
    source_order_id TEXT, source_customer_id TEXT, order_date TEXT,
    order_status TEXT, shipping_address TEXT,
    extracted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS etl.stg_order_items (
    batch_id BIGINT NOT NULL REFERENCES etl.batch_control(batch_id),
    source_order_id TEXT, sku TEXT, quantity TEXT, unit_price TEXT,
    extracted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS etl.stg_inventory (
    batch_id BIGINT NOT NULL REFERENCES etl.batch_control(batch_id),
    sku TEXT, warehouse_name TEXT, quantity_on_hand TEXT, updated_at TEXT,
    extracted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS etl.reject_log (
    reject_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    batch_id BIGINT NOT NULL REFERENCES etl.batch_control(batch_id),
    source_table TEXT NOT NULL,
    source_record_key TEXT,
    rejection_reason TEXT NOT NULL,
    raw_record JSONB,
    rejected_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
