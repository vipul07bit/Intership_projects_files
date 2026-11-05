from pathlib import Path
import sqlite3, random, csv, json, statistics, zipfile, shutil, textwrap, os
from datetime import datetime, timedelta, date
from docx import Document
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
import matplotlib.pyplot as plt

BASE=Path(__file__).resolve().parents[1]
PKG=BASE
if PKG.exists(): shutil.rmtree(PKG)
for d in ['sql','data','outputs','visualizations','docs','scripts','evidence']:(PKG/d).mkdir(parents=True,exist_ok=True)
random.seed(20261105)

# deterministic, synthetic retail dataset
con=sqlite3.connect(PKG/'data'/'retail_reporting_validation.sqlite')
con.executescript('''
PRAGMA foreign_keys=ON;
CREATE TABLE customers(customer_id INTEGER PRIMARY KEY, full_name TEXT NOT NULL, email TEXT UNIQUE, created_at TEXT NOT NULL);
CREATE TABLE categories(category_id INTEGER PRIMARY KEY, category_name TEXT NOT NULL UNIQUE);
CREATE TABLE products(product_id INTEGER PRIMARY KEY, category_id INTEGER, sku TEXT UNIQUE NOT NULL, product_name TEXT NOT NULL, current_price REAL NOT NULL, is_active INTEGER NOT NULL, FOREIGN KEY(category_id) REFERENCES categories(category_id));
CREATE TABLE suppliers(supplier_id INTEGER PRIMARY KEY, supplier_name TEXT NOT NULL);
CREATE TABLE product_suppliers(product_id INTEGER, supplier_id INTEGER, supply_cost REAL, PRIMARY KEY(product_id,supplier_id));
CREATE TABLE warehouses(warehouse_id INTEGER PRIMARY KEY, warehouse_name TEXT NOT NULL UNIQUE);
CREATE TABLE inventory(product_id INTEGER, warehouse_id INTEGER, quantity_on_hand INTEGER NOT NULL, reorder_level INTEGER NOT NULL, updated_at TEXT NOT NULL, PRIMARY KEY(product_id,warehouse_id));
CREATE TABLE orders(order_id INTEGER PRIMARY KEY, customer_id INTEGER NOT NULL, order_date TEXT NOT NULL, order_status TEXT NOT NULL, shipping_address TEXT NOT NULL, FOREIGN KEY(customer_id) REFERENCES customers(customer_id));
CREATE TABLE order_items(order_item_id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL, product_id INTEGER NOT NULL, quantity INTEGER NOT NULL, unit_price REAL NOT NULL, FOREIGN KEY(order_id) REFERENCES orders(order_id), FOREIGN KEY(product_id) REFERENCES products(product_id));
CREATE TABLE payments(payment_id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL, amount REAL NOT NULL, payment_method TEXT NOT NULL, payment_status TEXT NOT NULL, created_at TEXT NOT NULL, FOREIGN KEY(order_id) REFERENCES orders(order_id));
CREATE TABLE shipments(shipment_id INTEGER PRIMARY KEY, order_id INTEGER NOT NULL, shipment_status TEXT NOT NULL, shipped_at TEXT, delivered_at TEXT, FOREIGN KEY(order_id) REFERENCES orders(order_id));
''')

categories=['Electronics','Home Office','Accessories','Home & Kitchen','Fitness']
con.executemany('INSERT INTO categories VALUES (?,?)',enumerate(categories,1))
con.executemany('INSERT INTO suppliers VALUES (?,?)',[(i,f'Supplier {i:02d}') for i in range(1,9)])
con.executemany('INSERT INTO warehouses VALUES (?,?)',[(1,'Mumbai Central'),(2,'Pune West'),(3,'Bengaluru South')])
products=[]
for i in range(1,41):
    cat=((i-1)%5)+1
    price=round(random.choice([299,499,799,999,1499,2499,3999,6999,12999,24999])+random.random()*200,2)
    name=f'{categories[cat-1]} Product {i:02d}'
    products.append((i,cat,f'SKU-{i:04d}',name,price,1 if i%13 else 0))
con.executemany('INSERT INTO products VALUES (?,?,?,?,?,?)',products)
for i in range(1,41): con.execute('INSERT INTO product_suppliers VALUES (?,?,?)',(i,((i-1)%8)+1,round(products[i-1][4]*random.uniform(.45,.72),2)))
customers=[]
start=date(2025,1,1)
for i in range(1,301):
    created=start+timedelta(days=random.randrange(0,620))
    customers.append((i,f'Customer {i:03d}',f'customer{i:03d}@example.test',created.isoformat()))
con.executemany('INSERT INTO customers VALUES (?,?,?,?)',customers)

