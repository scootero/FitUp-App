-- =============================================================================
-- FitUp — TestFlight data-only reset (manual SQL Editor)
-- =============================================================================
-- Target project audited: FitUp-dev (ref uushejbizmlxzxonkuki), 2026-06-06
-- Audit method: Supabase MCP (list_tables + execute_sql). No data was changed.
--
-- GOAL
--   Wipe user/test *data* for a fresh external TestFlight start.
--   Preserve schema, tables, indexes, enums, functions/RPCs, RLS, triggers,
--   cron jobs, Edge Functions, Vault/secrets, migrations, storage config.
--
-- DOES NOT
--   DROP tables/schemas/functions, alter RLS, touch cron/Vault/Edge Functions,
--   modify migrations, or use TRUNCATE CASCADE.
--
-- RUN ORDER (manual, in SQL Editor)
--   1. Section 1 — dry-run counts
--   2. Section 2 — optional auth snapshot export
--   3. Section 3 — public data reset (BEGIN…COMMIT)
--   4. Section 4 — auth users cleanup (Dashboard preferred; SQL optional)
--   5. Section 5 — post-reset verification
--
-- =============================================================================
-- LIVE AUDIT SUMMARY (FitUp-dev, read-only, 2026-06-06)
-- =============================================================================
--
-- public schema: exactly 22 base tables (all are user/test data — none skipped)
--   all_time_bests, analytics_events, app_logs, direct_challenges, friendships,
--   leaderboard_entries, match_day_participants, match_days, match_participants,
--   match_search_requests, matches, message_threads, messages, metric_snapshots,
--   notification_events, profiles, tester_feedback, user_battle_step_totals,
--   user_daily_step_totals, user_health_baselines, user_intraday_step_ticks,
--   user_public_daily_activity
--
-- No extra public user-data tables beyond the list above.
-- private schema: no base tables (functions only — not touched).
-- storage: 0 buckets, 0 objects (avatar_url on profiles is text; no file cleanup).
--
-- profiles.auth_user_id → auth.users: NO database FK (logical link only).
--   ⇒ Delete public.profiles first, then auth.users separately for full reset.
--
-- matches: NO FK to profiles (orphan risk if you only delete profiles).
--   ⇒ Must delete match graph explicitly (Section 3).
--
-- FK delete rules (verified on FitUp-dev):
--   CASCADE from profiles: most child tables (friendships, metrics, etc.)
--   SET NULL: app_logs.user_id, analytics_events.user_id,
--             direct_challenges.match_id, match_days.winner_user_id,
--             match_search_requests.matched_match_id
--   CASCADE from matches: match_days, match_participants, metric_snapshots
--   CASCADE from match_days: match_day_participants
--   CASCADE from message_threads: messages
--
-- Row counts at audit time (FitUp-dev):
--   profiles 8 | auth.users 8 | matches 41 | match_search_requests 42
--   notification_events 3658 | app_logs 18274 | analytics_events 8244
--   metric_snapshots 1513 | user_intraday_step_ticks 324 | user_daily_step_totals 136
--   user_battle_step_totals 90 | message_threads 2 | messages 5 | friendships 5
--
-- Active cron (preserved, not modified):
--   day-cutoff-check, matchmaking-retry-stale, reconcile-stuck-match-completions,
--   send-daily-recap, send-evening-checkins, send-morning-checkins, send-pending-reminders
--
-- WHY DELETE (not TRUNCATE CASCADE):
--   Mixed ON DELETE CASCADE / SET NULL graph; explicit order is auditable;
--   TRUNCATE CASCADE can affect unexpected dependents and skips row-level semantics.
--
-- DO NOT RUN: supabase/manual_sql/analytics_events_reset.sql (DROP/recreate table).
-- =============================================================================


-- =============================================================================
-- SECTION 1 — DRY-RUN COUNTS (read-only)
-- =============================================================================
-- Run this first. Check SQL Editor "Messages" / notices panel for output.

DO $$
DECLARE
  r record;
  v_count bigint;
