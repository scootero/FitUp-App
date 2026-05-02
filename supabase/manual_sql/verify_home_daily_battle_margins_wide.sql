-- Wide read-only scan: find suspicious (profile, calendar_date, metric_type) days only.
-- Compares:
--   1) old_summed_margin        = raw join sum of (viewer - opponent) rows
--   2) top_opponent_margin      = max(viewer) - max(opponent)
--   3) new_deduped_sum_margin   = sum of per-(match_day, opponent) pair margins (expected)
-- No raw `match_day_participants` rows returned — summary columns only.
-- Run from Supabase SQL Editor with a privileged role. Not used by the app.

-- ============================================================================
-- Section 0: Params
-- ============================================================================
with params as (
  select 14 as p_day_count
)
select * from params;

-- ============================================================================
-- Section 1: Suspicious rows only (last `p_day_count` calendar days)
-- ============================================================================
with params as (
  select 14 as p_day_count
),
bounds as (
  select
    current_date::date as v_end,
    current_date::date - (p.p_day_count - 1) as v_start
  from params p
),
base as (
  select
    mp_v.user_id as profile_id,
    md.calendar_date::date as calendar_date,
    m.metric_type::text as metric_type,
    md.id as match_day_id,
    coalesce(mdp_v.finalized_value, mdp_v.metric_total)::bigint as viewer_val,
    coalesce(mdp_o.finalized_value, mdp_o.metric_total)::bigint as opponent_val,
    mp_o.user_id as opponent_id,
    (
      coalesce(mdp_v.finalized_value, mdp_v.metric_total)
      - coalesce(mdp_o.finalized_value, mdp_o.metric_total)
    )::bigint as row_margin
  from bounds b
  join public.match_days md
    on md.calendar_date >= b.v_start
   and md.calendar_date <= b.v_end
  join public.matches m
    on m.id = md.match_id
  join public.match_participants mp_v
    on mp_v.match_id = m.id
  join public.match_participants mp_o
    on mp_o.match_id = m.id
   and mp_o.user_id <> mp_v.user_id
  join public.match_day_participants mdp_v
    on mdp_v.match_day_id = md.id
   and mdp_v.user_id = mp_v.user_id
  join public.match_day_participants mdp_o
    on mdp_o.match_day_id = md.id
   and mdp_o.user_id = mp_o.user_id
  where md.is_void = false
    and m.state in ('active', 'completed')
    and m.metric_type in ('steps', 'active_calories')
),
pair_rows as (
  select
    profile_id,
    calendar_date,
    metric_type,
    match_day_id,
    opponent_id,
    max(viewer_val) - max(opponent_val) as pair_margin
  from base
  group by profile_id, calendar_date, metric_type, match_day_id, opponent_id
),
deduped as (
  select
    profile_id,
    calendar_date,
    metric_type,
    coalesce(sum(pair_margin), 0::bigint) as new_deduped_sum_margin
  from pair_rows
  group by profile_id, calendar_date, metric_type
),
agg as (
  select
    profile_id,
    calendar_date,
    metric_type,
    min(viewer_val) as min_viewer,
    max(viewer_val) as max_viewer,
    (
      count(distinct viewer_val)
      + case when bool_or(viewer_val is null) then 1 else 0 end
    ) as distinct_viewer_count,
    (
      (min(viewer_val) is distinct from max(viewer_val))
      or (
        count(*) filter (where viewer_val is null) > 0
        and count(*) filter (where viewer_val is not null) > 0
      )
    ) as viewer_values_inconsistent,
    count(distinct opponent_id) as opponent_count,
    max(opponent_val) as highest_opponent,
    coalesce(sum(row_margin), 0::bigint) as old_summed_margin,
    coalesce(max(viewer_val), 0::bigint) - coalesce(max(opponent_val), 0::bigint) as top_opponent_margin
  from base
  group by profile_id, calendar_date, metric_type
)
select
  a.profile_id,
  a.calendar_date,
  a.metric_type,
  a.min_viewer,
  a.max_viewer,
  a.distinct_viewer_count,
  a.viewer_values_inconsistent,
  a.highest_opponent,
  a.opponent_count,
  a.old_summed_margin,
  a.top_opponent_margin,
  d.new_deduped_sum_margin
from agg a
left join deduped d
  on d.profile_id = a.profile_id
 and d.calendar_date = a.calendar_date
 and d.metric_type = a.metric_type
where a.viewer_values_inconsistent
   or a.old_summed_margin is distinct from d.new_deduped_sum_margin
   or a.top_opponent_margin is distinct from d.new_deduped_sum_margin
order by a.calendar_date desc, a.profile_id, a.metric_type;
