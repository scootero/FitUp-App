-- Battle Steps deploy verification (read-only). Run in SQL Editor after
-- `user_battle_step_totals_create_table_rpcs.sql`.

-- 1) Objects exist
select
  to_regclass('public.user_battle_step_totals') as table_ok,
  to_regprocedure('public.get_cumulative_battle_steps()') as rpc_ok;

-- 2) Backfill produced rows (service_role / dashboard — not RLS-scoped)
select
  count(*)::bigint as total_rows,
  count(*) filter (where finalized_at is not null)::bigint as finalized_rows,
  coalesce(sum(steps) filter (where finalized_at is not null), 0)::bigint as finalized_step_sum
from public.user_battle_step_totals;
