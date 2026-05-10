-- Home: per-calendar-day net margin = (you − closest relevant opponent) at end-of-day.
-- If you're behind, compare to the nearest opponent ahead.
-- If you're leading/tied, compare to the nearest opponent behind (fallback to max opponent if needed).
-- Uses CTEs only — no nested aggregates (Postgres rejects max inside min, etc.).
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
    pair_rows as (
      select
        md.calendar_date as cal_date,
        max(coalesce(mdp_v.finalized_value, mdp_v.metric_total))::bigint as viewer_total,
        max(coalesce(mdp_o.finalized_value, mdp_o.metric_total))::bigint as opponent_total
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
      where md.calendar_date between v_start and p_end_date
        and md.is_void = false
        and m.state in ('active', 'completed')
        and m.metric_type = p_metric_type
      group by md.calendar_date, md.id, mp_o.user_id
    ),
    day_my as (
      select
        cal_date,
        max(viewer_total) as my_total
      from pair_rows
      group by cal_date
    ),
    day_ref as (
      select
        pr.cal_date,
        dm.my_total,
        min(pr.opponent_total) filter (
          where pr.opponent_total is not null
            and pr.opponent_total > dm.my_total
        ) as nearest_ahead,
        max(pr.opponent_total) filter (
          where pr.opponent_total is not null
            and pr.opponent_total <= dm.my_total
        ) as nearest_behind,
        max(pr.opponent_total) filter (where pr.opponent_total is not null) as max_opponent_total
      from pair_rows pr
      inner join day_my dm on dm.cal_date = pr.cal_date
      group by pr.cal_date, dm.my_total
    ),
    daily as (
      select
        d.cal_date,
        coalesce(
          case
            when dr.cal_date is null then 0::bigint
            when dr.nearest_ahead is not null then dr.my_total - dr.nearest_ahead
            when dr.nearest_behind is not null then dr.my_total - dr.nearest_behind
            when dr.max_opponent_total is not null then dr.my_total - dr.max_opponent_total
            else 0::bigint
          end,
          0::bigint
        ) as margin
      from days d
      left join day_ref dr on dr.cal_date = d.cal_date
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
