-- Slice 3A verification for get_my_rival_stats() extended fields.
-- Run manually after applying stats_arcade_slice3a_extend_get_my_rival_stats.sql.

select
  opponent_display_name,
  finalized_days_competed,
  match_wins,
  match_losses,
  match_ties,
  days_won_by_viewer,
  days_won_by_opponent,
  avg_finalized_daily_margin,
  avg_margin_on_viewer_win_days,
  avg_margin_on_opponent_win_days,
  recent_series_results
from public.get_my_rival_stats(10);

-- Quick shape checks.
select
  count(*) as rival_rows,
  count(*) filter (where days_won_by_viewer is not null) as rows_with_days_won_viewer,
  count(*) filter (where days_won_by_opponent is not null) as rows_with_days_won_opponent,
  count(*) filter (where recent_series_results is not null) as rows_with_recent_results
from public.get_my_rival_stats(50);

-- Ensure recent series array has at most 5 entries and only expected tokens.
select
  s.opponent_display_name,
  cardinality(s.recent_series_results) as recent_len,
  (
    select bool_and(v in ('W', 'L', 'T'))
    from unnest(coalesce(s.recent_series_results, array[]::text[])) as v
  ) as recent_tokens_valid
from public.get_my_rival_stats(50) s
order by s.finalized_days_competed desc, s.opponent_display_name asc;
