-- Run in Supabase SQL Editor (Step 2 of 2).
-- Schedules hourly invocation of the send-evening-checkins Edge Function.
-- Requires: extension pg_cron, private.invoke_edge_function (from your project migrations).
-- After this, deploy the send-evening-checkins function if you have not already.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'send-evening-checkins') THEN
    PERFORM cron.unschedule('send-evening-checkins');
  END IF;

  PERFORM cron.schedule(
    'send-evening-checkins',
    '0 * * * *',
    $cmd$SELECT private.invoke_edge_function('send-evening-checkins', '{}'::jsonb);$cmd$
  );
END;
$$;
