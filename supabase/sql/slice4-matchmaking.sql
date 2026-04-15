-- Slice 4 — Quick Match pairing + activate match when all participants accepted
-- Run in Supabase SQL editor (owner / service role context).
-- Requires: same Vault secrets as slice8-finalization.sql (fitup_project_url, fitup_service_role_key).
-- Run after slice8-finalization.sql (pg_net already enabled).

CREATE EXTENSION IF NOT EXISTS pg_net;

CREATE SCHEMA IF NOT EXISTS private;

-- ---------------------------------------------------------------------------
-- RPC: atomic public matchmaking (called from matchmaking-pairing Edge Function)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.matchmaking_pair_atomic(p_request_id uuid)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_incoming match_search_requests%ROWTYPE;
  v_partner match_search_requests%ROWTYPE;
  v_match_id uuid;
  v_tz text;
  v_challenger uuid;
  v_opponent uuid;
  v_rowcount int;
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

  SELECT msr.*
  INTO v_partner
  FROM match_search_requests msr
  WHERE msr.status = 'searching'
    AND msr.id <> v_incoming.id
    AND msr.creator_id <> v_incoming.creator_id
    AND msr.metric_type = v_incoming.metric_type
    AND msr.duration_days = v_incoming.duration_days
    AND msr.start_mode = v_incoming.start_mode
  ORDER BY
    abs(msr.creator_baseline - v_incoming.creator_baseline) ASC NULLS LAST,
    msr.created_at ASC,
    msr.id ASC
  FOR UPDATE SKIP LOCKED
  LIMIT 1;

  IF NOT FOUND THEN
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

  SELECT COALESCE(p.timezone, 'America/Chicago')
  INTO v_tz
  FROM profiles p
  WHERE p.id = v_challenger
  LIMIT 1;

  IF v_tz IS NULL OR length(trim(v_tz)) = 0 THEN
    v_tz := 'America/Chicago';
  END IF;

  INSERT INTO matches (
    match_type,
    metric_type,
    duration_days,
    start_mode,
    state,
    match_timezone,
    starts_at
  )
  VALUES (
    'public_matchmaking',
    v_incoming.metric_type,
    v_incoming.duration_days,
    v_incoming.start_mode,
    'pending',
    v_tz,
    NULL
  )
  RETURNING id INTO v_match_id;

  INSERT INTO match_participants (match_id, user_id, role, joined_via, accepted_at)
  VALUES
    (v_match_id, v_challenger, 'challenger', 'matchmaking', NULL),
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
$$;

-- ---------------------------------------------------------------------------
-- RPC: activate match + create match_days / match_day_participants (idempotent)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.activate_match_with_days(p_match_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
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

  -- Match start = 00:00 local on Day 1 in match_timezone (proper timestamptz; server-TZ independent).
  v_tz := COALESCE(NULLIF(trim(v_tz), ''), 'America/Chicago');

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
    v_tz := 'America/Chicago';
  END IF;

  v_base_date := (timezone(v_tz, v_starts_at))::date;

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
$$;

REVOKE ALL ON FUNCTION public.matchmaking_pair_atomic(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.activate_match_with_days(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.matchmaking_pair_atomic(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.activate_match_with_days(uuid) TO service_role;

-- ---------------------------------------------------------------------------
-- pg_net → Edge Functions (same Vault pattern as slice8-finalization.sql)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION private.invoke_matchmaking_pairing(p_request_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_project_url text;
  v_service_role_key text;
BEGIN
  SELECT decrypted_secret
  INTO v_project_url
  FROM vault.decrypted_secrets
  WHERE name = 'fitup_project_url'
  LIMIT 1;

  SELECT decrypted_secret
  INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'fitup_service_role_key'
  LIMIT 1;

  IF v_project_url IS NULL OR v_service_role_key IS NULL THEN
    RAISE EXCEPTION 'Missing vault secrets fitup_project_url or fitup_service_role_key.';
  END IF;

  PERFORM net.http_post(
    url := v_project_url || '/functions/v1/matchmaking-pairing',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key,
      'apikey', v_service_role_key
    ),
    body := jsonb_build_object('match_search_request_id', p_request_id::text)
  );
END;
$$;

CREATE OR REPLACE FUNCTION private.invoke_on_all_accepted(p_match_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_project_url text;
  v_service_role_key text;
BEGIN
  SELECT decrypted_secret
  INTO v_project_url
  FROM vault.decrypted_secrets
  WHERE name = 'fitup_project_url'
  LIMIT 1;

  SELECT decrypted_secret
  INTO v_service_role_key
  FROM vault.decrypted_secrets
  WHERE name = 'fitup_service_role_key'
  LIMIT 1;

  IF v_project_url IS NULL OR v_service_role_key IS NULL THEN
    RAISE EXCEPTION 'Missing vault secrets fitup_project_url or fitup_service_role_key.';
  END IF;

  PERFORM net.http_post(
    url := v_project_url || '/functions/v1/on-all-accepted',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key,
      'apikey', v_service_role_key
    ),
    body := jsonb_build_object('match_id', p_match_id::text)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.tr_matchmaking_pairing_after_insert()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.status = 'searching' THEN
    PERFORM private.invoke_matchmaking_pairing(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.tr_on_all_accepted_after_participant()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.accepted_at IS NOT NULL THEN
    PERFORM private.invoke_on_all_accepted(NEW.match_id);
  END IF;
  RETURN NEW;
END;
$$;

-- Replace slice9 notification triggers that conflict with this flow
DROP TRIGGER IF EXISTS tr_notify_match_found_on_pairing ON match_participants;
DROP FUNCTION IF EXISTS public.notify_match_found_on_pairing();

DROP TRIGGER IF EXISTS tr_activate_match_when_all_accepted ON match_participants;
DROP FUNCTION IF EXISTS public.activate_match_when_all_accepted();

DROP TRIGGER IF EXISTS tr_matchmaking_pairing_after_insert ON match_search_requests;
CREATE TRIGGER tr_matchmaking_pairing_after_insert
AFTER INSERT ON match_search_requests
FOR EACH ROW
EXECUTE FUNCTION public.tr_matchmaking_pairing_after_insert();

DROP TRIGGER IF EXISTS tr_on_all_accepted_after_participant ON match_participants;
CREATE TRIGGER tr_on_all_accepted_after_participant
AFTER INSERT OR UPDATE OF accepted_at ON match_participants
FOR EACH ROW
EXECUTE FUNCTION public.tr_on_all_accepted_after_participant();
