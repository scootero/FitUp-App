-- Rollback: remove record_metric_snapshot RPC (restore direct client INSERT into metric_snapshots).
-- Run in Supabase SQL Editor manually AFTER reverting iOS to `.insert()` on metric_snapshots.
-- Existing rows are untouched.

REVOKE EXECUTE ON FUNCTION public.record_metric_snapshot(
  uuid, text, numeric, date, boolean, jsonb, timestamp with time zone
) FROM authenticated;

DROP FUNCTION IF EXISTS public.record_metric_snapshot(
  uuid, text, numeric, date, boolean, jsonb, timestamp with time zone
);
