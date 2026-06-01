-- =============================================================================
-- early_clinch_01_reconcile_clinched_active_matches_ROLLBACK.sql  (MANUAL APPLY)
-- =============================================================================
-- Purpose:
--   Restore current live behavior: reconcile only all-days-finalized active
--   matches.
--
-- Source:
--   Mirrors current live body validated in readonly audit.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.reconcile_stuck_match_completions()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'pg_temp'
AS $function$
DECLARE
  v_match_id uuid;
BEGIN
  FOR v_match_id IN
    SELECT m.id
    FROM public.matches m
    WHERE m.state = 'active'
      AND EXISTS (SELECT 1 FROM public.match_days md WHERE md.match_id = m.id)
      AND NOT EXISTS (
        SELECT 1
        FROM public.match_days md2
        WHERE md2.match_id = m.id
          AND md2.status IS DISTINCT FROM 'finalized'
      )
  LOOP
    PERFORM private.invoke_edge_function(
      'complete-match',
      jsonb_build_object('match_id', v_match_id::text)
    );
  END LOOP;
END;
$function$;

COMMENT ON FUNCTION public.reconcile_stuck_match_completions() IS
  'Invokes complete-match for active matches where all match_days are finalized, healing partial failures from finalize-match-day.';

