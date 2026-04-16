-- Slice 8 backend finalization wiring
-- Run in Supabase SQL editor (service role / owner context).

CREATE EXTENSION IF NOT EXISTS pg_net;
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Secrets expected in Vault:
--   fitup_project_url         -> https://<project-ref>.supabase.co
--   fitup_service_role_key    -> service role JWT
CREATE SCHEMA IF NOT EXISTS private;

CREATE OR REPLACE FUNCTION private.invoke_finalize_match_day(p_match_day_id uuid)
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
    url := v_project_url || '/functions/v1/finalize-match-day',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || v_service_role_key,
      'apikey', v_service_role_key
    ),
    body := jsonb_build_object('match_day_id', p_match_day_id::text)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.finalize_when_all_confirmed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_count int;
  v_confirmed_count int;
  v_day_status text;
BEGIN
  IF NEW.data_status <> 'confirmed' THEN
    RETURN NEW;
  END IF;

  SELECT status
  INTO v_day_status
  FROM match_days
  WHERE id = NEW.match_day_id
  LIMIT 1;

  IF v_day_status = 'finalized' THEN
    RETURN NEW;
  END IF;

  SELECT
    COUNT(*)::int,
    COUNT(*) FILTER (WHERE data_status = 'confirmed')::int
  INTO v_total_count, v_confirmed_count
  FROM match_day_participants
  WHERE match_day_id = NEW.match_day_id;

  IF v_total_count > 0 AND v_total_count = v_confirmed_count THEN
    PERFORM private.invoke_finalize_match_day(NEW.match_day_id);
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_finalize_when_all_confirmed ON match_day_participants;
CREATE TRIGGER tr_finalize_when_all_confirmed
AFTER INSERT OR UPDATE OF data_status ON match_day_participants
FOR EACH ROW
EXECUTE FUNCTION public.finalize_when_all_confirmed();

CREATE OR REPLACE FUNCTION public.day_cutoff_check()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_match_day_id uuid;
BEGIN
  FOR v_match_day_id IN
    WITH pending_cutoff_rows AS (
      SELECT mdp.id, mdp.match_day_id
      FROM match_day_participants mdp
      JOIN match_days md
        ON md.id = mdp.match_day_id
      JOIN profiles p
        ON p.id = mdp.user_id
      WHERE md.status <> 'finalized'
        AND mdp.data_status = 'pending'
        AND timezone(COALESCE(p.timezone, 'UTC'), now())
          >= ((md.calendar_date + 1)::timestamp + time '10:00')
    ),
    force_confirmed AS (
      UPDATE match_day_participants mdp
      SET data_status = 'confirmed',
          last_updated_at = now()
      FROM pending_cutoff_rows pending
      WHERE mdp.id = pending.id
      RETURNING pending.match_day_id
    )
    SELECT DISTINCT match_day_id
    FROM force_confirmed
  LOOP
    PERFORM private.invoke_finalize_match_day(v_match_day_id);
  END LOOP;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM cron.job
    WHERE jobname = 'day-cutoff-check'
  ) THEN
    PERFORM cron.schedule(
      'day-cutoff-check',
      '5 * * * *',
      $$SELECT public.day_cutoff_check();$$
    );
  END IF;
END;
$$;
