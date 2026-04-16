-- Head-to-head aggregate stats for two users (completed matches only).
-- Mirrors series resolution in supabase/functions/complete-match/index.ts:
--   computeSeriesScores + resolveSeriesWinner (higher day-win count wins the series; equal => tie).
--
-- App: HeadToHeadRepository calls rpc('head_to_head_stats', params: { p_opponent_id }).
-- Caller identity: profiles.id for auth.uid() must match the viewer; opponent is p_opponent_id.

CREATE OR REPLACE FUNCTION public.head_to_head_stats(p_opponent_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_viewer uuid;
  v_total int;
  v_vwins int;
  v_owins int;
  v_ties int;
BEGIN
  SELECT id
  INTO v_viewer
  FROM public.profiles
  WHERE auth_user_id = auth.uid()
  LIMIT 1;

  IF v_viewer IS NULL OR p_opponent_id IS NULL OR v_viewer = p_opponent_id THEN
    RETURN jsonb_build_object(
      'total_completed', 0,
      'viewer_wins', 0,
      'opponent_wins', 0,
      'series_ties', 0
    );
  END IF;

  WITH mutual_matches AS (
    SELECT DISTINCT m.id AS match_id
    FROM public.matches m
    INNER JOIN public.match_participants mp1
      ON mp1.match_id = m.id AND mp1.user_id = v_viewer
    INNER JOIN public.match_participants mp2
      ON mp2.match_id = m.id AND mp2.user_id = p_opponent_id
    WHERE m.state = 'completed'
  ),
  day_wins AS (
    SELECT
      md.match_id,
      md.winner_user_id
    FROM public.match_days md
    INNER JOIN mutual_matches mm ON mm.match_id = md.match_id
    WHERE md.status = 'finalized'
      AND md.is_void = false
      AND md.winner_user_id IS NOT NULL
  ),
  per_match AS (
    SELECT
      mm.match_id,
      COALESCE(
        SUM(CASE WHEN dw.winner_user_id = v_viewer THEN 1 ELSE 0 END),
        0
      )::int AS viewer_day_wins,
      COALESCE(
        SUM(CASE WHEN dw.winner_user_id = p_opponent_id THEN 1 ELSE 0 END),
        0
      )::int AS opponent_day_wins
    FROM mutual_matches mm
    LEFT JOIN day_wins dw ON dw.match_id = mm.match_id
    GROUP BY mm.match_id
  ),
  outcomes AS (
    SELECT
      CASE
        WHEN viewer_day_wins > opponent_day_wins THEN 1
        ELSE 0
      END AS win_viewer,
      CASE
        WHEN opponent_day_wins > viewer_day_wins THEN 1
        ELSE 0
      END AS win_opponent,
      CASE
        WHEN viewer_day_wins = opponent_day_wins THEN 1
        ELSE 0
      END AS tie_series
    FROM per_match
  )
  SELECT
    COALESCE(COUNT(*)::int, 0),
    COALESCE(SUM(win_viewer)::int, 0),
    COALESCE(SUM(win_opponent)::int, 0),
    COALESCE(SUM(tie_series)::int, 0)
  INTO v_total, v_vwins, v_owins, v_ties
  FROM outcomes;

  RETURN jsonb_build_object(
    'total_completed', COALESCE(v_total, 0),
    'viewer_wins', COALESCE(v_vwins, 0),
    'opponent_wins', COALESCE(v_owins, 0),
    'series_ties', COALESCE(v_ties, 0)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.head_to_head_stats(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.head_to_head_stats(uuid) TO service_role;
