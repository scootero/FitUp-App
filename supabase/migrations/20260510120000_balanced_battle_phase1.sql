-- Phase 1: Balanced Battle (steps), match options on queue + matches, baseline snapshots, finalize support columns.

-- ---------------------------------------------------------------------------
-- Schema (additive)
-- ---------------------------------------------------------------------------

ALTER TABLE public.user_health_baselines
  ADD COLUMN IF NOT EXISTS rolling_avg_30d_steps numeric,
  ADD COLUMN IF NOT EXISTS rolling_avg_90d_steps numeric;

ALTER TABLE public.matches
  ADD COLUMN IF NOT EXISTS scoring_mode text,
  ADD COLUMN IF NOT EXISTS baseline_timeframe text,
  ADD COLUMN IF NOT EXISTS difficulty text;

ALTER TABLE public.match_search_requests
  ADD COLUMN IF NOT EXISTS scoring_mode text,
  ADD COLUMN IF NOT EXISTS difficulty text,
  ADD COLUMN IF NOT EXISTS creator_avg_30d_steps numeric;

ALTER TABLE public.match_participants
  ADD COLUMN IF NOT EXISTS baseline_steps numeric;

ALTER TABLE public.match_day_participants
  ADD COLUMN IF NOT EXISTS balanced_ratio numeric,
  ADD COLUMN IF NOT EXISTS balanced_percent numeric;

ALTER TABLE public.matches DROP CONSTRAINT IF EXISTS matches_scoring_mode_check;
ALTER TABLE public.matches ADD CONSTRAINT matches_scoring_mode_check
  CHECK (scoring_mode IS NULL OR scoring_mode IN ('balanced', 'raw'));

ALTER TABLE public.matches DROP CONSTRAINT IF EXISTS matches_baseline_timeframe_check;
ALTER TABLE public.matches ADD CONSTRAINT matches_baseline_timeframe_check
  CHECK (baseline_timeframe IS NULL OR baseline_timeframe = '30d');

ALTER TABLE public.matches DROP CONSTRAINT IF EXISTS matches_difficulty_check;
ALTER TABLE public.matches ADD CONSTRAINT matches_difficulty_check
  CHECK (difficulty IS NULL OR difficulty IN ('easy', 'fair', 'hard'));

ALTER TABLE public.match_search_requests DROP CONSTRAINT IF EXISTS msq_scoring_mode_check;
ALTER TABLE public.match_search_requests ADD CONSTRAINT msq_scoring_mode_check
  CHECK (scoring_mode IS NULL OR scoring_mode IN ('balanced', 'raw'));

ALTER TABLE public.match_search_requests DROP CONSTRAINT IF EXISTS msq_difficulty_check;
ALTER TABLE public.match_search_requests ADD CONSTRAINT msq_difficulty_check
  CHECK (difficulty IS NULL OR difficulty IN ('easy', 'fair', 'hard'));

CREATE INDEX IF NOT EXISTS msq_pairing_dims
  ON public.match_search_requests (status, metric_type, duration_days, start_mode, scoring_mode, difficulty);

COMMENT ON COLUMN public.matches.scoring_mode IS 'balanced | raw | NULL legacy (raw winner semantics)';
COMMENT ON COLUMN public.match_participants.baseline_steps IS 'Snapshotted steps baseline for balanced scoring; immutable once set ideally';

-- ---------------------------------------------------------------------------
-- RPC: optional floor baseline from client (>= 3000), caller must be participant.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.set_my_match_participant_baseline(p_match_id uuid, p_baseline_steps numeric)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_pid uuid;
  v_metric text;
  v_mode text;
  v_updated int;
BEGIN
  IF p_baseline_steps IS NULL OR p_baseline_steps < 3000 THEN
    RAISE EXCEPTION 'baseline_steps must be >= 3000';
  END IF;

  SELECT id INTO v_pid FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1;
  IF v_pid IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT m.metric_type, m.scoring_mode
  INTO v_metric, v_mode
  FROM public.matches m
  WHERE m.id = p_match_id
  LIMIT 1;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'match not found';
  END IF;

  IF v_metric <> 'steps' OR COALESCE(v_mode, 'raw') <> 'balanced' THEN
    RAISE EXCEPTION 'baseline snapshot only for balanced steps matches';
  END IF;

  UPDATE public.match_participants mp
  SET baseline_steps = p_baseline_steps
  WHERE mp.match_id = p_match_id
    AND mp.user_id = v_pid
    AND mp.baseline_steps IS NULL;

  GET DIAGNOSTICS v_updated = ROW_COUNT;
  IF v_updated <> 1 THEN
    RAISE EXCEPTION 'not a participant';
  END IF;
