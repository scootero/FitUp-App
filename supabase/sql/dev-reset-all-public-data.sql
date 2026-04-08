-- Dev / staging only: wipe all app data in public schema so you can re-run onboarding.
-- Run in Supabase SQL Editor with a role that can bypass RLS for maintenance (often service role).
--
-- Does NOT remove auth.users. After this, either:
--   - Delete test users in Dashboard → Authentication → Users, or
--   - Sign up again with different emails.
-- If you keep the same auth user and the app expects a profile row, sign-in may need a fresh profile insert (your client flow).
--
-- Order: `matches` must be included because it has no FK to `profiles`; truncating only `profiles`
-- would leave orphan match rows.

BEGIN;

TRUNCATE TABLE
  matches,
  profiles
CASCADE;

COMMIT;

-- Optional sanity check (all counts should be 0):
-- SELECT 'profiles' AS t, count(*) FROM profiles
-- UNION ALL SELECT 'matches', count(*) FROM matches
-- UNION ALL SELECT 'match_search_requests', count(*) FROM match_search_requests
-- UNION ALL SELECT 'direct_challenges', count(*) FROM direct_challenges;
