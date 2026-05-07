-- Leaderboard audit (read-only)
-- Safe for Supabase SQL Editor: SELECT-only checks, no schema/data mutations.
-- Run sections top-to-bottom.

-- ============================================================================
-- Section 1: Table/column shape (core leaderboard + relationship tables)
-- ============================================================================
SELECT
  table_name,
  column_name,
  data_type,
  is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN (
    'leaderboard_entries',
    'user_public_daily_activity',
    'friendships',
    'matches',
    'match_participants',
    'profiles'
  )
ORDER BY table_name, ordinal_position;

-- ============================================================================
-- Section 2: Indexes/constraints that affect leaderboard reads
-- ============================================================================
SELECT
  schemaname,
  tablename,
  indexname,
  indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('leaderboard_entries', 'user_public_daily_activity', 'friendships')
ORDER BY tablename, indexname;

-- ============================================================================
-- Section 3: Leaderboard/friend/activity related functions in public schema
-- ============================================================================
SELECT
  n.nspname AS schema_name,
  p.proname AS function_name,
  pg_get_function_identity_arguments(p.oid) AS arguments,
  pg_get_function_result(p.oid) AS result_type
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'public'
  AND (
    p.proname ILIKE '%leader%'
    OR p.proname ILIKE '%friend%'
    OR p.proname ILIKE '%battle%'
    OR p.proname ILIKE '%head_to_head%'
    OR p.proname ILIKE '%activity%'
  )
ORDER BY p.proname;

-- ============================================================================
-- Section 4: Any relevant public views?
-- ============================================================================
SELECT
  table_schema,
  table_name
FROM information_schema.views
WHERE table_schema = 'public'
  AND (
    table_name ILIKE '%leader%'
    OR table_name ILIKE '%activity%'
    OR table_name ILIKE '%friend%'
  )
ORDER BY table_name;

-- ============================================================================
-- Section 5: Weekly shape in leaderboard_entries (what weeks have data?)
-- ============================================================================
SELECT
  week_start,
  COUNT(*) AS row_count,
  COUNT(*) FILTER (WHERE points > 0) AS positive_points_count,
  MIN(points) AS min_points,
  MAX(points) AS max_points,
  MAX(updated_at) AS last_updated_at
FROM public.leaderboard_entries
GROUP BY week_start
ORDER BY week_start DESC
LIMIT 12;

-- ============================================================================
-- Section 6: Current UTC Monday leaderboard sample (if rows exist)
-- ============================================================================
WITH current_week AS (
  SELECT
    (
      CURRENT_DATE
      - (((EXTRACT(DOW FROM CURRENT_DATE)::int + 6) % 7) * INTERVAL '1 day')
    )::date AS week_start
)
SELECT
  le.user_id,
  le.week_start,
  le.points,
  le.wins,
  le.losses,
  le.streak,
  le.rank,
  le.updated_at,
  p.display_name
FROM public.leaderboard_entries le
LEFT JOIN public.profiles p ON p.id = le.user_id
JOIN current_week cw ON cw.week_start = le.week_start
ORDER BY le.points DESC, le.wins DESC, le.rank ASC NULLS LAST, le.updated_at DESC
LIMIT 50;

-- ============================================================================
-- Section 7: user_public_daily_activity daily shape (how many days exist?)
-- ============================================================================
SELECT
  active_date,
  COUNT(*) AS row_count,
  COUNT(*) FILTER (WHERE steps > 0) AS positive_steps_count,
  MIN(steps) AS min_steps,
  MAX(steps) AS max_steps
FROM public.user_public_daily_activity
GROUP BY active_date
ORDER BY active_date DESC
LIMIT 14;

-- ============================================================================
-- Section 8: Current-week step totals from daily activity
-- ============================================================================
WITH current_week AS (
  SELECT
    (
      CURRENT_DATE
      - (((EXTRACT(DOW FROM CURRENT_DATE)::int + 6) % 7) * INTERVAL '1 day')
    )::date AS week_start
)
SELECT
  upda.user_id,
  SUM(COALESCE(upda.steps, 0)) AS weekly_steps,
  COUNT(*) AS daily_rows,
  MIN(upda.active_date) AS first_active_date,
  MAX(upda.active_date) AS last_active_date
FROM public.user_public_daily_activity upda
JOIN current_week cw
  ON upda.active_date >= cw.week_start
 AND upda.active_date < cw.week_start + INTERVAL '7 days'
GROUP BY upda.user_id
HAVING SUM(COALESCE(upda.steps, 0)) > 0
ORDER BY weekly_steps DESC
LIMIT 50;

-- ============================================================================
-- Section 9: Friend model snapshot
-- ============================================================================
SELECT
  status,
  COUNT(*) AS row_count
FROM public.friendships
GROUP BY status
ORDER BY status;

SELECT
  a_id,
  b_id,
  requested_by,
  status,
  created_at,
  accepted_at
FROM public.friendships
WHERE status = 'accepted'
ORDER BY accepted_at DESC NULLS LAST, created_at DESC
LIMIT 25;

-- ============================================================================
-- Section 10: "Played-with" feasibility from matches/match_participants
-- ============================================================================
SELECT
  m.state,
  COUNT(DISTINCT m.id) AS match_count,
  COUNT(*) AS participant_rows
FROM public.matches m
JOIN public.match_participants mp ON mp.match_id = m.id
GROUP BY m.state
ORDER BY m.state;

SELECT
  mp1.user_id AS user_id,
  mp2.user_id AS opponent_id,
  COUNT(DISTINCT mp1.match_id) AS shared_completed_matches
FROM public.match_participants mp1
JOIN public.match_participants mp2
  ON mp2.match_id = mp1.match_id
 AND mp2.user_id <> mp1.user_id
JOIN public.matches m
  ON m.id = mp1.match_id
 AND m.state = 'completed'
GROUP BY mp1.user_id, mp2.user_id
ORDER BY shared_completed_matches DESC
LIMIT 50;

-- ============================================================================
-- Section 11: RLS policies affecting leaderboard/friends/activity reads
-- ============================================================================
SELECT
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual,
  with_check
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('leaderboard_entries', 'user_public_daily_activity', 'friendships')
ORDER BY tablename, policyname;
