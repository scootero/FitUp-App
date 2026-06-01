-- =============================================================================
-- early_clinch_01_reconcile_clinched_active_matches.sql  (MANUAL APPLY)
-- =============================================================================
-- Purpose:
--   Extend reconcile_stuck_match_completions so active clinched matches are also
--   healed (not just all-days-finalized matches).
--
-- Notes:
--   - Manual apply only (do not run from Cursor).
--   - No cron schedule changes here.
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
      AND EXISTS (
        SELECT 1
        FROM public.match_days md
        WHERE md.match_id = m.id
      )
      AND (
        -- Existing fallback path: all scheduled days finalized
        NOT EXISTS (
          SELECT 1
          FROM public.match_days md2
          WHERE md2.match_id = m.id
            AND md2.status IS DISTINCT FROM 'finalized'
        )
        OR
        -- New healing path: clinched from finalized, non-void day wins
        EXISTS (
          SELECT 1
          FROM (
            SELECT md.winner_user_id, COUNT(*)::int AS wins
            FROM public.match_days md
            WHERE md.match_id = m.id
              AND md.status = 'finalized'
              AND md.is_void = false
              AND md.winner_user_id IS NOT NULL
            GROUP BY md.winner_user_id
          ) w
          WHERE w.wins >= ((m.duration_days + 1) / 2)
        )
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
  'Invokes complete-match for active matches where all match_days are finalized OR clinched by finalized day wins, healing partial failures from finalize-match-day.';

