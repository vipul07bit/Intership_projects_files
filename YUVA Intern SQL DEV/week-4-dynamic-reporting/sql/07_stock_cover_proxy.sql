-- PostgreSQL 15+ | reporting query
SET search_path TO retail, public;
-- Metric definitions and limitations are documented in the Week 4 report.
WITH recent_sales AS (
 SELECT oi.product_id,SUM(oi.quantity) AS units_sold_90d
 FROM order_items oi JOIN orders o ON o.order_id=oi.order_id
 WHERE o.order_status='delivered' AND o.order_date >= TIMESTAMPTZ '2026-08-07 00:00:00+00'
 GROUP BY oi.product_id
)
SELECT p.sku,p.product_name,w.warehouse_name,i.quantity_on_hand,
       COALESCE(rs.units_sold_90d,0) AS units_sold_90d,
       ROUND(COALESCE(rs.units_sold_90d,0)/90.0,3) AS avg_daily_units,
       CASE WHEN COALESCE(rs.units_sold_90d,0)=0 THEN NULL
            ELSE ROUND(i.quantity_on_hand/(rs.units_sold_90d/90.0),1) END AS estimated_stock_cover_days
FROM inventory i JOIN products p ON p.product_id=i.product_id
JOIN warehouses w ON w.warehouse_id=i.warehouse_id
LEFT JOIN recent_sales rs ON rs.product_id=p.product_id
ORDER BY estimated_stock_cover_days ASC;
