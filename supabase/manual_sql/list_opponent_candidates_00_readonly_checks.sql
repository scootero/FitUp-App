-- =============================================================================
-- list_opponent_candidates_00_readonly_checks.sql  (READ-ONLY)
-- =============================================================================
-- Run in Supabase SQL Editor before/after applying list_opponent_candidates.sql
-- Forbidden: INSERT/UPDATE/DELETE/DDL (except this script is SELECT-only).
-- =============================================================================

-- 0) Sanity
SELECT current_database() AS db, current_user AS role, now() AS server_now;

-- 1) Function exists with expected signature
SELECT
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS identity_args,
  pg_get_function_result(p.oid) AS result_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'list_opponent_candidates';

-- 2) EXECUTE grant for authenticated
SELECT
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
  AND routine_name = 'list_opponent_candidates'
  AND grantee IN ('authenticated', 'PUBLIC', 'anon')
ORDER BY grantee, privilege_type;

-- 3) Underlying tables present
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('profiles', 'user_health_baselines', 'leaderboard_entries', 'metric_snapshots')
ORDER BY table_name;

-- 4) Smoke call (returns rows only when run as an authenticated user in SQL editor
--    with a valid JWT — may return 0 rows when run as postgres/service role without auth)
-- SELECT * FROM public.list_opponent_candidates('', 'steps', current_date, 5);
