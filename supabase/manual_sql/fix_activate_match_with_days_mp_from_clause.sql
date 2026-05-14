-- =============================================================================
-- Manual fix: activate_match_with_days — invalid reference to table "mp"
-- =============================================================================
-- Symptom: Postgres ERROR 42P01 — "invalid reference to FROM-clause entry for
--   table \"mp\"" at the UPDATE that snapshots baseline_steps for balanced
--   steps matches. That aborts the whole RPC, so on-all-accepted returns 500,
--   matches stay pending, and match_days are never created.
--
-- Root cause: UPDATE match_participants mp ... FROM matches m
--   LEFT JOIN user_health_baselines uhb ON uhb.user_id = mp.user_id
--   PostgreSQL does not allow the UPDATE target alias (mp) inside the FROM
--   join graph that way.
--
-- Fix: Drive the update from a subquery that uses alias mp2, then join mp to
--   that result on match_participants.id.
--
-- Run in Supabase SQL Editor (or psql) against the affected project.
-- Safe to re-run: CREATE OR REPLACE only replaces the function body.
-- =============================================================================

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

  -- Balanced steps: snapshot rolling averages onto participants (fixed FROM).
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

-- Preserve typical lockdown (adjust if your project differs).
REVOKE ALL ON FUNCTION public.activate_match_with_days(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.activate_match_with_days(uuid) TO service_role;

-- =============================================================================
-- OPTIONAL — recover matches stuck after failed activation (run only if needed)
-- =============================================================================
-- Preview candidates: pending match, two participants, both accepted, zero days.
--
-- SELECT m.id,
--        m.match_type,
--        m.scoring_mode,
--        (SELECT count(*) FROM match_participants mp WHERE mp.match_id = m.id) AS n_mp,
--        (SELECT count(*) FROM match_participants mp WHERE mp.match_id = m.id AND mp.accepted_at IS NOT NULL) AS n_acc,
--        (SELECT count(*) FROM match_days md WHERE md.match_id = m.id) AS n_days
-- FROM matches m
-- WHERE m.state = 'pending'
--   AND (SELECT count(*) FROM match_participants mp WHERE mp.match_id = m.id) = 2
--   AND (SELECT count(*) FROM match_participants mp WHERE mp.match_id = m.id AND mp.accepted_at IS NOT NULL) = 2
--   AND NOT EXISTS (SELECT 1 FROM match_days md WHERE md.match_id = m.id);
--
-- Reactivate one match (service_role / dashboard as postgres). Triggers may
-- call on-all-accepted again; if that succeeds, clients get notifications.
--
-- SELECT public.activate_match_with_days('<match_uuid_here>'::uuid);
--
-- If activate returns true but you still need push rows only, invoke the
-- on-all-accepted Edge Function from your tooling with body {"match_id":"..."}
-- after DB is consistent (advanced; usually not required if RPC alone works).
