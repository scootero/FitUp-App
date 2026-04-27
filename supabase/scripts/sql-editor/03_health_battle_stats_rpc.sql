-- Health Stats Slice 1: viewer-scoped battle stats RPC
-- Run in Supabase SQL Editor.

create or replace function public.health_battle_stats()
returns jsonb
language plpgsql
stable
set search_path to 'public'
as $function$
declare
  v_viewer uuid;
  v_matches_played int := 0;
  v_wins int := 0;
  v_losses int := 0;
  v_ties int := 0;
  v_win_rate int := 0;
  v_current_streak_type text := 'none';
  v_current_streak_count int := 0;
  v_result text;
begin
  select p.id
  into v_viewer
  from public.profiles p
  where p.auth_user_id = auth.uid()
  limit 1;

  if v_viewer is null then
    return jsonb_build_object(
      'matches_played', 0,
      'wins', 0,
      'losses', 0,
      'ties', 0,
      'win_rate', 0,
      'current_streak_type', 'none',
      'current_streak_count', 0
    );
  end if;

  with viewer_matches as (
    select m.id, m.completed_at, m.ends_at
    from public.matches m
    inner join public.match_participants mp
      on mp.match_id = m.id
     and mp.user_id = v_viewer
    where m.state = 'completed'
  ),
  day_scores as (
    select
      vm.id as match_id,
      vm.completed_at,
      vm.ends_at,
      coalesce(sum(case when md.winner_user_id = v_viewer then 1 else 0 end), 0)::int as viewer_day_wins,
      coalesce(sum(case when md.winner_user_id is not null and md.winner_user_id <> v_viewer then 1 else 0 end), 0)::int as opponent_day_wins
    from viewer_matches vm
    left join public.match_days md
      on md.match_id = vm.id
     and md.status = 'finalized'
     and md.is_void = false
    group by vm.id, vm.completed_at, vm.ends_at
  ),
  outcomes as (
    select
      match_id,
      completed_at,
      ends_at,
      case
        when viewer_day_wins > opponent_day_wins then 'win'
        when opponent_day_wins > viewer_day_wins then 'loss'
        else 'tie'
      end as result
    from day_scores
  ),
  aggregate_counts as (
    select
      count(*)::int as matches_played,
      coalesce(sum(case when result = 'win' then 1 else 0 end), 0)::int as wins,
      coalesce(sum(case when result = 'loss' then 1 else 0 end), 0)::int as losses,
      coalesce(sum(case when result = 'tie' then 1 else 0 end), 0)::int as ties
    from outcomes
  )
  select
    a.matches_played,
    a.wins,
    a.losses,
    a.ties
  into
    v_matches_played,
    v_wins,
    v_losses,
    v_ties
  from aggregate_counts a;

  if (v_wins + v_losses) > 0 then
    v_win_rate := round((v_wins::numeric / (v_wins + v_losses)::numeric) * 100)::int;
  end if;

  for v_result in
    with viewer_matches as (
      select m.id, m.completed_at, m.ends_at
      from public.matches m
      inner join public.match_participants mp
        on mp.match_id = m.id
       and mp.user_id = v_viewer
      where m.state = 'completed'
    ),
    day_scores as (
      select
        vm.id as match_id,
        vm.completed_at,
        vm.ends_at,
        coalesce(sum(case when md.winner_user_id = v_viewer then 1 else 0 end), 0)::int as viewer_day_wins,
        coalesce(sum(case when md.winner_user_id is not null and md.winner_user_id <> v_viewer then 1 else 0 end), 0)::int as opponent_day_wins
      from viewer_matches vm
      left join public.match_days md
        on md.match_id = vm.id
       and md.status = 'finalized'
       and md.is_void = false
      group by vm.id, vm.completed_at, vm.ends_at
    )
    select
      case
        when viewer_day_wins > opponent_day_wins then 'win'
        when opponent_day_wins > viewer_day_wins then 'loss'
        else 'tie'
      end as result
    from day_scores
    order by completed_at desc nulls last, ends_at desc nulls last
  loop
    if v_result = 'tie' then
      exit;
    end if;

    if v_current_streak_type = 'none' then
      v_current_streak_type := v_result;
      v_current_streak_count := 1;
    elsif v_result = v_current_streak_type then
      v_current_streak_count := v_current_streak_count + 1;
    else
      exit;
    end if;
  end loop;

  return jsonb_build_object(
    'matches_played', coalesce(v_matches_played, 0),
    'wins', coalesce(v_wins, 0),
    'losses', coalesce(v_losses, 0),
    'ties', coalesce(v_ties, 0),
    'win_rate', coalesce(v_win_rate, 0),
    'current_streak_type', coalesce(v_current_streak_type, 'none'),
    'current_streak_count', coalesce(v_current_streak_count, 0)
  );
end;
$function$;

-- Optional quick verification after creating function:
-- select public.health_battle_stats();
