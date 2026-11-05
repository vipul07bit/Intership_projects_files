-- PostgreSQL 15+ | reporting query
SET search_path TO retail, public;
-- Metric definitions and limitations are documented in the Week 4 report.
WITH category_sales AS (
 SELECT c.category_name,COUNT(DISTINCT o.order_id) AS delivered_orders,
        SUM(oi.quantity) AS units_sold,SUM(oi.quantity*oi.unit_price) AS revenue
 FROM categories c JOIN products p ON p.category_id=c.category_id
 JOIN order_items oi ON oi.product_id=p.product_id JOIN orders o ON o.order_id=oi.order_id
 WHERE o.order_status='delivered'
 GROUP BY c.category_id,c.category_name
)
SELECT *,ROUND(100.0*revenue/NULLIF(SUM(revenue) OVER (),0),2) AS revenue_share_pct
FROM category_sales ORDER BY revenue DESC;
