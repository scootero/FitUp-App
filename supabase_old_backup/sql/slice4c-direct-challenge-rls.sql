-- Slice 4c — RLS INSERT policies for client-side direct challenges
-- Run in Supabase SQL Editor (Dashboard) after Step 4 policies from
-- FitUp/docs/supabase-setup-guide.md (profiles, matches SELECT, match_participants, etc.).
--
-- Why: MatchRepository.createDirectChallenge inserts `matches` and `match_participants`
-- from the iOS client. Without INSERT policies, Postgres returns:
--   "new row violates row-level security policy for table \"matches\""
--
-- Participant rows are inserted in TWO steps (challenger row, then opponent row) so the
-- opponent policy can require an existing challenger row for the same match_id.
--
-- Public matchmaking continues to use SECURITY DEFINER RPC + service role (no client INSERT).

-- ---------------------------------------------------------------------------
-- matches: allow creating a pending direct_challenge row
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "matches: insert direct challenge" ON public.matches;

CREATE POLICY "matches: insert direct challenge"
  ON public.matches FOR INSERT
  WITH CHECK (
    match_type = 'direct_challenge'
    AND state = 'pending'
    AND auth.uid() IS NOT NULL
  );

-- ---------------------------------------------------------------------------
-- match_participants: challenger row first (same request as match insert from app)
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "mp: insert challenger direct challenge" ON public.match_participants;

CREATE POLICY "mp: insert challenger direct challenge"
  ON public.match_participants FOR INSERT
  WITH CHECK (
    role = 'challenger'
    AND joined_via = 'direct_challenge'
    AND user_id = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid())
    AND EXISTS (
      SELECT 1
      FROM public.matches m
      WHERE m.id = match_participants.match_id
        AND m.match_type = 'direct_challenge'
        AND m.state = 'pending'
    )
  );

-- ---------------------------------------------------------------------------
-- match_participants: opponent row (requires challenger row already inserted)
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "mp: insert opponent direct challenge" ON public.match_participants;

CREATE POLICY "mp: insert opponent direct challenge"
  ON public.match_participants FOR INSERT
  WITH CHECK (
    role = 'opponent'
    AND joined_via = 'direct_challenge'
    AND accepted_at IS NULL
    AND EXISTS (
      SELECT 1
      FROM public.matches m
      WHERE m.id = match_participants.match_id
        AND m.match_type = 'direct_challenge'
        AND m.state = 'pending'
    )
    AND EXISTS (
      SELECT 1
      FROM public.match_participants mp
      WHERE mp.match_id = match_participants.match_id
        AND mp.user_id = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid())
        AND mp.role = 'challenger'
        AND mp.joined_via = 'direct_challenge'
    )
  );
