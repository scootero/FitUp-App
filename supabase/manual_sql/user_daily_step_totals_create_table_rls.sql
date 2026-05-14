-- User daily step totals (HealthKit end-of-day style totals per calendar day)
-- One row per (user_id, calendar_date). Client upserts last ~30 days on each app open.
--
-- Run in Supabase SQL Editor (or CLI) when ready. Idempotent-ish: safe to re-run;
-- policies are dropped and recreated.
--
-- Next steps (not in this file):
--   • Swift: on foreground / notification open, read HK daily totals for a sliding window
--     (e.g. last 30 calendar days in profile TZ), upsert rows here.
--   • Leaderboard: add a SECURITY DEFINER RPC that sums steps for a week (this table
--     is not world-readable under RLS — same pattern as user_intraday_step_ticks).
--
-- Optional retention (run periodically as service_role or in SQL Editor):
--   DELETE FROM public.user_daily_step_totals
--   WHERE calendar_date < (CURRENT_DATE AT TIME ZONE 'UTC') - INTERVAL '40 days';
--   (Use a buffer past your product retention, e.g. 30d display + margin.)

-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_daily_step_totals (
  user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  calendar_date date NOT NULL,
  timezone_identifier text NOT NULL,
  steps integer NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_daily_step_totals_pkey PRIMARY KEY (user_id, calendar_date),
  CONSTRAINT user_daily_step_totals_steps_non_negative
    CHECK (steps >= 0),
  CONSTRAINT user_daily_step_totals_timezone_identifier_nonempty
    CHECK (length(trim(timezone_identifier)) > 0)
);

COMMENT ON TABLE public.user_daily_step_totals IS
  'Canonical HealthKit total steps for one writer-local calendar day; upserted from the app for leaderboard and history (not intraday samples).';

COMMENT ON COLUMN public.user_daily_step_totals.user_id IS
  'profiles.id of the person who walked (writer).';

COMMENT ON COLUMN public.user_daily_step_totals.calendar_date IS
  'Calendar day for which `steps` is the full-day total (boundaries computed in timezone_identifier).';

COMMENT ON COLUMN public.user_daily_step_totals.timezone_identifier IS
  'IANA zone used when mapping HealthKit day boundaries to calendar_date (e.g. America/Chicago).';

COMMENT ON COLUMN public.user_daily_step_totals.steps IS
  'Total step count for that calendar_date from HealthKit (may increase intraday; past days may revise when late data syncs).';

COMMENT ON COLUMN public.user_daily_step_totals.updated_at IS
  'Last time this row was written from the client.';

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_user_daily_step_totals_calendar_date
  ON public.user_daily_step_totals (calendar_date);

CREATE INDEX IF NOT EXISTS idx_user_daily_step_totals_user_updated
  ON public.user_daily_step_totals (user_id, updated_at DESC);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE public.user_daily_step_totals ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_daily_step_totals_select_own ON public.user_daily_step_totals;
CREATE POLICY user_daily_step_totals_select_own
  ON public.user_daily_step_totals
  FOR SELECT
  TO authenticated
  USING (
    user_id = (SELECT p.id FROM public.profiles p WHERE p.auth_user_id = auth.uid() LIMIT 1)
  );

DROP POLICY IF EXISTS user_daily_step_totals_insert_own ON public.user_daily_step_totals;
CREATE POLICY user_daily_step_totals_insert_own
  ON public.user_daily_step_totals
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = (SELECT p.id FROM public.profiles p WHERE p.auth_user_id = auth.uid() LIMIT 1)
  );

DROP POLICY IF EXISTS user_daily_step_totals_update_own ON public.user_daily_step_totals;
CREATE POLICY user_daily_step_totals_update_own
  ON public.user_daily_step_totals
  FOR UPDATE
  TO authenticated
  USING (
    user_id = (SELECT p.id FROM public.profiles p WHERE p.auth_user_id = auth.uid() LIMIT 1)
  )
  WITH CHECK (
    user_id = (SELECT p.id FROM public.profiles p WHERE p.auth_user_id = auth.uid() LIMIT 1)
  );

-- No DELETE for authenticated; use service_role / SQL Editor for retention prunes.

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

GRANT SELECT, INSERT, UPDATE ON public.user_daily_step_totals TO authenticated;

-- Next (Ranks tab reads): run `user_daily_step_totals_weekly_leaderboard_rpc.sql` in SQL Editor.
