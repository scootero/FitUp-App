-- Notifications v1 — pause generic morning check-in AFTER yesterday_recap is verified on TestFlight.
-- Do NOT run until recap is tested. evening_checkin is intentionally left scheduled.

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'send-morning-checkins') THEN
    PERFORM cron.unschedule('send-morning-checkins');
  END IF;
END;
$$;

-- Verify morning job removed; evening still active:
-- SELECT jobname, schedule, active FROM cron.job WHERE jobname LIKE 'send-%' ORDER BY jobname;
