import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders, jsonResponse, readJsonBody } from "../_shared/http.ts";
import { invokeEdgeFunctionAsync, supabaseAdmin } from "../_shared/supabase.ts";

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
      .select("state, metric_type, duration_days, scoring_mode")
      .eq("id", dayRow.match_id)
      .limit(1)
      .maybeSingle();
    if (matchFetchError) {
      throw matchFetchError;
    }
    if ((matchRow?.state ?? "active") !== "active") {
      return jsonResponse(200, {
        status: "match_not_active",
        match_day_id: matchDayId,
        match_id: dayRow.match_id,
      });
    }
    const metricType = matchRow?.metric_type ?? "steps";
    const durationDays = Number(matchRow?.duration_days ?? 1);
    const scoringMode = matchRow?.scoring_mode ?? null;
    const useBalancedWinner = scoringMode === "balanced" && metricType === "steps";
    const { data: preDayRows, error: preDayError } = await supabaseAdmin
      .from("match_days")
      .select("status, winner_user_id, is_void")
      .eq("match_id", dayRow.match_id);
    if (preDayError) {
      throw preDayError;
    }
    const preSeries = summarizeSeries(preDayRows ?? [], durationDays);
    if (preSeries.clinched) {
      let completeMatchError: string | null = null;
      try {
        await invokeEdgeFunctionAsync("complete-match", { match_id: dayRow.match_id });
      } catch (err) {
        completeMatchError = err instanceof Error ? err.message : String(err);
        console.error("complete-match via invoke_edge_function_async failed:", completeMatchError);
      }
      return jsonResponse(200, {
        status: "already_clinched",
        match_day_id: matchDayId,
        match_id: dayRow.match_id,
        clinched: true,
        completed_match: true,
        complete_match_error: completeMatchError,
      });
    }
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
      await invokeEdgeFunctionAsync("update-leaderboard", {
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
      .select("status, winner_user_id, is_void")
      .eq("match_id", dayRow.match_id);
    if (allDayError) {
      throw allDayError;
    }
    const series = summarizeSeries(allDayRows ?? [], durationDays);
    const allFinalized = series.allFinalized;
    const clinched = series.clinched;
    const shouldComplete = allFinalized || clinched;
    let completeMatchError: string | null = null;
    if (shouldComplete) {
      try {
        await invokeEdgeFunctionAsync("complete-match", { match_id: dayRow.match_id });
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
      clinched,
      completed_match: shouldComplete,
      completion_reason: clinched ? "clinched" : allFinalized ? "all_days_finalized" : "none",
      leaderboard_error: leaderboardError,
      complete_match_error: completeMatchError,
    });
  } catch (error) {
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "finalize-match-day failed.",
    });
  }
});

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

function summarizeSeries(
  dayRows: Array<{ status: string; winner_user_id: string | null; is_void: boolean }>,
  durationDays: number,
): { allFinalized: boolean; clinched: boolean } {
  const rows = dayRows ?? [];
  const allFinalized = rows.length > 0 && rows.every((row) => row.status === "finalized");
  const winsRequired = Math.max(Math.floor((Math.max(durationDays, 1) + 1) / 2), 1);
  const wins = new Map<string, number>();
  for (const row of rows) {
    if (row.status !== "finalized" || row.is_void || !row.winner_user_id) continue;
    const winnerId = String(row.winner_user_id);
    wins.set(winnerId, (wins.get(winnerId) ?? 0) + 1);
  }
  let clinched = false;
  for (const count of wins.values()) {
    if (count >= winsRequired) {
      clinched = true;
      break;
    }
  }
  return { allFinalized, clinched };
}