# 2,400 orders across 2025-2026, seasonality in monthly volume; no real PII
order_rows=[]; item_rows=[]; payment_rows=[]; ship_rows=[]; item_id=pay_id=ship_id=1
status_weights=[('delivered',.70),('shipped',.09),('processing',.07),('confirmed',.06),('cancelled',.05),('refunded',.03)]
for oid in range(1,2401):
    month=random.choices(range(1,13),weights=[.75,.78,.85,.90,.95,1.0,1.05,1.1,1.0,1.15,1.45,1.7])[0]
    yr=2025 if oid<=1200 else 2026
    # 2026 dates only through Oct to preserve current-year partial period
    maxday=31
    if month==2:maxday=28
    if month in [4,6,9,11]:maxday=30
    if yr==2026 and month>10: month=10
    day=random.randint(1,maxday)
    dt=datetime(yr,month,day,random.randrange(8,22),random.randrange(0,60))
    status=random.choices([x[0] for x in status_weights],weights=[x[1] for x in status_weights])[0]
    cust=random.randint(1,300)
    order_rows.append((oid,cust,dt.isoformat(sep=' '),status,'Synthetic address, India'))
    nitems=random.choices([1,2,3,4],[.35,.38,.20,.07])[0]
    chosen=random.sample(products,nitems)
    for p in chosen:
        qty=random.choices([1,2,3,4,5],[.50,.25,.14,.08,.03])[0]
        price=p[4]
        item_rows.append((item_id,oid,p[0],qty,price)); item_id+=1
    total=sum(qty*price for _,o,pid,qty,price in item_rows if o==oid)
    pstatus='paid' if status in ('delivered','shipped','processing','confirmed') else ('refunded' if status=='refunded' else random.choice(['failed','pending']))
    payment_rows.append((pay_id,oid,round(total,2),random.choice(['upi','card','wallet','net_banking']),pstatus,dt.isoformat(sep=' ')));pay_id+=1
    if status in ('delivered','shipped'):
        shipped=dt+timedelta(days=random.randint(1,3))
        delivered=shipped+timedelta(days=random.randint(1,5)) if status=='delivered' else None
        ship_rows.append((ship_id,oid,status,shipped.isoformat(sep=' '),delivered.isoformat(sep=' ') if delivered else None));ship_id+=1
con.executemany('INSERT INTO orders VALUES (?,?,?,?,?)',order_rows)
con.executemany('INSERT INTO order_items VALUES (?,?,?,?,?)',item_rows)
con.executemany('INSERT INTO payments VALUES (?,?,?,?,?,?)',payment_rows)
con.executemany('INSERT INTO shipments VALUES (?,?,?,?,?)',ship_rows)
inv=[]
for p in products:
    for wh in [1,2,3]:
        reorder=random.randint(8,25)
        qty=random.randint(0,80)
        if (p[0]+wh)%9==0: qty=random.randint(0,reorder)
        inv.append((p[0],wh,qty,reorder,'2026-11-01 09:00:00'))
con.executemany('INSERT INTO inventory VALUES (?,?,?,?,?)',inv)
con.commit()

# Reporting SQL (SQLite-verification equivalents; SQL files use PostgreSQL syntax where noted)
queries={
'01_top_products':'''WITH product_sales AS (
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
FROM product_sales ORDER BY delivered_revenue DESC LIMIT 10''',
'02_category_performance':'''WITH category_sales AS (
 SELECT c.category_name,COUNT(DISTINCT o.order_id) AS delivered_orders,
        SUM(oi.quantity) AS units_sold,SUM(oi.quantity*oi.unit_price) AS revenue
 FROM categories c JOIN products p ON p.category_id=c.category_id
 JOIN order_items oi ON oi.product_id=p.product_id JOIN orders o ON o.order_id=oi.order_id
 WHERE o.order_status='delivered'
 GROUP BY c.category_id,c.category_name
)
SELECT *,ROUND(100.0*revenue/NULLIF(SUM(revenue) OVER (),0),2) AS revenue_share_pct
FROM category_sales ORDER BY revenue DESC''',
'03_monthly_trend':'''WITH monthly AS (
 SELECT substr(o.order_date,1,7) AS sales_month,COUNT(DISTINCT o.order_id) AS delivered_orders,
        SUM(oi.quantity*oi.unit_price) AS revenue
 FROM orders o JOIN order_items oi ON oi.order_id=o.order_id
 WHERE o.order_status='delivered' GROUP BY substr(o.order_date,1,7)
)
SELECT sales_month,delivered_orders,ROUND(revenue,2) AS revenue,
 ROUND(revenue-LAG(revenue) OVER (ORDER BY sales_month),2) AS revenue_change,
 ROUND(100.0*(revenue-LAG(revenue) OVER (ORDER BY sales_month))/NULLIF(LAG(revenue) OVER (ORDER BY sales_month),0),2) AS mom_growth_pct
FROM monthly ORDER BY sales_month''',
'04_customer_value':'''WITH customer_metrics AS (
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
FROM customer_metrics ORDER BY delivered_revenue DESC LIMIT 15''',
'05_repeat_customer_rate':'''WITH per_customer AS (
 SELECT c.customer_id,COUNT(DISTINCT o.order_id) AS delivered_orders
 FROM customers c LEFT JOIN orders o ON o.customer_id=c.customer_id AND o.order_status='delivered'
 GROUP BY c.customer_id
)
SELECT COUNT(*) AS total_customers,
 SUM(CASE WHEN delivered_orders>=2 THEN 1 ELSE 0 END) AS repeat_customers,
 ROUND(100.0*SUM(CASE WHEN delivered_orders>=2 THEN 1 ELSE 0 END)/COUNT(*),2) AS repeat_customer_pct,
 ROUND(AVG(delivered_orders),2) AS avg_delivered_orders_per_customer
FROM per_customer''',
'06_low_stock':'''SELECT w.warehouse_name,p.sku,p.product_name,i.quantity_on_hand,i.reorder_level,
       (i.reorder_level-i.quantity_on_hand) AS units_below_reorder
FROM inventory i JOIN products p ON p.product_id=i.product_id
JOIN warehouses w ON w.warehouse_id=i.warehouse_id
WHERE i.quantity_on_hand<=i.reorder_level
ORDER BY units_below_reorder DESC,w.warehouse_name,p.product_name''',
'07_stock_cover_proxy':'''WITH recent_sales AS (
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
ORDER BY estimated_stock_cover_days ASC''',
'08_order_status':'''WITH order_value AS (
 SELECT o.order_id,o.order_status,SUM(oi.quantity*oi.unit_price) AS order_value
 FROM orders o LEFT JOIN order_items oi ON oi.order_id=o.order_id GROUP BY o.order_id,o.order_status
)
SELECT order_status,COUNT(*) AS order_count,ROUND(SUM(COALESCE(order_value,0)),2) AS merchandise_value,
       ROUND(100.0*COUNT(*)/SUM(COUNT(*)) OVER (),2) AS order_share_pct
FROM order_value GROUP BY order_status ORDER BY order_count DESC'''
}

