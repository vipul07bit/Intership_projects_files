#!/usr/bin/env python3
"""Week 3 benchmark runner (PostgreSQL).

Runs the Week 3 experiments end to end and records REAL measurements:
  * 1 discarded warm-up run + 5 recorded runs per query (warm-cache), median reported
  * Execution Time / Planning Time taken from EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)
  * result-equivalence check (hash of the full result set) for every before/after pair
  * full text plan of the last run saved under results/execution-plans/

Prerequisite: 01_create_schema.sql and 02_generate_data.sql already executed.
Usage:
    pip install psycopg2-binary
    python 08_run_benchmarks.py "host=localhost port=5432 dbname=retaildb user=postgres password=..." ../results
The script drops/recreates ONLY the lab indexes and orders_partitioned, so it can be re-run.
"""
import hashlib, json, os, statistics, sys
import psycopg2

DSN = sys.argv[1]
OUT = sys.argv[2] if len(sys.argv) > 2 else "../results"
SQL_DIR = os.path.dirname(os.path.abspath(__file__))
RUNS = 5

Q = {
 "B1": """SELECT order_id, order_date, order_status, order_total
FROM orders WHERE customer_id = 12345 ORDER BY order_date DESC LIMIT 20""",
 "B2": """SELECT product_id, product_name, unit_price FROM products
WHERE category = 'Electronics' AND is_active = TRUE ORDER BY product_name LIMIT 100""",
 "B3": """SELECT order_id, customer_id, order_date, order_total FROM orders
WHERE order_status = 'DELIVERED' AND order_date >= TIMESTAMP '2026-01-01'
  AND order_date < TIMESTAMP '2027-01-01' ORDER BY order_date DESC""",
 "B4": """SELECT o.order_id, o.order_date, o.order_status, c.first_name, c.last_name, c.email
FROM orders o JOIN customers c ON c.customer_id = o.customer_id
WHERE o.customer_id = 23456 ORDER BY o.order_date DESC LIMIT 25""",
 "B5": """SELECT i.product_id, p.product_name, i.quantity_on_hand, i.reorder_level
FROM inventory i JOIN products p ON p.product_id = i.product_id
WHERE i.quantity_on_hand <= i.reorder_level ORDER BY i.quantity_on_hand ASC""",
 "B6_before": """SELECT order_id, order_date, order_total FROM orders
WHERE DATE_PART('year', order_date) = 2026""",
 "B6_after": """SELECT order_id, order_date, order_total FROM orders
WHERE order_date >= TIMESTAMP '2026-01-01' AND order_date < TIMESTAMP '2027-01-01'""",
 "B7": """SELECT DATE_TRUNC('month', order_date) AS sales_month, COUNT(*) AS delivered_orders,
       SUM(order_total) AS revenue
FROM orders WHERE order_status = 'DELIVERED' AND order_date >= TIMESTAMP '2026-01-01'
  AND order_date < TIMESTAMP '2027-01-01'
GROUP BY DATE_TRUNC('month', order_date) ORDER BY sales_month""",
 "B8_before": """SELECT * FROM orders WHERE customer_id = 12345 ORDER BY order_date DESC LIMIT 20""",
 "P_base": """SELECT order_id, customer_id, order_date, order_total FROM orders
WHERE order_date >= TIMESTAMP '2026-01-01' AND order_date < TIMESTAMP '2027-01-01'""",
 "P_part": """SELECT order_id, customer_id, order_date, order_total FROM orders_partitioned
WHERE order_date >= TIMESTAMP '2026-01-01' AND order_date < TIMESTAMP '2027-01-01'""",
}
Q["B8_after"] = """SELECT order_id, order_date, order_status FROM orders
WHERE customer_id = 12345 ORDER BY order_date DESC LIMIT 20"""

# (id, scenario, technique, before(phase, query key), after(phase, query key))
EXPERIMENTS = [
 ("B1", "Customer order history", "Composite covering index (customer_id, order_date DESC) INCLUDE (...)", ("base", "B1"), ("idx", "B1")),
 ("B2", "Product category browsing", "Composite index (category, is_active, product_name)", ("base", "B2"), ("idx", "B2")),
 ("B3", "Delivered sales, one year", "Composite covering index (order_status, order_date DESC) INCLUDE (...)", ("base", "B3"), ("idx", "B3")),
 ("B4", "Customer-order join (service lookup)", "Composite covering index on orders + PK lookup on customers", ("base", "B4"), ("idx", "B4")),
 ("B5", "Low-stock inventory", "Partial index WHERE quantity_on_hand <= reorder_level", ("base", "B5"), ("idx", "B5")),
 ("B6", "Year filter 2026", "Sargable half-open date range (no index change)", ("base", "B6_before"), ("base", "B6_after")),
 ("B7", "Monthly delivered revenue 2026", "Composite covering index (order_status, order_date DESC) INCLUDE (...)", ("base", "B7"), ("idx", "B7")),
 ("B8", "Order history projection", "Narrow column list instead of SELECT * (indexed state)", ("idx", "B8_before"), ("idx", "B8_after")),
 ("B9", "Date-range report 2026: partitioned vs plain", "Range partitioning by order_date (vs orders with 05 indexes only)", ("idx", "P_base"), ("part", "P_part")),
 ("B10", "Date-range report 2026: partitioned vs plain + order_date index", "Range partitioning (vs orders with a matching order_date index)", ("ctrl", "P_base"), ("part", "P_part")),
]

