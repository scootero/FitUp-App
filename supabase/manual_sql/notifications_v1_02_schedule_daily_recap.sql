-- Notifications v1 — schedule hourly send-daily-recap (function filters local hour 10 / 16).
-- Run in Supabase SQL Editor AFTER deploying send-daily-recap Edge Function.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'send-daily-recap') THEN
    PERFORM cron.unschedule('send-daily-recap');
  END IF;

  PERFORM cron.schedule(
    'send-daily-recap',
    '0 * * * *',
    $cmd$SELECT private.invoke_edge_function('send-daily-recap', '{}'::jsonb);$cmd$
  );
END;
$$;

-- Verify:
-- SELECT jobname, schedule, active FROM cron.job WHERE jobname = 'send-daily-recap';
