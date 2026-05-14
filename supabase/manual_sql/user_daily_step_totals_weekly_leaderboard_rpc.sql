-- Weekly steps leaderboard from `user_daily_step_totals` (one row per user per calendar day).
-- Same return shape and scope rules as `weekly_steps_leaderboard` (metric_snapshots).
--
-- Run in Supabase SQL Editor after `user_daily_step_totals_create_table_rls.sql`.
-- Client: `LeaderboardRepository` calls this RPC by name.

create or replace function public.weekly_steps_leaderboard_from_daily_totals(
  p_week_start date,
  p_limit integer default 100,
  p_scope text default 'global'
)
returns table(
  user_id uuid,
  display_name text,
  initials text,
  week_start date,
  week_end date,
  total_steps bigint,
  rank integer
)
language plpgsql
stable
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_viewer uuid;
  v_week_start date;
  v_limit int;
  v_scope text;
begin
  select p.id
  into v_viewer
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1;

  if v_viewer is null then
    return;
  end if;

  if p_week_start is null then
    return;
  end if;

  v_week_start := p_week_start;
  v_limit := least(500, greatest(1, coalesce(p_limit, 100)));
  v_scope := case
    when lower(coalesce(p_scope, 'global')) = 'friends' then 'friends'
    else 'global'
  end;

  return query
  with scoped_users as (
    select p.id
    from public.profiles p
    where v_scope = 'global'

    union

    select v_viewer
    where v_scope = 'friends'

    union

    select case
      when f.a_id = v_viewer then f.b_id
      else f.a_id
    end as id
    from public.friendships f
    where v_scope = 'friends'
      and f.status = 'accepted'
      and (f.a_id = v_viewer or f.b_id = v_viewer)
  ),
  weekly as (
    select
      d.user_id,
      sum(greatest(d.steps, 0))::bigint as total_steps
    from public.user_daily_step_totals d
    inner join scoped_users su
      on su.id = d.user_id
    where d.calendar_date >= v_week_start
      and d.calendar_date < (v_week_start + interval '7 days')::date
    group by d.user_id
    having sum(greatest(d.steps, 0)) > 0
  ),
  ranked as (
    select
      w.user_id,
      w.total_steps,
      row_number() over (
        order by w.total_steps desc, w.user_id asc
      )::int as rank
    from weekly w
  )
  select
    r.user_id,
    coalesce(nullif(trim(p.display_name), ''), 'Player') as display_name,
    coalesce(nullif(upper(trim(p.initials)), ''), 'PL') as initials,
    v_week_start as week_start,
    (v_week_start + interval '6 days')::date as week_end,
    r.total_steps,
    r.rank
  from ranked r
  inner join public.profiles p
    on p.id = r.user_id
  order by r.rank
  limit v_limit;
end;
$function$;

grant execute on function public.weekly_steps_leaderboard_from_daily_totals(date, integer, text) to authenticated;

comment on function public.weekly_steps_leaderboard_from_daily_totals(date, integer, text) is
  'Ranks users by sum of user_daily_step_totals.steps for UTC week [p_week_start, p_week_start+7).';
