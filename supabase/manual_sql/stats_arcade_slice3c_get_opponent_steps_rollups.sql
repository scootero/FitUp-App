-- Slice 3C (manual SQL): opponent step rollups for Stats Arcade "Opponents vs You".
-- Run manually in Supabase SQL Editor. Do not run from the app/agent.
--
-- If the return shape changes later, DROP first (same 42P13 lesson as get_my_rival_stats):
--   DROP FUNCTION IF EXISTS public.get_stats_opponent_steps_rollups();

create or replace function public.get_stats_opponent_steps_rollups()
returns jsonb
language plpgsql
stable
security invoker
set search_path to 'public'
as $function$
declare
  v_viewer_profile_id uuid;
  v_tz text;
  v_today date;
  v_month_start date;
  v_lifetime bigint := 0;
  v_rolling_365d bigint := 0;
  v_current_month bigint := 0;
begin
  select
    p.id,
    coalesce(nullif(trim(p.timezone), ''), 'UTC')
  into v_viewer_profile_id, v_tz
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1;

  if v_viewer_profile_id is null then
    return jsonb_build_object(
      'lifetime_steps', 0,
      'rolling_365d_steps', 0,
      'current_month_steps', 0,
      'computed_at', now()
    );
  end if;

  v_today := (now() at time zone v_tz)::date;
  v_month_start := date_trunc('month', v_today::timestamp)::date;

  with viewer_step_matches as (
    select m.id as match_id
    from public.matches m
    join public.match_participants mp_v
      on mp_v.match_id = m.id
     and mp_v.user_id = v_viewer_profile_id
    where m.metric_type = 'steps'
      and m.state in ('active', 'completed')
  ),
  battle_day_rows as (
    select
      md.calendar_date,
      greatest(
        0,
        coalesce(mdp_o.finalized_value, mdp_o.metric_total)::bigint
      ) as opponent_steps
    from viewer_step_matches vsm
    join public.match_days md
      on md.match_id = vsm.match_id
     and md.status = 'finalized'
     and md.is_void = false
    join public.match_participants mp_o
      on mp_o.match_id = vsm.match_id
     and mp_o.user_id <> v_viewer_profile_id
    join public.match_day_participants mdp_v
      on mdp_v.match_day_id = md.id
     and mdp_v.user_id = v_viewer_profile_id
    join public.match_day_participants mdp_o
      on mdp_o.match_day_id = md.id
     and mdp_o.user_id = mp_o.user_id
    where coalesce(mdp_v.finalized_value, mdp_v.metric_total) is not null
      and coalesce(mdp_o.finalized_value, mdp_o.metric_total) is not null
  )
  select
    coalesce(sum(bdr.opponent_steps), 0)::bigint,
    coalesce(
      sum(bdr.opponent_steps) filter (
        where bdr.calendar_date >= v_today - 364
      ),
      0
    )::bigint,
    coalesce(
      sum(bdr.opponent_steps) filter (
        where bdr.calendar_date >= v_month_start
          and bdr.calendar_date <= v_today
      ),
      0
    )::bigint
  into v_lifetime, v_rolling_365d, v_current_month
  from battle_day_rows bdr;

  return jsonb_build_object(
    'lifetime_steps', v_lifetime,
    'rolling_365d_steps', v_rolling_365d,
    'current_month_steps', v_current_month,
    'computed_at', now()
  );
end;
$function$;

grant execute on function public.get_stats_opponent_steps_rollups() to authenticated;
