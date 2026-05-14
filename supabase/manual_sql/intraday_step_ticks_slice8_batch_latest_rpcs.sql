-- Intraday step ticks — Slice 8: batch “latest tick per active opponent” for Home
--
-- Follow: FitUp/docs/sql-cmd-instructions.md
-- Plan: FitUp/docs/intraday-step-ticks-implementation-slices.md (Slice 8)
--
-- Prerequisites: Slice 1 table + Slice 2 grants already applied.
--
-- HUMAN: RUN after `intraday_step_ticks_slice2_rpcs.sql` (or any time after Slice 2).
--
-- RPC: one round-trip for all opponents in **active, fully accepted** matches with the viewer,
--       latest `user_intraday_step_ticks` row per opponent for a given **calendar_date**
--       (caller passes viewer-local `yyyy-MM-dd` as in Home; same convention as other tick RPCs).

CREATE OR REPLACE FUNCTION public.fetch_latest_opponent_intraday_ticks_for_active_matches(
  p_calendar_date date
) RETURNS TABLE (
  opponent_profile_id uuid,
  cumulative_steps integer,
  recorded_at timestamp with time zone
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_me uuid;
BEGIN
  SELECT p.id
  INTO v_me
  FROM public.profiles p
  WHERE p.auth_user_id = auth.uid()
  LIMIT 1;

  IF v_me IS NULL THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT DISTINCT ON (t.user_id)
    t.user_id AS opponent_profile_id,
    t.cumulative_steps,
    t.recorded_at
  FROM public.user_intraday_step_ticks t
  WHERE t.calendar_date = p_calendar_date
    AND t.user_id IN (
      SELECT mp_opp.user_id
      FROM public.match_participants mp_self
      JOIN public.matches m
        ON m.id = mp_self.match_id
       AND m.state = 'active'
      JOIN public.match_participants mp_opp
        ON mp_opp.match_id = m.id
       AND mp_opp.user_id <> v_me
      WHERE mp_self.user_id = v_me
        AND mp_self.accepted_at IS NOT NULL
        AND mp_opp.accepted_at IS NOT NULL
    )
  ORDER BY t.user_id, t.recorded_at DESC, t.id DESC;
END;
$function$;

COMMENT ON FUNCTION public.fetch_latest_opponent_intraday_ticks_for_active_matches(date) IS
  'Latest intraday step tick per active-match opponent for one calendar_date (viewer passes local date).';

GRANT EXECUTE ON FUNCTION public.fetch_latest_opponent_intraday_ticks_for_active_matches(date) TO authenticated;
