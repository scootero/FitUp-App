SELECT cron.schedule(
  'day-cutoff-check',
  '5 * * * *',
  $$ SELECT public.day_cutoff_check(); $$
);

-- Match completion backfill: public.reconcile_stuck_match_completions (*/10) is registered in
-- migration 20260422120000_reconcile_stuck_match_completions.sql — not duplicated here to avoid
-- duplicate jobname errors if migrations are applied first.

SELECT cron.schedule(
  'send-pending-reminders',
  '15 16 * * *',
  $$ SELECT private.invoke_edge_function('send-pending-reminders', '{}'::jsonb); $$
);

SELECT cron.schedule(
  'send-morning-checkins',
  '0 13 * * *',
  $$ SELECT private.invoke_edge_function('send-morning-checkins', '{}'::jsonb); $$
);

-- Hourly: evening check-in nudge (7pm in each user’s profile timezone) via send-evening-checkins.
SELECT cron.schedule(
  'send-evening-checkins',
  '0 * * * *',
  $$ SELECT private.invoke_edge_function('send-evening-checkins', '{}'::jsonb); $$
);

SELECT cron.schedule(
  'matchmaking-retry-stale',
  '* * * * *',
  $$ SELECT public.matchmaking_retry_stale_searches(5, 30); $$
);