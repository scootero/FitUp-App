-- FitUp — verify matchmaking pipeline (run in Supabase SQL Editor as postgres / owner)
-- Does not modify data.

-- 1) Trigger on INSERT into match_search_requests
SELECT tgname AS trigger_name,
       pg_get_triggerdef(oid) AS definition
FROM pg_trigger
WHERE tgrelid = 'public.match_search_requests'::regclass
  AND NOT tgisinternal
ORDER BY tgname;

-- 2) Functions exist
SELECT proname
FROM pg_proc
JOIN pg_namespace n ON n.oid = pg_proc.pronamespace
WHERE n.nspname = 'public'
  AND proname IN ('matchmaking_pair_atomic', 'activate_match_with_days', 'matchmaking_retry_stale_searches')
ORDER BY proname;

SELECT p.proname
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'private'
  AND p.proname = 'invoke_matchmaking_pairing';

-- 3) Vault secrets (names only — values hidden)
SELECT name
FROM vault.decrypted_secrets
WHERE name IN ('fitup_project_url', 'fitup_service_role_key')
ORDER BY name;

-- 4) pg_cron job for stale retries (after slice4b)
SELECT jobname, schedule, command
FROM cron.job
WHERE jobname IN ('matchmaking-retry-stale', 'day-cutoff-check')
ORDER BY jobname;

-- 5) pg_net tables (names vary by version — list first)
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'net'
ORDER BY table_name;

-- If your project has a response/history table (example — uncomment and fix name if needed):
-- SELECT * FROM net._http_response ORDER BY created DESC LIMIT 20;
