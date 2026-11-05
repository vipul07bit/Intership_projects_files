-- PostgreSQL 15+ | reporting query
SET search_path TO retail, public;
-- Metric definitions and limitations are documented in the Week 4 report.
WITH customer_metrics AS (
 SELECT c.customer_id,c.full_name,COUNT(DISTINCT o.order_id) AS delivered_orders,
        SUM(oi.quantity*oi.unit_price) AS delivered_revenue,
        MIN(o.order_date) AS first_delivered_order,MAX(o.order_date) AS latest_delivered_order
 FROM customers c JOIN orders o ON o.customer_id=c.customer_id
 JOIN order_items oi ON oi.order_id=o.order_id
 WHERE o.order_status='delivered'
 GROUP BY c.customer_id,c.full_name
)
SELECT *,ROUND(delivered_revenue/NULLIF(delivered_orders,0),2) AS avg_order_value,
       CASE WHEN delivered_orders>=8 THEN 'High frequency'
            WHEN delivered_orders>=3 THEN 'Repeat customer' ELSE 'Occasional customer' END AS segment,
       RANK() OVER (ORDER BY delivered_revenue DESC) AS customer_revenue_rank
FROM customer_metrics ORDER BY delivered_revenue DESC LIMIT 15;
