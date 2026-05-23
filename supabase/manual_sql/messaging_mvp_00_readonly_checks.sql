-- =============================================================================
-- messaging_mvp_00_readonly_checks.sql  (READ-ONLY)
-- =============================================================================
-- Run in Supabase SQL Editor before debugging Messages tap failures.
-- Forbidden: INSERT/UPDATE/DELETE/DDL.
--
-- Optional: set your profile + peer ids in section 6 (from app inbox row).
-- =============================================================================

-- 0) Sanity
SELECT current_database() AS db, current_user AS role, now() AS server_now;

-- 1) Tables exist
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('message_threads', 'messages', 'friendships', 'profiles')
ORDER BY table_name;

-- 2) Trigger + touch function
SELECT
  EXISTS (
    SELECT 1 FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname = 'fn_messages_touch_thread_last'
  ) AS fn_touch_last_exists,
  EXISTS (
    SELECT 1 FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relname = 'messages' AND t.tgname = 'tr_messages_touch_thread_last'
  ) AS trigger_touch_last_exists;

-- 3) RLS enabled + policies
SELECT c.relname AS table_name, c.relrowsecurity AS rls_enabled
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname IN ('message_threads', 'messages')
ORDER BY c.relname;

SELECT schemaname, tablename, policyname, cmd, roles
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('message_threads', 'messages')
ORDER BY tablename, policyname;

-- 4) Grants for authenticated
SELECT
  table_name,
  grantee,
  string_agg(privilege_type, ', ' ORDER BY privilege_type) AS privileges
FROM information_schema.table_privileges
WHERE table_schema = 'public'
  AND table_name IN ('message_threads', 'messages')
  AND grantee IN ('authenticated', 'anon', 'service_role')
GROUP BY table_name, grantee
ORDER BY table_name, grantee;

-- 5) Volume
SELECT
  (SELECT count(*) FROM public.message_threads) AS thread_count,
  (SELECT count(*) FROM public.messages) AS message_count;

-- 6) Session pair (REPLACE placeholders before running)
-- :my_profile_id  = your profiles.id from the app
-- :peer_profile_id = peer from inbox row (message_threads user_low/user_high other side)
/*
WITH params AS (
  SELECT
    '00000000-0000-0000-0000-000000000001'::uuid AS my_profile_id,
    '00000000-0000-0000-0000-000000000002'::uuid AS peer_profile_id
)
SELECT p.my_profile_id, pr.auth_user_id IS NOT NULL AS my_has_auth_user
FROM params p
JOIN public.profiles pr ON pr.id = p.my_profile_id;

WITH params AS (
  SELECT
    '00000000-0000-0000-0000-000000000001'::uuid AS my_profile_id,
    '00000000-0000-0000-0000-000000000002'::uuid AS peer_profile_id
),
pair AS (
  SELECT
    LEAST(my_profile_id, peer_profile_id) AS user_low,
    GREATEST(my_profile_id, peer_profile_id) AS user_high
  FROM params
)
SELECT f.a_id, f.b_id, f.status, f.requested_by
FROM pair p
JOIN public.friendships f ON f.a_id = p.user_low AND f.b_id = p.user_high;

WITH params AS (
  SELECT
    '00000000-0000-0000-0000-000000000001'::uuid AS my_profile_id,
    '00000000-0000-0000-0000-000000000002'::uuid AS peer_profile_id
),
pair AS (
  SELECT
    LEAST(my_profile_id, peer_profile_id) AS user_low,
    GREATEST(my_profile_id, peer_profile_id) AS user_high
  FROM params
)
SELECT t.id AS thread_id, t.user_low, t.user_high, t.last_message_at
FROM pair p
JOIN public.message_threads t ON t.user_low = p.user_low AND t.user_high = p.user_high;

WITH params AS (
  SELECT
    '00000000-0000-0000-0000-000000000001'::uuid AS my_profile_id,
    '00000000-0000-0000-0000-000000000002'::uuid AS peer_profile_id
),
pair AS (
  SELECT
    LEAST(my_profile_id, peer_profile_id) AS user_low,
    GREATEST(my_profile_id, peer_profile_id) AS user_high
  FROM params
),
thread AS (
  SELECT t.id
  FROM pair p
  JOIN public.message_threads t ON t.user_low = p.user_low AND t.user_high = p.user_high
)
SELECT m.id, m.thread_id, m.sender_id, left(m.body, 40) AS body_preview, m.created_at
FROM thread th
JOIN public.messages m ON m.thread_id = th.id
ORDER BY m.created_at DESC
LIMIT 10;
*/

-- 6b) Recent threads (no placeholders) — spot-check data shape
SELECT
  t.id AS thread_id,
  t.user_low,
  t.user_high,
  t.last_message_at,
  f.status AS friendship_status
FROM public.message_threads t
LEFT JOIN public.friendships f
  ON f.a_id = t.user_low AND f.b_id = t.user_high
ORDER BY t.last_message_at DESC NULLS LAST
LIMIT 15;

-- 7) Orphan threads (no accepted friendship — insert blocked, read may still work)
SELECT
  t.id AS thread_id,
  t.user_low,
  t.user_high,
  coalesce(f.status, '(no row)') AS friendship_status
FROM public.message_threads t
LEFT JOIN public.friendships f
  ON f.a_id = t.user_low AND f.b_id = t.user_high AND f.status = 'accepted'
WHERE f.id IS NULL
LIMIT 20;

-- 8) Sample message rows (decode sanity: created_at, body, ids)
SELECT id, thread_id, sender_id, left(body, 30) AS body_preview, created_at
FROM public.messages
ORDER BY created_at DESC
LIMIT 10;
