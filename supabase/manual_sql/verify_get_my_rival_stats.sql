-- Slice 4.5b verification: run after creating get_my_rival_stats().
-- This returns rows for the currently authenticated user only.

select *
from public.get_my_rival_stats(3);

-- Sanity checks on semantics:
-- 1) win_percentage uses wins/(wins+losses), ties excluded
-- 2) finalized_days_competed is finalized + non-void day count grain
-- 3) avg_finalized_daily_margin is day-level average of (my total - opponent total)
select
  opponent_profile_id,
  finalized_days_competed,
  match_wins,
  match_losses,
  match_ties,
  win_percentage,
  avg_finalized_daily_margin,
  last_played_on,
  active_match_id,
  computed_at
from public.get_my_rival_stats(10)
order by finalized_days_competed desc, last_played_on desc nulls last;