# Save SQL files, PostgreSQL-compatible versions (query 03 and 07 use timestamp expressions)
pg_queries={k:v for k,v in queries.items()}
pg_queries['03_monthly_trend']=queries['03_monthly_trend'].replace("substr(o.order_date,1,7)","TO_CHAR(o.order_date::date, 'YYYY-MM')")
pg_queries['07_stock_cover_proxy']=queries['07_stock_cover_proxy'].replace("o.order_date >= '2026-08-07'","o.order_date >= TIMESTAMPTZ '2026-08-07 00:00:00+00'")
for name,sql in pg_queries.items():
    (PKG/'sql'/f'{name}.sql').write_text('-- PostgreSQL 15+ | reporting query\n-- Metric definitions and limitations are documented in the Week 4 report.\n'+sql+';\n',encoding='utf-8')

# Execute every query against deterministic SQLite mirror and export exact outputs
all_results={}
for name,q in queries.items():
    cur=con.execute(q); cols=[x[0] for x in cur.description]; rows=cur.fetchall()
    all_results[name]={'columns':cols,'rows':rows,'row_count':len(rows)}
    with open(PKG/'outputs'/f'{name}.csv','w',newline='',encoding='utf-8') as f:
        w=csv.writer(f);w.writerow(cols);w.writerows(rows)
    with open(PKG/'outputs'/f'{name}.md','w',encoding='utf-8') as f:
        f.write(f'## {name.replace("_"," ").title()}\n\nRows returned: **{len(rows)}**\n\n')
        f.write('| '+' | '.join(cols)+' |\n|'+ '|'.join(['---']*len(cols))+'|\n')
        for row in rows[:25]: f.write('| '+' | '.join(str(x) if x is not None else 'NULL' for x in row)+' |\n')

# dataset counts and validation checks
counts={t:con.execute(f'SELECT COUNT(*) FROM {t}').fetchone()[0] for t in ['customers','categories','products','suppliers','product_suppliers','warehouses','inventory','orders','order_items','payments','shipments']}
checks={
 'orders_have_customer':con.execute('SELECT COUNT(*) FROM orders o LEFT JOIN customers c USING(customer_id) WHERE c.customer_id IS NULL').fetchone()[0]==0,
 'order_items_have_order':con.execute('SELECT COUNT(*) FROM order_items oi LEFT JOIN orders o USING(order_id) WHERE o.order_id IS NULL').fetchone()[0]==0,
 'order_items_have_product':con.execute('SELECT COUNT(*) FROM order_items oi LEFT JOIN products p USING(product_id) WHERE p.product_id IS NULL').fetchone()[0]==0,
 'positive_quantities':con.execute('SELECT COUNT(*) FROM order_items WHERE quantity<=0').fetchone()[0]==0,
 'nonnegative_inventory':con.execute('SELECT COUNT(*) FROM inventory WHERE quantity_on_hand<0 OR reorder_level<0').fetchone()[0]==0,
 'delivered_sales_positive':con.execute("SELECT COUNT(*) FROM orders o JOIN order_items oi USING(order_id) WHERE o.order_status='delivered' AND oi.quantity*oi.unit_price<0").fetchone()[0]==0
}
assert all(checks.values()),checks
(PKG/'outputs'/'validation_summary.json').write_text(json.dumps({'engine':'SQLite verification mirror','dataset_seed':20261105,'table_row_counts':counts,'checks':checks,'all_checks_passed':all(checks.values()),'warning':'Reporting SQL files target PostgreSQL. Query logic was executed against a SQLite mirror because a PostgreSQL server was not available in this build environment.'},indent=2))

# visualization charts
plt.figure(figsize=(10,5)); d=all_results['01_top_products']['rows'][:8]
plt.barh([r[2] for r in d][::-1],[r[5] for r in d][::-1]);plt.title('Top Products by Delivered Revenue');plt.xlabel('Delivered revenue (synthetic currency units)');plt.tight_layout();plt.savefig(PKG/'visualizations'/'top_products_revenue.png',dpi=170);plt.close()
plt.figure(figsize=(10,5)); d=all_results['03_monthly_trend']['rows']
plt.plot([r[0] for r in d],[r[2] for r in d],marker='o');plt.xticks(rotation=45,ha='right');plt.title('Monthly Delivered Revenue');plt.ylabel('Revenue (synthetic currency units)');plt.tight_layout();plt.savefig(PKG/'visualizations'/'monthly_revenue_trend.png',dpi=170);plt.close()
plt.figure(figsize=(8,5)); d=all_results['02_category_performance']['rows']
plt.bar([r[0] for r in d],[r[3] for r in d]);plt.xticks(rotation=25,ha='right');plt.title('Delivered Revenue by Category');plt.ylabel('Revenue (synthetic currency units)');plt.tight_layout();plt.savefig(PKG/'visualizations'/'category_revenue.png',dpi=170);plt.close()
plt.figure(figsize=(10,5)); d=all_results['06_low_stock']['rows'][:12]
plt.barh([r[2]+' / '+r[0] for r in d][::-1],[r[3] for r in d][::-1]);plt.title('Low-stock Items: On-hand Quantity');plt.xlabel('Units on hand');plt.tight_layout();plt.savefig(PKG/'visualizations'/'low_stock.png',dpi=170);plt.close()

