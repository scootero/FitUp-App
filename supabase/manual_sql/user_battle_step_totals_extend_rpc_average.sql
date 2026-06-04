-- Extend get_cumulative_battle_steps with finalized day count + average.
-- Run in Supabase SQL Editor after user_battle_step_totals_create_table_rpcs.sql.

create or replace function public.get_cumulative_battle_steps()
returns jsonb
language plpgsql
stable
security invoker
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_user_id uuid;
  v_tz text;
  v_today date;
  v_finalized_total bigint := 0;
  v_finalized_count bigint := 0;
  v_avg_steps bigint := 0;
  v_is_today_battle_day boolean := false;
  v_is_today_finalized boolean := false;
begin
  select
    p.id,
    coalesce(nullif(trim(p.timezone), ''), 'UTC')
  into v_user_id, v_tz
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1;

  if v_user_id is null then
    return jsonb_build_object(
      'finalized_total', 0,
      'finalized_battle_day_count', 0,
      'average_finalized_battle_day_steps', 0,
      'is_today_battle_day', false,
      'is_today_finalized', false,
      'today_battle_date', null
    );
  end if;

  v_today := (now() at time zone v_tz)::date;

  select
    coalesce(sum(ub.steps), 0)::bigint,
    count(*)::bigint,
    coalesce(round(avg(ub.steps)), 0)::bigint
  into v_finalized_total, v_finalized_count, v_avg_steps
  from public.user_battle_step_totals ub
  where ub.user_id = v_user_id
    and ub.finalized_at is not null;

  v_is_today_battle_day := public.is_user_steps_battle_day(v_user_id, v_today);

  select exists (
    select 1
    from public.user_battle_step_totals ub
    where ub.user_id = v_user_id
      and ub.battle_date = v_today
      and ub.finalized_at is not null
  )
  into v_is_today_finalized;

  return jsonb_build_object(
    'finalized_total', v_finalized_total,
    'finalized_battle_day_count', v_finalized_count,
    'average_finalized_battle_day_steps', v_avg_steps,
    'is_today_battle_day', v_is_today_battle_day,
    'is_today_finalized', v_is_today_finalized,
    'today_battle_date', v_today
  );
end;
$function$;

grant execute on function public.get_cumulative_battle_steps() to authenticated;
