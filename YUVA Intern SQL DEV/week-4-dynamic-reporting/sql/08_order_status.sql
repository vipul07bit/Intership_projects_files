-- PostgreSQL 15+ | reporting query
SET search_path TO retail, public;
-- Metric definitions and limitations are documented in the Week 4 report.
WITH order_value AS (
 SELECT o.order_id,o.order_status,SUM(oi.quantity*oi.unit_price) AS order_value
 FROM orders o LEFT JOIN order_items oi ON oi.order_id=o.order_id GROUP BY o.order_id,o.order_status
)
SELECT order_status,COUNT(*) AS order_count,ROUND(SUM(COALESCE(order_value,0)),2) AS merchandise_value,
       ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS order_share_pct
FROM order_value GROUP BY order_status ORDER BY order_count DESC;
