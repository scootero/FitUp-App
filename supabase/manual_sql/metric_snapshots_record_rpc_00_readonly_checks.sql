-- =============================================================================
-- metric_snapshots_record_rpc_00_readonly_checks.sql  (READ-ONLY)
-- =============================================================================
-- Run in Supabase SQL Editor before/after applying metric_snapshots_record_rpc.sql
-- Forbidden: INSERT/UPDATE/DELETE/DDL/cron.schedule/Vault writes.
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
  AND p.proname = 'record_metric_snapshot';

-- 2) EXECUTE grant for authenticated
SELECT
  grantee,
  privilege_type
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
  AND routine_name = 'record_metric_snapshot'
  AND grantee IN ('authenticated', 'PUBLIC', 'anon')
ORDER BY grantee, privilege_type;

-- 3) metric_snapshots table still present (no schema migration required)
SELECT
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'metric_snapshots'
ORDER BY ordinal_position;

-- 4) Spot-check: consecutive same-value runs per match/day (duplicate candidates)
--    High counts here mean apply + iOS RPC should reduce future growth.
SELECT
  user_id,
  match_id,
  metric_type,
  source_date,
  value,
  count(*) AS row_count,
  min(synced_at) AS first_synced_at,
  max(synced_at) AS last_synced_at
FROM public.metric_snapshots
GROUP BY user_id, match_id, metric_type, source_date, value
HAVING count(*) > 2
ORDER BY row_count DESC, last_synced_at DESC
LIMIT 50;

-- 5) Related objects unchanged (sanity — should still exist)
SELECT proname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND proname IN (
    'append_user_intraday_step_tick',
    'weekly_steps_leaderboard',
    'weekly_steps_leaderboard_from_daily_totals'
  )
ORDER BY proname;