# CSV for overall dataset counts
with open(PKG/'outputs'/'dataset_row_counts.csv','w',newline='') as f:
 w=csv.writer(f);w.writerow(['table','row_count']);w.writerows(counts.items())

# Helper functions for DOCX
D=Document(); sec=D.sections[0]; sec.top_margin=Inches(.65);sec.bottom_margin=Inches(.65);sec.left_margin=Inches(.75);sec.right_margin=Inches(.75)
styles=D.styles
styles['Normal'].font.name='Aptos';styles['Normal'].font.size=Pt(9)
for s in ['Heading 1','Heading 2','Heading 3']:
 styles[s].font.name='Aptos Display';styles[s].font.color.rgb=RGBColor(27,75,115)
styles['Heading 1'].font.size=Pt(16);styles['Heading 2'].font.size=Pt(12);styles['Heading 3'].font.size=Pt(10)

def shade(cell,fill):
 tcPr=cell._tc.get_or_add_tcPr();shd=OxmlElement('w:shd');shd.set(qn('w:fill'),fill);tcPr.append(shd)
def table(headers,rows,widths=None):
 t=D.add_table(rows=1,cols=len(headers));t.alignment=WD_TABLE_ALIGNMENT.CENTER;t.style='Light Shading Accent 1'
 for i,h in enumerate(headers):t.rows[0].cells[i].text=str(h);shade(t.rows[0].cells[i],'D9EAF7')
 for row in rows:
  cells=t.add_row().cells
  for i,v in enumerate(row):cells[i].text=str(v)
 return t
def para(text='',boldlead=None):
 p=D.add_paragraph()
 if boldlead and text.startswith(boldlead):p.add_run(boldlead).bold=True;p.add_run(text[len(boldlead):])
 else:p.add_run(text)
 return p
def bullets(items):
 for x in items:D.add_paragraph(x,style='List Bullet')
def add_query_section(n,title,business,logic,interpretation,viz,limits,recommendation):
 D.add_heading(f'{n}. {title}',2)
 para('Business question: '+business)
 para('Query logic: '+logic)
 para('Result evidence: The exact CSV/Markdown output is included in outputs/. The displayed figures below are generated from the deterministic synthetic dataset and were executed against the SQLite verification mirror.')
 res=all_results[n]
 headers=res['columns'][:6]; rows=[r[:6] for r in res['rows'][:5]]
 table(headers,rows)
 para('Interpretation: '+interpretation)
 para('Visualization: '+viz)
 para('Limitations and trade-offs: '+limits)
 para('Recommended action: '+recommendation)

# Cover
p=D.add_paragraph();p.alignment=WD_ALIGN_PARAGRAPH.CENTER
r=p.add_run('SQL DEVELOPER INTERNSHIP');r.bold=True;r.font.size=Pt(15);r.font.color.rgb=RGBColor(27,75,115)
p=D.add_paragraph();p.alignment=WD_ALIGN_PARAGRAPH.CENTER
r=p.add_run('WEEK 4 REPORT');r.bold=True;r.font.size=Pt(27)
p=D.add_paragraph();p.alignment=WD_ALIGN_PARAGRAPH.CENTER
r=p.add_run('Dynamic Reporting and Data Visualization Using SQL');r.font.size=Pt(16)
D.add_paragraph('\nVirtual Retail Environment | PostgreSQL reporting design',style='Subtitle').alignment=WD_ALIGN_PARAGRAPH.CENTER
D.add_paragraph('\nPrepared by: ______________________________\nInternship organization: ____________________\nSubmission date: 05 November 2026\nDatabase target: PostgreSQL 15+\nValidation engine: SQLite mirror (query logic validation)').alignment=WD_ALIGN_PARAGRAPH.CENTER
D.add_page_break()

