# Virtual Retail Environment — Database Design

**Task:** Data Modeling and Architecture Design  
**Role:** SQL Developer Intern  
**Database:** PostgreSQL  
**Status:** Proposed schema and project documentation; run and validate locally before describing it as implemented.

## Overview

This repository contains a relational database design for a virtual retail environment. It models customers, product categories, products, suppliers, warehouses, inventory, orders, order items, payments, and shipments. The design uses primary and foreign keys, unique and check constraints, normalized entities, and indexes aimed at common retail queries.

## Repository structure

```text
virtual-retail-database-project/
├── README.md
├── .gitignore
├── sql/
│   ├── schema.sql
│   ├── sample_data.sql
│   ├── reporting_queries.sql
│   └── validation_tests.sql
├── diagrams/
│   ├── retail_erd.mmd
│   └── architecture.mmd
└── docs/
    ├── Virtual_Retail_Data_Modeling_Report.docx
    └── report_description.txt
```

## Main entities

- `customers`: customer contact information.
- `categories`: product grouping.
- `products`: catalog information and current price.
- `suppliers`: supplier contact information.
- `product_suppliers`: many-to-many product/supplier bridge.
- `warehouses`: stock locations.
- `inventory`: quantity per product and warehouse.
- `orders`: order-level information.
- `order_items`: products and purchase-time unit prices within each order.
- `payments`: payment records and status.
- `shipments`: delivery and tracking information.

## Requirements

- PostgreSQL 14+ recommended.
- A PostgreSQL client such as `psql`, pgAdmin, DBeaver, or another compatible tool.

## Setup

1. Create a new, empty database, for example `virtual_retail`.
2. Run `sql/schema.sql`.
3. Run `sql/sample_data.sql`.
4. Run selected queries from `sql/reporting_queries.sql`.
5. Review `sql/validation_tests.sql` and execute the tests individually. Some examples are intentionally invalid and should fail because of constraints.

Example using `psql`:

```bash
psql -U YOUR_USERNAME -d virtual_retail -f sql/schema.sql
psql -U YOUR_USERNAME -d virtual_retail -f sql/sample_data.sql
```

Replace `YOUR_USERNAME` and the database name with your local values. Do not commit passwords or connection strings.

## ERD and architecture diagrams

The `.mmd` files use Mermaid syntax. View them in a Mermaid-compatible Markdown preview or paste the content into the Mermaid Live Editor. The ERD shows the main cardinalities and the bridge tables used to resolve many-to-many relationships.

## Design choices

- Surrogate identity keys are used for stable row identifiers.
- `NUMERIC(12,2)` is used for currency values.
- `CHECK` constraints restrict invalid quantities, prices, and status values.
- `order_items.unit_price` preserves the price at the time of purchase.
- Composite keys in `inventory` and `product_suppliers` prevent duplicate product/location and product/supplier pairs.
- Indexes are added for frequent order, order-item, payment, shipment, and low-stock queries.

## Important implementation notes

- This is a learning and design project, not a production-ready commerce platform.
- The sample schema does not implement a full payment gateway, tax engine, refund workflow, stock reservation service, or authentication system.
- A production order flow must use transactions and concurrency-safe stock updates to avoid overselling.
- Test all scripts on a disposable database first and document actual results.
- The sample dataset uses fictional information and example-domain email addresses.

## Suggested next improvements

1. Add a graphical export of the ERD to the Word report.
2. Implement transaction-safe order creation and stock reservation.
3. Add returns/refunds, stock movement history, and order status history if required.
4. Compare query plans with `EXPLAIN ANALYZE` on a representative dataset.
5. Add screenshots of successful schema creation and validation to the report if the evaluator expects evidence.

## Author

Replace this section with your name, internship name, and project date before publishing.
