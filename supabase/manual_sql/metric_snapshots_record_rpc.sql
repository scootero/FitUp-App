-- Metric snapshots — record_metric_snapshot RPC (insert on value change, update synced_at on same value)
--
-- Follow: FitUp/docs/sql-cmd-instructions.md
-- Rollback: `metric_snapshots_record_rpc_rollback.sql`
-- Read-only checks: `metric_snapshots_record_rpc_00_readonly_checks.sql`
--
-- ═══════════════════════════════════════════════════════════════════════════
-- HUMAN: RUN ORDER (SQL Editor only — do not run via agent/CLI deploy)
-- ═══════════════════════════════════════════════════════════════════════════
--   1. (Optional) `metric_snapshots_record_rpc_00_readonly_checks.sql` — pre-check
--   2. This file: `metric_snapshots_record_rpc.sql`
--   3. Deploy iOS build that calls `record_metric_snapshot`
--   4. (Optional) post-checks in readonly file
-- ═══════════════════════════════════════════════════════════════════════════
--
-- PostgREST (Supabase Swift): `.rpc("record_metric_snapshot", params: ...)`
-- Returns: `{ "snapshot_id": uuid, "was_updated": boolean }`
-- ═══════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.record_metric_snapshot(
  p_match_id uuid,
  p_metric_type text,
  p_value numeric,
  p_source_date date,
  p_flagged boolean DEFAULT false,
  p_metadata jsonb DEFAULT NULL,
  p_synced_at timestamp with time zone DEFAULT now()
) RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $function$
DECLARE
  v_profile_id uuid;
  v_latest_id uuid;
  v_latest_value numeric;
  v_new_id uuid;
  v_was_updated boolean := false;
BEGIN
  SELECT p.id
  INTO v_profile_id
  FROM public.profiles p
  WHERE p.auth_user_id = auth.uid()
  LIMIT 1;

  IF v_profile_id IS NULL THEN
    RAISE EXCEPTION 'not authenticated or profile missing';
  END IF;

  IF p_metric_type NOT IN ('steps', 'active_calories') THEN
    RAISE EXCEPTION 'invalid metric_type: %', p_metric_type;
  END IF;

  IF p_value IS NULL OR p_value < 0 THEN
    RAISE EXCEPTION 'value must be non-negative';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.match_participants mp
    WHERE mp.match_id = p_match_id
      AND mp.user_id = v_profile_id
  ) THEN
    RAISE EXCEPTION 'not a participant in match';
  END IF;

  SELECT ms.id, ms.value
  INTO v_latest_id, v_latest_value
  FROM public.metric_snapshots ms
  WHERE ms.user_id = v_profile_id
    AND ms.match_id = p_match_id
    AND ms.metric_type = p_metric_type
    AND ms.source_date = p_source_date
  ORDER BY ms.synced_at DESC, ms.id DESC
  LIMIT 1;

  IF v_latest_id IS NOT NULL AND v_latest_value = p_value THEN
    UPDATE public.metric_snapshots
    SET
      synced_at = COALESCE(p_synced_at, now()),
      metadata = COALESCE(p_metadata, metadata),
      flagged = p_flagged
    WHERE id = v_latest_id;

    v_new_id := v_latest_id;
    v_was_updated := true;
  ELSE
    INSERT INTO public.metric_snapshots (
      match_id,
      user_id,
      metric_type,
      value,
      source_date,
      synced_at,
      flagged,
      metadata
    )
    VALUES (
      p_match_id,
      v_profile_id,
      p_metric_type,
      p_value,
      p_source_date,
      COALESCE(p_synced_at, now()),
      COALESCE(p_flagged, false),
      p_metadata
    )
    RETURNING id INTO v_new_id;
  END IF;

  RETURN jsonb_build_object(
    'snapshot_id', v_new_id,
    'was_updated', v_was_updated
  );
END;
$function$;

COMMENT ON FUNCTION public.record_metric_snapshot(
  uuid, text, numeric, date, boolean, jsonb, timestamp with time zone
) IS
  'Records a metric snapshot for the signed-in user: inserts when value changed, updates synced_at when value unchanged for that match/day.';

REVOKE ALL ON FUNCTION public.record_metric_snapshot(
  uuid, text, numeric, date, boolean, jsonb, timestamp with time zone
) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.record_metric_snapshot(
  uuid, text, numeric, date, boolean, jsonb, timestamp with time zone
) TO authenticated;
