-- app_logs — optional retention (manual run in Supabase SQL Editor)
--
-- Follow: FitUp/docs/sql-cmd-instructions.md
--
-- Deletes diagnostic rows older than 14 days. Dev Tools only fetches the latest 200
-- rows per user, so older rows are safe to prune once exported if needed.
--
-- HUMAN:
--   • Safe to re-run periodically (e.g. weekly) or wire to pg_cron later.
--   • Run `VACUUM (ANALYZE) public.app_logs;` after a large first purge to reclaim disk.
--
-- Optional: inspect before delete
--   SELECT date_trunc('day', created_at)::date AS day, count(*)
--   FROM public.app_logs
--   WHERE created_at < (now() - interval '14 days')
--   GROUP BY 1 ORDER BY 1;
--
-- Optional: one-time aggressive purge (7 days) — uncomment and adjust interval if needed:
--   DELETE FROM public.app_logs WHERE created_at < (now() - interval '7 days');

BEGIN;

DELETE FROM public.app_logs
WHERE created_at < (now() - interval '14 days');

COMMIT;

-- Reclaim space after a large delete (run separately; may take a moment on free tier):
-- VACUUM (ANALYZE) public.app_logs;
