CREATE OR REPLACE FUNCTION retail.fn_inventory_before_update()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_inventory_before_update ON retail.inventory;
CREATE TRIGGER trg_inventory_before_update
BEFORE UPDATE ON retail.inventory
FOR EACH ROW EXECUTE FUNCTION retail.fn_inventory_before_update();

CREATE OR REPLACE FUNCTION retail.fn_inventory_after_update()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.quantity_on_hand IS DISTINCT FROM OLD.quantity_on_hand THEN
    INSERT INTO retail.inventory_movements
      (product_id, warehouse_id, quantity_before, quantity_after,
       change_quantity, movement_reason)
    VALUES
      (NEW.product_id, NEW.warehouse_id, OLD.quantity_on_hand,
       NEW.quantity_on_hand, NEW.quantity_on_hand - OLD.quantity_on_hand,
       'INVENTORY_UPDATE');

    IF NEW.quantity_on_hand <= NEW.reorder_level THEN
      INSERT INTO retail.low_stock_alerts
        (product_id, warehouse_id, current_quantity, reorder_level)
      VALUES (NEW.product_id, NEW.warehouse_id,
              NEW.quantity_on_hand, NEW.reorder_level)
      ON CONFLICT (product_id, warehouse_id) WHERE alert_status = 'OPEN'
      DO UPDATE SET current_quantity = EXCLUDED.current_quantity,
                    reorder_level = EXCLUDED.reorder_level;
    ELSE
      UPDATE retail.low_stock_alerts
      SET alert_status='RESOLVED', resolved_at=clock_timestamp()
      WHERE product_id=NEW.product_id AND warehouse_id=NEW.warehouse_id
        AND alert_status='OPEN';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_inventory_after_update ON retail.inventory;
CREATE TRIGGER trg_inventory_after_update
AFTER UPDATE OF quantity_on_hand ON retail.inventory
FOR EACH ROW EXECUTE FUNCTION retail.fn_inventory_after_update();
