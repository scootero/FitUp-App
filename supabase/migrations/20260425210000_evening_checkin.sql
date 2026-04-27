-- Eligible users for 7pm local evening check-in: local wall-clock hour 19, and
-- public daily activity is missing or not yet stamped for the user's local calendar day.

CREATE OR REPLACE FUNCTION public.evening_checkin_candidates()
RETURNS TABLE (user_id uuid, local_date text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = 'public', 'pg_temp'
AS $function$
  SELECT
    p.id AS user_id,
    to_char(
      ((now() AT TIME ZONE COALESCE(NULLIF(btrim(p.timezone), ''), 'America/New_York')))::date,
      'YYYY-MM-DD'
    ) AS local_date
  FROM public.profiles p
  WHERE
    EXTRACT(
      HOUR
      FROM (now() AT TIME ZONE COALESCE(NULLIF(btrim(p.timezone), ''), 'America/New_York'))
    ) = 19
    AND NOT EXISTS (
      SELECT 1
      FROM public.user_public_daily_activity u
      WHERE u.user_id = p.id
        AND u.active_date = ((now() AT TIME ZONE COALESCE(NULLIF(btrim(p.timezone), ''), 'America/New_York')))::date
    );
$function$;

COMMENT ON FUNCTION public.evening_checkin_candidates() IS
  'User ids in local 7–8pm window (hour 19) who have not synced user_public_daily_activity for the local calendar day.';

REVOKE ALL ON FUNCTION public.evening_checkin_candidates() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.evening_checkin_candidates() TO postgres, service_role;

-- Hourly: local 7pm is a different UTC instant per user; the Edge Function keeps only user-local 19:xx.
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
