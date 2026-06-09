-- verify_matchmaking_expire_stale_searches.sql
--
-- Read-only checks after applying matchmaking_expire_stale_searches.sql.
-- Safe to re-run anytime.

-- 1) Status constraint includes expired
SELECT conname, pg_get_constraintdef(oid) AS def
FROM pg_constraint
WHERE conrelid = 'public.match_search_requests'::regclass
  AND contype = 'c'
  AND conname = 'match_search_requests_status_check';

-- 2) Expire function exists
SELECT pg_get_functiondef('public.matchmaking_expire_stale_searches(integer)'::regprocedure);

-- 3) Retry function has max-age guard (same 2-arg signature as before)
SELECT pg_get_functiondef('public.matchmaking_retry_stale_searches(integer, integer)'::regprocedure);

-- 4) Cron jobs
SELECT jobid, jobname, schedule, command, active
FROM cron.job
WHERE jobname ILIKE '%matchmaking%'
ORDER BY jobname;

-- 5) No stale searching rows (should return 0 rows)
SELECT id, creator_id, status, created_at, matched_match_id
FROM public.match_search_requests
WHERE status = 'searching'
  AND matched_match_id IS NULL
  AND created_at < now() - interval '24 hours';

-- 6) Status distribution (optional audit)
SELECT status, count(*) AS n
FROM public.match_search_requests
GROUP BY status
ORDER BY status;

-- 7) Paired rows untouched (sanity)
SELECT count(*) AS matched_search_rows
FROM public.match_search_requests
WHERE status = 'matched';
