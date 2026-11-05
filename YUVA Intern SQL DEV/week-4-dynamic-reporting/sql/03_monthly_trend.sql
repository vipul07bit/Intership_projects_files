-- PostgreSQL 15+ | reporting query
SET search_path TO retail, public;
-- Metric definitions and limitations are documented in the Week 4 report.
WITH monthly AS (
 SELECT TO_CHAR(o.order_date::date, 'YYYY-MM') AS sales_month,COUNT(DISTINCT o.order_id) AS delivered_orders,
        SUM(oi.quantity*oi.unit_price) AS revenue
 FROM orders o JOIN order_items oi ON oi.order_id=o.order_id
 WHERE o.order_status='delivered' GROUP BY TO_CHAR(o.order_date::date, 'YYYY-MM')
)
SELECT sales_month,delivered_orders,ROUND(revenue,2) AS revenue,
 ROUND(revenue-LAG(revenue) OVER (ORDER BY sales_month),2) AS revenue_change,
 ROUND(100.0*(revenue-LAG(revenue) OVER (ORDER BY sales_month))/NULLIF(LAG(revenue) OVER (ORDER BY sales_month),0),2) AS mom_growth_pct
FROM monthly ORDER BY sales_month;
