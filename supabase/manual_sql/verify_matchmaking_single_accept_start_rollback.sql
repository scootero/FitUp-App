-- Read-only verification queries for matchmaking_single_accept_start_rollback.sql
-- These do not modify data.

-- 1) Inspect function text and confirm both participant rows use accepted_at NULL.
SELECT pg_get_functiondef('public.matchmaking_pair_atomic(uuid)'::regprocedure);

-- 2) Recent pending public matches + participant acceptance state.
SELECT
  m.id AS match_id,
  m.created_at,
  m.state,
  m.match_type,
  mp.user_id,
  mp.role,
  mp.joined_via,
  mp.accepted_at
FROM public.matches m
JOIN public.match_participants mp
  ON mp.match_id = m.id
WHERE m.match_type = 'public_matchmaking'
  AND m.state IN ('pending', 'active')
ORDER BY m.created_at DESC
LIMIT 100;

-- Expected after rollback for new pending pairs:
-- - challenger row: accepted_at IS NULL
-- - opponent row:   accepted_at IS NULL
