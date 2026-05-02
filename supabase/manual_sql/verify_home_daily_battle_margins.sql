-- Read-only diagnostics for `public.home_daily_battle_margins` (Home battle margin chart).
-- Compares OLD behavior (sum of viewer − opponent per opponent row) vs NEW (max viewer − max opponent).
-- No writes. Safe to run in SQL Editor.
--
-- Usage:
-- 1) Replace params below: p_profile_id (profiles.id), optional p_metric_type, p_end_date, p_day_count.
-- 2) Run Section 0 optionally, then Section 1.
--
-- Interpretation:
-- - viewer_inconsistent: true if your stored viewer total differs across rows for that day (includes NULL vs non-NULL).
-- - summed_minus_top_margin_delta: how much the OLD summed margin overstated vs top-opponent margin (large when opponent_count > 1).

-- ============================================================================
-- Section 0: Params only (optional sanity check)
-- ============================================================================
with params as (
  select
    '00000000-0000-0000-0000-000000000000'::uuid as p_profile_id,
    'steps'::text as p_metric_type,
    current_date::date as p_end_date,
    7 as p_day_count
)
select * from params;

-- ============================================================================
-- Section 1: Per-calendar-day margin breakdown (same joins/filters as the RPC)
-- ============================================================================
with params as (
  select
    '00000000-0000-0000-0000-000000000000'::uuid as p_profile_id,
    'steps'::text as p_metric_type,
    current_date::date as p_end_date,
    7 as p_day_count
),
bounds as (
  select
    p.p_profile_id,
    p.p_metric_type,
    p.p_end_date,
    least(31, greatest(1, coalesce(p.p_day_count, 7))) as v_count,
    p.p_end_date
      - (least(31, greatest(1, coalesce(p.p_day_count, 7))) - 1) as v_start
  from params p
),
days as (
  select gs::date as cal_date
  from bounds b
  cross join lateral generate_series(b.v_start, b.p_end_date, interval '1 day') as gs
),
base as (
  select
    md.calendar_date as cal_date,
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
   and md.calendar_date <= b.p_end_date
  join public.matches m
    on m.id = md.match_id
  join public.match_participants mp_v
    on mp_v.match_id = m.id
   and mp_v.user_id = b.p_profile_id
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
    and m.metric_type = b.p_metric_type
),
agg as (
  select
    cal_date,
    min(viewer_val) as viewer_min,
    max(viewer_val) as viewer_max,
    (
      count(distinct viewer_val)
      + case when bool_or(viewer_val is null) then 1 else 0 end
    ) as viewer_distinct,
    (
      (min(viewer_val) is distinct from max(viewer_val))
      or (
        count(*) filter (where viewer_val is null) > 0
        and count(*) filter (where viewer_val is not null) > 0
      )
    ) as viewer_inconsistent,
    count(distinct opponent_id) as opponent_count,
    max(opponent_val) as highest_opponent_value,
    coalesce(sum(row_margin), 0::bigint) as old_summed_margin,
    coalesce(max(viewer_val), 0::bigint) - coalesce(max(opponent_val), 0::bigint) as new_top_opponent_margin
  from base
  group by cal_date
)
select
  d.cal_date,
  a.viewer_min,
  a.viewer_max,
  a.viewer_distinct,
  coalesce(a.viewer_inconsistent, false) as viewer_inconsistent,
  a.highest_opponent_value,
  coalesce(a.opponent_count, 0::bigint) as opponent_count,
  coalesce(a.old_summed_margin, 0::bigint) as old_summed_margin,
  coalesce(a.new_top_opponent_margin, 0::bigint) as new_top_opponent_margin,
  coalesce(a.old_summed_margin, 0::bigint) - coalesce(a.new_top_opponent_margin, 0::bigint)
    as summed_minus_top_margin_delta
from days d
left join agg a
  on a.cal_date = d.cal_date
order by d.cal_date;
