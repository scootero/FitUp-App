-- =============================================================================
-- early_clinch_00_readonly_audit.sql  (READ-ONLY)
-- =============================================================================
-- Purpose:
--   Validate early-clinch readiness and post-deploy behavior without mutations.
--
-- Rules:
--   - No INSERT/UPDATE/DELETE/DDL
--   - No cron.schedule changes
--   - No function replacement
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 0) Sanity
-- ---------------------------------------------------------------------------
SELECT current_database() AS db, current_user AS role, now() AS server_now;

-- ---------------------------------------------------------------------------
-- 1) Current active matches and day status
-- ---------------------------------------------------------------------------
SELECT
  m.id AS match_id,
  m.state,
  m.duration_days,
  ((m.duration_days + 1) / 2) AS wins_required,
  md.day_number,
  md.calendar_date,
  md.status AS day_status,
  md.winner_user_id,
  md.is_void,
  md.finalized_at
FROM public.matches m
JOIN public.match_days md ON md.match_id = m.id
WHERE m.state = 'active'
ORDER BY m.id, md.day_number;

-- ---------------------------------------------------------------------------
-- 2) Clinched-active detector (should be 0 after early-clinch rollout stabilizes)
-- ---------------------------------------------------------------------------
WITH finalized_wins AS (
  SELECT
    m.id AS match_id,
    m.duration_days,
    ((m.duration_days + 1) / 2) AS wins_required,
    md.winner_user_id,
    COUNT(*)::int AS wins
  FROM public.matches m
  JOIN public.match_days md ON md.match_id = m.id
  WHERE m.state = 'active'
    AND md.status = 'finalized'
    AND md.is_void = false
    AND md.winner_user_id IS NOT NULL
  GROUP BY m.id, m.duration_days, md.winner_user_id
)
SELECT
  fw.match_id,
  fw.duration_days,
  fw.wins_required,
  fw.winner_user_id,
  fw.wins,
  (SELECT COUNT(*) FROM public.match_days d WHERE d.match_id = fw.match_id AND d.status <> 'finalized') AS pending_days
FROM finalized_wins fw
WHERE fw.wins >= fw.wins_required
ORDER BY fw.match_id, fw.wins DESC;

-- ---------------------------------------------------------------------------
-- 3) Historical clinch-delay signal (3-day, same winner D1 + D2)
-- ---------------------------------------------------------------------------
WITH three_day_completed AS (
  SELECT m.id, m.completed_at
  FROM public.matches m
  WHERE m.state = 'completed'
    AND m.duration_days = 3
),
d1 AS (
  SELECT md.match_id, md.winner_user_id AS d1_winner
  FROM public.match_days md
  WHERE md.day_number = 1
    AND md.status = 'finalized'
    AND md.is_void = false
),
d2 AS (
  SELECT md.match_id, md.winner_user_id AS d2_winner, md.finalized_at AS d2_finalized_at
  FROM public.match_days md
  WHERE md.day_number = 2
    AND md.status = 'finalized'
    AND md.is_void = false
),
sweeps AS (
  SELECT
    t.id AS match_id,
    t.completed_at,
    d2.d2_finalized_at,
    (t.completed_at - d2.d2_finalized_at) AS delay_after_clinch
  FROM three_day_completed t
  JOIN d1 ON d1.match_id = t.id
  JOIN d2 ON d2.match_id = t.id
  WHERE d1.d1_winner IS NOT NULL
    AND d2.d2_winner = d1.d1_winner
)
SELECT
  COUNT(*) AS total_2_0_sweeps,
  COUNT(*) FILTER (WHERE delay_after_clinch > interval '1 hour') AS delayed_over_1h,
  MIN(delay_after_clinch) AS min_delay,
  MAX(delay_after_clinch) AS max_delay
FROM sweeps;

