-- Optional PostgreSQL pg_cron setup. Requires server-side installation and privileges.
-- Administrator performs once (availability depends on hosting provider):
--   CREATE EXTENSION IF NOT EXISTS pg_cron;
-- Then schedule tasks. Jobs run in the database server timezone.
SELECT cron.schedule(
  'retail-daily-inventory-snapshot',
  '5 0 * * *',
  $$CALL retail.sp_capture_daily_inventory();$$
);
SELECT cron.schedule(
  'retail-monthly-order-archive',
  '30 2 1 * *',
  $$CALL retail.sp_archive_old_orders(365);$$
);
-- Inspect:
-- SELECT jobid, schedule, command, active FROM cron.job;
-- Recent runs:
-- SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 20;
-- Remove by job id:
-- SELECT cron.unschedule(<jobid>);
