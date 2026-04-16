-- Slice 4d — Server-side direct challenge creation (bypasses client RLS on INSERT)
-- Run in Supabase SQL Editor after slice4c (optional if you rely only on this path).
--
-- Why: If `matches` INSERT still fails with RLS from the iOS client (e.g. auth context
-- differs from policies), this function runs as SECURITY DEFINER and performs all writes
-- in one transaction. The caller is identified only via auth.uid() → profiles.id.
--
-- App: MatchRepository.createDirectChallenge calls `rpc('create_direct_challenge', ...)`.

CREATE OR REPLACE FUNCTION public.create_direct_challenge(
  p_recipient_id uuid,
  p_metric_type text,
  p_duration_days int,
  p_start_mode text,
  p_match_timezone text,
  p_starts_at timestamptz
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_challenger uuid;
  v_match_id uuid;
  v_challenge_id uuid;
  v_now timestamptz := now();
  v_tz text;
BEGIN
  v_challenger := (
    SELECT id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1
  );

  IF v_challenger IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  IF p_recipient_id = v_challenger THEN
    RAISE EXCEPTION 'cannot challenge self';
  END IF;

  IF p_metric_type NOT IN ('steps', 'active_calories') THEN
    RAISE EXCEPTION 'invalid metric_type';
  END IF;

  IF p_duration_days NOT IN (1, 3, 5, 7) THEN
    RAISE EXCEPTION 'invalid duration_days';
  END IF;

  IF p_start_mode NOT IN ('today', 'tomorrow') THEN
    RAISE EXCEPTION 'invalid start_mode';
  END IF;

  v_tz := COALESCE(NULLIF(trim(p_match_timezone), ''), 'America/Chicago');

  INSERT INTO public.matches (
    match_type,
    metric_type,
    duration_days,
    start_mode,
    state,
    match_timezone,
    starts_at
  )
  VALUES (
    'direct_challenge',
    p_metric_type,
    p_duration_days,
    p_start_mode,
    'pending',
    v_tz,
    p_starts_at
  )
  RETURNING id INTO v_match_id;

  INSERT INTO public.match_participants (match_id, user_id, role, joined_via, accepted_at)
  VALUES
    (v_match_id, v_challenger, 'challenger', 'direct_challenge', v_now),
    (v_match_id, p_recipient_id, 'opponent', 'direct_challenge', NULL);

  INSERT INTO public.direct_challenges (challenger_id, recipient_id, match_id, status)
  VALUES (v_challenger, p_recipient_id, v_match_id, 'pending')
  RETURNING id INTO v_challenge_id;

  RETURN json_build_object(
    'match_id', v_match_id,
    'challenge_id', v_challenge_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_direct_challenge(uuid, text, int, text, text, timestamptz) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_direct_challenge(uuid, text, int, text, text, timestamptz) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_direct_challenge(uuid, text, int, text, text, timestamptz) TO service_role;

COMMENT ON FUNCTION public.create_direct_challenge(uuid, text, int, text, text, timestamptz) IS
  'Creates a direct challenge match + participants + direct_challenges row; challenger from JWT only.';
