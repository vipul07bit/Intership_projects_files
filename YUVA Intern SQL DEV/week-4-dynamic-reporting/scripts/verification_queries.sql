-- SQLite verification equivalents. PostgreSQL-targeted SQL is in ../sql/.
-- QUERY:01_top_products
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

-- QUERY:02_category_performance
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

-- QUERY:03_monthly_trend
WITH monthly AS (
 SELECT substr(o.order_date,1,7) AS sales_month,COUNT(DISTINCT o.order_id) AS delivered_orders,
        SUM(oi.quantity*oi.unit_price) AS revenue
 FROM orders o JOIN order_items oi ON oi.order_id=o.order_id
 WHERE o.order_status='delivered' GROUP BY substr(o.order_date,1,7)
)
SELECT sales_month,delivered_orders,ROUND(revenue,2) AS revenue,
 ROUND(revenue-LAG(revenue) OVER (ORDER BY sales_month),2) AS revenue_change,
 ROUND(100.0*(revenue-LAG(revenue) OVER (ORDER BY sales_month))/NULLIF(LAG(revenue) OVER (ORDER BY sales_month),0),2) AS mom_growth_pct
FROM monthly ORDER BY sales_month;

-- QUERY:04_customer_value
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

-- QUERY:05_repeat_customer_rate
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

-- QUERY:06_low_stock
SELECT w.warehouse_name,p.sku,p.product_name,i.quantity_on_hand,i.reorder_level,
       (i.reorder_level-i.quantity_on_hand) AS units_below_reorder
FROM inventory i JOIN products p ON p.product_id=i.product_id
JOIN warehouses w ON w.warehouse_id=i.warehouse_id
WHERE i.quantity_on_hand<=i.reorder_level
ORDER BY units_below_reorder DESC,w.warehouse_name,p.product_name;

-- QUERY:07_stock_cover_proxy
WITH recent_sales AS (
 SELECT oi.product_id,SUM(oi.quantity) AS units_sold_90d
 FROM order_items oi JOIN orders o ON o.order_id=oi.order_id
 WHERE o.order_status='delivered' AND o.order_date >= '2026-08-07'
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

-- QUERY:08_order_status
WITH order_value AS (
 SELECT o.order_id,o.order_status,SUM(oi.quantity*oi.unit_price) AS order_value
 FROM orders o LEFT JOIN order_items oi ON oi.order_id=o.order_id GROUP BY o.order_id,o.order_status
)
SELECT order_status,COUNT(*) AS order_count,ROUND(SUM(COALESCE(order_value,0)),2) AS merchandise_value,
       ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS order_share_pct
FROM order_value GROUP BY order_status ORDER BY order_count DESC;

