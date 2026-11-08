-- Inventory turnover and stock cover metrics.
-- The query uses snapshots for average inventory valuation and order_items for
-- cost of goods sold. Only paid/completed orders are included.
CREATE OR REPLACE VIEW retail.v_inventory_health AS
WITH sales_30d AS (
  SELECT oi.product_id, SUM(oi.quantity)::NUMERIC AS units_sold_30d,
         SUM(oi.quantity * COALESCE(p.unit_cost, oi.unit_price)) AS cogs_30d
  FROM retail.order_items oi
  JOIN retail.orders o USING(order_id)
  JOIN retail.products p USING(product_id)
  WHERE o.order_status IN ('paid','completed')
    AND o.order_date >= CURRENT_DATE - INTERVAL '30 days'
  GROUP BY oi.product_id
),
avg_stock AS (
  SELECT product_id, AVG(quantity_on_hand)::NUMERIC AS avg_units,
         AVG(quantity_on_hand * COALESCE(unit_cost,0)) AS avg_inventory_value
  FROM retail.inventory_daily_snapshot
  WHERE snapshot_date >= CURRENT_DATE - 30
  GROUP BY product_id
),
stock_now AS (
  SELECT product_id, SUM(quantity_on_hand) AS current_units,
         SUM(reorder_level) AS summed_reorder_level
  FROM retail.inventory GROUP BY product_id
)
SELECT p.product_id, p.sku, p.product_name,
       COALESCE(s.units_sold_30d,0) AS units_sold_30d,
       COALESCE(n.current_units,0) AS current_units,
       COALESCE(a.avg_units, n.current_units, 0) AS average_units,
       CASE WHEN COALESCE(s.units_sold_30d,0)>0
            THEN COALESCE(a.avg_units,n.current_units,0) /
                 (s.units_sold_30d / 30.0) END AS stock_cover_days,
       CASE WHEN COALESCE(a.avg_inventory_value,0)>0
            THEN COALESCE(s.cogs_30d,0) / a.avg_inventory_value END
            AS inventory_turnover_30d,
       CASE WHEN COALESCE(s.units_sold_30d,0)>0
            THEN s.cogs_30d / s.units_sold_30d END AS avg_cogs_per_unit
FROM retail.products p
LEFT JOIN sales_30d s USING(product_id)
LEFT JOIN avg_stock a USING(product_id)
LEFT JOIN stock_now n USING(product_id);

-- Daily capture is a prerequisite for a meaningful average inventory denominator.
-- If snapshots do not yet span 30 days, treat turnover/cover as provisional.
