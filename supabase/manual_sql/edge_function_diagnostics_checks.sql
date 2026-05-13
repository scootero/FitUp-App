-- =============================================================================
-- edge_function_diagnostics_checks.sql  (READ-ONLY)
-- =============================================================================
-- Run in Supabase SQL Editor as a privileged role (postgres).
-- No writes, DDL, or extension mutation — SELECT / catalog introspection only.
--
-- Purpose: prove or disprove schema drift, missing RPC/triggers, and cron/pg_net
-- failures vs what Edge Functions (finalize-match-day, chain, check-ins) expect.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 0) Quick project sanity
-- ---------------------------------------------------------------------------
SELECT current_database() AS db, current_user AS role, now() AS server_now;

-- ---------------------------------------------------------------------------
-- 1) Schema: columns expected by current Edge Function code (supabase/functions)
--
-- Edge refs (repo):
--   finalize-match-day: match_day_participants.finalized_value, balanced_ratio,
--     balanced_percent; match_participants.baseline_steps; matches.scoring_mode,
--     metric_type, duration_days
--   complete-match:     matches.state, metric_type, duration_days, scoring_mode
--   update-leaderboard: match_days.finalized_at, match_day_participants.finalized_value,
--     leaderboard_entries.*
--   send-morning/evening: matches.scoring_mode, metric_type, match_participants.baseline_steps
--   send-pending-reminders: matches.state, metric_type, match_participants.accepted_at
--
-- NOT referenced by Edge Functions as column updates (informational if present):
--   balanced_battle_score, balance_multiplier
-- ---------------------------------------------------------------------------
WITH expected AS (
  SELECT * FROM (VALUES
    ('public', 'match_day_participants', 'finalized_value'),
    ('public', 'match_day_participants', 'balanced_ratio'),
    ('public', 'match_day_participants', 'balanced_percent'),
    ('public', 'match_participants', 'baseline_steps'),
    ('public', 'matches', 'scoring_mode'),
    ('public', 'matches', 'difficulty'),
    ('public', 'matches', 'matchmaking_resolution'),
    ('public', 'matches', 'matchmaking_attempt')
  ) AS t(table_schema, table_name, column_name)
)
SELECT
  e.table_schema,
  e.table_name,
  e.column_name,
  (c.column_name IS NOT NULL) AS present,
  c.data_type,
  c.is_nullable
FROM expected e
LEFT JOIN information_schema.columns c
  ON c.table_schema = e.table_schema
 AND c.table_name = e.table_name
 AND c.column_name = e.column_name
ORDER BY e.table_schema, e.table_name, e.column_name;

-- Tables that must exist for dispatch-notification and finalize chain
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN (
    'matches',
    'match_days',
    'match_day_participants',
    'match_participants',
    'profiles',
    'leaderboard_entries',
    'notification_events',
    'user_health_baselines',
    'match_search_requests'
  )
ORDER BY table_name;

-- ---------------------------------------------------------------------------
-- 2) RPC / functions: existence + OID (compare across environments)
-- ---------------------------------------------------------------------------
SELECT
  p.oid,
  n.nspname AS schema,
  p.proname AS name,
  pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE (n.nspname, p.proname) IN (
    ('public', 'matchmaking_pair_atomic'),
    ('public', 'activate_match_with_days'),
    ('public', 'notify_lead_changed'),
    ('public', 'day_cutoff_check'),
    ('public', 'reconcile_stuck_match_completions'),
    ('public', 'evening_checkin_candidates'),
    ('public', 'matchmaking_retry_stale_searches'),
    ('public', 'set_my_match_participant_baseline')
  )
ORDER BY schema, name;

-- Definitions (large). Comment out if Editor times out; run one at a time.
-- SELECT pg_get_functiondef('public.matchmaking_pair_atomic(uuid)'::regprocedure);
-- SELECT pg_get_functiondef('public.activate_match_with_days(uuid)'::regprocedure);
-- SELECT pg_get_functiondef('public.notify_lead_changed()'::regprocedure);
-- SELECT pg_get_functiondef('public.day_cutoff_check()'::regprocedure);
-- SELECT pg_get_functiondef('public.reconcile_stuck_match_completions()'::regprocedure);
-- SELECT pg_get_functiondef('public.evening_checkin_candidates()'::regprocedure);

-- private.invoke_* helpers (Edge invocation from SQL)
SELECT
  p.oid,
  n.nspname AS schema,
  p.proname AS name,
  pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'private'
  AND p.proname IN (
    'invoke_edge_function',
    'invoke_finalize_match_day',
    'invoke_dispatch_notification'
  )
ORDER BY p.proname;

-- ---------------------------------------------------------------------------
-- 3) Triggers (match finalization, lead change, search insert, etc.)
-- ---------------------------------------------------------------------------
SELECT
  event_object_schema,
  event_object_table,
  trigger_name,
  event_manipulation,
  action_timing,
  action_orientation
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND (
    event_object_table IN (
      'match_day_participants',
      'match_search_requests',
      'matches',
      'match_participants',
      'direct_challenges'
    )
    OR trigger_name ILIKE '%lead%'
    OR trigger_name ILIKE '%matchmaking%'
    OR trigger_name ILIKE '%finalize%'
  )
ORDER BY event_object_table, trigger_name;

-- ---------------------------------------------------------------------------
-- 4) pg_cron: registered jobs (live config, not assumed from repo)
-- ---------------------------------------------------------------------------
SELECT jobid, jobname, schedule, command, nodename, nodeport, database, username, active
FROM cron.job
ORDER BY jobname;

-- Recent cron runs (may be large on Free tier)
SELECT
  jobid,
  runid,
  job_pid,
  database,
  username,
  command,
  status,
  return_message,
  start_time,
  end_time
FROM cron.job_run_details
ORDER BY start_time DESC NULLS LAST
LIMIT 100;

-- Failures only
SELECT
  jobid,
  runid,
  status,
  left(return_message::text, 500) AS return_message_preview,
  start_time,
  end_time
FROM cron.job_run_details
WHERE status IS DISTINCT FROM 'succeeded'
ORDER BY start_time DESC NULLS LAST
LIMIT 50;

-- ---------------------------------------------------------------------------
-- 5) pg_net: HTTP responses from async calls (Edge URLs, status codes)
-- ---------------------------------------------------------------------------
SELECT EXISTS (
  SELECT 1
  FROM information_schema.tables
  WHERE table_schema = 'net' AND table_name = '_http_response'
) AS net__http_response_exists;

-- Status histogram
SELECT status_code, count(*) AS n
FROM net._http_response
GROUP BY status_code
ORDER BY n DESC;

-- Recent non-success
SELECT *
FROM net._http_response
WHERE coalesce(status_code, 0) >= 400
ORDER BY created DESC
LIMIT 30;

-- Recent 5xx bodies (truncated)
SELECT
  id,
  status_code,
  left(coalesce(content::text, '')::text, 800) AS content_preview,
  created
FROM net._http_response
WHERE status_code >= 500
ORDER BY created DESC
LIMIT 20;

-- ---------------------------------------------------------------------------
-- 6) Optional: rows waiting finalization (read-only health)
-- ---------------------------------------------------------------------------
SELECT
  md.id AS match_day_id,
  md.match_id,
  md.status,
  md.day_number,
  md.calendar_date,
  m.scoring_mode,
  m.metric_type
FROM public.match_days md
JOIN public.matches m ON m.id = md.match_id
WHERE md.status IS DISTINCT FROM 'finalized'
  AND m.state = 'active'
ORDER BY md.calendar_date ASC
LIMIT 50;

-- =============================================================================
-- End
-- =============================================================================
