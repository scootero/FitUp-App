-- Slice 9 notifications + Live Activity backend wiring
-- Run in Supabase SQL editor (service role / owner context).
--
-- Required Vault secrets:
--   fitup_project_url          -> https://<project-ref>.supabase.co
--   fitup_service_role_key     -> service role JWT
-- Required Edge Function env secrets (set in Supabase dashboard):
--   APNS_TEAM_ID
--   APNS_KEY_ID
--   APNS_PRIVATE_KEY
--   APNS_BUNDLE_ID
--   APNS_USE_SANDBOX           -> true (dev) / false (prod)

CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pg_cron;

ALTER TABLE profiles
  ADD COLUMN IF NOT EXISTS notifications_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS live_activity_push_token text;

CREATE SCHEMA IF NOT EXISTS private;

CREATE OR REPLACE FUNCTION private.invoke_edge_function(
  p_function_name text,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
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
    url := v_project_url || '/functions/v1/' || p_function_name,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key,
      'apikey', v_service_role_key
    ),
    body := p_payload
  );
END;
$$;

CREATE OR REPLACE FUNCTION private.invoke_dispatch_notification(
  p_user_ids uuid[],
  p_event_type text,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_ids text[];
BEGIN
  IF p_user_ids IS NULL OR array_length(p_user_ids, 1) IS NULL THEN
    RETURN;
  END IF;

  SELECT ARRAY_AGG(value::text)
  INTO v_user_ids
  FROM unnest(p_user_ids) AS value;

  PERFORM private.invoke_edge_function(
    'dispatch-notification',
    jsonb_build_object(
      'user_ids', to_jsonb(v_user_ids),
      'event_type', p_event_type,
      'payload', COALESCE(p_payload, '{}'::jsonb)
    )
  );
END;
$$;

CREATE OR REPLACE FUNCTION private.notification_sent_today(
  p_user_id uuid,
  p_event_type text,
  p_match_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM notification_events ne
    WHERE ne.user_id = p_user_id
      AND ne.event_type = p_event_type
      AND COALESCE(ne.payload ->> 'match_id', '') = p_match_id::text
      AND ne.created_at >= date_trunc('day', now())
  );
$$;

CREATE OR REPLACE FUNCTION private.resolve_leader_user(
  p_my_value numeric,
  p_other_value numeric,
  p_my_user_id uuid,
  p_other_user_id uuid
)
RETURNS uuid
LANGUAGE plpgsql
IMMUTABLE
AS $$
BEGIN
  IF COALESCE(p_my_value, 0) = COALESCE(p_other_value, 0) THEN
    RETURN NULL;
  END IF;
  IF COALESCE(p_my_value, 0) > COALESCE(p_other_value, 0) THEN
    RETURN p_my_user_id;
  END IF;
  RETURN p_other_user_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.notify_match_found_on_pairing()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_state text;
  v_match_type text;
  v_metric_type text;
  v_participant_count int;
  v_user_id uuid;
  v_opponent_name text;
BEGIN
  SELECT state, match_type, metric_type
  INTO v_state, v_match_type, v_metric_type
  FROM matches
  WHERE id = NEW.match_id
  LIMIT 1;

  IF v_state IS NULL OR v_match_type <> 'public_matchmaking' OR v_state <> 'pending' THEN
    RETURN NEW;
  END IF;

  SELECT COUNT(*)::int
  INTO v_participant_count
  FROM match_participants
  WHERE match_id = NEW.match_id;

  IF v_participant_count < 2 THEN
    RETURN NEW;
  END IF;

  FOR v_user_id, v_opponent_name IN
    SELECT
      mp.user_id,
      COALESCE(opp.display_name, 'Opponent')
    FROM match_participants mp
    LEFT JOIN LATERAL (
      SELECT p.display_name
      FROM match_participants omp
      JOIN profiles p
        ON p.id = omp.user_id
      WHERE omp.match_id = mp.match_id
        AND omp.user_id <> mp.user_id
      LIMIT 1
    ) opp ON true
    WHERE mp.match_id = NEW.match_id
  LOOP
    IF private.notification_sent_today(v_user_id, 'match_found', NEW.match_id) THEN
      CONTINUE;
    END IF;
    PERFORM private.invoke_dispatch_notification(
      ARRAY[v_user_id],
      'match_found',
      jsonb_build_object(
        'match_id', NEW.match_id::text,
        'metric_type', v_metric_type,
        'opponent_display_name', v_opponent_name,
        'deep_link_target', 'home'
      )
    );
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_notify_match_found_on_pairing ON match_participants;
CREATE TRIGGER tr_notify_match_found_on_pairing
AFTER INSERT ON match_participants
FOR EACH ROW
EXECUTE FUNCTION public.notify_match_found_on_pairing();

CREATE OR REPLACE FUNCTION public.notify_challenge_received()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_metric_type text;
  v_challenger_name text;
BEGIN
  SELECT metric_type
  INTO v_metric_type
  FROM matches
  WHERE id = NEW.match_id
  LIMIT 1;

  SELECT COALESCE(display_name, 'Opponent')
  INTO v_challenger_name
  FROM profiles
  WHERE id = NEW.challenger_id
  LIMIT 1;

  IF private.notification_sent_today(NEW.recipient_id, 'challenge_received', NEW.match_id) THEN
    RETURN NEW;
  END IF;

  PERFORM private.invoke_dispatch_notification(
    ARRAY[NEW.recipient_id],
    'challenge_received',
    jsonb_build_object(
      'match_id', NEW.match_id::text,
      'metric_type', COALESCE(v_metric_type, 'steps'),
      'opponent_display_name', v_challenger_name,
      'deep_link_target', 'home'
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_notify_challenge_received ON direct_challenges;
CREATE TRIGGER tr_notify_challenge_received
AFTER INSERT ON direct_challenges
FOR EACH ROW
EXECUTE FUNCTION public.notify_challenge_received();

CREATE OR REPLACE FUNCTION public.notify_challenge_declined()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_metric_type text;
  v_decliner_name text;
BEGIN
  IF NEW.status <> 'declined' OR OLD.status = 'declined' THEN
    RETURN NEW;
  END IF;

  SELECT metric_type
  INTO v_metric_type
  FROM matches
  WHERE id = NEW.match_id
  LIMIT 1;

  SELECT COALESCE(display_name, 'Opponent')
  INTO v_decliner_name
  FROM profiles
  WHERE id = NEW.recipient_id
  LIMIT 1;

  PERFORM private.invoke_dispatch_notification(
    ARRAY[NEW.challenger_id],
    'challenge_declined',
    jsonb_build_object(
      'match_id', NEW.match_id::text,
      'metric_type', COALESCE(v_metric_type, 'steps'),
      'opponent_display_name', v_decliner_name,
      'deep_link_target', 'home'
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_notify_challenge_declined ON direct_challenges;
CREATE TRIGGER tr_notify_challenge_declined
AFTER UPDATE OF status ON direct_challenges
FOR EACH ROW
EXECUTE FUNCTION public.notify_challenge_declined();

CREATE OR REPLACE FUNCTION public.activate_match_when_all_accepted()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_state text;
  v_metric_type text;
  v_duration_days int;
  v_total_count int;
  v_accepted_count int;
  v_updated_id uuid;
  v_user_id uuid;
  v_opponent_name text;
BEGIN
  IF NEW.accepted_at IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT state, metric_type, duration_days
  INTO v_state, v_metric_type, v_duration_days
  FROM matches
  WHERE id = NEW.match_id
  LIMIT 1;

  IF v_state IS NULL OR v_state <> 'pending' THEN
    RETURN NEW;
  END IF;

  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE accepted_at IS NOT NULL)::int
  INTO v_total_count, v_accepted_count
  FROM match_participants
  WHERE match_id = NEW.match_id;

  IF v_total_count = 0 OR v_total_count <> v_accepted_count THEN
    RETURN NEW;
  END IF;

  UPDATE matches
  SET state = 'active',
      starts_at = COALESCE(starts_at, now())
  WHERE id = NEW.match_id
    AND state = 'pending'
  RETURNING id INTO v_updated_id;

  IF v_updated_id IS NULL THEN
    RETURN NEW;
  END IF;

  FOR v_user_id, v_opponent_name IN
    SELECT
      mp.user_id,
      COALESCE(opp.display_name, 'Opponent')
    FROM match_participants mp
    LEFT JOIN LATERAL (
      SELECT p.display_name
      FROM match_participants omp
      JOIN profiles p
        ON p.id = omp.user_id
      WHERE omp.match_id = mp.match_id
        AND omp.user_id <> mp.user_id
      LIMIT 1
    ) opp ON true
    WHERE mp.match_id = NEW.match_id
  LOOP
    PERFORM private.invoke_dispatch_notification(
      ARRAY[v_user_id],
      'match_active',
      jsonb_build_object(
        'match_id', NEW.match_id::text,
        'metric_type', COALESCE(v_metric_type, 'steps'),
        'opponent_display_name', v_opponent_name,
        'day_number', 1,
        'duration_days', COALESCE(v_duration_days, 1),
        'deep_link_target', 'match_details'
      )
    );
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_activate_match_when_all_accepted ON match_participants;
CREATE TRIGGER tr_activate_match_when_all_accepted
AFTER INSERT OR UPDATE OF accepted_at ON match_participants
FOR EACH ROW
EXECUTE FUNCTION public.activate_match_when_all_accepted();

CREATE OR REPLACE FUNCTION public.notify_lead_changed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_match_id uuid;
  v_match_state text;
  v_metric_type text;
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

  SELECT m.id, m.state, m.metric_type
  INTO v_match_id, v_match_state, v_metric_type
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
      'opponent_display_name', v_leader_name,
      'lead_delta', v_lead_delta,
      'deep_link_target', 'match_details'
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_notify_lead_changed ON match_day_participants;
CREATE TRIGGER tr_notify_lead_changed
AFTER UPDATE OF metric_total ON match_day_participants
FOR EACH ROW
EXECUTE FUNCTION public.notify_lead_changed();

CREATE OR REPLACE FUNCTION public.push_live_activity_updates()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_match_id uuid;
  v_metric_type text;
  v_day_number int;
  v_participant_ids uuid[];
BEGIN
  SELECT m.id, m.metric_type, md.day_number
  INTO v_match_id, v_metric_type, v_day_number
  FROM match_days md
  JOIN matches m
    ON m.id = md.match_id
  WHERE md.id = NEW.match_day_id
    AND m.state = 'active'
  LIMIT 1;

  IF v_match_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT ARRAY_AGG(user_id)
  INTO v_participant_ids
  FROM match_participants
  WHERE match_id = v_match_id;

  PERFORM private.invoke_dispatch_notification(
    v_participant_ids,
    'live_activity_update',
    jsonb_build_object(
      'match_id', v_match_id::text,
      'match_day_id', NEW.match_day_id::text,
      'metric_type', COALESCE(v_metric_type, 'steps'),
      'day_number', COALESCE(v_day_number, 1),
      'deep_link_target', 'match_details'
    )
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_push_live_activity_updates ON match_day_participants;
CREATE TRIGGER tr_push_live_activity_updates
AFTER INSERT OR UPDATE OF metric_total ON match_day_participants
FOR EACH ROW
EXECUTE FUNCTION public.push_live_activity_updates();

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'send-pending-reminders') THEN
    PERFORM cron.unschedule('send-pending-reminders');
  END IF;

  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'send-morning-checkins') THEN
    PERFORM cron.unschedule('send-morning-checkins');
  END IF;

  -- Daily at 16:15 UTC.
  PERFORM cron.schedule(
    'send-pending-reminders',
    '15 16 * * *',
    $cmd$SELECT private.invoke_edge_function('send-pending-reminders', '{}'::jsonb);$cmd$
  );

  -- Daily at 13:00 UTC.
  PERFORM cron.schedule(
    'send-morning-checkins',
    '0 13 * * *',
    $cmd$SELECT private.invoke_edge_function('send-morning-checkins', '{}'::jsonb);$cmd$
  );
END;
$$;
