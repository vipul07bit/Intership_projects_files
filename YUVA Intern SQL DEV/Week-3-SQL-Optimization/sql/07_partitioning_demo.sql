-- Optional advanced experiment: range partitioning by order_date.
-- Demonstrates partition pruning. This is a separate comparison table so the
-- original Week 1/2 retail orders table remains unchanged.
SET search_path TO retail, public;

DROP TABLE IF EXISTS orders_partitioned CASCADE;
CREATE TABLE orders_partitioned (
    order_id BIGINT NOT NULL,
    customer_id BIGINT NOT NULL,
    order_date TIMESTAMP NOT NULL,
    order_status VARCHAR(20) NOT NULL,
    order_total NUMERIC(14,2) NOT NULL
) PARTITION BY RANGE (order_date);

CREATE TABLE orders_p_before_2025 PARTITION OF orders_partitioned
FOR VALUES FROM (MINVALUE) TO (TIMESTAMP '2025-01-01');
CREATE TABLE orders_p_2025 PARTITION OF orders_partitioned
FOR VALUES FROM (TIMESTAMP '2025-01-01') TO (TIMESTAMP '2026-01-01');
CREATE TABLE orders_p_2026 PARTITION OF orders_partitioned
FOR VALUES FROM (TIMESTAMP '2026-01-01') TO (TIMESTAMP '2027-01-01');
CREATE TABLE orders_p_2027_plus PARTITION OF orders_partitioned
FOR VALUES FROM (TIMESTAMP '2027-01-01') TO (MAXVALUE);

INSERT INTO orders_partitioned
SELECT order_id, customer_id, order_date, order_status, order_total
FROM orders;

CREATE INDEX idx_orders_partitioned_date
ON orders_partitioned (order_date);

ANALYZE orders_partitioned;

-- Inspect the plan. A 2026-only predicate should prune unrelated partitions.
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)
SELECT order_id, customer_id, order_date, order_total
FROM orders_partitioned
WHERE order_date >= TIMESTAMP '2026-01-01'
  AND order_date <  TIMESTAMP '2027-01-01';

-- Partitioning is not automatically faster for every workload.
-- Compare the plan and timing against the same query on the non-partitioned
-- orders table; account for table size, cache state and partition count.

-- Fair comparison (control): give the plain table the same kind of index first,
-- otherwise the partitioned table has an index on order_date and orders does not.
--   CREATE INDEX idx_orders_order_date_ctrl ON orders (order_date);
--   ANALYZE orders;
--   (run the same 2026 range query on orders, then)
--   DROP INDEX idx_orders_order_date_ctrl;
-- 08_run_benchmarks.py performs this control automatically (benchmark BM-10).
