-- Slice 3C verification: run after applying stats_arcade_slice3c_get_opponent_steps_rollups.sql.
-- Note: auth.uid() is null in SQL Editor → expect zeros. Test real values in the signed-in app.

select jsonb_pretty(public.get_stats_opponent_steps_rollups());

-- Shape check (zeros without JWT are expected).
select
  (public.get_stats_opponent_steps_rollups() ->> 'lifetime_steps')::bigint as lifetime_steps,
  (public.get_stats_opponent_steps_rollups() ->> 'rolling_365d_steps')::bigint as rolling_365d_steps,
  (public.get_stats_opponent_steps_rollups() ->> 'current_month_steps')::bigint as current_month_steps,
  public.get_stats_opponent_steps_rollups() ->> 'computed_at' as computed_at;

-- Soft sanity when signed in: lifetime should be >= rolling 365d (not strict for backfills).
-- select
--   (r ->> 'lifetime_steps')::bigint >= (r ->> 'rolling_365d_steps')::bigint as lifetime_gte_rolling
-- from (select public.get_stats_opponent_steps_rollups() as r) x;
