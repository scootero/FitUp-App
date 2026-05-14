-- Intraday step ticks — Slice 1: optional retention (manual run in Supabase SQL Editor)
--
-- Follow: FitUp/docs/sql-cmd-instructions.md
--
-- Deletes rows whose calendar_date is **strictly older** than 7 days before **today (UTC date)**.
-- Rationale: ticks are keyed by writer-local calendar_date; using UTC midnight for the cutoff is a
-- simple ops default. Adjust the interval or use profiles.timezone in a cron job later if needed.
--
-- HUMAN:
--   • Run only AFTER `intraday_step_ticks_slice1_create_table_rls.sql` has been applied.
--   • Safe to re-run periodically (e.g. weekly) or wire to pg_cron later — not automated here.
--
-- Optional: inspect before delete
--   SELECT calendar_date, count(*) FROM public.user_intraday_step_ticks
--   WHERE calendar_date < (current_date - interval '7 days')
--   GROUP BY 1 ORDER BY 1;

BEGIN;

DELETE FROM public.user_intraday_step_ticks
WHERE calendar_date < (CURRENT_DATE - interval '7 days');

COMMIT;
