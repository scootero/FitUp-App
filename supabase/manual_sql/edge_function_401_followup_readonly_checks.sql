-- =============================================================================
-- edge_function_401_followup_readonly_checks.sql  (READ-ONLY)
-- =============================================================================
-- Run in Supabase SQL Editor as postgres (or equivalent privileged role).
--
-- Context: 401/500 on chained internal Edge calls may be intermittent or tied
-- to deploy / check-in windows; recent logs may show 200s. This script is still
-- useful for correlating pg_cron and pg_net with gateway issues when rows exist.
--
-- Purpose: correlate internal Edge Function 401/500 issues with pg_cron and
-- pg_net — without secrets, JWT inspection, or any DDL/DML.
--
-- Forbidden here: INSERT/UPDATE/DELETE/DDL/cron.schedule/Vault writes, etc.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 0) Sanity
-- ---------------------------------------------------------------------------
SELECT current_database() AS db, current_user AS role, now() AS server_now;

-- ---------------------------------------------------------------------------
-- 1) Cron jobs that invoke Edge Functions (command shape / slugs)
--     Confirms DB-side schedulers target expected function names.
-- ---------------------------------------------------------------------------
SELECT
  jobid,
  jobname,
  schedule,
  active,
  left(command::text, 400) AS command_preview
FROM cron.job
WHERE command::text ILIKE '%invoke_edge_function%'
   OR command::text ILIKE '%finalize%'
   OR jobname ILIKE '%send-%'
   OR jobname ILIKE '%reconcile%'
   OR jobname ILIKE '%cutoff%'
   OR jobname ILIKE '%matchmaking%'
ORDER BY jobname;

-- ---------------------------------------------------------------------------
-- 2) Recent cron failures (non-success statuses)
-- ---------------------------------------------------------------------------
SELECT
  jobid,
  runid,
  status,
  left(return_message::text, 800) AS return_message_preview,
  start_time,
  end_time
FROM cron.job_run_details
WHERE status IS DISTINCT FROM 'succeeded'
ORDER BY start_time DESC NULLS LAST
LIMIT 50;

-- ---------------------------------------------------------------------------
-- 3) net._http_response (pg_net async HTTP)
--     Note: retention may be short; 401 rows may be empty after cleanup.
-- ---------------------------------------------------------------------------
SELECT EXISTS (
  SELECT 1
  FROM information_schema.tables
  WHERE table_schema = 'net' AND table_name = '_http_response'
) AS net__http_response_exists;

-- Status histogram (all retained rows — can be large on busy projects)
SELECT status_code, count(*) AS n
FROM net._http_response
GROUP BY status_code
ORDER BY n DESC;

-- Recent client/gateway errors
SELECT
  id,
  status_code,
  timed_out,
  left(coalesce(error_msg::text, ''), 500) AS error_msg_preview,
  left(coalesce(content::text, ''), 600) AS content_preview,
  created
FROM net._http_response
WHERE coalesce(status_code, 0) >= 400
ORDER BY created DESC NULLS LAST
LIMIT 40;

-- Focus: 401 / 403 / 500 if any
SELECT
  id,
  status_code,
  left(coalesce(content::text, ''), 1000) AS content_preview,
  created
FROM net._http_response
WHERE status_code IN (401, 403, 500)
ORDER BY created DESC NULLS LAST
LIMIT 25;

-- ---------------------------------------------------------------------------
-- 4) private Edge-invoke helpers (existence only)
-- ---------------------------------------------------------------------------
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

-- =============================================================================
-- Broader schema/RPC/trigger checks:
--   supabase/manual_sql/edge_function_diagnostics_checks.sql
-- =============================================================================
