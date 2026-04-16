-- Slice 4e — Decline pending match (direct challenge + public matchmaking)
-- Run in Supabase SQL editor after slice9-notifications.sql (requires private.invoke_dispatch_notification).
--
-- iOS calls public.decline_pending_match(p_match_id) instead of patching direct_challenges only.
-- Sets matches.state = 'cancelled' so Home stops showing the card; notifies the other user for
-- public_matchmaking via trigger (direct_challenge still uses notify_challenge_declined on direct_challenges).

CREATE OR REPLACE FUNCTION public.notify_public_matchmaking_declined()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_decliner_id uuid;
  v_other_id uuid;
  v_metric_type text;
  v_decliner_name text;
  v_setting text;
BEGIN
  -- Trigger WHEN clause already limits to pending→cancelled, public_matchmaking.
  v_setting := current_setting('app.decline_user_id', true);
  IF v_setting IS NULL OR length(trim(v_setting)) = 0 THEN
    RETURN NEW;
  END IF;

  BEGIN
    v_decliner_id := trim(v_setting)::uuid;
  EXCEPTION WHEN invalid_text_representation THEN
    RETURN NEW;
  END;

  SELECT user_id
  INTO v_other_id
  FROM match_participants
  WHERE match_id = NEW.id
    AND user_id <> v_decliner_id
  LIMIT 1;

  IF v_other_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT metric_type
  INTO v_metric_type
  FROM matches
  WHERE id = NEW.id
  LIMIT 1;

  SELECT COALESCE(display_name, 'Opponent')
  INTO v_decliner_name
  FROM profiles
  WHERE id = v_decliner_id
  LIMIT 1;

  PERFORM private.invoke_dispatch_notification(
    ARRAY[v_other_id],
    'challenge_declined',
    jsonb_build_object(
      'match_id', NEW.id::text,
      'metric_type', COALESCE(v_metric_type, 'steps'),
      'opponent_display_name', v_decliner_name,
      'deep_link_target', 'home'
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_notify_public_matchmaking_declined ON public.matches;
CREATE TRIGGER tr_notify_public_matchmaking_declined
AFTER UPDATE OF state ON public.matches
FOR EACH ROW
WHEN (
  OLD.state = 'pending'
  AND NEW.state = 'cancelled'
  AND NEW.match_type = 'public_matchmaking'
)
EXECUTE FUNCTION public.notify_public_matchmaking_declined();

-- ---------------------------------------------------------------------------
-- RPC: decline pending match (authenticated caller must be a participant)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.decline_pending_match(p_match_id uuid)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_profile_id uuid;
  v_state text;
  v_match_type text;
  v_updated int;
BEGIN
  v_profile_id := (
    SELECT id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1
  );

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated';
  END IF;

  SELECT m.state, m.match_type
  INTO v_state, v_match_type
  FROM public.matches m
  WHERE m.id = p_match_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN json_build_object('ok', false, 'reason', 'match_not_found');
  END IF;

  IF v_state <> 'pending' THEN
    RETURN json_build_object('ok', true, 'reason', 'already_resolved');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.match_participants mp
    WHERE mp.match_id = p_match_id
      AND mp.user_id = v_profile_id
  ) THEN
    RAISE EXCEPTION 'not a participant';
  END IF;

  IF v_match_type = 'direct_challenge' THEN
    UPDATE public.direct_challenges
    SET status = 'declined'
    WHERE match_id = p_match_id
      AND status = 'pending';
  END IF;

  PERFORM set_config('app.decline_user_id', v_profile_id::text, true);

  UPDATE public.matches
  SET state = 'cancelled'
  WHERE id = p_match_id
    AND state = 'pending';

  GET DIAGNOSTICS v_updated = ROW_COUNT;

  IF v_updated = 0 THEN
    RETURN json_build_object('ok', true, 'reason', 'already_resolved');
  END IF;

  RETURN json_build_object('ok', true, 'reason', 'declined');
END;
$$;

REVOKE ALL ON FUNCTION public.decline_pending_match(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.decline_pending_match(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.decline_pending_match(uuid) TO service_role;

COMMENT ON FUNCTION public.decline_pending_match(uuid) IS
  'Declines a pending match: updates direct_challenges when present, sets matches.state to cancelled; notifies opponent for public_matchmaking.';
