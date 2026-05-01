-- Read-only diagnostics for Home hero/top-circle data path.
-- No writes. Safe to run in SQL Editor.
--
-- Usage:
-- 1) Replace the UUID in params.p_profile_id with the viewer profile id.
-- 2) Run each section independently or all at once.

-- ============================================================================
-- Section 0: Set viewer profile id (required)
-- ============================================================================
with params as (
  select '00000000-0000-0000-0000-000000000000'::uuid as p_profile_id
)
select p_profile_id as viewer_profile_id
from params;

-- ============================================================================
-- Section 1: Minimal hero payload (single compact query shape)
-- Returns exactly what the top circle needs for the active match:
-- - match id/state/metric/duration
-- - opponent id/name
-- - today day row + my/opponent totals
-- - per-side freshness timestamps from match_day_participants.last_updated_at
-- ============================================================================
with params as (
  select '00000000-0000-0000-0000-000000000000'::uuid as p_profile_id
),
my_matches as (
  select m.id, m.state, m.metric_type, m.duration_days, m.created_at
  from public.matches m
  join public.match_participants mp
    on mp.match_id = m.id
  join params p
    on mp.user_id = p.p_profile_id
  where m.state = 'active'
  order by m.created_at desc
  limit 1
),
opp as (
  select
    mm.id as match_id,
    mp.user_id as opponent_id
  from my_matches mm
  join public.match_participants mp
    on mp.match_id = mm.id
  join params p
    on mp.user_id <> p.p_profile_id
  limit 1
),
today_day as (
  select md.*
  from public.match_days md
  join my_matches mm
    on mm.id = md.match_id
  where md.calendar_date = current_date
  order by md.day_number desc
  limit 1
)
select
  mm.id as match_id,
  mm.state,
  mm.metric_type,
  mm.duration_days,
  td.id as match_day_id,
  td.day_number,
  td.calendar_date,
  td.status as match_day_status,
  o.opponent_id,
  coalesce(pr.display_name, 'Opponent') as opponent_display_name,
  coalesce(mdp_me.finalized_value, mdp_me.metric_total, 0)::int as my_today_total,
  coalesce(mdp_opp.finalized_value, mdp_opp.metric_total, 0)::int as opponent_today_total,
  mdp_me.last_updated_at as my_last_updated_at,
  mdp_opp.last_updated_at as opponent_last_updated_at,
  extract(epoch from (now() - mdp_me.last_updated_at))::int as my_seconds_since_update,
  extract(epoch from (now() - mdp_opp.last_updated_at))::int as opponent_seconds_since_update
from my_matches mm
left join today_day td
  on td.match_id = mm.id
left join params p
  on true
left join opp o
  on o.match_id = mm.id
left join public.profiles pr
  on pr.id = o.opponent_id
left join public.match_day_participants mdp_me
  on mdp_me.match_day_id = td.id
 and mdp_me.user_id = p.p_profile_id
left join public.match_day_participants mdp_opp
  on mdp_opp.match_day_id = td.id
 and mdp_opp.user_id = o.opponent_id;

-- ============================================================================
-- Section 2: Freshness lag (today row, both users)
-- Helps explain "opponent showed 0 for minutes" by showing update staleness.
-- ============================================================================
with params as (
  select '00000000-0000-0000-0000-000000000000'::uuid as p_profile_id
),
active_match as (
  select m.id
  from public.matches m
  join public.match_participants mp
    on mp.match_id = m.id
  join params p
    on mp.user_id = p.p_profile_id
  where m.state = 'active'
  order by m.created_at desc
  limit 1
),
today_day as (
  select md.id
  from public.match_days md
  join active_match am
    on am.id = md.match_id
  where md.calendar_date = current_date
  order by md.day_number desc
  limit 1
)
select
  mdp.user_id,
  coalesce(mdp.finalized_value, mdp.metric_total, 0)::int as total_for_today,
  mdp.last_updated_at,
  extract(epoch from (now() - mdp.last_updated_at))::int as seconds_since_update
from public.match_day_participants mdp
join today_day td
  on td.id = mdp.match_day_id
order by seconds_since_update desc;

-- ============================================================================
-- Section 3: Sync pipeline evidence (recent writes)
-- Confirms whether user/opponent writes reached DB recently.
-- ============================================================================
with params as (
  select '00000000-0000-0000-0000-000000000000'::uuid as p_profile_id
),
active_match as (
  select m.id as match_id
  from public.matches m
  join public.match_participants mp
    on mp.match_id = m.id
  join params p
    on mp.user_id = p.p_profile_id
  where m.state = 'active'
  order by m.created_at desc
  limit 1
),
match_users as (
  select mp.user_id
  from public.match_participants mp
  join active_match am
    on am.match_id = mp.match_id
)
select
  ms.match_id,
  ms.user_id,
  ms.metric_type,
  ms.value::int as value,
  ms.source_date,
  ms.synced_at,
  ms.metadata
from public.metric_snapshots ms
join active_match am
  on am.match_id = ms.match_id
join match_users mu
  on mu.user_id = ms.user_id
where ms.source_date = current_date
order by ms.synced_at desc
limit 50;

-- ============================================================================
-- Section 4: Home perf logs (from app_logs)
-- Reads recent home_first_render/home_data_loaded measurements.
-- ============================================================================
with params as (
  select '00000000-0000-0000-0000-000000000000'::uuid as p_profile_id
)
select
  al.created_at,
  al.category,
  al.message,
  al.metadata ->> 'elapsed_ms_from_first_render' as elapsed_ms_from_first_render,
  al.metadata
from public.app_logs al
join params p
  on al.user_id = p.p_profile_id
where al.category = 'home_perf'
  and al.message in ('home_first_render', 'home_data_loaded')
order by al.created_at desc
limit 50;

-- ============================================================================
-- Section 5: Health sync logs (for correlation with Home staleness)
-- ============================================================================
with params as (
  select '00000000-0000-0000-0000-000000000000'::uuid as p_profile_id
)
select
  al.created_at,
  al.category,
  al.message,
  al.metadata ->> 'trigger' as trigger,
  al.metadata ->> 'duration_ms' as duration_ms,
  al.metadata ->> 'steps_today' as steps_today,
  al.metadata ->> 'active_calories_today' as active_calories_today,
  al.metadata
from public.app_logs al
join params p
  on al.user_id = p.p_profile_id
where al.category in ('healthkit_sync', 'healthkit_read')
  and al.message in ('metric sync started', 'metric sync finished', 'today steps read', 'today active calories read')
order by al.created_at desc
limit 100;
