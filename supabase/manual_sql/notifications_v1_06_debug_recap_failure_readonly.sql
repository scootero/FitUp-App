-- =============================================================================
-- notifications_v1_06_debug_recap_failure_readonly.sql  (READ-ONLY)
-- =============================================================================
-- Run in Supabase SQL Editor to diagnose missing yesterday_recap.
-- =============================================================================

SELECT now() AS server_now;

-- 1) Any yesterday_recap events recently?
SELECT event_type, status, count(*) AS n, max(created_at) AS latest
FROM notification_events
WHERE event_type = 'yesterday_recap'
  AND created_at >= now() - interval '7 days'
GROUP BY event_type, status
ORDER BY latest DESC;

-- 2) Today's notification attempts (all types)
SELECT event_type, status, count(*) AS n, max(created_at) AS latest
FROM notification_events
WHERE created_at >= date_trunc('day', now())
GROUP BY event_type, status
ORDER BY n DESC;

-- 3) Match days for active matches (stuck pending = recap blocker)
SELECT
  m.id AS match_id,
  m.state,
  m.duration_days,
  md.day_number,
  md.calendar_date,
  md.status,
  md.finalized_at,
  md.winner_user_id
FROM matches m
JOIN match_days md ON md.match_id = m.id
WHERE m.state = 'active'
ORDER BY m.id, md.day_number;

-- 4) pg_net responses for finalize / leaderboard (if table exists)
SELECT EXISTS (
  SELECT 1 FROM information_schema.tables
  WHERE table_schema = 'net' AND table_name = '_http_response'
) AS net_http_response_exists;

SELECT id, status_code, left(coalesce(content::text, error_msg::text, ''), 400) AS body_preview, created
FROM net._http_response
WHERE created >= now() - interval '24 hours'
  AND (
    content::text ILIKE '%finalize-match-day%'
    OR content::text ILIKE '%update-leaderboard%'
    OR status_code >= 400
  )
ORDER BY created DESC
LIMIT 25;

-- 5) Recent cron runs
SELECT j.jobname, d.status, d.start_time, left(d.return_message::text, 300) AS msg
FROM cron.job_run_details d
JOIN cron.job j ON j.jobid = d.jobid
WHERE j.jobname IN ('send-daily-recap', 'day-cutoff-check')
ORDER BY d.start_time DESC
LIMIT 15;
