-- Slice 4C verification: run after creating get_profile_stats_snapshot().

select jsonb_pretty(public.get_profile_stats_snapshot('7D', 'steps'));
select jsonb_pretty(public.get_profile_stats_snapshot('30D', 'steps'));
select jsonb_pretty(public.get_profile_stats_snapshot('1D', 'steps'));
select jsonb_pretty(public.get_profile_stats_snapshot('3M', 'steps'));
select jsonb_pretty(public.get_profile_stats_snapshot('ALL', 'steps'));

-- Summary comparison + comeback contract checks.
select
  public.get_profile_stats_snapshot('30D', 'steps') -> 'summary' ->> 'previous_period_percent' as previous_period_percent,
  public.get_profile_stats_snapshot('30D', 'steps') -> 'personal_bests' ->> 'biggest_comeback_day_deficit_recovered' as comeback_a,
  public.get_profile_stats_snapshot('30D', 'steps') -> 'personal_bests' ->> 'biggest_comeback_series_net_swing' as comeback_b;
