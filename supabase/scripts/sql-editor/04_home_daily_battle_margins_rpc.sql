-- Home: per-calendar-day net margin = SUM over matches of (your total − opponent total) for that day.
-- Each (match_day × opponent) pair is counted once (dedupes duplicate participant/join rows).
-- Copy into Supabase SQL Editor and run (same as migration 20260428120000_home_daily_battle_margins_rpc.sql).

create or replace function public.home_daily_battle_margins(
  p_end_date date,
  p_day_count integer,
  p_metric_type text
)
returns jsonb
language plpgsql
stable
security invoker
set search_path to 'public'
as $function$
declare
  v_viewer uuid;
  v_start date;
  v_count int;
begin
  if p_metric_type is null
     or p_metric_type not in ('steps', 'active_calories') then
    return '[]'::jsonb;
  end if;

  if p_end_date is null then
    return '[]'::jsonb;
  end if;

  v_count := least(31, greatest(1, coalesce(p_day_count, 7)));

  select p.id
  into v_viewer
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1;

  if v_viewer is null then
    return '[]'::jsonb;
  end if;

  v_start := p_end_date - (v_count - 1);

  return (
    with days as (
      select gs::date as cal_date
      from generate_series(v_start, p_end_date, interval '1 day') as gs
    ),
    daily as (
      select
        d.cal_date,
        coalesce((
          select coalesce(sum(pair_margin), 0::bigint)
          from (
            select
              max(coalesce(mdp_v.finalized_value, mdp_v.metric_total))::bigint
              - max(coalesce(mdp_o.finalized_value, mdp_o.metric_total))::bigint as pair_margin
            from public.match_days md
            inner join public.matches m on m.id = md.match_id
            inner join public.match_participants mp_v
              on mp_v.match_id = m.id
             and mp_v.user_id = v_viewer
            inner join public.match_participants mp_o
              on mp_o.match_id = m.id
             and mp_o.user_id <> mp_v.user_id
            inner join public.match_day_participants mdp_v
              on mdp_v.match_day_id = md.id
             and mdp_v.user_id = mp_v.user_id
            inner join public.match_day_participants mdp_o
              on mdp_o.match_day_id = md.id
             and mdp_o.user_id = mp_o.user_id
            where md.calendar_date = d.cal_date
              and md.is_void = false
              and m.state in ('active', 'completed')
              and m.metric_type = p_metric_type
            group by md.id, mp_o.user_id
          ) pair_rows
        ), 0::bigint) as margin
      from days d
    )
    select coalesce(
      jsonb_agg(
        jsonb_build_object(
          'date', cal_date,
          'margin', margin
        )
        order by cal_date
      ),
      '[]'::jsonb
    )
    from daily
  );
end;
$function$;

grant execute on function public.home_daily_battle_margins(date, integer, text) to authenticated;
