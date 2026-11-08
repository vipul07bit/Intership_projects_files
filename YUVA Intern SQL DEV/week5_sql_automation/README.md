# Week 5 — SQL Automation and Integration (PostgreSQL)

This package extends the virtual retail model from Weeks 1–2 and uses the `retail` schema/table names documented in the modeling report: `customers`, `products`, `warehouses`, `inventory`, `orders`, and `order_items`.

## Contents
- `sql/00_bootstrap_retail.sql` — compatible training bootstrap and additive columns/indexes.
- `sql/01_automation_support_tables.sql` — inventory movement, alert, log, archive and daily snapshot tables.
- `sql/02_triggers.sql` — automatic movement logging, low-stock alert creation and resolution.
- `sql/03_stored_procedures.sql` — transactional sale, daily stock snapshot and non-destructive archive.
- `sql/04_metrics_and_reporting.sql` — inventory turnover / stock cover view.
- `sql/05_seed_demo_data.sql` — idempotent synthetic fixture rows (`.example.test` email).
- `sql/06_run_demo.sql` — demonstration sale and evidence queries.
- `sql/07_tests.sql` — SQL assertions, including oversell rejection and alert lifecycle; transaction rolls back.
- `sql/08_schedule_pg_cron.sql` — optional pg_cron schedule.
- `scripts/run_all.sh` / `.ps1` — one-command execution using `DATABASE_URL`.
- `docs/Week_5_Automation_Report.docx` — submission report.
- `diagrams/` — architecture/workflow and metric charts.

## Requirements and execution
PostgreSQL 14+ and `psql`. Use a disposable training database or take a backup first. The scripts are ordered and use `ON_ERROR_STOP`. Set a connection string, then:
```bash
export DATABASE_URL='postgresql://username:password@localhost:5432/retaildb'
bash scripts/run_all.sh
```
PowerShell:
```powershell
$env:DATABASE_URL='postgresql://username:password@localhost:5432/retaildb'
.\scripts\run_all.ps1
```
Do not commit credentials. The bootstrap creates a minimal compatible schema if absent; on an existing database, `CREATE TABLE IF NOT EXISTS` does not reconcile every possible column/type difference. Compare your live schema first. The Week 1–2 report was a proposed design, not proof that every table was already deployed.

## Important implementation decisions
1. `sp_process_sale` locks the inventory row with `FOR UPDATE`, checks stock, inserts the order and line, then deducts stock. A failed `CALL` is statement-atomic in PostgreSQL; the test asserts that an oversell attempt leaves no order.
2. The trigger logs stock movements and maintains one open low-stock alert per product/warehouse. Replenishment resolves the open alert.
3. Archiving is intentionally copy-only. It does not delete original sales. Deletion requires a retention/legal approval, verified row counts, and tested restore plan.
4. `pg_cron` is optional because managed PostgreSQL services may not permit installing it. A host scheduler can call `psql` instead.
5. Metrics use 30-day paid/completed order items. Inventory turnover is COGS divided by average inventory value. Stock cover days is average stock units divided by average daily units sold. Daily snapshots are needed for a defensible average; before a full period exists, values are provisional.

## Evidence status
The included seed values and expected test cases are deterministic synthetic fixtures. The scripts are generated, but no connection to your internship PostgreSQL server was available in this workspace; therefore no live database execution, query plan, runtime, or screenshot is claimed. Run the harness against your database and preserve the actual terminal output in `tests/execution_log.txt`. Do not label illustrative charts as measured production results.