BEGIN
  RAISE NOTICE '=== FitUp TestFlight reset — DRY RUN ===';
  RAISE NOTICE 'Project: FitUp-dev (uushejbizmlxzxonkuki)';
  RAISE NOTICE '';

  FOR r IN
    SELECT *
    FROM (VALUES
      ( 10, 'messages'),
      ( 20, 'message_threads'),
      ( 30, 'match_day_participants'),
      ( 40, 'match_days'),
      ( 50, 'metric_snapshots'),
      ( 60, 'match_participants'),
      ( 70, 'matches'),
      ( 80, 'direct_challenges'),
      ( 90, 'match_search_requests'),
      (100, 'friendships'),
      (110, 'notification_events'),
      (120, 'leaderboard_entries'),
      (130, 'all_time_bests'),
      (140, 'user_health_baselines'),
      (150, 'user_public_daily_activity'),
      (160, 'user_battle_step_totals'),
      (170, 'user_daily_step_totals'),
      (180, 'user_intraday_step_ticks'),
      (190, 'tester_feedback'),
      (200, 'analytics_events'),
      (210, 'app_logs'),
      (220, 'profiles')
    ) AS t(sort_order, table_name)
    ORDER BY sort_order
  LOOP
    IF to_regclass('public.' || r.table_name) IS NULL THEN
      RAISE NOTICE '% | % | MISSING (skip in Section 3 if absent on your project)',
        lpad(r.sort_order::text, 3), r.table_name;
    ELSE
      EXECUTE format('SELECT count(*) FROM public.%I', r.table_name) INTO v_count;
      RAISE NOTICE '% | % | % rows',
        lpad(r.sort_order::text, 3), r.table_name, v_count;
    END IF;
  END LOOP;

  RAISE NOTICE '';
  RAISE NOTICE '--- auth (not cleared by Section 3) ---';
  RAISE NOTICE 'auth.users     | % rows', (SELECT count(*) FROM auth.users);
  RAISE NOTICE 'auth.sessions  | % rows', (SELECT count(*) FROM auth.sessions);
  RAISE NOTICE 'auth.identities| % rows', (SELECT count(*) FROM auth.identities);
END $$;


-- =============================================================================
-- SECTION 2 — OPTIONAL: auth snapshot before reset
-- =============================================================================
-- Save this result (CSV export) if you want a record of who existed pre-reset.

-- SELECT
--   u.id AS auth_user_id,
--   u.email,
--   u.created_at,
--   u.last_sign_in_at,
--   p.id AS profile_id,
--   p.display_name
-- FROM auth.users u
-- LEFT JOIN public.profiles p ON p.auth_user_id = u.id
-- ORDER BY u.created_at;


-- =============================================================================
-- SECTION 3 — PUBLIC DATA RESET (destructive — review Section 1 first)
-- =============================================================================
-- Uncomment the entire block below when ready. Single transaction.

/*
BEGIN;

-- Stash auth_user_id values for Section 4 (temp table dies on COMMIT)
CREATE TEMP TABLE _fitup_reset_auth_user_ids (
  auth_user_id uuid PRIMARY KEY
) ON COMMIT DROP;

INSERT INTO _fitup_reset_auth_user_ids (auth_user_id)
SELECT DISTINCT p.auth_user_id
FROM public.profiles p
WHERE p.auth_user_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- ---------------------------------------------------------------------------
-- 3a) Messaging (child → parent)
-- ---------------------------------------------------------------------------
DELETE FROM public.messages;
DELETE FROM public.message_threads;

-- ---------------------------------------------------------------------------
-- 3b) Match graph (deepest → root; matches has no FK to profiles)
-- ---------------------------------------------------------------------------
DELETE FROM public.match_day_participants;
DELETE FROM public.match_days;
DELETE FROM public.metric_snapshots;
DELETE FROM public.match_participants;
DELETE FROM public.matches;

-- ---------------------------------------------------------------------------
-- 3c) Match-adjacent
-- ---------------------------------------------------------------------------
DELETE FROM public.direct_challenges;
DELETE FROM public.match_search_requests;

-- ---------------------------------------------------------------------------
-- 3d) Social, notifications, aggregates
-- ---------------------------------------------------------------------------
DELETE FROM public.friendships;
DELETE FROM public.notification_events;
DELETE FROM public.leaderboard_entries;
DELETE FROM public.all_time_bests;
DELETE FROM public.user_health_baselines;
DELETE FROM public.user_public_daily_activity;

-- ---------------------------------------------------------------------------
-- 3e) Step / battle metric tables (all present on FitUp-dev as of 2026-06-06)
-- ---------------------------------------------------------------------------
DELETE FROM public.user_battle_step_totals;
DELETE FROM public.user_daily_step_totals;
DELETE FROM public.user_intraday_step_ticks;

-- ---------------------------------------------------------------------------
-- 3f) Diagnostics / feedback
-- ---------------------------------------------------------------------------
DELETE FROM public.tester_feedback;
DELETE FROM public.analytics_events;
DELETE FROM public.app_logs;

-- ---------------------------------------------------------------------------
-- 3g) Profiles last
-- ---------------------------------------------------------------------------
DELETE FROM public.profiles;

COMMIT;
*/


