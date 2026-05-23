-- =============================================================================
-- notifications_v1_09_invoke_edge_function_async.sql  (MUTATING — you run)
-- =============================================================================
-- Lets finalize-match-day call downstream Edge functions via Vault JWT (pg_net),
-- same path as lead_changed / evening cron. Run BEFORE deploying finalize-match-day fix.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.invoke_edge_function_async(
  p_function_name text,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, extensions
AS $$
BEGIN
  PERFORM private.invoke_edge_function(p_function_name, p_payload);
END;
$$;

REVOKE ALL ON FUNCTION public.invoke_edge_function_async(text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.invoke_edge_function_async(text, jsonb) TO service_role;
