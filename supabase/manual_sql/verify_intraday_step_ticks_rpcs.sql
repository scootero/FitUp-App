-- Intraday step ticks — Slice 2 RPC verification (read-only, Supabase SQL Editor)
--
-- Run after: intraday_step_ticks_slice2_rpcs.sql

-- Functions exist
SELECT p.proname,
       pg_get_function_identity_arguments(p.oid) AS identity_args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname IN (
    'intraday_step_ticks_prune_one_victim',
    'append_user_intraday_step_tick',
    'prune_user_intraday_step_tick_day',
    'fetch_opponent_intraday_step_ticks'
  )
ORDER BY p.proname;

-- EXECUTE grants for authenticated
SELECT routine_name,
       string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privileges
FROM information_schema.routine_privileges
WHERE routine_schema = 'public'
  AND grantee = 'authenticated'
  AND routine_name IN (
    'append_user_intraday_step_tick',
    'prune_user_intraday_step_tick_day',
    'fetch_opponent_intraday_step_ticks'
  )
GROUP BY routine_name
ORDER BY routine_name;

-- Internal helper should NOT be executable by PUBLIC / authenticated (best-effort check)
SELECT has_function_privilege('authenticated', p.oid, 'execute') AS authenticated_can_execute,
       p.proname,
       pg_get_function_identity_arguments(p.oid) AS identity_args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'intraday_step_ticks_prune_one_victim';
