-- Safety net: complete-match is invoked at the end of finalize-match-day, but that HTTP
-- call can fail after match_days is already finalized. This job finds active matches
-- where every day is finalized and re-invokes complete-match (idempotent).

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

-- Every 10 minutes; normal runs process zero rows.
SELECT cron.schedule(
  'reconcile-stuck-match-completions',
  '*/10 * * * *',
  $$ SELECT public.reconcile_stuck_match_completions(); $$
);
