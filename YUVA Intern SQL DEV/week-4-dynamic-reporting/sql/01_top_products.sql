-- PostgreSQL 15+ | reporting query
SET search_path TO retail, public;
-- Metric definitions and limitations are documented in the Week 4 report.
WITH product_sales AS (
 SELECT p.product_id,p.sku,p.product_name,c.category_name,
        SUM(oi.quantity) AS units_sold,
        SUM(oi.quantity * oi.unit_price) AS delivered_revenue,
        COUNT(DISTINCT o.order_id) AS delivered_orders
 FROM orders o JOIN order_items oi ON oi.order_id=o.order_id
 JOIN products p ON p.product_id=oi.product_id
 LEFT JOIN categories c ON c.category_id=p.category_id
 WHERE o.order_status='delivered'
 GROUP BY p.product_id,p.sku,p.product_name,c.category_name
)
SELECT *,ROUND(100.0*delivered_revenue/NULLIF(SUM(delivered_revenue) OVER (),0),2) AS revenue_share_pct,
       RANK() OVER (ORDER BY delivered_revenue DESC) AS revenue_rank
FROM product_sales ORDER BY delivered_revenue DESC LIMIT 10;
