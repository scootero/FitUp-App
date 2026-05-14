-- Intraday step ticks — Slice 1: table + indexes + RLS (manual apply in Supabase SQL Editor)
--
-- Follow: FitUp/docs/sql-cmd-instructions.md
-- Plan: FitUp/docs/intraday-step-ticks-implementation-slices.md
--
-- ═══════════════════════════════════════════════════════════════════════════
-- HUMAN: RUN ORDER
-- ═══════════════════════════════════════════════════════════════════════════
--   1. This file first: `intraday_step_ticks_slice1_create_table_rls.sql`
--   2. (Optional, periodic) `intraday_step_ticks_slice1_retention_ttl_7d.sql`
--   3. (Optional) `verify_user_intraday_step_ticks.sql` — read-only checks
--
-- Slice 2 will add SECURITY DEFINER RPCs for insert/prune/fetch (opponent reads).
-- After Slice 1, run: `intraday_step_ticks_slice2_rpcs.sql` (see implementation slices doc).
-- Direct SELECT on this table is limited to **own rows** only; rivals read via RPC.
-- ═══════════════════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------------------
-- Table
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.user_intraday_step_ticks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  calendar_date date NOT NULL,
  timezone_identifier text NOT NULL,
  cumulative_steps integer NOT NULL,
  recorded_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT user_intraday_step_ticks_cumulative_steps_non_negative
    CHECK (cumulative_steps >= 0),
  CONSTRAINT user_intraday_step_ticks_timezone_identifier_nonempty
    CHECK (length(trim(timezone_identifier)) > 0)
);

COMMENT ON TABLE public.user_intraday_step_ticks IS
  'Append-only cumulative step samples for a writer-local calendar day (Slice 1). Opponent/chart reads use Slice 2 RPCs.';

COMMENT ON COLUMN public.user_intraday_step_ticks.user_id IS
  'profiles.id of the person who walked (writer).';

COMMENT ON COLUMN public.user_intraday_step_ticks.calendar_date IS
  'Writer-local calendar date for "today" when the sample was taken (IANA TZ in timezone_identifier).';

COMMENT ON COLUMN public.user_intraday_step_ticks.timezone_identifier IS
  'IANA zone used to interpret calendar_date (e.g. America/Chicago).';

COMMENT ON COLUMN public.user_intraday_step_ticks.cumulative_steps IS
  'HealthKit-style cumulative steps for that calendar_date at recorded_at.';

COMMENT ON COLUMN public.user_intraday_step_ticks.recorded_at IS
  'Instant the sample represents (typically client clock at HK read; monotonic with uploads).';

COMMENT ON COLUMN public.user_intraday_step_ticks.created_at IS
  'Server insert time (audit).';

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_user_intraday_step_ticks_user_date_recorded
  ON public.user_intraday_step_ticks (user_id, calendar_date, recorded_at DESC);

CREATE INDEX IF NOT EXISTS idx_user_intraday_step_ticks_calendar_date
  ON public.user_intraday_step_ticks (calendar_date);

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE public.user_intraday_step_ticks ENABLE ROW LEVEL SECURITY;

-- Authenticated app users map to profiles via auth_user_id.
DROP POLICY IF EXISTS user_intraday_step_ticks_select_own ON public.user_intraday_step_ticks;
CREATE POLICY user_intraday_step_ticks_select_own
  ON public.user_intraday_step_ticks
  FOR SELECT
  TO authenticated
  USING (
    user_id = (SELECT p.id FROM public.profiles p WHERE p.auth_user_id = auth.uid() LIMIT 1)
  );

DROP POLICY IF EXISTS user_intraday_step_ticks_insert_own ON public.user_intraday_step_ticks;
CREATE POLICY user_intraday_step_ticks_insert_own
  ON public.user_intraday_step_ticks
  FOR INSERT
  TO authenticated
  WITH CHECK (
    user_id = (SELECT p.id FROM public.profiles p WHERE p.auth_user_id = auth.uid() LIMIT 1)
  );

-- Append-only: no UPDATE / DELETE for authenticated (retention uses SQL Editor / service_role).

-- ---------------------------------------------------------------------------
-- Grants
-- ---------------------------------------------------------------------------

GRANT SELECT, INSERT ON public.user_intraday_step_ticks TO authenticated;

-- service_role bypasses RLS for ops / retention scripts run from dashboard if needed