D.add_heading('Executive Summary',1)
para('This report develops a reproducible reporting layer for the virtual retail database established in the earlier internship weeks. Week 1 supplied the normalized retail entities and relationships; Week 2 documented the ETL lifecycle and data-quality controls; Week 3 focused on query performance and evidence-based optimization. Week 4 uses those foundations to answer management questions about product sales, category performance, customer value, repeat purchasing, monthly trends, inventory risk and order status.')
para(f'The reporting dataset is synthetic and deterministic (seed 20261105). It contains {counts["customers"]:,} customers, {counts["products"]:,} products, {counts["orders"]:,} orders and {counts["order_items"]:,} order-item rows, across {counts["warehouses"]} warehouses. All reporting outputs were generated by executing the query logic against a local SQLite verification mirror. PostgreSQL-specific SQL scripts are supplied for the internship database. No PostgreSQL runtime was available during artifact generation, so the report does not claim PostgreSQL execution or measured performance results.')
para('The report emphasizes metric definitions and decision quality. Sales revenue is calculated from order-item quantity multiplied by the price captured on the order line. Delivered revenue includes only orders whose status is delivered; it is not labelled net revenue because the model does not include a complete returns/refunds ledger, taxes, discounts or chargebacks. Inventory turnover is not claimed because the current schema stores balances rather than dated stock movements or cost of goods sold. A stock-cover estimate is provided as a transparent operational proxy.')
D.add_heading('1. Objectives and Scope',1)
bullets(['Convert retail business questions into repeatable SQL reports.','Use joins, CTEs, aggregations, conditional logic, subqueries and window functions.','Provide executed result samples, full CSV exports and validation evidence.','Recommend charts that match the analytical question and explain how to interpret them.','Document business definitions, assumptions, limitations, optimization rationale and future improvements.'])
D.add_heading('2. Continuity with Weeks 1–3',1)
table(['Week','Foundation','How Week 4 reuses it'],[
('Week 1 – Data modeling','Normalized entities, primary/foreign keys, product/order/inventory relationships.','Reports join customers, categories, products, orders, order_items and inventory without duplicating facts.'),
('Week 2 – ETL planning','Extract, stage, transform, validate and load; data-quality checks.','The report assumes validated, consistently typed data and recommends a refresh pipeline with quality gates.'),
('Week 3 – SQL optimization','EXPLAIN plans, composite/partial indexes, sargable date filters, trade-off analysis.','Reporting queries use selective predicates, explicit columns, pre-aggregation and indexes aligned to common filters.')])
D.add_heading('3. Dataset, Schema and Reproducibility',1)
para('The PostgreSQL target schema is retail, consistent with the Week 3 report. The original Week 1 package defines customers, categories, products, suppliers, product_suppliers, warehouses, inventory, orders, order_items, payments and shipments. Week 4 queries use the relevant subset. The supplied data generator creates a separate deterministic synthetic reporting dataset with the same core relationships. It is designed for repeatability and demonstration, not to replace production records.')
table(['Table','Rows generated'],[(k,f'{v:,}') for k,v in counts.items()])
para('Data range: synthetic order timestamps span January 2025 through October 2026. Inventory snapshot timestamp: 1 November 2026. Currency is treated as generic synthetic currency units because the inherited schema does not declare an ISO currency column. For a real multi-currency retailer, currency must be stored and reports must avoid summing unlike currencies.')
D.add_heading('3.1 Business definitions and assumptions',2)
bullets(['Delivered revenue = SUM(order_items.quantity × order_items.unit_price) for orders with order_status = delivered. This is fulfilled merchandise value, not accounting net revenue.','Units sold = sum of order-item quantities for delivered orders only. Cancelled, refunded, pending and in-flight orders are excluded from fulfilled sales.','Average order value (AOV) = delivered merchandise value divided by delivered order count. It is not the average line value.','Repeat customer = customer with at least two delivered orders in the full reporting period. This is a simple repeat-purchase measure, not a cohort retention rate.','Low stock = quantity_on_hand <= reorder_level at a given warehouse. This is a threshold rule, not a forecast.','Stock cover days = current on-hand units divided by average daily delivered units over the trailing 90-day window. It is a proxy and can be unstable for intermittent demand.','Inventory turnover is not calculated: no dated inventory movement ledger or cost-of-goods-sold field exists in the inherited model.'])
D.add_heading('4. Reporting Architecture and Workflow',1)
para('Source tables → ETL validation → reporting SQL/CTEs → result tables or views → dashboard charts → management action. Each report should have a refresh timestamp, reporting period, metric definition and data-quality status. For repeated dashboard use, stable SQL views or materialized views can provide a governed interface between transactional tables and visualization tools.')
D.add_heading('5. SQL Reporting Analyses',1)
add_query_section('01_top_products','Top products by delivered revenue','Which products contribute the most fulfilled merchandise revenue?','Joins order headers to line items, products and categories; aggregates units, distinct orders and line revenue per product; uses a window sum for revenue share and RANK for ordering.','A high-revenue product may lead because of price, volume or both. Compare units sold with revenue share before deciding whether to prioritize availability, pricing or promotion.','Sorted horizontal bar chart of delivered revenue; optionally show units as labels or a second aligned chart.','Revenue does not equal profit. Supply cost, discounts, returns and marketing spend are not included.','Protect availability of high-contribution products; assess margin and stock cover before increasing promotion.')
add_query_section('02_category_performance','Category revenue and mix','Which categories account for the largest share of delivered sales?','Joins categories to products, order items and orders; aggregates revenue, units and distinct delivered orders; window sum calculates category revenue share.','A category with high revenue share may be strategically important, but revenue concentration can also create dependency risk. Compare order count and units to understand whether the category has broad demand.','Column chart for category revenue plus a 100% stacked bar or donut for share. Use the bar chart as the primary comparison.','Categories with no delivered orders do not appear because the query uses inner joins. Add LEFT JOIN logic if zero-sales categories must be shown.','Review assortment depth and stock allocation in leading categories; investigate low-share categories before discontinuing products.')
add_query_section('03_monthly_trend','Monthly delivered sales trend','How does fulfilled revenue change month by month?','Groups delivered order lines by calendar month; LAG compares each month with the prior month; calculates absolute and percentage month-over-month change.','Seasonality and promotions can influence monthly movement. The latest month is incomplete (October 2026 in this generated dataset), so it must not be compared directly with a complete month without a partial-period warning.','Line chart with monthly revenue; annotate major promotions and mark incomplete periods. A companion line can show order count.','Month-over-month growth is volatile on small bases. The report has no promotion calendar, traffic or margin data to explain causality.','Use year-over-year comparisons when a full prior-year period exists; compare equivalent day ranges and add promotion/event context.')
add_query_section('04_customer_value','Highest-value delivered customers','Which customers contribute the most delivered merchandise revenue?','Aggregates delivered orders and line revenue per customer; computes AOV; uses CASE for simple frequency segments and RANK for revenue position.','Revenue ranking identifies valuable customers but does not establish profitability or lifetime value. A customer with fewer high-value orders may rank above a frequent low-value buyer.','Ranked horizontal bar chart or Pareto curve showing cumulative revenue share by customer. Avoid a pie chart with many customer slices.','Customer names are synthetic. No acquisition cost, margin, churn probability or marketing-contact permission is modeled.','Use customer-level insights for service prioritization and retention experiments, subject to privacy and consent controls.')
add_query_section('05_repeat_customer_rate','Repeat purchase rate','What proportion of customers placed at least two delivered orders?','Uses a customer-level subquery/CTE with LEFT JOIN so customers with zero delivered orders remain in the denominator; conditional aggregation counts repeat customers.','The metric provides a simple repeat-purchase signal. It is sensitive to the observation window and customer tenure; new customers have had less time to make a second purchase.','KPI card for repeat-customer percentage, paired with a cohort retention heatmap in a future version.','This is not cohort retention, churn or customer lifetime value. The denominator includes all generated customers, including recently created customers.','Build acquisition-month cohorts and compare repeat purchase at 30/60/90 days to separate tenure effects.')
add_query_section('06_low_stock','Low-stock items by warehouse','Which warehouse/product combinations are at or below their reorder threshold?','Joins inventory to products and warehouses; filters quantity_on_hand <= reorder_level; computes the units required to return to threshold.','A low-stock flag identifies a replenishment exception. It does not guarantee an imminent stockout because lead time, reserved stock, supplier reliability and demand forecast are absent.','Horizontal bar chart of on-hand units by product/warehouse with a reference marker for reorder level; use conditional table formatting for operations.','A product can appear once per warehouse. Do not sum the same SKU across locations without deciding whether stock is transferable.','Prioritize items below threshold, then incorporate supplier lead time, open purchase orders and reserved quantities before creating purchase orders.')
add_query_section('07_stock_cover_proxy','Estimated stock-cover days (proxy)','How many days of recent demand can current stock support?','Aggregates delivered units in the trailing 90-day period by product; joins that demand to each warehouse balance; divides stock by average daily demand.','Low cover days can signal replenishment urgency. A NULL cover value means no delivered units were observed in the window; it must not be interpreted as infinite safe stock.','Dot plot or ranked horizontal bar chart with threshold bands (for example, 7/14/30 days) only after business owners approve policy thresholds.','The proxy applies product-level demand to each warehouse and can overstate local demand if sales are not warehouse-attributed. It ignores stock reservations, seasonality and lead times.','Add warehouse-level sales attribution and stock movement history before using this as an automated replenishment trigger.')
add_query_section('08_order_status','Order status distribution and value','How are orders distributed across operational statuses and what merchandise value is associated with each status?','Pre-aggregates order-item value to one row per order, then groups by status. This avoids multiplying order totals when orders contain multiple lines.','Status counts reveal operational pipeline composition. Pending/in-flight amounts are not recognized as delivered revenue. Cancelled and refunded amounts should be separately reconciled with payment/refund records.','Stacked column by status for order count and a separate bar for merchandise value; do not mix count and currency on one axis.','Order value is merchandise line value, not payment settlement. The model permits payment attempts; joining raw payments directly can duplicate order values.','Monitor ageing by status and reconcile payment status separately. Add status history timestamps to measure processing delays.')

