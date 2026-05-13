-- Balanced Battle — Slice 1 (manual apply in Supabase SQL Editor)
--
-- Run this against your project when you are ready to deploy Slice 1 server-side changes.
-- It updates:
--   1) public.create_direct_challenge — Balanced steps matches store difficulty = NULL (no Easy/Fair/Hard).
--   2) public.matchmaking_pair_atomic — Balanced queue: oldest compatible search first; ignore difficulty
--      and step-average bands. Raw queue: unchanged widening + difficulty equality vs migration
--      20260510120000_balanced_battle_phase1.sql (attempt 1–3, raw bands only in attempt 1).
--
-- Verify after apply (examples):
--   SELECT pg_get_functiondef('public.matchmaking_pair_atomic(uuid)'::regprocedure);
--   SELECT pg_get_functiondef('public.create_direct_challenge'::regprocedure);
--
-- Manual test scenario: two accounts both searching steps, same duration/start_mode, scoring_mode = balanced,
-- different creator_id — should pair even with very different creator_avg_30d_steps / difficulty NULL vs legacy.

-- ---------------------------------------------------------------------------
-- create_direct_challenge: Balanced has no difficulty
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.create_direct_challenge(
  p_recipient_id uuid,
  p_metric_type text,
  p_duration_days integer,
  p_start_mode text,
  p_match_timezone text,
  p_starts_at timestamp with time zone,
  p_scoring_mode text DEFAULT NULL,
  p_difficulty text DEFAULT NULL
)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_challenger uuid;
  v_match_id uuid;
  v_challenge_id uuid;
  v_now timestamptz := now();
  v_tz text;
  v_score text;
  v_diff text;
  v_bt text;
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

  v_tz := COALESCE(NULLIF(trim(p_match_timezone), ''), 'America/New_York');

  IF p_metric_type = 'steps' THEN
    v_score := COALESCE(NULLIF(trim(p_scoring_mode), ''), 'balanced');
    IF v_score NOT IN ('balanced', 'raw') THEN
      RAISE EXCEPTION 'invalid scoring_mode';
    END IF;
    IF v_score = 'balanced' THEN
      v_diff := NULL;
    ELSE
      v_diff := COALESCE(NULLIF(trim(p_difficulty), ''), 'fair');
      IF v_diff NOT IN ('easy', 'fair', 'hard') THEN
        RAISE EXCEPTION 'invalid difficulty';
      END IF;
    END IF;
    v_bt := CASE WHEN v_score = 'balanced' THEN '30d' ELSE NULL END;
  ELSE
    v_score := NULL;
    v_diff := NULL;
    v_bt := NULL;
  END IF;

  INSERT INTO public.matches (
    match_type,
    metric_type,
    duration_days,
    start_mode,
    state,
    match_timezone,
    starts_at,
    scoring_mode,
    baseline_timeframe,
    difficulty
  )
  VALUES (
    'direct_challenge',
    p_metric_type,
    p_duration_days,
    p_start_mode,
    'pending',
    v_tz,
    p_starts_at,
    v_score,
    v_bt,
    v_diff
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
$function$;

-- ---------------------------------------------------------------------------
-- matchmaking_pair_atomic: Balanced = oldest compatible; Raw = unchanged logic
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.matchmaking_pair_atomic(p_request_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_incoming match_search_requests%ROWTYPE;
  v_partner match_search_requests%ROWTYPE;
  v_match_id uuid;
  v_tz text;
  v_challenger uuid;
  v_opponent uuid;
  v_rowcount int;
  v_now timestamptz := now();
  v_my_avg numeric;
  v_attempt int;
  v_eff_diff text;
  v_found boolean := false;
BEGIN
  SELECT *
  INTO v_incoming
  FROM match_search_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  IF v_incoming.status <> 'searching' OR v_incoming.matched_match_id IS NOT NULL THEN
    RETURN NULL;
  END IF;

  IF v_incoming.scoring_mode = 'balanced' THEN
    SELECT msr.*
    INTO v_partner
    FROM match_search_requests msr
    WHERE msr.status = 'searching'
      AND msr.id <> v_incoming.id
      AND msr.creator_id <> v_incoming.creator_id
      AND msr.metric_type = v_incoming.metric_type
      AND msr.duration_days = v_incoming.duration_days
      AND msr.start_mode = v_incoming.start_mode
      AND msr.scoring_mode = 'balanced'
    ORDER BY msr.created_at ASC, msr.id ASC
    FOR UPDATE SKIP LOCKED
    LIMIT 1;

    v_found := FOUND;
  ELSE
    v_my_avg := COALESCE(v_incoming.creator_avg_30d_steps, v_incoming.creator_baseline);
    v_eff_diff := COALESCE(v_incoming.difficulty, 'fair');

    FOR v_attempt IN 1..3 LOOP
      SELECT msr.*
      INTO v_partner
      FROM match_search_requests msr
      WHERE msr.status = 'searching'
        AND msr.id <> v_incoming.id
        AND msr.creator_id <> v_incoming.creator_id
        AND msr.metric_type = v_incoming.metric_type
        AND msr.duration_days = v_incoming.duration_days
        AND msr.start_mode = v_incoming.start_mode
        AND msr.scoring_mode IS NOT DISTINCT FROM v_incoming.scoring_mode
        AND msr.difficulty IS NOT DISTINCT FROM v_incoming.difficulty
        AND (
          v_incoming.metric_type <> 'steps'
          OR v_attempt >= 3
          OR v_my_avg IS NULL
          OR v_my_avg <= 0
          OR (
            v_attempt = 2
            AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) >= v_my_avg * 0.01
            AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) <= v_my_avg * 100
          )
          OR (
            v_attempt = 1
            AND (
              (v_eff_diff = 'easy'
                AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) BETWEEN v_my_avg * 0.70 AND v_my_avg * 1.00)
              OR (v_eff_diff = 'fair'
                AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) BETWEEN v_my_avg * 0.85 AND v_my_avg * 1.15)
              OR (v_eff_diff = 'hard'
                AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) BETWEEN v_my_avg * 1.05 AND v_my_avg * 1.40)
            )
          )
        )
      ORDER BY
        CASE
          WHEN v_incoming.metric_type = 'steps' THEN abs(COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) - v_my_avg)
          ELSE abs(msr.creator_baseline - v_incoming.creator_baseline)
        END ASC NULLS LAST,
        msr.created_at ASC,
        msr.id ASC
      FOR UPDATE SKIP LOCKED
      LIMIT 1;

      IF FOUND THEN
        v_found := true;
        EXIT;
      END IF;
    END LOOP;
  END IF;

  IF NOT v_found THEN
    RETURN NULL;
  END IF;

  IF v_incoming.created_at < v_partner.created_at
    OR (
      v_incoming.created_at = v_partner.created_at
      AND v_incoming.id < v_partner.id
    )
  THEN
    v_challenger := v_incoming.creator_id;
    v_opponent := v_partner.creator_id;
  ELSE
    v_challenger := v_partner.creator_id;
    v_opponent := v_incoming.creator_id;
  END IF;

  SELECT COALESCE(p.timezone, 'America/New_York')
  INTO v_tz
  FROM profiles p
  WHERE p.id = v_challenger
  LIMIT 1;

  IF v_tz IS NULL OR length(trim(v_tz)) = 0 THEN
    v_tz := 'America/New_York';
  END IF;

  INSERT INTO matches (
    match_type,
    metric_type,
    duration_days,
    start_mode,
    state,
    match_timezone,
    starts_at,
    scoring_mode,
    baseline_timeframe,
    difficulty
  )
  VALUES (
    'public_matchmaking',
    v_incoming.metric_type,
    v_incoming.duration_days,
    v_incoming.start_mode,
    'pending',
    v_tz,
    NULL,
    v_incoming.scoring_mode,
    CASE
      WHEN v_incoming.scoring_mode = 'balanced' AND v_incoming.metric_type = 'steps' THEN '30d'
      ELSE NULL
    END,
    CASE
      WHEN v_incoming.scoring_mode = 'balanced' THEN NULL
      ELSE v_incoming.difficulty
    END
  )
  RETURNING id INTO v_match_id;

  INSERT INTO match_participants (match_id, user_id, role, joined_via, accepted_at)
  VALUES
    (v_match_id, v_challenger, 'challenger', 'matchmaking', v_now),
    (v_match_id, v_opponent, 'opponent', 'matchmaking', NULL);

  UPDATE match_search_requests
  SET status = 'matched',
      matched_match_id = v_match_id
  WHERE id IN (v_incoming.id, v_partner.id)
    AND status = 'searching';

  GET DIAGNOSTICS v_rowcount = ROW_COUNT;
  IF v_rowcount <> 2 THEN
    RAISE EXCEPTION 'matchmaking_pair_atomic: expected 2 updated search rows, got %', v_rowcount;
  END IF;

  RETURN v_match_id;
END;
$function$;
