-- =============================================================================
-- notifications_v1_00_readonly_checks.sql  (READ-ONLY)
-- =============================================================================
-- Run in Supabase SQL Editor before Notifications v1 deploy.
-- Forbidden: INSERT/UPDATE/DELETE/DDL/cron.schedule/Vault writes.
-- =============================================================================

-- 0) Sanity
SELECT current_database() AS db, current_user AS role, now() AS server_now;

-- 1) Notification-related cron jobs
SELECT jobid, jobname, schedule, active, left(command::text, 400) AS command_preview
FROM cron.job
WHERE jobname IN (
  'send-morning-checkins',
  'send-evening-checkins',
  'send-pending-reminders',
  'send-daily-recap',
  'day-cutoff-check'
)
   OR command::text ILIKE '%send-daily-recap%'
   OR command::text ILIKE '%send-morning%'
   OR command::text ILIKE '%send-evening%'
ORDER BY jobname;

-- 2) Recent cron failures (notification-related jobnames)
SELECT j.jobname, d.status, left(d.return_message::text, 400) AS msg, d.start_time
FROM cron.job_run_details d
JOIN cron.job j ON j.jobid = d.jobid
WHERE j.jobname ILIKE 'send-%' OR j.jobname = 'day-cutoff-check'
  AND d.status IS DISTINCT FROM 'succeeded'
ORDER BY d.start_time DESC NULLS LAST
LIMIT 30;

-- 3) Required functions exist
SELECT n.nspname AS schema, p.proname AS name
FROM pg_proc p
JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE (n.nspname = 'public' AND p.proname IN (
    'notify_lead_changed',
    'evening_checkin_candidates',
    'day_cutoff_check'
  ))
   OR (n.nspname = 'private' AND p.proname IN (
    'invoke_edge_function',
    'invoke_dispatch_notification'
  ))
ORDER BY 1, 2;

-- 4) notify_lead_changed includes scoring_mode in payload (Balanced copy)
SELECT
  pg_get_functiondef('public.notify_lead_changed()'::regprocedure) ILIKE '%scoring_mode%' AS lead_fn_has_scoring_mode;

-- 5) notification_events volume (7d)
SELECT event_type, status, count(*) AS n
FROM notification_events
WHERE created_at >= now() - interval '7 days'
GROUP BY event_type, status
ORDER BY n DESC;

-- 6) lead_changed spam risk (24h, sent)
SELECT user_id, count(*) AS lead_sent_24h
FROM notification_events
WHERE event_type = 'lead_changed'
  AND status = 'sent'
  AND sent_at >= now() - interval '24 hours'
GROUP BY user_id
HAVING count(*) > 2
ORDER BY lead_sent_24h DESC
LIMIT 20;

-- 7) Active match sample (recap data)
SELECT
  m.id AS match_id,
  m.state,
  m.metric_type,
  m.scoring_mode,
  m.duration_days,
  md.day_number,
  md.status AS day_status,
  md.calendar_date,
  mdp.user_id,
  mdp.metric_total,
  mdp.finalized_value,
  mdp.last_updated_at
FROM matches m
JOIN match_days md ON md.match_id = m.id
JOIN match_day_participants mdp ON mdp.match_day_id = md.id
WHERE m.state = 'active'
ORDER BY mdp.last_updated_at DESC NULLS LAST
LIMIT 12;

-- 8) APNs token readiness
SELECT
  count(*) FILTER (WHERE apns_token IS NOT NULL AND length(trim(apns_token)) > 0) AS with_apns,
  count(*) FILTER (WHERE apns_token IS NULL OR length(trim(coalesce(apns_token, ''))) = 0) AS without_apns,
  count(*) AS total_profiles
FROM profiles;

-- 9) Vault secret names (existence only)
SELECT name
FROM vault.secrets
WHERE name IN ('fitup_project_url', 'fitup_service_role_key')
ORDER BY name;
