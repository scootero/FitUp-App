import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders, jsonResponse, readJsonBody } from "../_shared/http.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";

/**
 * Finalizes one match day: copies metric_total → finalized_value, sets winner/void,
 * updates leaderboard, may complete the match.
 *
 * Downstream Edge calls use public.invoke_edge_function_async (Vault JWT via pg_net),
 * not invokeInternalFunction, so auth matches lead-change / cron invocations.
 *
 * Partial-failure note: DB rows are updated before downstream calls. Leaderboard /
 * complete-match failures are logged; finalize still returns 200 when the day row is written.
 */
serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed." });
  }
  try {
    const body = await readJsonBody(request);
    const matchDayId = body.match_day_id?.trim();
    if (!matchDayId) {
      return jsonResponse(400, { error: "match_day_id is required." });
    }
    const { data: dayRow, error: dayError } = await supabaseAdmin
      .from("match_days")
      .select("id, match_id, status, day_number")
      .eq("id", matchDayId)
      .limit(1)
      .maybeSingle();
    if (dayError) {
      throw dayError;
    }
    if (!dayRow) {
      return jsonResponse(404, { error: "match_day not found." });
    }
    if (dayRow.status === "finalized") {
      return jsonResponse(200, {
        status: "already_finalized",
        match_day_id: matchDayId,
      });
    }
    const { data: matchRow, error: matchFetchError } = await supabaseAdmin
      .from("matches")
      .select("metric_type, duration_days, scoring_mode")
      .eq("id", dayRow.match_id)
      .limit(1)
      .maybeSingle();
    if (matchFetchError) {
      throw matchFetchError;
    }
    const metricType = matchRow?.metric_type ?? "steps";
    const scoringMode = matchRow?.scoring_mode ?? null;
    const useBalancedWinner = scoringMode === "balanced" && metricType === "steps";
    const { data: baselineRows, error: baselineError } = await supabaseAdmin
      .from("match_participants")
      .select("user_id, baseline_steps")
      .eq("match_id", dayRow.match_id);
    if (baselineError) {
      throw baselineError;
    }
    const baselineByUser = new Map<string, number | null>();
    for (const row of baselineRows ?? []) {
      const raw = row.baseline_steps;
      baselineByUser.set(
        String(row.user_id),
        raw === null || raw === undefined ? null : toNumber(raw),
      );
    }
    const { data: participantRows, error: participantError } = await supabaseAdmin
      .from("match_day_participants")
      .select("id, user_id, metric_total, finalized_value")
      .eq("match_day_id", matchDayId);
    if (participantError) {
      throw participantError;
    }
    const participants = participantRows ?? [];
    if (participants.length === 0) {
      return jsonResponse(409, { error: "No match_day_participants found." });
    }
    const ratiosByUser: { userId: string; ratio: number }[] = [];
    for (const participant of participants) {
      const finalizedValue = toNumber(participant.metric_total);
      const uid = String(participant.user_id);
      let patch: Record<string, unknown> = { finalized_value: finalizedValue };
      if (useBalancedWinner) {
        const rawBaseline = baselineByUser.get(uid);
        const baselineNum = rawBaseline === null || rawBaseline === undefined ? 0 : toNumber(rawBaseline);
        const effectiveBaseline = baselineNum > 0 ? Math.max(3000, baselineNum) : 3000;
        const ratio = effectiveBaseline > 0 ? finalizedValue / effectiveBaseline : 0;
        patch = {
          finalized_value: finalizedValue,
          balanced_ratio: ratio,
          balanced_percent: ratio * 100,
        };
        ratiosByUser.push({ userId: uid, ratio });
      }
      const { error: updateError } = await supabaseAdmin
        .from("match_day_participants")
        .update(patch)
        .eq("id", participant.id);
      if (updateError) {
        throw updateError;
      }
    }
    let valuesByUser: { userId: string; value: number }[];
    let isVoid: boolean;
    let winnerUserId: string | null = null;
    if (useBalancedWinner) {
      valuesByUser = ratiosByUser.map((row) => ({ userId: row.userId, value: row.ratio }));
      const ratios = valuesByUser.map((row) => row.value);
      const maxValue = Math.max(...ratios);
      const minValue = Math.min(...ratios);
      isVoid = maxValue === minValue;
      if (!isVoid) {
        winnerUserId = valuesByUser.reduce((best, current) =>
          current.value > best.value ? current : best
        ).userId;
      }
    } else {
      valuesByUser = participants.map((row) => ({
        userId: String(row.user_id),
        value: toNumber(row.metric_total),
      }));
      const values = valuesByUser.map((row) => row.value);
      const maxValue = Math.max(...values);
      const minValue = Math.min(...values);
      isVoid = maxValue === minValue;
      if (!isVoid) {
        winnerUserId = valuesByUser.reduce((best, current) =>
          current.value > best.value ? current : best
        ).userId;
      }
    }
    const nowIso = new Date().toISOString();
    const { error: finalizeError } = await supabaseAdmin
      .from("match_days")
      .update({
        status: "finalized",
        finalized_at: nowIso,
        winner_user_id: winnerUserId,
        is_void: isVoid,
      })
      .eq("id", matchDayId);
    if (finalizeError) {
      throw finalizeError;
    }

    let leaderboardError: string | null = null;
    try {
      await invokeEdgeViaVaultRpc("update-leaderboard", {
        match_day_id: matchDayId,
        match_id: dayRow.match_id,
        winner_user_id: winnerUserId,
        is_void: isVoid,
      });
    } catch (err) {
      leaderboardError = err instanceof Error ? err.message : String(err);
      console.error("update-leaderboard via invoke_edge_function_async failed:", leaderboardError);
    }

    const { data: allDayRows, error: allDayError } = await supabaseAdmin
      .from("match_days")
      .select("id, status")
      .eq("match_id", dayRow.match_id);
    if (allDayError) {
      throw allDayError;
    }
    const allFinalized =
      (allDayRows ?? []).length > 0 &&
      (allDayRows ?? []).every((row) => row.status === "finalized");
    let completeMatchError: string | null = null;
    if (allFinalized) {
      try {
        await invokeEdgeViaVaultRpc("complete-match", { match_id: dayRow.match_id });
      } catch (err) {
        completeMatchError = err instanceof Error ? err.message : String(err);
        console.error("complete-match via invoke_edge_function_async failed:", completeMatchError);
      }
    }

    return jsonResponse(200, {
      status: "finalized",
      match_day_id: matchDayId,
      match_id: dayRow.match_id,
      is_void: isVoid,
      winner_user_id: winnerUserId,
      completed_match: allFinalized,
      leaderboard_error: leaderboardError,
      complete_match_error: completeMatchError,
    });
  } catch (error) {
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "finalize-match-day failed.",
    });
  }
});

async function invokeEdgeViaVaultRpc(
  functionName: string,
  payload: Record<string, unknown>,
): Promise<void> {
  const { error } = await supabaseAdmin.rpc("invoke_edge_function_async", {
    p_function_name: functionName,
    p_payload: payload,
  });
  if (error) {
    throw new Error(`${functionName} rpc failed: ${error.message}`);
  }
}

function toNumber(value: unknown): number {
  if (typeof value === "number") {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    if (!Number.isNaN(parsed)) {
      return parsed;
    }
  }
  return 0;
}