-- =============================================================================
-- SECTION 4 — AUTH USERS CLEANUP (separate step, after Section 3)
-- =============================================================================
--
-- Section 3 does NOT remove auth.users (no FK from profiles → auth.users).
--
-- RECOMMENDED: Supabase Dashboard → Authentication → Users → delete test users.
--   Safer audit trail; Auth service handles identity/session cascades cleanly.
--
-- SQL Editor CAN delete auth.users (postgres role). Related auth rows cascade
-- inside auth schema (identities, sessions, refresh_tokens, etc.).
--
-- Existing JWTs may remain valid until expiry after user deletion — testers
-- should sign out / reinstall for a clean session.
--
-- ---------------------------------------------------------------------------
-- Option A — Preview (read-only)
-- ---------------------------------------------------------------------------
-- SELECT id, email, created_at, last_sign_in_at FROM auth.users ORDER BY created_at;

-- ---------------------------------------------------------------------------
-- Option B — Delete ALL auth users (TestFlight-only project)
-- ---------------------------------------------------------------------------
-- Only uncomment when Section 3 is complete and you intend a full auth wipe.

/*
BEGIN;
DELETE FROM auth.users;
COMMIT;
*/

-- ---------------------------------------------------------------------------
-- Option C — Targeted delete by email domain (safer if mixed accounts)
-- ---------------------------------------------------------------------------
/*
BEGIN;
DELETE FROM auth.users u
WHERE u.email ILIKE '%@example.com';  -- ← replace with your tester domain/pattern
COMMIT;
*/


-- =============================================================================
-- SECTION 5 — POST-RESET VERIFICATION (read-only)
-- =============================================================================

DO $$
DECLARE
  r record;
  v_count bigint;
  v_bad int := 0;
  v_auth_users bigint;
BEGIN
  RAISE NOTICE '=== FitUp TestFlight reset — POST-RESET VERIFICATION ===';

  FOR r IN
    SELECT table_name
    FROM (VALUES
      ('messages'),
      ('message_threads'),
      ('match_day_participants'),
      ('match_days'),
      ('metric_snapshots'),
      ('match_participants'),
      ('matches'),
      ('direct_challenges'),
      ('match_search_requests'),
      ('friendships'),
      ('notification_events'),
      ('leaderboard_entries'),
      ('all_time_bests'),
      ('user_health_baselines'),
      ('user_public_daily_activity'),
      ('user_battle_step_totals'),
      ('user_daily_step_totals'),
      ('user_intraday_step_ticks'),
      ('tester_feedback'),
      ('analytics_events'),
      ('app_logs'),
      ('profiles')
    ) AS t(table_name)
    ORDER BY table_name
  LOOP
    IF to_regclass('public.' || r.table_name) IS NOT NULL THEN
      EXECUTE format('SELECT count(*) FROM public.%I', r.table_name) INTO v_count;
      IF v_count > 0 THEN
        v_bad := v_bad + 1;
        RAISE WARNING 'STILL HAS DATA: public.% = % rows', r.table_name, v_count;
      ELSE
        RAISE NOTICE 'OK (0): public.%', r.table_name;
      END IF;
    END IF;
  END LOOP;

  SELECT count(*) INTO v_auth_users FROM auth.users;
  RAISE NOTICE '';
  RAISE NOTICE 'auth.users = %', v_auth_users;
  IF v_auth_users > 0 THEN
    RAISE WARNING 'auth.users still has rows — complete Section 4 if full reset intended';
  END IF;

  IF v_bad = 0 THEN
    RAISE NOTICE '';
    RAISE NOTICE 'PASS: all checked public tables are empty';
  ELSE
    RAISE WARNING 'FAIL: % public table(s) still contain data', v_bad;
  END IF;
END $$;

-- Orphan checks (should return 0 rows after full reset including Section 4)
-- SELECT p.id, p.auth_user_id, p.display_name
-- FROM public.profiles p
-- LEFT JOIN auth.users u ON u.id = p.auth_user_id
-- WHERE u.id IS NULL;
--
-- SELECT u.id, u.email
-- FROM auth.users u
-- LEFT JOIN public.profiles p ON p.auth_user_id = u.id
-- WHERE p.id IS NULL;


-- =============================================================================
-- RISKS / NOTES
-- =============================================================================
--
-- | Table / area              | After wipe |
-- |---------------------------|------------|
-- | profiles                  | All users re-onboard; client inserts profile on signup |
-- | matches + match_*         | All battle history gone; RPCs return empty |
-- | match_search_requests     | Matchmaking queue cleared (good for stale test rows) |
-- | user_health_baselines     | Balanced battle baselines reset |
-- | user_*_step_*             | Stats/leaderboard/intraday charts empty until HK sync |
-- | notification_events       | Push audit history gone; cron/APNs infra unchanged |
-- | analytics_events/app_logs | Diagnostics gone (intended) |
-- | cron jobs                 | Still active; mostly no-op with zero users |
-- | storage                   | Empty on FitUp-dev; no action needed |
--
-- Confirm you are on the intended Supabase project before uncommenting Section 3.
-- =============================================================================
