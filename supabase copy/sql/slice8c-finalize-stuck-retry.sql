-- Slice 8c — pg_net timeout + retry finalize when all confirmed but day still open
-- Run in Supabase SQL editor after slice8-finalization.sql (Vault secrets unchanged).
-- Fixes: short default pg_net timeouts vs. slow finalize-match-day; no cron retry once
-- participants are already data_status = 'confirmed' but match_days not finalized.

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
    body := jsonb_build_object('match_day_id', p_match_day_id::text),
    timeout_milliseconds := 60000
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.day_cutoff_check()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_match_day_id uuid;
BEGIN
  -- Phase 1: pending participants past local cutoff → confirmed (existing behavior)
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

  -- Phase 2: all participants already confirmed, day not finalized, cutoff passed for
  -- every participant — re-invoke finalize (e.g. after pg_net timeout or edge hiccup)
  FOR v_match_day_id IN
    SELECT md.id
    FROM match_days md
    WHERE md.status <> 'finalized'
      AND NOT EXISTS (
        SELECT 1
        FROM match_day_participants mdp
        WHERE mdp.match_day_id = md.id
          AND mdp.data_status <> 'confirmed'
      )
      AND EXISTS (
        SELECT 1
        FROM match_day_participants mdp
        WHERE mdp.match_day_id = md.id
      )
      AND NOT EXISTS (
        SELECT 1
        FROM match_day_participants mdp
        JOIN profiles p ON p.id = mdp.user_id
        WHERE mdp.match_day_id = md.id
          AND timezone(COALESCE(p.timezone, 'UTC'), now())
            < ((md.calendar_date + 1)::timestamp + time '10:00')
      )
  LOOP
    PERFORM private.invoke_finalize_match_day(v_match_day_id);
  END LOOP;
END;
$$;