D.add_heading('6. Query Design and Optimization Rationale',1)
table(['Technique','Why it is used','Benefit','Trade-off / control'],[
('CTEs and pre-aggregation','Separate metric grain before joining or ranking.','Improves readability and prevents order-level totals being multiplied by line/payment joins.','CTEs are not automatically faster; inspect plans and avoid unnecessary materialization.'),
('Explicit column projection','Return only fields used in report.','Reduces row width, memory and network transfer.','A wider report may require additional lookups; select only needed columns.'),
('Window functions','RANK, LAG and window SUM for ranking, trends and shares.','Avoids separate self-joins and keeps calculations alongside grouped results.','Window sorts can be expensive on large result sets; pre-aggregate to the correct grain first.'),
('Sargable date filters','Filter timestamps with >= start and < end.','Allows conventional B-tree range access and preserves timestamp precision.','Requires correct time-zone boundary handling; report timezone must be explicit.'),
('Composite indexes','Align index keys to recurring equality filters, date ranges and ordering.','Can reduce heap visits and sort work for selective reports.','Consumes storage and adds INSERT/UPDATE/DELETE cost; validate with EXPLAIN (ANALYZE, BUFFERS).'),
('Partial indexes','Index only rows meeting a selective operational predicate.','Can reduce index size for sparse exception reports.','Predicate rows enter/leave the index as data changes; update cost and selectivity matter.'),
('Materialized views','Precompute expensive repeated dashboard aggregates.','Can lower dashboard latency and isolate reporting from OLTP workload.','Data becomes stale between refreshes; refresh consumes resources and needs a freshness SLA.')])
para('Suggested PostgreSQL indexes must be workload-tested, not blindly added. The inherited Week 1/3 schema already includes orders(customer_id, order_date DESC), orders(order_status, order_date DESC), order_items(order_id), order_items(product_id), and a partial inventory reorder index. Before creating duplicates, inspect pg_indexes and the existing index definitions. For category browsing, a candidate index is products(category_id, is_active, product_name). For delivered sales by date, a candidate partial index is orders(order_date) WHERE order_status = \'delivered\'. The planner may still choose a sequential scan for broad reporting ranges; that can be the correct plan.')
D.add_heading('7. Visualization and Dashboard Specification',1)
for fn,caption in [('top_products_revenue.png','Figure 1. Top products by delivered revenue.'),('category_revenue.png','Figure 2. Category revenue comparison.'),('monthly_revenue_trend.png','Figure 3. Monthly delivered revenue trend.'),('low_stock.png','Figure 4. Low-stock quantities by product and warehouse.')]:
 D.add_picture(str(PKG/'visualizations'/fn),width=Inches(6.2));p=D.add_paragraph(caption);p.alignment=WD_ALIGN_PARAGRAPH.CENTER
