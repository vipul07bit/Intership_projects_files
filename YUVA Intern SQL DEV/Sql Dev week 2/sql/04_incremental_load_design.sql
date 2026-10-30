-- Incremental extraction design.
-- Use a source-side modified_at/updated_at timestamp plus a persisted watermark.
-- A small overlap window (e.g. 5 minutes) helps capture late-arriving updates;
-- target upserts make the overlap safe when business keys are stable.
CREATE TABLE IF NOT EXISTS etl.source_watermark (
    source_name TEXT PRIMARY KEY,
    last_successful_watermark TIMESTAMPTZ NOT NULL
);

-- Example source extraction predicate (execute against the source system):
-- SELECT * FROM source_orders
-- WHERE modified_at >= :last_successful_watermark - INTERVAL '5 minutes'
--   AND modified_at < :run_started_at
-- ORDER BY modified_at;

-- Advance the watermark ONLY after the batch has passed validation and committed:
-- INSERT INTO etl.source_watermark(source_name,last_successful_watermark)
-- VALUES ('orders', :run_started_at)
-- ON CONFLICT(source_name) DO UPDATE
-- SET last_successful_watermark = EXCLUDED.last_successful_watermark;

-- Full reload: suitable for small reference tables or initial load.
-- Incremental: suitable for high-volume orders/payments and frequent updates.
-- Upsert: makes reruns idempotent when the target has a stable UNIQUE business key.
