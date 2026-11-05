-- PostgreSQL 15+ | reporting query
SET search_path TO retail, public;
-- Metric definitions and limitations are documented in the Week 4 report.
SELECT w.warehouse_name,p.sku,p.product_name,i.quantity_on_hand,i.reorder_level,
       (i.reorder_level-i.quantity_on_hand) AS units_below_reorder
FROM inventory i JOIN products p ON p.product_id=i.product_id
JOIN warehouses w ON w.warehouse_id=i.warehouse_id
WHERE i.quantity_on_hand<=i.reorder_level
ORDER BY units_below_reorder DESC,w.warehouse_name,p.product_name;
