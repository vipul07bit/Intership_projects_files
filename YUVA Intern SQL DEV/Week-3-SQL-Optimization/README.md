# Week 3 – SQL Query Optimization and Performance Tuning

**Track:** SQL Developer internship | **Database:** PostgreSQL (schema `retail`) | **Author:** Vipul

## Project objective
Find and fix performance bottlenecks in a virtual retail database. Each optimization is justified by an `EXPLAIN (ANALYZE, BUFFERS)` plan and a median-of-five timing, and each business result is checked to be unchanged. It continues Week 1 (retail data model) and Week 2 (ETL plan).

## Database structure
Schema `retail`: `suppliers` → `products` → `order_items` ← `orders` ← `customers`, plus `inventory` (one row per product). At baseline only primary keys, `customers.email` UNIQUE and foreign keys exist; the optimization indexes are created only in `05_create_indexes.sql`.

## Dataset size (verified with COUNT(*))
| Table | Rows |
|---|---|
| suppliers | 500 |
| customers | 50,000 |
| products | 10,000 |
| orders | 200,000 |
| order_items | 600,000 |
| inventory | 10,000 |
| **Total** | **870,500** (synthetic, ~137 MB) |

## Tools
PostgreSQL 16 (psql, pgAdmin or DBeaver), Python 3 with `psycopg2-binary` for the benchmark runner, Mermaid for the flowchart.

## Repository structure
```text
README.md
sql/       01_create_schema.sql … 07_partitioning_demo.sql, 08_run_benchmarks.py
results/   performance-comparison.csv, benchmark_results.json, benchmark-protocol.md,
           benchmark-chart.png, execution-plans/ (full plan text for every benchmark)
diagrams/  performance-tuning-flowchart.mmd / .png
report/    Week-3-SQL-Optimization-Report.docx
SUBMISSION_DESCRIPTION.txt
```

## How to run each script
```bash
createdb retaildb
psql -d retaildb -f sql/01_create_schema.sql      # schema + 6 tables
psql -d retaildb -f sql/02_generate_data.sql      # 870,500 rows, ~15 s, then ANALYZE
psql -d retaildb -f sql/03_baseline_queries.sql   # baseline plans B1-B7 (save the output)
psql -d retaildb -f sql/04_rewrite_examples.sql   # year-filter rewrite, SELECT *, aggregation
psql -d retaildb -f sql/05_create_indexes.sql     # 4 optimization indexes
psql -d retaildb -c "VACUUM (ANALYZE) orders"     # needed for index-only scans
psql -d retaildb -f sql/06_optimized_queries.sql  # same queries after indexing
psql -d retaildb -f sql/07_partitioning_demo.sql  # orders_partitioned + pruning check
```
Automatic end-to-end run with 5 timed runs per query (re-runnable, after 01 and 02):
```bash
pip install psycopg2-binary
python sql/08_run_benchmarks.py "host=localhost dbname=retaildb user=postgres" results
```
Before collecting your own plans run `SHOW enable_seqscan;` – it must be `on`.

## Optimization techniques
- **Composite covering index** `orders(customer_id, order_date DESC) INCLUDE (order_status, order_total)` for customer history and the customer-order join.
- **Composite covering index** `orders(order_status, order_date DESC) INCLUDE (customer_id, order_total)` for delivered-sales reports (Index Only Scan for the monthly aggregate).
- **Composite index** `products(category, is_active, product_name)` for category browsing.
- **Partial index** `inventory(quantity_on_hand, product_id) WHERE quantity_on_hand <= reorder_level` for low-stock checks.
- **Sargable rewrite** of `DATE_PART('year', order_date) = 2026` into a half-open date range.
- **Narrow projection** instead of `SELECT *`.
- **Range partitioning** of orders by `order_date` (partition pruning).

## Benchmarking methodology
One discarded warm-up run and five recorded runs per query, warm cache, identical parameters; **median** `Execution Time` reported; full-result hash compared for every before/after pair; improvement % = (Before − After) / Before × 100. Full details in `results/benchmark-protocol.md`. Results from my own instance (Environment A, four supplied plans, single runs) and from the reproduction run (Environment B, PostgreSQL 16.15, 2 vCPU) are kept in separate rows and never compared with each other.

## Key findings (Environment B, median of 5)
| ID | Scenario | Before ms | After ms | Improvement |
|---|---|---|---|---|
| BM-01 | Customer order history | 11.073 | 0.014 | 99.9% |
| BM-02 | Category browsing | 1.178 | 0.065 | 94.5% |
| BM-03 | Delivered sales 2026 | 20.864 | 14.429 | 30.8% |
| BM-04 | Customer-order join | 11.856 | 0.051 | 99.6% |
| BM-05 | Low-stock inventory | 2.424 | 3.101 | −27.9% (inconclusive, noise) |
| BM-06 | Year filter rewrite only | 24.199 | 22.840 | 5.6% (not significant) |
| BM-07 | Monthly delivered revenue | 20.462 | 6.742 | 67.1% |
| BM-08 | SELECT * vs column list | 0.028 | 0.009 | not significant (microseconds) |
| BM-09 | Partitioned vs plain | 25.401 | 12.603 | 50.4% |
| BM-10 | Partitioned vs plain + order_date index | 20.335 | 12.603 | 38.0% |

Plans supplied from my own instance: sequential scan 125.4 ms → bitmap heap scan 74.4 ms (40.7%, provisional) and bitmap scan on `orders` 74.4 ms → partition `orders_p_2026` 46.5 ms (37.5%, provisional). Their `10000000000.00` costs are the signature of `enable_seqscan = off`; the 1,000 vs 53,673 row estimate is the default for a function applied to a column.

## Limitations
Synthetic data and a small 14 MiB orders table; one 2-vCPU container, warm cache, no concurrent load; index write overhead and cold-cache behaviour not measured; Environment A plans are single runs; `order_total` is not consistent with `order_items`. See report Section 13.