END;
$function$;

GRANT EXECUTE ON FUNCTION public.set_my_match_participant_baseline(uuid, numeric) TO authenticated;

-- ---------------------------------------------------------------------------
-- activate_match_with_days: snapshot baseline_steps from user_health_baselines
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.activate_match_with_days(p_match_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_state text;
  v_duration int;
  v_starts_at timestamptz;
  v_tz text;
  v_total int;
  v_accepted int;
  v_rowcount int;
  v_base_date date;
  v_day int;
  v_match_day_id uuid;
  r_participant record;
BEGIN
  SELECT state, duration_days, starts_at, match_timezone
  INTO v_state, v_duration, v_starts_at, v_tz
  FROM matches
  WHERE id = p_match_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN false;
  END IF;

  IF v_state <> 'pending' THEN
    RETURN false;
  END IF;

  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE accepted_at IS NOT NULL)::int
  INTO v_total, v_accepted
  FROM match_participants
  WHERE match_id = p_match_id;

  IF v_total = 0 OR v_total <> v_accepted THEN
    RETURN false;
  END IF;

  v_tz := COALESCE(NULLIF(trim(v_tz), ''), 'America/New_York');

  UPDATE matches
  SET state = 'active',
      starts_at = (((timezone(v_tz, clock_timestamp()))::date)::timestamp) AT TIME ZONE v_tz
  WHERE id = p_match_id
    AND state = 'pending';

  GET DIAGNOSTICS v_rowcount = ROW_COUNT;
  IF v_rowcount = 0 THEN
    RETURN false;
  END IF;

  SELECT starts_at, match_timezone, duration_days
  INTO v_starts_at, v_tz, v_duration
  FROM matches
  WHERE id = p_match_id;

  IF v_tz IS NULL OR length(trim(v_tz)) = 0 THEN
    v_tz := 'America/New_York';
  END IF;

  v_base_date := (timezone(v_tz, v_starts_at))::date;

  -- Balanced steps: snapshot rolling averages (subquery avoids invalid mp reference in FROM).
  UPDATE match_participants mp
  SET baseline_steps = src.baseline
  FROM (
    SELECT
      mp2.id,
      COALESCE(uhb.rolling_avg_30d_steps, uhb.rolling_avg_7d_steps) AS baseline
    FROM match_participants mp2
    INNER JOIN matches m ON m.id = mp2.match_id AND m.id = p_match_id
    LEFT JOIN user_health_baselines uhb ON uhb.user_id = mp2.user_id
    WHERE mp2.match_id = p_match_id
      AND m.scoring_mode = 'balanced'
      AND m.metric_type = 'steps'
  ) src
  WHERE mp.id = src.id;

  FOR v_day IN 1..v_duration LOOP
    INSERT INTO match_days (match_id, day_number, calendar_date, status)
    VALUES (p_match_id, v_day, v_base_date + (v_day - 1), 'pending')
    ON CONFLICT (match_id, day_number) DO NOTHING;

    SELECT id
    INTO v_match_day_id
    FROM match_days
    WHERE match_id = p_match_id
      AND day_number = v_day
    LIMIT 1;

    IF v_match_day_id IS NULL THEN
      CONTINUE;
    END IF;

    FOR r_participant IN
      SELECT user_id FROM match_participants WHERE match_id = p_match_id
    LOOP
      INSERT INTO match_day_participants (match_day_id, user_id, metric_total, data_status)
      VALUES (v_match_day_id, r_participant.user_id, 0, 'pending')
      ON CONFLICT (match_day_id, user_id) DO NOTHING;
    END LOOP;
  END LOOP;

  RETURN true;
END;
$function$;

-- ---------------------------------------------------------------------------
-- create_direct_challenge: optional scoring_mode + difficulty (steps only)
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
    v_diff := COALESCE(NULLIF(trim(p_difficulty), ''), 'fair');
    IF v_diff NOT IN ('easy', 'fair', 'hard') THEN
      RAISE EXCEPTION 'invalid difficulty';
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
-- matchmaking_pair_atomic: scoring_mode + difficulty + band widening
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
