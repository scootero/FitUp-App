-- =============================================================================
-- notifications_v1_08_retry_finalize_stuck_day.sql  (MUTATING — you run)
-- =============================================================================
-- Run AFTER:
--   1) notifications_v1_09_invoke_edge_function_async.sql
--   2) supabase functions deploy finalize-match-day
-- =============================================================================

-- Preview stuck days (calendar date before today in America/New_York)
SELECT md.id AS match_day_id, md.match_id, md.day_number, md.calendar_date, md.status
FROM match_days md
JOIN matches m ON m.id = md.match_id
WHERE m.state = 'active'
  AND md.status <> 'finalized'
  AND md.calendar_date < (current_date AT TIME ZONE 'America/New_York')::date
ORDER BY md.match_id, md.day_number;

-- Invoke finalize for each stuck day (uncomment one line per match_day_id from preview)
-- SELECT private.invoke_finalize_match_day('PASTE_MATCH_DAY_UUID_HERE'::uuid);
