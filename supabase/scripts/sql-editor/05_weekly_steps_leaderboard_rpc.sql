-- Weekly leaderboard source for the Ranks tab.
-- Returns real Monday-Sunday step totals (UTC week start), deduped to one snapshot per user/day.
-- Scope:
--   p_scope = 'global'  -> all users with >0 weekly steps
--   p_scope = 'friends' -> viewer + accepted friends with >0 weekly steps
-- Copy into Supabase SQL Editor and run (same as migration 20260502154000_weekly_steps_leaderboard_rpc.sql).

create or replace function public.weekly_steps_leaderboard(
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
  latest_daily_snapshots as (
    select
      ms.user_id,
      ms.source_date,
      ms.value::bigint as step_value,
      row_number() over (
        partition by ms.user_id, ms.source_date
        order by ms.synced_at desc, ms.id desc
      ) as rn
    from public.metric_snapshots ms
    inner join scoped_users su
      on su.id = ms.user_id
    where ms.metric_type = 'steps'
      and ms.flagged = false
      and ms.source_date >= v_week_start
      and ms.source_date < (v_week_start + interval '7 days')::date
  ),
  weekly as (
    select
      l.user_id,
      sum(greatest(l.step_value, 0))::bigint as total_steps
    from latest_daily_snapshots l
    where l.rn = 1
    group by l.user_id
    having sum(greatest(l.step_value, 0)) > 0
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

grant execute on function public.weekly_steps_leaderboard(date, integer, text) to authenticated;
