-- Intraday step ticks — Slice 2: RPCs (insert + Visvalingam prune + opponent fetch)
--
-- Follow: FitUp/docs/sql-cmd-instructions.md
-- Plan: FitUp/docs/intraday-step-ticks-implementation-slices.md
--
-- Prerequisites: `intraday_step_ticks_slice1_create_table_rls.sql` already applied.
--
-- ═══════════════════════════════════════════════════════════════════════════
-- HUMAN: RUN ORDER
-- ═══════════════════════════════════════════════════════════════════════════
--   1. This file: `intraday_step_ticks_slice2_rpcs.sql`
--   2. (Optional) `verify_intraday_step_ticks_rpcs.sql` — read-only checks
-- ═══════════════════════════════════════════════════════════════════════════
--
-- PostgREST (Supabase JS/Swift): call RPCs by name with named args.
--   append_user_intraday_step_tick / fetch_opponent_intraday_step_ticks / prune_user_intraday_step_tick_day
--
-- Internal helper `intraday_step_ticks_prune_one_victim` is NOT granted to clients.
-- ═══════════════════════════════════════════════════════════════════════════

-- ---------------------------------------------------------------------------
-- Internal: delete one interior point with smallest normalized triangle area
-- (Visvalingam–Whyatt style). Never deletes global first/last by (recorded_at, id).
-- Returns deleted row id, or NULL if count <= 30. Raises if count > 30 but no victim.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.intraday_step_ticks_prune_one_victim(
  p_user_id uuid,
  p_calendar_date date
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_cnt int;
  v_victim uuid;
BEGIN
  SELECT count(*)::int
  INTO v_cnt
  FROM public.user_intraday_step_ticks
  WHERE user_id = p_user_id
    AND calendar_date = p_calendar_date;

  IF v_cnt <= 30 THEN
    RETURN NULL;
  END IF;

  WITH day_rows AS (
    SELECT *
    FROM public.user_intraday_step_ticks
    WHERE user_id = p_user_id
      AND calendar_date = p_calendar_date
  ),
  bounds AS (
    SELECT
      (SELECT min(recorded_at) FROM day_rows) AS ra_min,
      (SELECT max(recorded_at) FROM day_rows) AS ra_max,
      (SELECT min(cumulative_steps)::double precision FROM day_rows) AS s_min,
      (SELECT max(cumulative_steps)::double precision FROM day_rows) AS s_max
  ),
  seq AS (
    SELECT
      d.id,
      d.recorded_at,
      d.cumulative_steps,
      lag(d.recorded_at) OVER w AS prev_t,
      lag(d.cumulative_steps) OVER w AS prev_s,
      lead(d.recorded_at) OVER w AS next_t,
      lead(d.cumulative_steps) OVER w AS next_s
    FROM day_rows d
    WINDOW w AS (ORDER BY d.recorded_at, d.id)
  ),
  norm AS (
    SELECT
      s.id,
      s.recorded_at,
      extract(epoch FROM (s.prev_t - b.ra_min))
        / greatest(extract(epoch FROM (b.ra_max - b.ra_min)), 1e-9) AS x_prev,
      extract(epoch FROM (s.recorded_at - b.ra_min))
        / greatest(extract(epoch FROM (b.ra_max - b.ra_min)), 1e-9) AS x_curr,
      extract(epoch FROM (s.next_t - b.ra_min))
        / greatest(extract(epoch FROM (b.ra_max - b.ra_min)), 1e-9) AS x_next,
      (s.prev_s - b.s_min) / greatest(b.s_max - b.s_min, 1.0::double precision) AS y_prev,
      (s.cumulative_steps - b.s_min) / greatest(b.s_max - b.s_min, 1.0::double precision) AS y_curr,
      (s.next_s - b.s_min) / greatest(b.s_max - b.s_min, 1.0::double precision) AS y_next
    FROM seq s
    CROSS JOIN bounds b
    WHERE s.prev_t IS NOT NULL
      AND s.next_t IS NOT NULL
  ),
  scored AS (
    SELECT
      id,
      recorded_at,
      abs(
        x_prev * (y_curr - y_next)
        + x_curr * (y_next - y_prev)
        + x_next * (y_prev - y_curr)
      ) / 2.0 AS tri_area
    FROM norm
  )
  SELECT id
  INTO v_victim
  FROM scored
  ORDER BY tri_area ASC NULLS LAST, recorded_at ASC, id ASC
  LIMIT 1;

  IF v_victim IS NULL THEN
    RAISE EXCEPTION 'intraday_step_ticks_prune_one_victim: count=% but no interior victim', v_cnt;
  END IF;

  DELETE FROM public.user_intraday_step_ticks
  WHERE id = v_victim;

  RETURN v_victim;
END;
$function$;

COMMENT ON FUNCTION public.intraday_step_ticks_prune_one_victim(uuid, date) IS
  'Internal (no client EXECUTE): one Visvalingam-style prune step for user_intraday_step_ticks.';

REVOKE ALL ON FUNCTION public.intraday_step_ticks_prune_one_victim(uuid, date) FROM PUBLIC;

-- ---------------------------------------------------------------------------
-- append_user_intraday_step_tick: insert one row for caller, then prune to <= 30
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.append_user_intraday_step_tick(
  p_calendar_date date,
  p_timezone_identifier text,
  p_cumulative_steps integer,
  p_recorded_at timestamp with time zone DEFAULT now()
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_profile_id uuid;
  v_new_id uuid;
BEGIN
  SELECT p.id
  INTO v_profile_id
  FROM public.profiles p
  WHERE p.auth_user_id = auth.uid()
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated or profile missing';
  END IF;

  IF length(trim(coalesce(p_timezone_identifier, ''))) = 0 THEN
    RAISE EXCEPTION 'timezone_identifier required';
  END IF;

  IF p_cumulative_steps < 0 THEN
    RAISE EXCEPTION 'cumulative_steps must be non-negative';
  END IF;

  INSERT INTO public.user_intraday_step_ticks (
    user_id,
    calendar_date,
    timezone_identifier,
    cumulative_steps,
    recorded_at
  )
  VALUES (
    v_profile_id,
    p_calendar_date,
    trim(p_timezone_identifier),
    p_cumulative_steps,
    p_recorded_at
  )
  RETURNING id INTO v_new_id;

  WHILE (
    SELECT count(*)::int
    FROM public.user_intraday_step_ticks
    WHERE user_id = v_profile_id
      AND calendar_date = p_calendar_date
  ) > 30
  LOOP
    PERFORM public.intraday_step_ticks_prune_one_victim(v_profile_id, p_calendar_date);
  END LOOP;

  RETURN v_new_id;
END;
$function$;

COMMENT ON FUNCTION public.append_user_intraday_step_tick(date, text, integer, timestamp with time zone) IS
  'Inserts one tick for the signed-in profile and prunes that calendar_date to at most 30 rows.';

-- ---------------------------------------------------------------------------
-- prune_user_intraday_step_tick_day: repair / backfill — prune only, no insert
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.prune_user_intraday_step_tick_day(
  p_calendar_date date
) RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_profile_id uuid;
  v_deleted int := 0;
BEGIN
  SELECT p.id
  INTO v_profile_id
  FROM public.profiles p
  WHERE p.auth_user_id = auth.uid()
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated or profile missing';
  END IF;

  WHILE (
    SELECT count(*)::int
    FROM public.user_intraday_step_ticks
    WHERE user_id = v_profile_id
      AND calendar_date = p_calendar_date
  ) > 30
  LOOP
    PERFORM public.intraday_step_ticks_prune_one_victim(v_profile_id, p_calendar_date);
    v_deleted := v_deleted + 1;
  END LOOP;

  RETURN v_deleted;
END;
$function$;

COMMENT ON FUNCTION public.prune_user_intraday_step_tick_day(date) IS
  'Deletes excess ticks for the caller for one calendar_date using the same prune heuristic. Returns number of rows removed.';

-- ---------------------------------------------------------------------------
-- fetch_opponent_intraday_step_ticks: active-match participants only
-- Optional p_since: only rows with recorded_at > p_since (incremental refresh).
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fetch_opponent_intraday_step_ticks(
  p_opponent_profile_id uuid,
  p_calendar_date date,
  p_since timestamp with time zone DEFAULT NULL
) RETURNS TABLE (
  tick_id uuid,
  cumulative_steps integer,
  recorded_at timestamp with time zone,
  timezone_identifier text,
  calendar_date date,
  created_at timestamp with time zone
)
LANGUAGE plpgsql
VOLATILE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_me uuid;
BEGIN
  SELECT p.id
  INTO v_me
  FROM public.profiles p
  WHERE p.auth_user_id = auth.uid()
  LIMIT 1;

  IF v_me IS NULL THEN
    RETURN;
  END IF;

  IF p_opponent_profile_id IS NULL OR p_opponent_profile_id = v_me THEN
    RETURN;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.matches m
    JOIN public.match_participants mp_self
      ON mp_self.match_id = m.id
     AND mp_self.user_id = v_me
    JOIN public.match_participants mp_opp
      ON mp_opp.match_id = m.id
     AND mp_opp.user_id = p_opponent_profile_id
    WHERE m.state = 'active'
      AND mp_self.accepted_at IS NOT NULL
      AND mp_opp.accepted_at IS NOT NULL
  ) THEN
    RETURN;
  END IF;

  RETURN QUERY
  SELECT
    t.id AS tick_id,
    t.cumulative_steps,
    t.recorded_at,
    t.timezone_identifier,
    t.calendar_date,
    t.created_at
  FROM public.user_intraday_step_ticks t
  WHERE t.user_id = p_opponent_profile_id
    AND t.calendar_date = p_calendar_date
    AND (p_since IS NULL OR t.recorded_at > p_since)
  ORDER BY t.recorded_at ASC, t.id ASC;
END;
$function$;

COMMENT ON FUNCTION public.fetch_opponent_intraday_step_ticks(uuid, date, timestamp with time zone) IS
  'Returns opponent ticks for a calendar_date if viewer shares an active accepted match with that profile.';

-- ---------------------------------------------------------------------------
-- Grants (authenticated only for public RPCs)
-- ---------------------------------------------------------------------------

GRANT EXECUTE ON FUNCTION public.append_user_intraday_step_tick(date, text, integer, timestamp with time zone) TO authenticated;

GRANT EXECUTE ON FUNCTION public.prune_user_intraday_step_tick_day(date) TO authenticated;

GRANT EXECUTE ON FUNCTION public.fetch_opponent_intraday_step_ticks(uuid, date, timestamp with time zone) TO authenticated;
