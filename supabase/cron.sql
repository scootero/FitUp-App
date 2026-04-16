SELECT cron.schedule(
  'day-cutoff-check',
  '5 * * * *',
  $$ SELECT public.day_cutoff_check(); $$
);

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

SELECT cron.schedule(
  'matchmaking-retry-stale',
  '* * * * *',
  $$ SELECT public.matchmaking_retry_stale_searches(5, 30); $$
);