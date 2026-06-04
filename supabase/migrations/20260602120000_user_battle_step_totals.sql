-- Cumulative Battle Steps: one literal step total per user per battle calendar day (HealthKit-aligned).
-- Deduped across multiple steps matches on the same day. Absolute upserts only (never +=).

create table if not exists public.user_battle_step_totals (
  user_id uuid not null references public.profiles (id) on delete cascade,
  battle_date date not null,
  steps integer not null,
  finalized_at timestamptz,
  updated_at timestamptz not null default now(),
  source text,
  constraint user_battle_step_totals_pkey primary key (user_id, battle_date),
  constraint user_battle_step_totals_steps_non_negative check (steps >= 0)
);

comment on table public.user_battle_step_totals is
  'Literal HealthKit step count per profile-local battle day; one row per user per date regardless of match count.';

create index if not exists idx_user_battle_step_totals_user_finalized
  on public.user_battle_step_totals (user_id)
  where finalized_at is not null;

alter table public.user_battle_step_totals enable row level security;

drop policy if exists user_battle_step_totals_select_own on public.user_battle_step_totals;
create policy user_battle_step_totals_select_own
  on public.user_battle_step_totals
  for select
  to authenticated
  using (
    user_id = (select p.id from public.profiles p where p.auth_user_id = auth.uid() limit 1)
  );

drop policy if exists user_battle_step_totals_insert_own on public.user_battle_step_totals;
create policy user_battle_step_totals_insert_own
  on public.user_battle_step_totals
  for insert
  to authenticated
  with check (
    user_id = (select p.id from public.profiles p where p.auth_user_id = auth.uid() limit 1)
  );

drop policy if exists user_battle_step_totals_update_own on public.user_battle_step_totals;
create policy user_battle_step_totals_update_own
  on public.user_battle_step_totals
  for update
  to authenticated
  using (
    user_id = (select p.id from public.profiles p where p.auth_user_id = auth.uid() limit 1)
  )
  with check (
    user_id = (select p.id from public.profiles p where p.auth_user_id = auth.uid() limit 1)
  );

grant select, insert, update on public.user_battle_step_totals to authenticated;

-- Returns true when the user has at least one non-void steps match_day on p_battle_date.
create or replace function public.is_user_steps_battle_day(
  p_user_id uuid,
  p_battle_date date
)
returns boolean
language sql
stable
security definer
set search_path to 'public', 'pg_temp'
as $$
  select exists (
    select 1
    from public.match_days md
    inner join public.matches m on m.id = md.match_id
    inner join public.match_participants mp
      on mp.match_id = m.id
     and mp.user_id = p_user_id
    where md.calendar_date = p_battle_date
      and md.is_void = false
      and m.metric_type = 'steps'
      and m.state in ('active', 'completed')
  );
$$;

-- Materialize or refresh one battle-day row (absolute steps; optional HK override from client/finalize).
create or replace function public.reconcile_user_battle_step_total(
  p_user_id uuid,
  p_battle_date date,
  p_steps integer default null,
  p_source text default 'reconcile'
)
returns void
language plpgsql
security definer
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_is_battle_day boolean;
  v_steps integer;
  v_finalized_at timestamptz;
  v_pending int;
