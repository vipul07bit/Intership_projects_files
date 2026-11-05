# Week 4 – Dynamic Reporting and Data Visualization Using SQL

## Deliverables
- `docs/Week_4_Dynamic_Reporting_Report.docx` – primary internship report.
- `sql/` – eight PostgreSQL 15+ reporting queries.
- `data/` – deterministic synthetic data extracts and SQLite verification database.
- `scripts/verify_package.py` – reruns all packaged verification queries and refreshes CSV outputs automatically.
- `scripts/verification_queries.sql` – SQLite-compatible equivalents used only for local logic verification.
- `outputs/` – exact CSV/Markdown outputs, row counts and validation summary.
- `visualizations/` – chart examples referenced in the report.

## Reproducibility
The synthetic data uses seed `20261105`. Run the generator with Python 3. The report query logic was executed against a SQLite verification mirror because PostgreSQL was not available in the artifact-generation environment. The SQL files are authored for PostgreSQL and must be run against the internship PostgreSQL database before claiming PostgreSQL runtime validation.

## Important metric boundaries
- Delivered revenue is line quantity × order-time unit price for `delivered` orders. It is not net revenue.
- Inventory turnover is not calculated because the source model has no dated stock movement ledger or COGS.
- Stock-cover days is an indicative proxy using trailing 90-day delivered unit demand and is not warehouse-attributed.
- Synthetic outputs are test evidence, not real business results.

## Run
1. Review the report's assumptions and SQL files.
2. Use a disposable PostgreSQL 15+ database with the Week 1 retail schema.
3. Execute the SQL scripts in `sql/`.
4. Capture `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)` in PostgreSQL for performance evaluation.
5. Do not treat SQLite verification as PostgreSQL plan or performance evidence.
