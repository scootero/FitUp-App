-- Slice 4b — Re-invoke matchmaking for stale `searching` rows (pg_net → matchmaking-pairing)
-- Run in Supabase SQL editor after `slice4-matchmaking.sql`.
-- Requires: `private.invoke_matchmaking_pairing` from slice 4, Vault secrets, pg_cron (from slice8-finalization.sql).

CREATE OR REPLACE FUNCTION public.matchmaking_retry_stale_searches(
  p_min_age_seconds int DEFAULT 5,
  p_max_invocations int DEFAULT 30
)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  n int := 0;
  r record;
BEGIN
  IF p_min_age_seconds < 0 OR p_max_invocations < 1 THEN
    RAISE EXCEPTION 'matchmaking_retry_stale_searches: invalid parameters';
  END IF;

  FOR r IN
    SELECT id
    FROM match_search_requests
    WHERE status = 'searching'
      AND created_at <= now() - make_interval(secs => p_min_age_seconds)
    ORDER BY created_at ASC
    LIMIT p_max_invocations
  LOOP
    PERFORM private.invoke_matchmaking_pairing(r.id);
    n := n + 1;
  END LOOP;

  RETURN n;
END;
$$;

REVOKE ALL ON FUNCTION public.matchmaking_retry_stale_searches(int, int) FROM PUBLIC;

-- pg_cron job (same pattern as slice8 `day-cutoff-check`)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM cron.job
    WHERE jobname = 'matchmaking-retry-stale'
  ) THEN
    PERFORM cron.schedule(
      'matchmaking-retry-stale',
      '* * * * *',
      $$SELECT public.matchmaking_retry_stale_searches(5, 30);$$
    );
  END IF;
END;
$$;