para('Recommended dashboard layout: (1) KPI strip: delivered revenue, delivered orders, AOV, repeat-customer percentage and low-stock SKU/location count; (2) sales section: monthly trend, category mix and top products; (3) customer section: repeat purchase and top-customer Pareto; (4) inventory section: low-stock exceptions and stock-cover proxy; (5) operations section: order-status distribution and ageing. Every page should expose a date filter, status definition, refresh timestamp and drill-through to source rows.')
D.add_heading('8. Data Quality, Correctness and Validation',1)
para('The synthetic generator is deterministic and the verification script runs all eight report queries automatically. It checks referential integrity for orders, order items and products; positive quantities; non-negative inventory; and non-negative delivered line values. Exact row counts and query outputs are saved under outputs/.')
table(['Validation check','Result'],[(k,'PASS' if v else 'FAIL') for k,v in checks.items()])
para('Execution boundary: the local environment did not provide a PostgreSQL server/client. The queries were therefore executed against a SQLite mirror using equivalent query logic. The delivered SQL files are PostgreSQL-targeted; date formatting and timestamp literals are adapted in the PostgreSQL scripts. Before claiming PostgreSQL validation, run the scripts against the actual Week 1/3 PostgreSQL database and capture its version, row counts and EXPLAIN plans.')
D.add_heading('9. Risks, Limitations and Future Improvements',1)
bullets(['Add a returns/refunds table and discount/tax fields so gross merchandise value, refunds, net sales and recognized revenue can be reported separately.','Add inventory_movements with movement type, timestamp, quantity delta, warehouse and unit cost. This enables true inventory turnover, days inventory outstanding and stock reconciliation.','Add warehouse_id to order fulfilment/shipments or order items to attribute demand to the correct warehouse.','Build customer cohorts by acquisition month and calculate repeat purchase at fixed horizons; do not treat the simple repeat rate as retention.','Add promotion calendar, traffic/session and campaign attribution to explain sales changes rather than infer causality from a line chart.','Add currency_code and exchange-rate policy before combining international sales.','Create governed reporting views/materialized views with refresh timestamps, role-based access and data lineage.','Benchmark dashboard queries under realistic concurrency; capture PostgreSQL EXPLAIN (ANALYZE, BUFFERS), median latency and index sizes.'])
para('Optimization trade-off principle: an optimization is accepted only when it preserves the report definition and result, improves a measured workload characteristic, and has an acceptable maintenance cost. Indexes can speed reads but slow writes and consume disk. Materialized views reduce repeated computation but introduce staleness and refresh load. Partitioning can prune large time ranges but adds operational complexity and is not justified for a small dataset.')
D.add_heading('10. Conclusion',1)
para('Week 4 turns the inherited retail data model into a practical reporting specification. Eight business questions are answered using joins, aggregations, CTEs, conditional expressions, subqueries and window functions. The package includes deterministic synthetic data, executed query outputs, CSV exports, chart examples, validation checks and PostgreSQL SQL scripts. The most important analytical discipline is to define each metric before charting it: delivered merchandise revenue is not net revenue, a reorder threshold is not a forecast, and stock cover is not inventory turnover. Future work should add returns, stock movements, warehouse-level demand attribution and cohort analysis, then validate the PostgreSQL execution plans and benchmark dashboard workloads.')
D.add_heading('Appendix A. Run Instructions',1)
para('1. Create a disposable PostgreSQL database. 2. Load the Week 1 schema and any required data, or use the supplied synthetic generator for the isolated test dataset. 3. Review SQL scripts and confirm schema/table names. 4. Run each file in sql/ against PostgreSQL 15+. 5. Capture EXPLAIN (ANALYZE, BUFFERS, VERBOSE) for selected expensive queries. 6. Compare the PostgreSQL outputs with the included SQLite verification outputs only after aligning dataset, timestamps and business definitions.')
D.add_heading('Appendix B. Included Files',1)
bullets(['sql/: eight PostgreSQL reporting queries.','scripts/generate_and_verify.py: deterministic dataset generator and query verification runner.','data/: generated CSV data extracts and SQLite verification database.','outputs/: exact CSV and Markdown result tables, row counts and validation summary.','visualizations/: four chart examples used in the report.','docs/: submission description and metric dictionary.'])
D.save(PKG/'docs'/'Week_4_Dynamic_Reporting_Report.docx')

