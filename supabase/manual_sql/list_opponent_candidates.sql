-- =============================================================================
-- list_opponent_candidates.sql  (manual — paste into Supabase SQL Editor)
-- =============================================================================
-- Challenge flow opponent picker: one round-trip, baseline-distance sort,
-- optional name search, today's steps + latest W/L.
--
-- Prerequisite: authenticated app users with rows in public.profiles.
-- Does NOT modify tables. Creates/replaces one RPC only.
--
-- After apply: run list_opponent_candidates_00_readonly_checks.sql
-- Rollback: DROP FUNCTION IF EXISTS public.list_opponent_candidates(text, text, date, int);
-- =============================================================================

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
  rolling_avg_7d_calories numeric
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
  with latest_lb as (
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
    r.rolling_avg_7d_calories
  from ranked r
  order by r.baseline_distance asc, r.display_name asc
  limit v_limit;
end;
$function$;

revoke all on function public.list_opponent_candidates(text, text, date, int) from public;
grant execute on function public.list_opponent_candidates(text, text, date, int) to authenticated;

comment on function public.list_opponent_candidates(text, text, date, int) is
  'Challenge opponent picker: skill-sorted candidates with optional name filter. Caller passes viewer local calendar date for today steps.';
