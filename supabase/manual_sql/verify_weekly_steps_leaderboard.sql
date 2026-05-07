-- Read-only verification SQL for public.weekly_steps_leaderboard.
-- No writes. Safe for SQL editor.
--
-- Usage:
-- 1) Replace p_week_start with a UTC Monday date.
-- 2) Run all sections.

-- ============================================================================
-- Section 0: Params
-- ============================================================================
with params as (
  select
    '2026-04-27'::date as p_week_start,
    100::int as p_limit
)
select * from params;

-- ============================================================================
-- Section 1: RPC output (global)
-- ============================================================================
with params as (
  select
    '2026-04-27'::date as p_week_start,
    100::int as p_limit
)
select *
from public.weekly_steps_leaderboard(
  (select p_week_start from params),
  (select p_limit from params),
  'global'
);

-- ============================================================================
-- Section 2: RPC output (friends)
-- ============================================================================
with params as (
  select
    '2026-04-27'::date as p_week_start,
    100::int as p_limit
)
select *
from public.weekly_steps_leaderboard(
  (select p_week_start from params),
  (select p_limit from params),
  'friends'
);

-- ============================================================================
-- Section 3: Duplicate snapshot diagnostics by user/day (steps only)
-- ============================================================================
with params as (
  select
    '2026-04-27'::date as p_week_start
)
select
  ms.user_id,
  ms.source_date,
  count(*) as snapshot_count,
  max(ms.synced_at) as latest_sync,
  max(ms.value)::bigint as max_value
from public.metric_snapshots ms
where ms.metric_type = 'steps'
  and ms.flagged = false
  and ms.source_date >= (select p_week_start from params)
  and ms.source_date < ((select p_week_start from params) + interval '7 days')::date
group by ms.user_id, ms.source_date
having count(*) > 1
order by snapshot_count desc, ms.source_date desc
limit 200;
