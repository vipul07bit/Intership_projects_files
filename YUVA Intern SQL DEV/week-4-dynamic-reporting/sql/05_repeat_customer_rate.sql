-- PostgreSQL 15+ | reporting query
SET search_path TO retail, public;
-- Metric definitions and limitations are documented in the Week 4 report.
WITH per_customer AS (
 SELECT c.customer_id,COUNT(DISTINCT o.order_id) AS delivered_orders
 FROM customers c LEFT JOIN orders o ON o.customer_id=c.customer_id AND o.order_status='delivered'
 GROUP BY c.customer_id
)
SELECT COUNT(*) AS total_customers,
 SUM(CASE WHEN delivered_orders>=2 THEN 1 ELSE 0 END) AS repeat_customers,
 ROUND(100.0*SUM(CASE WHEN delivered_orders>=2 THEN 1 ELSE 0 END)/COUNT(*),2) AS repeat_customer_pct,
 ROUND(AVG(delivered_orders),2) AS avg_delivered_orders_per_customer
FROM per_customer;
