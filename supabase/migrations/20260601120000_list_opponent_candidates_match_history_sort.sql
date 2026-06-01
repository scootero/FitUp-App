-- Opponent picker: sort by shared completed match count (frequent rivals first).
-- Must drop first: return type adds past_match_count (CREATE OR REPLACE cannot change OUT columns).

drop function if exists public.list_opponent_candidates(text, text, date, int);

create or replace function public.list_opponent_candidates(
  p_query text default '',
  p_metric_type text default 'steps',
  p_viewer_local_date date default (current_date),
  p_limit int default 15
)
returns table (
  id uuid,
  display_name text,
  initials text,
  wins int,
  losses int,
  today_steps int,
  rolling_avg_7d_steps numeric,
  rolling_avg_7d_calories numeric,
  past_match_count int
)
language plpgsql
stable
security invoker
set search_path to 'public'
as $function$
declare
  v_viewer_id uuid;
  v_my_baseline numeric;
  v_limit int;
  v_query text;
begin
  v_limit := greatest(1, least(coalesce(p_limit, 15), 50));
  v_query := lower(trim(coalesce(p_query, '')));

  select p.id
  into v_viewer_id
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1;

  if v_viewer_id is null then
    return;
  end if;

  select
    case
      when coalesce(p_metric_type, 'steps') = 'active_calories'
        then uhb.rolling_avg_7d_calories
      else uhb.rolling_avg_7d_steps
    end
  into v_my_baseline
  from public.user_health_baselines uhb
  where uhb.user_id = v_viewer_id
  limit 1;

  return query
  with past_matches as (
    select
      mp_o.user_id as opponent_id,
      count(distinct m.id)::int as past_match_count
    from public.matches m
    inner join public.match_participants mp_v
      on mp_v.match_id = m.id and mp_v.user_id = v_viewer_id
    inner join public.match_participants mp_o
      on mp_o.match_id = m.id and mp_o.user_id <> v_viewer_id
    where m.state = 'completed'
    group by mp_o.user_id
  ),
  latest_lb as (
    select distinct on (le.user_id)
      le.user_id,
      le.wins,
      le.losses
    from public.leaderboard_entries le
    order by le.user_id, le.week_start desc
  ),
  today_snap as (
    select distinct on (ms.user_id)
      ms.user_id,
      ms.value::int as today_steps
    from public.metric_snapshots ms
    where ms.metric_type = 'steps'
      and ms.source_date = p_viewer_local_date
    order by ms.user_id, ms.synced_at desc
  ),
  ranked as (
    select
      p.id,
      p.display_name,
      p.initials,
      lb.wins,
      lb.losses,
      ts.today_steps,
      uhb.rolling_avg_7d_steps,
      uhb.rolling_avg_7d_calories,
      coalesce(pm.past_match_count, 0) as past_match_count,
      case
        when coalesce(p_metric_type, 'steps') = 'active_calories' then uhb.rolling_avg_7d_calories
        else uhb.rolling_avg_7d_steps
      end as candidate_baseline,
      case
        when v_my_baseline is not null
          and (
            case
              when coalesce(p_metric_type, 'steps') = 'active_calories'
                then uhb.rolling_avg_7d_calories
              else uhb.rolling_avg_7d_steps
            end
          ) is not null
          then abs(
            (
              case
                when coalesce(p_metric_type, 'steps') = 'active_calories'
                  then uhb.rolling_avg_7d_calories
                else uhb.rolling_avg_7d_steps
              end
            ) - v_my_baseline
          )
        when (
          case
            when coalesce(p_metric_type, 'steps') = 'active_calories'
              then uhb.rolling_avg_7d_calories
            else uhb.rolling_avg_7d_steps
          end
        ) is not null then 10000000::numeric
        when v_my_baseline is not null then 10000001::numeric
        else 10000002::numeric
      end as baseline_distance
    from public.profiles p
    left join public.user_health_baselines uhb on uhb.user_id = p.id
    left join latest_lb lb on lb.user_id = p.id
    left join today_snap ts on ts.user_id = p.id
    left join past_matches pm on pm.opponent_id = p.id
    where p.id <> v_viewer_id
      and (
        v_query = ''
        or lower(coalesce(p.display_name, '')) like '%' || v_query || '%'
      )
  )
  select
    r.id,
    r.display_name,
    r.initials,
    r.wins,
    r.losses,
    r.today_steps,
    r.rolling_avg_7d_steps,
    r.rolling_avg_7d_calories,
    r.past_match_count
  from ranked r
  order by r.past_match_count desc, r.baseline_distance asc, r.display_name asc
  limit v_limit;
end;
$function$;

comment on function public.list_opponent_candidates(text, text, date, int) is
  'Challenge opponent picker: frequent rivals first, then baseline-distance sort. Optional name filter.';
