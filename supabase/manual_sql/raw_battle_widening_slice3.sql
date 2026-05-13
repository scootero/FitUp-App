-- Slice 3 — Raw Battle time-based widening + match resolution metadata + Balanced lead notification payload
--
-- Apply in Supabase SQL Editor when ready. Does not assume a migration workflow.
--
-- Summary:
-- 1) Adds matches.matchmaking_resolution / matches.matchmaking_attempt (public_matchmaking only).
-- 2) Replaces matchmaking_pair_atomic: Raw steps searches use age since request created_at:
--      < 120s  : exact_preference (original tight avg bands)
--      120–179s: widened (Easy 50–115%, Fair 65–135%, Hard 90–175%)
--      >= 180s : fallback_fifo (no avg filter, oldest compatible partner first)
--    Balanced queue unchanged (FIFO by created_at). Non-steps matchmaking unchanged (no metadata).
-- 3) notify_lead_changed includes matches.scoring_mode for client copy (Balanced vs raw steps).
--
-- Cron: Existing matchmaking_retry_stale_searches continues to re-invoke pairing; widening phases
-- depend on elapsed time since each search row was inserted, not time since last retry.

-- ---------------------------------------------------------------------------
-- Schema (additive)
-- ---------------------------------------------------------------------------

ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS matchmaking_resolution text,
  ADD COLUMN IF NOT EXISTS matchmaking_attempt int;

ALTER TABLE public.matches DROP CONSTRAINT IF EXISTS matches_matchmaking_resolution_check;
ALTER TABLE public.matches ADD CONSTRAINT matches_matchmaking_resolution_check
  CHECK (
    matchmaking_resolution IS NULL
    OR matchmaking_resolution IN ('exact_preference', 'widened', 'fallback_fifo')
  );

COMMENT ON COLUMN public.matches.matchmaking_resolution IS
  'public_matchmaking only: exact_preference | widened | fallback_fifo (Raw widening phase)';
COMMENT ON COLUMN public.matches.matchmaking_attempt IS
  'public_matchmaking Raw steps: widening phase index 1–3; NULL otherwise';