begin
  v_is_battle_day := public.is_user_steps_battle_day(p_user_id, p_battle_date);

  if not v_is_battle_day then
    delete from public.user_battle_step_totals
    where user_id = p_user_id
      and battle_date = p_battle_date;
    return;
  end if;

  if p_steps is not null and p_steps >= 0 then
    v_steps := p_steps;
  else
    select d.steps
    into v_steps
    from public.user_daily_step_totals d
    where d.user_id = p_user_id
      and d.calendar_date = p_battle_date;

    if v_steps is null then
      select max(
        greatest(0, coalesce(mdp.finalized_value, mdp.metric_total)::integer)
      )::integer
      into v_steps
      from public.match_days md
      inner join public.matches m on m.id = md.match_id
      inner join public.match_participants mp
        on mp.match_id = m.id
       and mp.user_id = p_user_id
      inner join public.match_day_participants mdp
        on mdp.match_day_id = md.id
       and mdp.user_id = p_user_id
      where md.calendar_date = p_battle_date
        and md.is_void = false
        and m.metric_type = 'steps'
        and m.state in ('active', 'completed');
    end if;
  end if;

  if v_steps is null then
    return;
  end if;

  select count(*)::int
  into v_pending
  from public.match_days md
  inner join public.matches m on m.id = md.match_id
  inner join public.match_participants mp
    on mp.match_id = m.id
   and mp.user_id = p_user_id
  where md.calendar_date = p_battle_date
    and md.is_void = false
    and m.metric_type = 'steps'
    and m.state in ('active', 'completed')
    and md.status <> 'finalized';

  if v_pending = 0 then
    select max(md.finalized_at)
    into v_finalized_at
    from public.match_days md
    inner join public.matches m on m.id = md.match_id
    inner join public.match_participants mp
      on mp.match_id = m.id
     and mp.user_id = p_user_id
    where md.calendar_date = p_battle_date
      and md.is_void = false
      and m.metric_type = 'steps'
      and m.state in ('active', 'completed')
      and md.status = 'finalized';
  else
    v_finalized_at := null;
  end if;

  insert into public.user_battle_step_totals (
    user_id,
    battle_date,
    steps,
    finalized_at,
    updated_at,
    source
  )
  values (
    p_user_id,
    p_battle_date,
    v_steps,
    v_finalized_at,
    now(),
    p_source
  )
  on conflict (user_id, battle_date) do update
  set
    steps = excluded.steps,
    finalized_at = excluded.finalized_at,
    updated_at = now(),
    source = excluded.source;
end;
$function$;

-- Client HK sync: absolute steps for a battle day; does not overwrite finalized rows.
create or replace function public.upsert_provisional_user_battle_step(
  p_battle_date date,
  p_steps integer
)
returns void
language plpgsql
security invoker
set search_path to 'public', 'pg_temp'
as $function$
declare
  v_user_id uuid;
begin
  select p.id
  into v_user_id
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1;

  if v_user_id is null then
    return;
  end if;

  if p_steps is null or p_steps < 0 then
    return;
  end if;

  if not public.is_user_steps_battle_day(v_user_id, p_battle_date) then
    return;
  end if;

  insert into public.user_battle_step_totals (
    user_id,
    battle_date,
    steps,
    finalized_at,
    updated_at,
    source
  )
  values (
    v_user_id,
    p_battle_date,
    p_steps,
    null,
    now(),
    'healthkit'
  )
  on conflict (user_id, battle_date) do update
  set
    steps = excluded.steps,
    updated_at = now(),
    source = excluded.source
  where public.user_battle_step_totals.finalized_at is null;
end;
$function$;

grant execute on function public.is_user_steps_battle_day(uuid, date) to authenticated;
grant execute on function public.reconcile_user_battle_step_total(uuid, date, integer, text) to authenticated;
grant execute on function public.upsert_provisional_user_battle_step(date, integer) to authenticated;

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

-- Backfill finalized battle days from deduped participant totals (legacy when HK table empty).
insert into public.user_battle_step_totals (
  user_id,
  battle_date,
  steps,
  finalized_at,
  updated_at,
  source
)
select
  mp.user_id,
  md.calendar_date,
  max(greatest(0, coalesce(mdp.finalized_value, mdp.metric_total)::integer))::integer as steps,
  max(md.finalized_at) as finalized_at,
  now() as updated_at,
  'backfill_match_participant' as source
from public.match_days md
inner join public.matches m on m.id = md.match_id
inner join public.match_participants mp on mp.match_id = m.id
inner join public.match_day_participants mdp
  on mdp.match_day_id = md.id
 and mdp.user_id = mp.user_id
where md.status = 'finalized'
  and md.is_void = false
  and m.metric_type = 'steps'
  and m.state in ('active', 'completed')
  and coalesce(mdp.finalized_value, mdp.metric_total) is not null
group by mp.user_id, md.calendar_date
on conflict (user_id, battle_date) do update
set
  steps = excluded.steps,
  finalized_at = excluded.finalized_at,
  updated_at = now(),
  source = excluded.source
where public.user_battle_step_totals.finalized_at is null
   or public.user_battle_step_totals.source = 'backfill_match_participant';
