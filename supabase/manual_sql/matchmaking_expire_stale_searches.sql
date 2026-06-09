-- matchmaking_expire_stale_searches.sql
--
-- FitUp-dev manual apply: expire Quick Match searches stuck in `searching` for 24+ hours.
--
-- What this does (and does NOT do):
--   - Updates `match_search_requests.status` from `searching` → `expired` (no deletes).
--   - Only rows with status = `searching`, matched_match_id IS NULL, created_at older than 24h.
--   - Does NOT touch `matches`, `match_participants`, `direct_challenges`, or paired rows (`matched`).
--   - iOS already filters Home searching UI with `.eq("status", "searching")` — no app change required.
--
-- Also updates `matchmaking_retry_stale_searches` so the existing every-5-min retry cron stops
-- re-invoking pairing for rows older than 24h (wasted Edge Function calls until expiration runs).
--
-- Pre-flight on FitUp-dev (2026-06-08, read-only):
--   status CHECK: searching | matched | cancelled  (expired not yet present)
--   matchmaking_expire_stale_searches: absent
--   matchmaking_retry_stale_searches + matchmaking_pair_atomic: present
--   cron job matchmaking-retry-stale: */5 * * * * (active)
--   rows that would expire now: 0
--
-- Apply (Supabase SQL editor as postgres):
--   Run SECTION 1 (pre-flight) → SECTION 2 (apply) → SECTION 3 (verify).
--
-- Rollback: SECTION 4 at bottom.


-- ===========================================================================
-- SECTION 1 — Pre-flight (read-only; safe to re-run)
-- ===========================================================================

-- 1a) Status constraint (expect searching | matched | cancelled before apply)
SELECT conname, pg_get_constraintdef(oid) AS def
FROM pg_constraint
WHERE conrelid = 'public.match_search_requests'::regclass
  AND contype = 'c'
  AND conname = 'match_search_requests_status_check';

-- 1b) Rows that would expire with default 24h threshold
SELECT count(*) AS would_expire
FROM public.match_search_requests
WHERE status = 'searching'
  AND matched_match_id IS NULL
  AND created_at < now() - interval '24 hours';

-- 1c) Current status distribution
SELECT status, count(*) AS n
FROM public.match_search_requests
GROUP BY status
ORDER BY status;

-- 1d) Matchmaking cron jobs
SELECT jobid, jobname, schedule, command, active
FROM cron.job
WHERE jobname ILIKE '%matchmaking%'
ORDER BY jobname;

-- 1e) Matchmaking functions present on server
SELECT p.proname, pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'matchmaking_pair_atomic',
    'matchmaking_retry_stale_searches',
    'matchmaking_expire_stale_searches'
  )
ORDER BY p.proname;


-- ===========================================================================
-- SECTION 2 — Apply
-- ===========================================================================

-- 2a) Allow `expired` status (distinct from user-initiated `cancelled` for auditability)
ALTER TABLE public.match_search_requests
  DROP CONSTRAINT IF EXISTS match_search_requests_status_check;

ALTER TABLE public.match_search_requests
  ADD CONSTRAINT match_search_requests_status_check
  CHECK (status = ANY (ARRAY[
    'searching'::text,
    'matched'::text,
    'cancelled'::text,
    'expired'::text
  ]));

COMMENT ON CONSTRAINT match_search_requests_status_check ON public.match_search_requests IS
  'searching = open queue; matched = paired; cancelled = user cancelled; expired = auto-expired after max search age';