-- ---------------------------------------------------------------------------
-- matchmaking_pair_atomic (Balanced unchanged; Raw steps = time phases; metadata on insert)
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
  v_eff_diff text;
  v_found boolean := false;
  v_age_sec double precision;
  v_matchmaking_resolution text := NULL;
  v_matchmaking_attempt int := NULL;
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
  -- Raw steps: explicit raw, or legacy NULL scoring (not Balanced).
  ELSIF v_incoming.metric_type = 'steps'
    AND v_incoming.scoring_mode IS DISTINCT FROM 'balanced' THEN
    v_my_avg := COALESCE(v_incoming.creator_avg_30d_steps, v_incoming.creator_baseline);
    v_eff_diff := COALESCE(v_incoming.difficulty, 'fair');
    v_age_sec := EXTRACT(EPOCH FROM (v_now - v_incoming.created_at));

    IF v_age_sec >= 180 THEN
      v_matchmaking_attempt := 3;
      v_matchmaking_resolution := 'fallback_fifo';

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
      ORDER BY msr.created_at ASC, msr.id ASC
      FOR UPDATE SKIP LOCKED
      LIMIT 1;

      v_found := FOUND;
    ELSIF v_age_sec >= 120 THEN
      v_matchmaking_attempt := 2;
      v_matchmaking_resolution := 'widened';

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
          v_my_avg IS NULL
          OR v_my_avg <= 0
          OR (
            (v_eff_diff = 'easy'
              AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) BETWEEN v_my_avg * 0.50 AND v_my_avg * 1.15)
            OR (v_eff_diff = 'fair'
              AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) BETWEEN v_my_avg * 0.65 AND v_my_avg * 1.35)
            OR (v_eff_diff = 'hard'
              AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) BETWEEN v_my_avg * 0.90 AND v_my_avg * 1.75)
          )
        )
      ORDER BY
        abs(COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) - v_my_avg) ASC NULLS LAST,
        msr.created_at ASC,
        msr.id ASC
      FOR UPDATE SKIP LOCKED
      LIMIT 1;

      v_found := FOUND;
    ELSE
      v_matchmaking_attempt := 1;
      v_matchmaking_resolution := 'exact_preference';

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
          v_my_avg IS NULL
          OR v_my_avg <= 0
          OR (
            (v_eff_diff = 'easy'
              AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) BETWEEN v_my_avg * 0.70 AND v_my_avg * 1.00)
            OR (v_eff_diff = 'fair'
              AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) BETWEEN v_my_avg * 0.85 AND v_my_avg * 1.15)
            OR (v_eff_diff = 'hard'
              AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) BETWEEN v_my_avg * 1.05 AND v_my_avg * 1.40)
          )
        )
      ORDER BY
        abs(COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) - v_my_avg) ASC NULLS LAST,
        msr.created_at ASC,
        msr.id ASC
      FOR UPDATE SKIP LOCKED
      LIMIT 1;

      v_found := FOUND;
    END IF;
  ELSE
    -- Non-steps, or rare metric/scoring combos: original 3-pass widening.
    v_my_avg := COALESCE(v_incoming.creator_avg_30d_steps, v_incoming.creator_baseline);
    v_eff_diff := COALESCE(v_incoming.difficulty, 'fair');

    FOR v_legacy_attempt IN 1..3 LOOP
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
          OR v_legacy_attempt >= 3
          OR v_my_avg IS NULL
          OR v_my_avg <= 0
          OR (
            v_legacy_attempt = 2
            AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) >= v_my_avg * 0.01
            AND COALESCE(msr.creator_avg_30d_steps, msr.creator_baseline) <= v_my_avg * 100
          )
          OR (
            v_legacy_attempt = 1
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

    v_matchmaking_resolution := NULL;
    v_matchmaking_attempt := NULL;
  END IF;

  IF NOT v_found THEN
    RETURN NULL;
  END IF;

  -- Balanced: no resolution metadata
  IF v_incoming.scoring_mode = 'balanced' THEN
    v_matchmaking_resolution := NULL;
    v_matchmaking_attempt := NULL;
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
    difficulty,
    matchmaking_resolution,
    matchmaking_attempt
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
    END,
    v_matchmaking_resolution,
    v_matchmaking_attempt
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

-- ---------------------------------------------------------------------------
-- notify_lead_changed: include scoring_mode for push copy (Balanced vs raw)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.notify_lead_changed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_match_id uuid;
  v_match_state text;
  v_metric_type text;
  v_scoring_mode text;
  v_opponent_user_id uuid;
  v_opponent_total numeric;
  v_prev_leader uuid;
  v_new_leader uuid;
  v_trailing_user_id uuid;
  v_leader_name text;
  v_lead_delta int;
BEGIN
  IF COALESCE(NEW.metric_total, 0) = COALESCE(OLD.metric_total, 0) THEN
    RETURN NEW;
  END IF;

  SELECT m.id, m.state, m.metric_type, m.scoring_mode
  INTO v_match_id, v_match_state, v_metric_type, v_scoring_mode
  FROM match_days md
  JOIN matches m
    ON m.id = md.match_id
  WHERE md.id = NEW.match_day_id
    AND md.status <> 'finalized'
  LIMIT 1;

  IF v_match_id IS NULL OR v_match_state <> 'active' THEN
    RETURN NEW;
  END IF;

  SELECT user_id, metric_total
  INTO v_opponent_user_id, v_opponent_total
  FROM match_day_participants
  WHERE match_day_id = NEW.match_day_id
    AND user_id <> NEW.user_id
  LIMIT 1;

  IF v_opponent_user_id IS NULL THEN
    RETURN NEW;
  END IF;

  v_prev_leader := private.resolve_leader_user(OLD.metric_total, v_opponent_total, NEW.user_id, v_opponent_user_id);
  v_new_leader := private.resolve_leader_user(NEW.metric_total, v_opponent_total, NEW.user_id, v_opponent_user_id);

  IF v_prev_leader IS NULL OR v_new_leader IS NULL OR v_prev_leader = v_new_leader THEN
    RETURN NEW;
  END IF;

  IF v_new_leader = NEW.user_id THEN
    v_trailing_user_id := v_opponent_user_id;
  ELSE
    v_trailing_user_id := NEW.user_id;
  END IF;

  SELECT COALESCE(display_name, 'Opponent')
  INTO v_leader_name
  FROM profiles
  WHERE id = v_new_leader
  LIMIT 1;

  v_lead_delta := ABS(COALESCE(NEW.metric_total, 0)::int - COALESCE(v_opponent_total, 0)::int);

  PERFORM private.invoke_dispatch_notification(
    ARRAY[v_trailing_user_id],
    'lead_changed',
    jsonb_build_object(
      'match_id', v_match_id::text,
      'metric_type', COALESCE(v_metric_type, 'steps'),
      'scoring_mode', COALESCE(v_scoring_mode, ''),
      'opponent_display_name', v_leader_name,
      'lead_delta', v_lead_delta,
      'deep_link_target', 'match_details'
    )
  );

  RETURN NEW;
END;
$function$;