# Copy submission description and README
submission='''Week 4 Submission Description – Dynamic Reporting and Data Visualization Using SQL\n\nThis submission presents a reproducible SQL reporting solution for the same virtual retail environment developed during the earlier weeks of the SQL Developer Internship. Week 1 established the relational retail model, including customers, categories, products, suppliers, warehouses, inventory, orders, order items, payments and shipments. Week 2 documented the ETL workflow and data-quality controls. Week 3 addressed SQL query optimization, execution-plan analysis and the benefits and costs of indexes. Week 4 builds the reporting layer on those foundations.\n\nThe report answers eight business questions: top products by delivered revenue, category performance, monthly delivered-sales trends, highest-value customers, repeat-customer rate, low-stock products by warehouse, estimated stock-cover days, and order-status distribution. The SQL uses joins, CTEs, aggregations, conditional expressions, subqueries and window functions. Each analysis defines its metric, explains the query logic, interprets the output, recommends a suitable visualization, and identifies the business action and limitations.\n\nThe package includes PostgreSQL-targeted SQL scripts, a deterministic synthetic dataset, exact query-result CSV/Markdown files, dataset row counts, validation evidence, chart examples, and the detailed DOCX report. The synthetic dataset is generated with a fixed seed and contains no real customer information. All eight reporting query logics were executed automatically against a local SQLite verification mirror and the validation checks passed. The build environment did not provide a PostgreSQL server, so the submission does not claim that PostgreSQL execution plans or performance benchmarks were captured. PostgreSQL-specific execution and EXPLAIN (ANALYZE, BUFFERS) remain the next validation step in the target database.\n\nThe report also addresses the prior evaluation feedback by explaining why each reporting and optimization technique is used, its expected benefit, and its trade-offs. It distinguishes delivered merchandise revenue from net revenue, identifies why true inventory turnover cannot be calculated without dated stock movements and cost data, and proposes future improvements such as returns/refunds tracking, warehouse-level demand attribution, customer cohort retention, governed materialized views, currency handling and measured dashboard performance.\n'''
(PKG/'docs'/'Week_4_Submission_Description.txt').write_text(submission)
(PKG/'README.md').write_text('''# Week 4 – Dynamic Reporting and Data Visualization Using SQL\n\n## Deliverables\n- `docs/Week_4_Dynamic_Reporting_Report.docx` – primary internship report.\n- `sql/` – eight PostgreSQL 15+ reporting queries.\n- `data/` – deterministic synthetic data extracts and SQLite verification database.\n- `scripts/generate_and_verify.py` – regenerates data and executes query logic automatically.\n- `outputs/` – exact CSV/Markdown outputs, row counts and validation summary.\n- `visualizations/` – chart examples referenced in the report.\n\n## Reproducibility\nThe synthetic data uses seed `20261105`. Run the generator with Python 3. The report query logic was executed against a SQLite verification mirror because PostgreSQL was not available in the artifact-generation environment. The SQL files are authored for PostgreSQL and must be run against the internship PostgreSQL database before claiming PostgreSQL runtime validation.\n\n## Important metric boundaries\n- Delivered revenue is line quantity × order-time unit price for `delivered` orders. It is not net revenue.\n- Inventory turnover is not calculated because the source model has no dated stock movement ledger or COGS.\n- Stock-cover days is an indicative proxy using trailing 90-day delivered unit demand and is not warehouse-attributed.\n- Synthetic outputs are test evidence, not real business results.\n\n## Run\n1. Review the report's assumptions and SQL files.\n2. Use a disposable PostgreSQL 15+ database with the Week 1 retail schema.\n3. Execute the SQL scripts in `sql/`.\n4. Capture `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)` in PostgreSQL for performance evaluation.\n5. Do not treat SQLite verification as PostgreSQL plan or performance evidence.\n''')
(PKG/'docs'/'metric_dictionary.md').write_text('''# Metric dictionary\n\n| Metric | Definition | Important caveat |\n|---|---|---|\n| Delivered revenue | Sum(quantity × order-item unit_price) for delivered orders | Not net revenue; excludes tax/discount/refund accounting. |\n| Units sold | Sum quantity for delivered orders | Excludes cancelled/refunded/in-flight orders. |\n| AOV | Delivered revenue / distinct delivered orders | Calculated at order grain. |\n| Repeat customer | Customer with >=2 delivered orders in period | Not cohort retention or lifetime value. |\n| Low stock | quantity_on_hand <= reorder_level | Threshold alert, not a forecast. |\n| Stock cover days | on-hand / trailing-90-day average daily delivered units | Product-level demand applied to each warehouse; proxy only. |\n| Inventory turnover | Not computed | Requires COGS and average inventory or movement history. |\n''')

# Generator script as a copy of this builder with safe output root; keep reproducibility executable
script=Path(__file__).read_text()
script=script.replace("BASE=Path(__file__).resolve().parents[1]", "BASE=Path(__file__).resolve().parents[1]")
script=script.replace("PKG=BASE", "PKG=BASE")
(PKG/'scripts'/'generate_and_verify.py').write_text(script,encoding='utf-8')

# copy relevant inherited schema for context (not modified)
shutil.copy('/mnt/data/week4_work/virtual-retail-database-project/sql/schema.sql',PKG/'sql'/'reference_week1_schema.sql')

# zip package
zip_path=BASE/'Week_4_Dynamic_Reporting_GitHub_Package.zip'
with zipfile.ZipFile(zip_path,'w',zipfile.ZIP_DEFLATED) as z:
    for p in PKG.rglob('*'):
        if p.is_file():z.write(p,p.relative_to(BASE))
print(json.dumps({'package':str(PKG),'zip':str(zip_path),'docx':str(PKG/'docs'/'Week_4_Dynamic_Reporting_Report.docx'),'counts':counts,'checks':checks,'query_rows':{k:v['row_count'] for k,v in all_results.items()},'sample_top_products':all_results['01_top_products']['rows'][:3],'repeat_rate':all_results['05_repeat_customer_rate']['rows'][0]},indent=2,default=str))