-- 2b) Expire stale searches (idempotent; safe to run repeatedly)
CREATE OR REPLACE FUNCTION public.matchmaking_expire_stale_searches(
  p_max_age_hours integer DEFAULT 24
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_expired int;
BEGIN
  IF p_max_age_hours < 1 THEN
    RAISE EXCEPTION 'matchmaking_expire_stale_searches: p_max_age_hours must be >= 1';
  END IF;

  UPDATE public.match_search_requests
  SET status = 'expired'
  WHERE status = 'searching'
    AND matched_match_id IS NULL
    AND created_at < now() - make_interval(hours => p_max_age_hours);

  GET DIAGNOSTICS v_expired = ROW_COUNT;

  RAISE NOTICE 'matchmaking_expire_stale_searches: expired % row(s) (max_age_hours=%)',
    v_expired, p_max_age_hours;

  RETURN v_expired;
END;
$function$;

COMMENT ON FUNCTION public.matchmaking_expire_stale_searches(integer) IS
  'Marks open match_search_requests older than p_max_age_hours as expired. Idempotent; does not delete rows or touch matches.';

REVOKE ALL ON FUNCTION public.matchmaking_expire_stale_searches(integer) FROM PUBLIC;


-- 2c) Cap retry cron so 24h+ searching rows are not re-paired every 5 minutes.
-- Keeps the existing (integer, integer) signature so cron.schedule(..., 5, 30) keeps working
-- and CREATE OR REPLACE updates in place (no overload ambiguity).
CREATE OR REPLACE FUNCTION public.matchmaking_retry_stale_searches(
  p_min_age_seconds integer DEFAULT 5,
  p_max_invocations integer DEFAULT 30
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  n int := 0;
  r record;
  c_max_search_age_hours constant integer := 24;
BEGIN
  IF p_min_age_seconds < 0 OR p_max_invocations < 1 THEN
    RAISE EXCEPTION 'matchmaking_retry_stale_searches: invalid parameters';
  END IF;

  FOR r IN
    SELECT id
    FROM public.match_search_requests
    WHERE status = 'searching'
      AND matched_match_id IS NULL
      AND created_at <= now() - make_interval(secs => p_min_age_seconds)
      AND created_at > now() - make_interval(hours => c_max_search_age_hours)
    ORDER BY created_at ASC
    LIMIT p_max_invocations
  LOOP
    PERFORM private.invoke_matchmaking_pairing(r.id);
    n := n + 1;
  END LOOP;

  RETURN n;
END;
$function$;

COMMENT ON FUNCTION public.matchmaking_retry_stale_searches(integer, integer) IS
  'Re-invokes matchmaking-pairing for searching rows between p_min_age_seconds old and 24h max age. Skips matched/expired/cancelled rows.';

REVOKE ALL ON FUNCTION public.matchmaking_retry_stale_searches(integer, integer) FROM PUBLIC;


-- 2d) Schedule expiration cron (every 15 minutes; idempotent job registration)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM cron.job WHERE jobname = 'matchmaking-expire-stale'
  ) THEN
    PERFORM cron.unschedule('matchmaking-expire-stale');
  END IF;

  PERFORM cron.schedule(
    'matchmaking-expire-stale',
    '*/15 * * * *',
    $$ SELECT public.matchmaking_expire_stale_searches(24); $$
  );
END;
$$;


-- ===========================================================================
-- SECTION 3 — Verify (read-only except 3b manual smoke test)
-- ===========================================================================

-- 3a) Constraint now includes expired
SELECT conname, pg_get_constraintdef(oid) AS def
FROM pg_constraint
WHERE conrelid = 'public.match_search_requests'::regclass
  AND contype = 'c'
  AND conname = 'match_search_requests_status_check';

-- 3b) Manual smoke test (idempotent; returns 0 when nothing is stale)
SELECT public.matchmaking_expire_stale_searches(24) AS expired_count;

-- 3c) No ancient searching rows should remain
SELECT id, creator_id, status, created_at, matched_match_id
FROM public.match_search_requests
WHERE status = 'searching'
  AND matched_match_id IS NULL
  AND created_at < now() - interval '24 hours';

-- 3d) Cron jobs
SELECT jobid, jobname, schedule, command, active
FROM cron.job
WHERE jobname ILIKE '%matchmaking%'
ORDER BY jobname;

-- 3e) Retry function includes max-age guard (inspect text)
SELECT pg_get_functiondef('public.matchmaking_retry_stale_searches(integer, integer)'::regprocedure);


-- ===========================================================================
-- SECTION 4 — Rollback (run only if you need to undo)
-- ===========================================================================

-- 4a) Remove expiration cron
-- SELECT cron.unschedule('matchmaking-expire-stale');

-- 4b) Drop expire function
-- DROP FUNCTION IF EXISTS public.matchmaking_expire_stale_searches(integer);

-- 4c) Restore retry function without max-age cap (2-arg signature from migration baseline)
-- CREATE OR REPLACE FUNCTION public.matchmaking_retry_stale_searches(
--   p_min_age_seconds integer DEFAULT 5,
--   p_max_invocations integer DEFAULT 30
-- )
-- RETURNS integer
-- LANGUAGE plpgsql
-- SECURITY DEFINER
-- SET search_path TO 'public', 'pg_temp'
-- AS $function$
-- DECLARE
--   n int := 0;
--   r record;
-- BEGIN
--   IF p_min_age_seconds < 0 OR p_max_invocations < 1 THEN
--     RAISE EXCEPTION 'matchmaking_retry_stale_searches: invalid parameters';
--   END IF;
--   FOR r IN
--     SELECT id
--     FROM match_search_requests
--     WHERE status = 'searching'
--       AND created_at <= now() - make_interval(secs => p_min_age_seconds)
--     ORDER BY created_at ASC
--     LIMIT p_max_invocations
--   LOOP
--     PERFORM private.invoke_matchmaking_pairing(r.id);
--     n := n + 1;
--   END LOOP;
--   RETURN n;
-- END;
-- $function$;
-- REVOKE ALL ON FUNCTION public.matchmaking_retry_stale_searches(integer, integer) FROM PUBLIC;

-- 4d) Revert any expired rows back to searching (only if you rolled back before users noticed)
-- UPDATE public.match_search_requests
-- SET status = 'searching'
-- WHERE status = 'expired';

-- 4e) Remove expired from status CHECK (only after no rows use expired)
-- ALTER TABLE public.match_search_requests DROP CONSTRAINT IF EXISTS match_search_requests_status_check;
-- ALTER TABLE public.match_search_requests ADD CONSTRAINT match_search_requests_status_check
--   CHECK (status = ANY (ARRAY['searching'::text, 'matched'::text, 'cancelled'::text]));
