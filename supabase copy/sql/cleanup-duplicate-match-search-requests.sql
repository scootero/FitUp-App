-- One-time maintenance: cancel extra `searching` rows per creator (keeps the newest per metric/duration/start_mode).
-- Run manually in SQL Editor when duplicate queue rows exist. Review results before running in production.

WITH ranked AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY creator_id, metric_type, duration_days, start_mode
           ORDER BY created_at DESC
         ) AS rn
  FROM match_search_requests
  WHERE status = 'searching'
)
UPDATE match_search_requests AS m
SET status = 'cancelled'
FROM ranked AS r
WHERE m.id = r.id
  AND r.rn > 1;
