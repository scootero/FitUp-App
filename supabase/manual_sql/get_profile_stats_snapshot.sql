-- Slice 4C: Stats page snapshot RPC (manual SQL editor script)
-- Run this in Supabase SQL Editor (no migration file).

create or replace function public.get_profile_stats_snapshot(
  p_range_key text,
  p_metric_type text default 'steps'
)
returns jsonb
language plpgsql
stable
security invoker
set search_path to 'public'
as $function$
declare
  v_effective_range_key text;
  v_day_count int;
  v_range_support text;
  v_margins jsonb := '[]'::jsonb;
  v_previous_margins jsonb := '[]'::jsonb;
  v_battle jsonb := '{}'::jsonb;
  v_net_margin bigint := 0;
  v_previous_net_margin bigint := 0;
  v_previous_period_percent int := 0;
begin
  if coalesce(p_metric_type, '') not in ('steps', 'active_calories') then
    return jsonb_build_object(
      'range_key', coalesce(p_range_key, '30D'),
      'effective_range_key', '30D',
      'scope_flags', jsonb_build_object(
        'battle_stats_scope', 'lifetime',
        'range_support', 'fallback'
      ),
      'summary', jsonb_build_object(
        'net_margin', 0,
        'wins', 0,
        'losses', 0,
        'ties', 0,
        'win_rate_percent', 0,
        'current_streak_type', 'none',
        'current_streak_count', 0
      ),
      'chart', jsonb_build_object('points', '[]'::jsonb)
    );
  end if;

  if p_range_key = '1D' then
    v_effective_range_key := '1D';
    v_day_count := 1;
    v_range_support := 'native';
  elsif p_range_key = '7D' then
    v_effective_range_key := '7D';
    v_day_count := 7;
    v_range_support := 'native';
  elsif p_range_key = '30D' then
    v_effective_range_key := '30D';
    v_day_count := 30;
    v_range_support := 'native';
  else
    -- Current margin RPC supports up to 31 days. Until expanded backend support lands,
    -- keep this explicit and return 30D data for unsupported ranges.
    v_effective_range_key := '30D';
    v_day_count := 30;
    v_range_support := 'fallback';
  end if;

  v_margins := coalesce(
    public.home_daily_battle_margins(current_date, v_day_count, p_metric_type),
    '[]'::jsonb
  );
  v_previous_margins := coalesce(
    public.home_daily_battle_margins((current_date - v_day_count), v_day_count, p_metric_type),
    '[]'::jsonb
  );
  v_battle := coalesce(public.health_battle_stats(), '{}'::jsonb);

  select coalesce(sum((e ->> 'margin')::bigint), 0)
  into v_net_margin
  from jsonb_array_elements(v_margins) as e;
  select coalesce(sum((e ->> 'margin')::bigint), 0)
  into v_previous_net_margin
  from jsonb_array_elements(v_previous_margins) as e;

  if v_previous_net_margin = 0 then
    if v_net_margin > 0 then
      v_previous_period_percent := 100;
    elsif v_net_margin < 0 then
      v_previous_period_percent := -100;
    else
      v_previous_period_percent := 0;
    end if;
  else
    v_previous_period_percent := round(
      ((v_net_margin - v_previous_net_margin)::numeric / abs(v_previous_net_margin)::numeric) * 100
    )::int;
  end if;

  return jsonb_build_object(
    'range_key', coalesce(p_range_key, '30D'),
    'effective_range_key', v_effective_range_key,
    'saved_at', now(),
    'scope_flags', jsonb_build_object(
      'battle_stats_scope', 'lifetime',
      'range_support', v_range_support
    ),
    'summary', jsonb_build_object(
      'net_margin', v_net_margin,
      'previous_period_percent', v_previous_period_percent,
      'wins', coalesce((v_battle ->> 'wins')::int, 0),
      'losses', coalesce((v_battle ->> 'losses')::int, 0),
      'ties', coalesce((v_battle ->> 'ties')::int, 0),
      'win_rate_percent', coalesce((v_battle ->> 'win_rate')::int, 0),
      'current_streak_type', coalesce(v_battle ->> 'current_streak_type', 'none'),
      'current_streak_count', coalesce((v_battle ->> 'current_streak_count')::int, 0)
    ),
    'chart', jsonb_build_object(
      'unit', p_metric_type,
      'points', v_margins
    ),
    'personal_bests', jsonb_build_object(
      'battle_win_streak_days', coalesce((v_battle ->> 'current_streak_count')::int, 0),
      'biggest_comeback_day_deficit_recovered', null,
      'biggest_comeback_series_net_swing', null
    )
  );
end;
$function$;

grant execute on function public.get_profile_stats_snapshot(text, text) to authenticated;
