#!/usr/bin/env python3
"""Re-run all packaged reporting queries against the included SQLite validation database.
The production/reporting SQL files in ../sql/ target PostgreSQL; this script validates equivalent logic.
"""
from pathlib import Path
import sqlite3,csv,json,re
ROOT=Path(__file__).resolve().parents[1]
DB=ROOT/'data'/'retail_reporting_validation.sqlite'
SQL=ROOT/'scripts'/'verification_queries.sql'
OUT=ROOT/'outputs'; OUT.mkdir(exist_ok=True)
con=sqlite3.connect(DB)
text=SQL.read_text(encoding='utf-8')
parts=re.split(r'^-- QUERY:([\w]+)\s*$',text,flags=re.M)
summary={}
for i in range(1,len(parts),2):
    name=parts[i]; query=parts[i+1].strip().rstrip(';')
    cur=con.execute(query); cols=[d[0] for d in cur.description]; rows=cur.fetchall()
    with (OUT/f'{name}.csv').open('w',newline='',encoding='utf-8') as f:
        w=csv.writer(f);w.writerow(cols);w.writerows(rows)
    summary[name]={'row_count':len(rows),'columns':cols}
counts={t:con.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0] for t in ['customers','categories','products','suppliers','product_suppliers','warehouses','inventory','orders','order_items','payments','shipments']}
checks={
 'orders_have_customer':con.execute('SELECT COUNT(*) FROM orders o LEFT JOIN customers c USING(customer_id) WHERE c.customer_id IS NULL').fetchone()[0]==0,
 'order_items_have_order':con.execute('SELECT COUNT(*) FROM order_items oi LEFT JOIN orders o USING(order_id) WHERE o.order_id IS NULL').fetchone()[0]==0,
 'order_items_have_product':con.execute('SELECT COUNT(*) FROM order_items oi LEFT JOIN products p USING(product_id) WHERE p.product_id IS NULL').fetchone()[0]==0,
 'positive_quantities':con.execute('SELECT COUNT(*) FROM order_items WHERE quantity<=0').fetchone()[0]==0,
 'nonnegative_inventory':con.execute('SELECT COUNT(*) FROM inventory WHERE quantity_on_hand<0 OR reorder_level<0').fetchone()[0]==0}
result={'engine':'SQLite verification mirror','table_row_counts':counts,'checks':checks,'all_checks_passed':all(checks.values()),'query_results':summary,'note':'This is not PostgreSQL runtime or EXPLAIN benchmark evidence.'}
(OUT/'validation_summary.json').write_text(json.dumps(result,indent=2))
print(json.dumps(result,indent=2))
if not all(checks.values()): raise SystemExit(1)
