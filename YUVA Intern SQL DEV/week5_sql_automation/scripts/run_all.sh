#!/usr/bin/env bash
set -euo pipefail
: "${DATABASE_URL:?Set DATABASE_URL, e.g. postgresql://user:pass@localhost:5432/retaildb}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for f in \
  sql/00_bootstrap_retail.sql \
  sql/01_automation_support_tables.sql \
  sql/02_triggers.sql \
  sql/03_stored_procedures.sql \
  sql/04_metrics_and_reporting.sql \
  sql/05_seed_demo_data.sql \
  sql/06_run_demo.sql \
  sql/07_tests.sql
do
  echo "==> $f"
  psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$ROOT/$f"
done
echo "Core demo and transactional assertions completed."
echo "Optional pg_cron setup is documented separately in sql/08_schedule_pg_cron.sql."
