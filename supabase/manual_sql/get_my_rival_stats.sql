-- Slice 4.5b: Safer rival stats RPC (manual SQL editor script)
-- Run this in Supabase SQL Editor (no migration file).
-- This variant does NOT accept profile_id from the client.

create or replace function public.get_my_rival_stats(
  p_limit int default 3
)
returns table (
  opponent_profile_id uuid,
  opponent_display_name text,
  opponent_initials text,
  opponent_avatar_url text,
  finalized_days_competed int,
  match_wins int,
  match_losses int,
  match_ties int,
  win_percentage int,
  avg_finalized_daily_margin numeric,
  last_played_on date,
  active_match_id uuid,
  computed_at timestamptz
)
language plpgsql
stable
security invoker
set search_path to 'public'
as $function$
declare
  v_viewer_profile_id uuid;
  v_limit int;
begin
  v_limit := greatest(1, least(coalesce(p_limit, 3), 50));

  select p.id
  into v_viewer_profile_id
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1;

  -- Return no rows if unauthenticated or profile is missing.
  if v_viewer_profile_id is null then
    return;
  end if;

  return query
  with opponent_matches as (
    -- Mutual matches vs each opponent (active + completed).
    select
      m.id as match_id,
      m.state,
      m.created_at,
      m.completed_at,
      mp_o.user_id as opponent_id
    from public.matches m
    join public.match_participants mp_v
      on mp_v.match_id = m.id
     and mp_v.user_id = v_viewer_profile_id
    join public.match_participants mp_o
      on mp_o.match_id = m.id
     and mp_o.user_id <> v_viewer_profile_id
    where m.state in ('active', 'completed')
  ),
  finalized_days as (
    -- Canonical day grain: finalized, non-void days where both totals are present.
    select
      om.opponent_id,
      md.match_id,
      md.calendar_date,
      coalesce(mdp_v.finalized_value, mdp_v.metric_total)::numeric as viewer_day_total,
      coalesce(mdp_o.finalized_value, mdp_o.metric_total)::numeric as opponent_day_total,
      case when md.winner_user_id = v_viewer_profile_id then 1 else 0 end as viewer_day_win,
      case when md.winner_user_id = om.opponent_id then 1 else 0 end as opponent_day_win
    from opponent_matches om
    join public.match_days md
      on md.match_id = om.match_id
     and md.status = 'finalized'
     and md.is_void = false
    join public.match_day_participants mdp_v
      on mdp_v.match_day_id = md.id
     and mdp_v.user_id = v_viewer_profile_id
    join public.match_day_participants mdp_o
      on mdp_o.match_day_id = md.id
     and mdp_o.user_id = om.opponent_id
    where coalesce(mdp_v.finalized_value, mdp_v.metric_total) is not null
      and coalesce(mdp_o.finalized_value, mdp_o.metric_total) is not null
  ),
  day_rollup as (
    select
      fd.opponent_id,
      count(*)::int as finalized_days_competed,
      avg(fd.viewer_day_total - fd.opponent_day_total) as avg_finalized_daily_margin,
      max(fd.calendar_date) as last_played_on
    from finalized_days fd
    group by fd.opponent_id
  ),
  completed_series as (
    -- Match-level series outcomes (not day-level record).
    select
      om.opponent_id,
      om.match_id,
      coalesce(sum(fd.viewer_day_win), 0)::int as viewer_day_wins,
      coalesce(sum(fd.opponent_day_win), 0)::int as opponent_day_wins
    from opponent_matches om
    left join finalized_days fd
      on fd.match_id = om.match_id
     and fd.opponent_id = om.opponent_id
    where om.state = 'completed'
    group by om.opponent_id, om.match_id
  ),
  series_rollup as (
    select
      cs.opponent_id,
      sum(case when cs.viewer_day_wins > cs.opponent_day_wins then 1 else 0 end)::int as match_wins,
      sum(case when cs.opponent_day_wins > cs.viewer_day_wins then 1 else 0 end)::int as match_losses,
      sum(case when cs.viewer_day_wins = cs.opponent_day_wins then 1 else 0 end)::int as match_ties
    from completed_series cs
    group by cs.opponent_id
  ),
  active_match as (
    -- Optional convenience field for UI affordances.
    select distinct on (om.opponent_id)
      om.opponent_id,
      om.match_id as active_match_id
    from opponent_matches om
    where om.state = 'active'
    order by om.opponent_id, om.created_at desc, om.match_id
  ),
  rivals as (
    select
      dr.opponent_id,
      dr.finalized_days_competed,
      coalesce(sr.match_wins, 0) as match_wins,
      coalesce(sr.match_losses, 0) as match_losses,
      coalesce(sr.match_ties, 0) as match_ties,
      case
        when (coalesce(sr.match_wins, 0) + coalesce(sr.match_losses, 0)) > 0 then
          round(
            (coalesce(sr.match_wins, 0)::numeric
            / (coalesce(sr.match_wins, 0) + coalesce(sr.match_losses, 0))::numeric) * 100
          )::int
        else 0
      end as win_percentage,
      dr.avg_finalized_daily_margin,
      dr.last_played_on
    from day_rollup dr
    left join series_rollup sr
      on sr.opponent_id = dr.opponent_id
  )
  select
    r.opponent_id as opponent_profile_id,
    coalesce(nullif(trim(p.display_name), ''), 'Opponent') as opponent_display_name,
    coalesce(nullif(upper(trim(p.initials)), ''), 'OP') as opponent_initials,
    p.avatar_url as opponent_avatar_url,
    r.finalized_days_competed,
    r.match_wins,
    r.match_losses,
    r.match_ties,
    r.win_percentage,
    round(r.avg_finalized_daily_margin, 2) as avg_finalized_daily_margin,
    r.last_played_on,
    am.active_match_id,
    now() as computed_at
  from rivals r
  join public.profiles p
    on p.id = r.opponent_id
  left join active_match am
    on am.opponent_id = r.opponent_id
  order by
    r.finalized_days_competed desc,
    r.last_played_on desc nulls last,
    r.opponent_id
  limit v_limit;
end;
$function$;

grant execute on function public.get_my_rival_stats(int) to authenticated;

-- Optional index recommendation (only apply after profiling, not required for MVP):
-- create index if not exists md_match_finalized_nonvoid_caldate
--   on public.match_days (match_id, calendar_date desc)
--   where status = 'finalized' and is_void = false;
