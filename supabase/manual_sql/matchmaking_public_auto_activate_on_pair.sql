-- Public matchmaking: auto-start when two search rows pair (no accept / no "waiting on opponent").
--
-- Apply in Supabase SQL editor (or merge into a migration). Replaces `public.matchmaking_pair_atomic`
-- from balanced_battle_phase1 / raw widening: same pairing rules, but both participants get
-- `accepted_at` immediately and `activate_match_with_days` runs in the same transaction.
--
-- Direct challenges are unchanged (`create_direct_challenge`).

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
  v_eff_mode text;
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

  v_my_avg := COALESCE(v_incoming.creator_avg_30d_steps, v_incoming.creator_baseline);
  v_eff_mode := COALESCE(v_incoming.scoring_mode, 'raw');
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
            (v_eff_mode = 'raw' AND v_eff_diff = 'easy'
              AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) BETWEEN v_my_avg * 0.70 AND v_my_avg * 1.00)
            OR (v_eff_mode = 'raw' AND v_eff_diff = 'fair'
              AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) BETWEEN v_my_avg * 0.85 AND v_my_avg * 1.15)
            OR (v_eff_mode = 'raw' AND v_eff_diff = 'hard'
              AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) BETWEEN v_my_avg * 1.05 AND v_my_avg * 1.40)
            OR (v_eff_mode = 'balanced' AND v_eff_diff = 'easy'
              AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) BETWEEN v_my_avg * 0.60 AND v_my_avg * 1.10)
            OR (v_eff_mode = 'balanced' AND v_eff_diff = 'fair'
              AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) BETWEEN v_my_avg * 0.50 AND v_my_avg * 1.50)
            OR (v_eff_mode = 'balanced' AND v_eff_diff = 'hard'
              AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) BETWEEN v_my_avg * 0.90 AND v_my_avg * 2.50)
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
    v_incoming.difficulty
  )
  RETURNING id INTO v_match_id;

  -- Both players treated as having accepted public matchmaking; no invite / opponent-wait UI.
  INSERT INTO match_participants (match_id, user_id, role, joined_via, accepted_at)
  VALUES
    (v_match_id, v_challenger, 'challenger', 'matchmaking', v_now),
    (v_match_id, v_opponent, 'opponent', 'matchmaking', v_now);

  IF NOT public.activate_match_with_days(v_match_id) THEN
    RAISE EXCEPTION 'matchmaking_pair_atomic: activate_match_with_days failed for match %', v_match_id;
  END IF;

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
