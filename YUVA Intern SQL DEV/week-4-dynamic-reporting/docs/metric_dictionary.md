# Metric dictionary

| Metric | Definition | Important caveat |
|---|---|---|
| Delivered revenue | Sum(quantity × order-item unit_price) for delivered orders | Not net revenue; excludes tax/discount/refund accounting. |
| Units sold | Sum quantity for delivered orders | Excludes cancelled/refunded/in-flight orders. |
| AOV | Delivered revenue / distinct delivered orders | Calculated at order grain. |
| Repeat customer | Customer with >=2 delivered orders in period | Not cohort retention or lifetime value. |
| Low stock | quantity_on_hand <= reorder_level | Threshold alert, not a forecast. |
| Stock cover days | on-hand / trailing-90-day average daily delivered units | Product-level demand applied to each warehouse; proxy only. |
| Inventory turnover | Not computed | Requires COGS and average inventory or movement history. |
