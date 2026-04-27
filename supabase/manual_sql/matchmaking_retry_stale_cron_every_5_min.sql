-- matchmaking_retry_stale_cron_every_5_min.sql
--
-- Pre–TestFlight: reduce pg_cron + edge invocations by running stale matchmaking
-- retry every 5 minutes instead of every minute. Reversible.
--
-- Apply (SQL editor or psql as postgres):
--   Inspect current row:
--     select jobid, jobname, schedule, command, active from cron.job where jobname = 'matchmaking-retry-stale';

select cron.unschedule('matchmaking-retry-stale');

select cron.schedule(
  'matchmaking-retry-stale',
  '*/5 * * * *',
  $$ SELECT public.matchmaking_retry_stale_searches(5, 30); $$
);

-- ROLLBACK (restore every-minute schedule):
-- select cron.unschedule('matchmaking-retry-stale');
-- select cron.schedule(
--   'matchmaking-retry-stale',
--   '* * * * *',
--   $$ SELECT public.matchmaking_retry_stale_searches(5, 30); $$
-- );
