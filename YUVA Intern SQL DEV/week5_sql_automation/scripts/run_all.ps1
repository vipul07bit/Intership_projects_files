$ErrorActionPreference = "Stop"
if (-not $env:DATABASE_URL) { throw "Set DATABASE_URL, e.g. postgresql://user:pass@localhost:5432/retaildb" }
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$SqlFiles = @(
"sql/00_bootstrap_retail.sql",
"sql/01_automation_support_tables.sql",
"sql/02_triggers.sql",
"sql/03_stored_procedures.sql",
"sql/04_metrics_and_reporting.sql",
"sql/05_seed_demo_data.sql",
"sql/06_run_demo.sql",
"sql/07_tests.sql"
)
foreach ($File in $SqlFiles) {
  Write-Host "==> $File"
  & psql $env:DATABASE_URL -v ON_ERROR_STOP=1 -f (Join-Path $Root $File)
  if ($LASTEXITCODE -ne 0) { throw "psql failed on $File" }
}
Write-Host "Core demo and transactional assertions completed."
Write-Host "Optional pg_cron setup: sql/08_schedule_pg_cron.sql"
