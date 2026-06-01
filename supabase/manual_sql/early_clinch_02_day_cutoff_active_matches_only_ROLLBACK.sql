-- =============================================================================
-- early_clinch_02_day_cutoff_active_matches_only_ROLLBACK.sql  (MANUAL APPLY)
-- =============================================================================
-- Purpose:
--   Restore current live behavior for day_cutoff_check() without the active-match
--   parent filter.
--
-- Source:
--   Mirrors current live body validated in readonly audit.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.day_cutoff_check()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
DECLARE
  v_match_day_id uuid;
BEGIN
  -- Phase 1: pending participants past local cutoff -> confirmed (existing behavior)
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
$function$;