def read(name):
    with open(os.path.join(SQL_DIR, name)) as f:
        return f.read()

conn = psycopg2.connect(DSN); conn.autocommit = True
cur = conn.cursor()
cur.execute("SET search_path TO retail, public")
cur.execute("SET jit = off")  # stable timings for small/medium queries

def nodes(plan, acc):
    acc.append((plan["Node Type"], plan.get("Index Name"), plan.get("Relation Name")))
    for ch in plan.get("Plans", []):
        nodes(ch, acc)
    return acc

def measure(sql):
    cur.execute(sql); rows = cur.fetchall()
    digest = hashlib.md5(repr(sorted(map(repr, rows))).encode()).hexdigest()
    cur.execute("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + sql); cur.fetchall()  # warm-up, discarded
    ex, pl, last = [], [], None
    for _ in range(RUNS):
        cur.execute("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + sql)
        last = cur.fetchone()[0][0]
        ex.append(last["Execution Time"]); pl.append(last["Planning Time"])
    root = last["Plan"]
    cur.execute("EXPLAIN (ANALYZE, BUFFERS) " + sql)
    text = "\n".join(r[0] for r in cur.fetchall())
    return dict(exec_ms=ex, median_ms=statistics.median(ex), plan_ms_median=statistics.median(pl),
                rows=len(rows), digest=digest, shared_hit=root.get("Shared Hit Blocks"),
                shared_read=root.get("Shared Read Blocks"), nodes=nodes(root, []), plan_text=text)

def run_phase(phase, keys):
    return {k: measure(Q[k]) for k in keys}

res = {}
# ---- reset to baseline
for ix in ("idx_orders_customer_date", "idx_orders_status_date", "idx_products_category_active_name",
           "idx_inventory_low_stock", "idx_orders_order_date_ctrl"):
    cur.execute(f"DROP INDEX IF EXISTS {ix}")
cur.execute("DROP TABLE IF EXISTS orders_partitioned CASCADE")
cur.execute("VACUUM (ANALYZE)")
cur.execute("SELECT version()"); version = cur.fetchone()[0]
cur.execute("SELECT current_setting('shared_buffers'), current_setting('work_mem'), current_setting('max_parallel_workers_per_gather')")
settings = cur.fetchone()
print("baseline ...")
res["base"] = run_phase("base", ["B1","B2","B3","B4","B5","B6_before","B6_after","B7"])
# ---- 05_create_indexes.sql
print("indexes ...")
cur.execute(read("05_create_indexes.sql"))
cur.execute("VACUUM (ANALYZE) orders"); cur.execute("VACUUM (ANALYZE) products"); cur.execute("VACUUM (ANALYZE) inventory")
res["idx"] = run_phase("idx", ["B1","B2","B3","B4","B5","B7","B8_before","B8_after"])
# ---- 07_partitioning_demo.sql (creates idx_orders_partitioned_date)
print("partitioning ...")
cur.execute(read("07_partitioning_demo.sql").split("-- Inspect the plan.")[0])
cur.execute("VACUUM (ANALYZE) orders_partitioned")
res["idx"].update(run_phase("idx", ["P_base"]))
res["part"] = run_phase("part", ["P_part"])
# control: plain orders with matching order_date index
cur.execute("CREATE INDEX idx_orders_order_date_ctrl ON orders (order_date)")
cur.execute("VACUUM (ANALYZE) orders")
res["ctrl"] = run_phase("ctrl", ["P_base"])
cur.execute("DROP INDEX idx_orders_order_date_ctrl")
cur.execute("ANALYZE orders")

os.makedirs(os.path.join(OUT, "execution-plans"), exist_ok=True)
summary = []
for eid, scen, tech, (bp, bk), (ap, ak) in EXPERIMENTS:
    b, a = res[bp][bk], res[ap][ak]
    saved = b["median_ms"] - a["median_ms"]
    summary.append(dict(id=eid, scenario=scen, technique=tech, before_key=bk, after_key=ak,
        before_ms=round(b["median_ms"], 3), after_ms=round(a["median_ms"], 3),
        saved_ms=round(saved, 3), improvement_pct=round(saved / b["median_ms"] * 100, 1),
        before_runs=[round(x, 3) for x in b["exec_ms"]], after_runs=[round(x, 3) for x in a["exec_ms"]],
        before_nodes=b["nodes"], after_nodes=a["nodes"], rows_before=b["rows"], rows_after=a["rows"],
        same_result=(b["digest"] == a["digest"]), before_hit=b["shared_hit"], after_hit=a["shared_hit"],
        before_read=b["shared_read"], after_read=a["shared_read"]))
    for tag, r in (("before", b), ("after", a)):
        with open(os.path.join(OUT, "execution-plans", f"{eid}_{tag}.txt"), "w") as f:
            f.write(f"-- {eid} {tag}\n" + r["plan_text"] + "\n")
with open(os.path.join(OUT, "benchmark_results.json"), "w") as f:
    json.dump(dict(version=version, shared_buffers=settings[0], work_mem=settings[1],
                   parallel_workers=settings[2], runs=RUNS, experiments=summary), f, indent=1, default=str)
print("done");
for s in summary:
    print(s["id"], s["before_ms"], s["after_ms"], s["improvement_pct"], s["same_result"])
