-- Intraday step ticks — read-only verification (Supabase SQL Editor)
--
-- Run after: intraday_step_ticks_slice1_create_table_rls.sql
-- Does not modify data.

-- Table exists
SELECT EXISTS (
  SELECT 1
  FROM information_schema.tables
  WHERE table_schema = 'public'
    AND table_name = 'user_intraday_step_ticks'
) AS table_exists;

-- Columns
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'user_intraday_step_ticks'
ORDER BY ordinal_position;

-- Indexes
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename = 'user_intraday_step_ticks'
ORDER BY indexname;

-- RLS enabled + policies
SELECT c.relname, c.relrowsecurity AS rls_enabled, c.relforcerowsecurity AS rls_forced
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = 'user_intraday_step_ticks';

SELECT polname, polcmd, polpermissive, pg_get_expr(polqual, polrelid) AS using_expr
FROM pg_policy
WHERE polrelid = 'public.user_intraday_step_ticks'::regclass
ORDER BY polname;

-- Grants (table level)
SELECT grantee, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'public'
  AND table_name = 'user_intraday_step_ticks'
ORDER BY grantee, privilege_type;

-- Row counts (sanity)
SELECT count(*) AS total_rows FROM public.user_intraday_step_ticks;
SELECT user_id, calendar_date, count(*) AS ticks_per_day
FROM public.user_intraday_step_ticks
GROUP BY user_id, calendar_date
ORDER BY ticks_per_day DESC
LIMIT 20;
