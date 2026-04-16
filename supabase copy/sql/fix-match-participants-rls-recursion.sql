-- Fix infinite recursion in RLS policies on match_participants.
-- Policies that subquery match_participants from within match_participants policies
-- re-enter RLS indefinitely. This script adds a SECURITY DEFINER helper that reads
-- match_ids for the current user without RLS, then replaces affected policies.
--
-- Run in Supabase SQL Editor (Dashboard) after the base schema + policies from
-- FitUp/docs/supabase-setup-guide.md Step 4, or on any project that still has
-- the recursive policy definitions.
--
-- Optional: list existing policies before running:
--   SELECT policyname, tablename, cmd FROM pg_policies
--   WHERE tablename IN ('matches','match_participants','match_days','match_day_participants','metric_snapshots')
--   ORDER BY tablename, policyname;

-- ---------------------------------------------------------------------------
-- Helper: current user's match IDs (bypasses RLS on match_participants)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.current_user_match_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT mp.match_id
  FROM match_participants mp
  WHERE mp.user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid());
$$;

REVOKE ALL ON FUNCTION public.current_user_match_ids() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_match_ids() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_match_ids() TO service_role;

COMMENT ON FUNCTION public.current_user_match_ids() IS
  'Returns match_id values for the invoking user; SECURITY DEFINER avoids RLS recursion in policies.';

-- ---------------------------------------------------------------------------
-- Drop policies that subquery match_participants (or will be merged)
-- ---------------------------------------------------------------------------

DROP POLICY IF EXISTS "matches: participant read" ON public.matches;
DROP POLICY IF EXISTS "mp: own read" ON public.match_participants;
DROP POLICY IF EXISTS "mp: co-participant read" ON public.match_participants;
DROP POLICY IF EXISTS "mp: participant read" ON public.match_participants;
DROP POLICY IF EXISTS "md: participant read" ON public.match_days;
DROP POLICY IF EXISTS "mdp: participant read" ON public.match_day_participants;
DROP POLICY IF EXISTS "ms: participant read" ON public.metric_snapshots;

-- Note: "mp: own update" is unchanged and not dropped here.

-- ---------------------------------------------------------------------------
-- Recreate policies using current_user_match_ids()
-- ---------------------------------------------------------------------------

CREATE POLICY "matches: participant read"
  ON public.matches FOR SELECT
  USING (id IN (SELECT public.current_user_match_ids()));

-- Single SELECT policy: own row + opponent rows for shared matches
CREATE POLICY "mp: participant read"
  ON public.match_participants FOR SELECT
  USING (match_id IN (SELECT public.current_user_match_ids()));

CREATE POLICY "md: participant read"
  ON public.match_days FOR SELECT
  USING (match_id IN (SELECT public.current_user_match_ids()));

CREATE POLICY "mdp: participant read"
  ON public.match_day_participants FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.match_days md
      WHERE md.id = match_day_participants.match_day_id
        AND md.match_id IN (SELECT public.current_user_match_ids())
    )
  );

CREATE POLICY "ms: participant read"
  ON public.metric_snapshots FOR SELECT
  USING (match_id IN (SELECT public.current_user_match_ids()));
