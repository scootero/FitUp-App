-- =============================================================================
-- home_hero_beam_animation_00_readonly_checks.sql  (READ-ONLY)
-- =============================================================================
-- Validates Home hero data + app log patterns related to beam intro / HK patch.
-- NO schema changes required for the iOS hero beam animation fix.
-- Forbidden: INSERT/UPDATE/DELETE/DDL/cron.schedule/Vault writes.
--
-- Usage:
-- 1) Replace p_profile_id in each params CTE with the viewer profile UUID.
-- 2) Run sections independently or all at once in Supabase SQL Editor.
-- =============================================================================

-- =============================================================================
-- Section 0: Sanity
-- =============================================================================
SELECT current_database() AS db, current_user AS role, now() AS server_now;

-- =============================================================================
-- Section 1: Active match today totals (baseline for "should hero animate?")
-- =============================================================================
WITH params AS (
  SELECT '00000000-0000-0000-0000-000000000000'::uuid AS p_profile_id
),
my_matches AS (
  SELECT m.id, m.state, m.metric_type, m.duration_days, m.created_at
  FROM public.matches m
  JOIN public.match_participants mp ON mp.match_id = m.id
  JOIN params p ON mp.user_id = p.p_profile_id
  WHERE m.state = 'active'
  ORDER BY m.created_at DESC
  LIMIT 1
),
opp AS (
  SELECT mm.id AS match_id, mp.user_id AS opponent_id
  FROM my_matches mm
  JOIN public.match_participants mp ON mp.match_id = mm.id
  JOIN params p ON mp.user_id <> p.p_profile_id
  LIMIT 1
),
today_day AS (
  SELECT md.*
  FROM public.match_days md
  JOIN my_matches mm ON mm.id = md.match_id
  WHERE md.calendar_date = current_date
  ORDER BY md.day_number DESC
  LIMIT 1
)
SELECT
  mm.id AS match_id,
  mm.metric_type,
  o.opponent_id,
  coalesce(pr.display_name, 'Opponent') AS opponent_display_name,
  coalesce(mdp_me.finalized_value, mdp_me.metric_total, 0)::int AS my_today_total,
  coalesce(mdp_opp.finalized_value, mdp_opp.metric_total, 0)::int AS opponent_today_total,
  mdp_me.last_updated_at AS my_last_updated_at,
  mdp_opp.last_updated_at AS opponent_last_updated_at
FROM my_matches mm
LEFT JOIN today_day td ON td.match_id = mm.id
LEFT JOIN params p ON true
LEFT JOIN opp o ON o.match_id = mm.id
LEFT JOIN public.profiles pr ON pr.id = o.opponent_id
LEFT JOIN public.match_day_participants mdp_me
  ON mdp_me.match_day_id = td.id AND mdp_me.user_id = p.p_profile_id
LEFT JOIN public.match_day_participants mdp_opp
  ON mdp_opp.match_day_id = td.id AND mdp_opp.user_id = o.opponent_id;

-- =============================================================================
-- Section 2: Duplicate hk_patch clusters within 5s (startup duplication signal)
-- =============================================================================
WITH params AS (
  SELECT '00000000-0000-0000-0000-000000000000'::uuid AS p_profile_id
),
hk_logs AS (
  SELECT
    al.created_at,
    al.metadata ->> 'metric_type' AS metric_type,
    al.metadata ->> 'value' AS value,
    al.metadata ->> 'hk_patch_ms' AS hk_patch_ms
  FROM public.app_logs al
  JOIN params p ON al.user_id = p.p_profile_id
  WHERE al.category = 'home_perf'
    AND al.message = 'hk_patch'
    AND al.created_at > now() - interval '24 hours'
  ORDER BY al.created_at
),
clustered AS (
  SELECT
    created_at,
    metric_type,
    value,
    hk_patch_ms,
    count(*) OVER (
      PARTITION BY date_trunc('second', created_at)
    ) AS same_second_count,
    lag(created_at) OVER (ORDER BY created_at) AS prev_at
  FROM hk_logs
)
SELECT
  created_at,
  metric_type,
  value,
  hk_patch_ms,
  extract(epoch FROM (created_at - prev_at))::numeric(10, 3) AS seconds_since_prev,
  same_second_count
FROM clustered
WHERE prev_at IS NULL
   OR created_at - prev_at < interval '5 seconds'
ORDER BY created_at DESC
LIMIT 50;

-- =============================================================================
-- Section 3: Duplicate home_snapshot_saved clusters within 5s
-- =============================================================================
WITH params AS (
  SELECT '00000000-0000-0000-0000-000000000000'::uuid AS p_profile_id
),
snap_logs AS (
  SELECT al.created_at, al.metadata ->> 'summary' AS summary
  FROM public.app_logs al
  JOIN params p ON al.user_id = p.p_profile_id
  WHERE al.category = 'home_snapshot'
    AND al.message = 'home_snapshot_saved'
    AND al.created_at > now() - interval '24 hours'
  ORDER BY al.created_at
),
clustered AS (
  SELECT
    created_at,
    summary,
    lag(created_at) OVER (ORDER BY created_at) AS prev_at
  FROM snap_logs
)
SELECT
  created_at,
  summary,
  extract(epoch FROM (created_at - prev_at))::numeric(10, 3) AS seconds_since_prev
FROM clustered
WHERE prev_at IS NULL
   OR created_at - prev_at < interval '5 seconds'
ORDER BY created_at DESC
LIMIT 50;

-- =============================================================================
-- Section 4: Metric sync vs hero patch correlation (recent timeline)
-- =============================================================================
WITH params AS (
  SELECT '00000000-0000-0000-0000-000000000000'::uuid AS p_profile_id
)
SELECT
  al.created_at,
  al.category,
  al.message,
  al.metadata ->> 'trigger' AS trigger,
  al.metadata ->> 'metric_type' AS metric_type,
  al.metadata ->> 'value' AS value,
  al.metadata ->> 'steps_today' AS steps_today,
  al.metadata ->> 'active_calories_today' AS active_calories_today,
  al.metadata ->> 'reason' AS reason
FROM public.app_logs al
JOIN params p ON al.user_id = p.p_profile_id
WHERE al.created_at > now() - interval '2 hours'
  AND (
    (al.category = 'home_perf' AND al.message IN ('hk_patch', 'hk_patch_skipped', 'hero_intro_played', 'hero_intro_skipped'))
    OR (al.category = 'home_snapshot' AND al.message IN ('home_snapshot_loaded', 'home_snapshot_saved', 'home_return_no_reload'))
    OR (al.category = 'healthkit_read' AND al.message IN ('today steps read', 'today active calories read'))
    OR (al.category = 'healthkit_sync' AND al.message IN ('metric sync started', 'metric sync finished'))
  )
ORDER BY al.created_at DESC
LIMIT 100;

-- =============================================================================
-- Section 5: Backend sanity — no migration required for hero animation fix
-- =============================================================================
SELECT
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS identity_args
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND p.proname = 'record_metric_snapshot';

SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'metric_snapshots'
ORDER BY ordinal_position;
