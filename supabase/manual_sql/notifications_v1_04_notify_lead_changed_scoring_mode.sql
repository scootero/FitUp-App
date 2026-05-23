-- Notifications v1 — ensure notify_lead_changed passes scoring_mode for Balanced lead copy.
-- Run only if notifications_v1_00_readonly_checks shows lead_fn_has_scoring_mode = false.

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
  JOIN matches m ON m.id = md.match_id
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