-- ---------------------------------------------------------------------------
-- 4) New invariant verifier:
--    Completed can be all-finalized OR clinched-with-pending
-- ---------------------------------------------------------------------------
WITH completed AS (
  SELECT
    m.id,
    m.duration_days,
    COUNT(*) FILTER (WHERE md.status = 'finalized') AS finalized_days,
    COUNT(*) FILTER (WHERE md.status <> 'finalized') AS pending_days,
    COUNT(*) AS total_days
  FROM public.matches m
  JOIN public.match_days md ON md.match_id = m.id
  WHERE m.state = 'completed'
  GROUP BY m.id, m.duration_days
),
clinch AS (
  SELECT
    m.id AS match_id,
    ((m.duration_days + 1) / 2) AS wins_required,
    MAX(win_count.wins) AS max_wins
  FROM public.matches m
  LEFT JOIN (
    SELECT
      md.match_id,
      md.winner_user_id,
      COUNT(*)::int AS wins
    FROM public.match_days md
    WHERE md.status = 'finalized'
      AND md.is_void = false
      AND md.winner_user_id IS NOT NULL
    GROUP BY md.match_id, md.winner_user_id
  ) win_count
    ON win_count.match_id = m.id
  WHERE m.state = 'completed'
  GROUP BY m.id, m.duration_days
)
SELECT
  COUNT(*) AS completed_matches,
  COUNT(*) FILTER (WHERE c.pending_days = 0) AS completed_all_days_finalized,
  COUNT(*) FILTER (WHERE c.pending_days > 0 AND COALESCE(k.max_wins, 0) >= k.wins_required) AS completed_clinched_with_pending,
  COUNT(*) FILTER (WHERE c.pending_days > 0 AND COALESCE(k.max_wins, 0) < k.wins_required) AS completed_pending_but_not_clinched
FROM completed c
JOIN clinch k ON k.match_id = c.id;

-- ---------------------------------------------------------------------------
-- 5) Function assumptions scan (completed + finalized dependency)
-- ---------------------------------------------------------------------------
WITH defs AS (
  SELECT
    n.nspname AS schema,
    p.proname AS name,
    p.prokind,
    pg_get_function_identity_arguments(p.oid) AS args,
    pg_get_functiondef(p.oid) AS def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname IN ('public', 'private')
    AND p.prokind IN ('f', 'p')
)
SELECT schema, name, args
FROM defs
WHERE def ILIKE '%state = ''completed''%'
ORDER BY schema, name;

-- Watch query: completed assumptions that reference match_days but not finalized filter
WITH defs AS (
  SELECT
    n.nspname AS schema,
    p.proname AS name,
    p.prokind,
    pg_get_functiondef(p.oid) AS def
  FROM pg_proc p
  JOIN pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname IN ('public', 'private')
    AND p.prokind IN ('f', 'p')
)
SELECT schema, name
FROM defs
WHERE def ILIKE '%state = ''completed''%'
  AND def ILIKE '%match_days%'
  AND def NOT ILIKE '%status = ''finalized''%'
ORDER BY schema, name;

-- Explicit watch item details
SELECT
  p.proname,
  pg_get_functiondef(p.oid) AS fn_def
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.prokind IN ('f', 'p')
  AND p.proname = 'home_daily_battle_margins';

-- ---------------------------------------------------------------------------
-- 6) Cron / trigger / function sanity
-- ---------------------------------------------------------------------------
SELECT jobid, jobname, schedule, command, active
FROM cron.job
ORDER BY jobname;

SELECT
  event_object_table,
  trigger_name,
  event_manipulation,
  action_timing
FROM information_schema.triggers
WHERE event_object_schema = 'public'
  AND event_object_table IN ('match_day_participants', 'matches', 'match_participants')
ORDER BY event_object_table, trigger_name;

SELECT
  p.oid,
  n.nspname AS schema,
  p.proname AS name,
  pg_get_function_identity_arguments(p.oid) AS args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE (n.nspname, p.proname) IN (
    ('public', 'day_cutoff_check'),
    ('public', 'reconcile_stuck_match_completions'),
    ('public', 'finalize_when_all_confirmed'),
    ('private', 'invoke_finalize_match_day'),
    ('private', 'invoke_edge_function')
  )
ORDER BY schema, name;

-- ---------------------------------------------------------------------------
-- 7) Optional quick spot checks for recent failures
-- ---------------------------------------------------------------------------
SELECT
  jobid,
  status,
  left(return_message::text, 300) AS return_message_preview,
  start_time,
  end_time
FROM cron.job_run_details
WHERE status IS DISTINCT FROM 'succeeded'
ORDER BY start_time DESC
LIMIT 25;

