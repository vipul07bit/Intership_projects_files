# Week 2 — Retail ETL Planning

This repository contains the Week 2 ETL planning deliverables for the SQL Developer Internship. The plan reuses the Week 1 PostgreSQL virtual retail schema as its target.

## Repository structure
- `docs/Week2_ETL_Planning_Report.docx` — required Word report.
- `diagrams/etl_pipeline.png` — ETL architecture flowchart.
- `diagrams/etl_pipeline.mmd` — editable Mermaid source.
- `sql/01_staging_schema.sql` — ETL batch, staging and reject tables.
- `sql/02_transform_reference_load.sql` — worked transformation/load examples for categories, customers and products.
- `sql/03_data_quality_checks.sql` — validation queries.
- `sql/04_incremental_load_design.sql` — watermark-based incremental pattern.
- `data/` — synthetic CSV source extracts.

## Important scope note
The target business tables (`customers`, `categories`, `products`, `suppliers`, `product_suppliers`, `warehouses`, `inventory`, `orders`, `order_items`, `payments`, `shipments`) are part of the Week 1 model and are not recreated here. Run these scripts only after the Week 1 target schema exists.

## Suggested execution
1. Back up or use a development copy of the Week 1 PostgreSQL database.
2. Run `sql/01_staging_schema.sql`.
3. Create a batch:
   ```sql
   INSERT INTO etl.batch_control(source_name, notes)
   VALUES ('sample_customer_product_batch', 'Synthetic Week 2 demonstration')
   RETURNING batch_id;
   ```
4. Import each CSV into its matching `etl.stg_*` table. Add the returned `batch_id` to each imported row. Use pgAdmin/DBeaver import or `psql \copy`; server-side `COPY` requires the file to be readable by the database server.
5. Run `sql/03_data_quality_checks.sql`, replacing `:batch_id` with the returned value. Review rejects before loading.
6. Run `sql/02_transform_reference_load.sql` for the reference-data examples, replacing `:batch_id`. The `:batch_id` syntax is a client placeholder; some SQL clients require a bind variable or literal number.
7. Adapt order, order-item, inventory, payment and shipment loads after implementing a source-to-target key map and confirming source status/date mappings.
8. Reconcile counts and mark the batch status only after successful validation and commit.

## Sample data
All records are synthetic. The sample batch intentionally contains case/whitespace differences, a repeated customer email, a repeated SKU, a negative product price, an unknown customer reference, an invalid order-line quantity, and an unknown inventory SKU.

## Safety
- Never commit `.env`, database passwords, API tokens, payment-card data, or real customer exports.
- Do not run the scripts against production without reviewing permissions, backups, mappings, and transaction behavior.
- The SQL is a planning/reference implementation, not a claim that a complete production ETL job has been deployed.
