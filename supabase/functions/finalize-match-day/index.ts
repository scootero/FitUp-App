import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders, jsonResponse, readJsonBody } from "../_shared/http.ts";
import { invokeInternalFunction, supabaseAdmin } from "../_shared/supabase.ts";
/**
 * Finalizes one match day: copies metric_total → finalized_value, sets winner/void,
 * updates leaderboard, notifies participants, may complete the match.
 *
 * Partial-failure note: `match_days` / `match_day_participants` are updated before
 * downstream HTTP calls. If `update-leaderboard`, `dispatch-notification`, or
 * `complete-match` fails, the day stays finalized; a retry returns `already_finalized`
 * and does not re-run side effects — recover by manually invoking those functions.
 */ serve(async (request)=>{
  if (request.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders
    });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, {
      error: "Method not allowed."
    });
  }
  try {
    const body = await readJsonBody(request);
    const matchDayId = body.match_day_id?.trim();
    if (!matchDayId) {
      return jsonResponse(400, {
        error: "match_day_id is required."
      });
    }
    const { data: dayRow, error: dayError } = await supabaseAdmin.from("match_days").select("id, match_id, status, day_number").eq("id", matchDayId).limit(1).maybeSingle();
    if (dayError) {
      throw dayError;
    }
    if (!dayRow) {
      return jsonResponse(404, {
        error: "match_day not found."
      });
    }
    if (dayRow.status === "finalized") {
      return jsonResponse(200, {
        status: "already_finalized",
        match_day_id: matchDayId
      });
    }
    const { data: participantRows, error: participantError } = await supabaseAdmin.from("match_day_participants").select("id, user_id, metric_total, finalized_value").eq("match_day_id", matchDayId);
    if (participantError) {
      throw participantError;
    }
    const participants = participantRows ?? [];
    if (participants.length === 0) {
      return jsonResponse(409, {
        error: "No match_day_participants found."
      });
    }
    for (const participant of participants){
      const finalizedValue = toNumber(participant.metric_total);
      const { error: updateError } = await supabaseAdmin.from("match_day_participants").update({
        finalized_value: finalizedValue
      }).eq("id", participant.id);
      if (updateError) {
        throw updateError;
      }
    }
    const valuesByUser = participants.map((row)=>({
        userId: row.user_id,
        value: toNumber(row.metric_total)
      }));
    const values = valuesByUser.map((row)=>row.value);
    const maxValue = Math.max(...values);
    const minValue = Math.min(...values);
    const isVoid = maxValue === minValue;
    let winnerUserId = null;
    if (!isVoid) {
      winnerUserId = valuesByUser.reduce((best, current)=>current.value > best.value ? current : best).userId;
    }
    const nowIso = new Date().toISOString();
    const { error: finalizeError } = await supabaseAdmin.from("match_days").update({
      status: "finalized",
      finalized_at: nowIso,
      winner_user_id: winnerUserId,
      is_void: isVoid
    }).eq("id", matchDayId);
    if (finalizeError) {
      throw finalizeError;
    }
    await invokeInternalFunction("update-leaderboard", {
      match_day_id: matchDayId,
      match_id: dayRow.match_id,
      winner_user_id: winnerUserId,
      is_void: isVoid
    });
    const { data: matchParticipants, error: matchParticipantError } = await supabaseAdmin.from("match_participants").select("user_id").eq("match_id", dayRow.match_id);
    if (matchParticipantError) {
      throw matchParticipantError;
    }
    const matchParticipantRows = matchParticipants ?? [];
    const participantUserIds = Array.from(new Set(matchParticipantRows.map((row)=>String(row.user_id))));
    const { data: matchRow, error: matchError } = await supabaseAdmin.from("matches").select("metric_type, duration_days").eq("id", dayRow.match_id).limit(1).maybeSingle();
    if (matchError) {
      throw matchError;
    }
    const participantNames = await loadParticipantNames(participantUserIds);
    const seriesScores = await computeSeriesScores(dayRow.match_id, participantUserIds);
    for (const userId of participantUserIds){
      const opponentId = participantUserIds.find((value)=>value !== userId) ?? null;
      const opponentDisplayName = opponentId ? participantNames.get(opponentId) ?? "Opponent" : "Opponent";
      const myScore = seriesScores.get(userId) ?? 0;
      const theirScore = opponentId ? seriesScores.get(opponentId) ?? 0 : 0;
      const eventType = isVoid ? "day_void" : winnerUserId === userId ? "day_won" : "day_lost";
      await invokeInternalFunction("dispatch-notification", {
        user_id: userId,
        event_type: eventType,
        payload: {
          match_id: dayRow.match_id,
          match_day_id: matchDayId,
          metric_type: matchRow?.metric_type ?? "steps",
          day_number: Number(dayRow.day_number ?? 1),
          duration_days: Number(matchRow?.duration_days ?? 1),
          opponent_display_name: opponentDisplayName,
          my_score: myScore,
          their_score: theirScore,
          winner_user_id: winnerUserId,
          is_void: isVoid,
          deep_link_target: "match_details"
        }
      });
    }
    const { data: allDayRows, error: allDayError } = await supabaseAdmin.from("match_days").select("id, status").eq("match_id", dayRow.match_id);
    if (allDayError) {
      throw allDayError;
    }
    const allFinalized = (allDayRows ?? []).length > 0 && (allDayRows ?? []).every((row)=>row.status === "finalized");
    if (allFinalized) {
      await invokeInternalFunction("complete-match", {
        match_id: dayRow.match_id
      });
    }
    return jsonResponse(200, {
      status: "finalized",
      match_day_id: matchDayId,
      match_id: dayRow.match_id,
      is_void: isVoid,
      winner_user_id: winnerUserId,
      completed_match: allFinalized
    });
  } catch (error) {
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "finalize-match-day failed."
    });
  }
});
function toNumber(value) {
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
async function loadParticipantNames(userIds) {
  const names = new Map();
  if (userIds.length === 0) {
    return names;
  }
  const { data, error } = await supabaseAdmin.from("profiles").select("id, display_name").in("id", userIds);
  if (error) {
    throw error;
  }
  for (const row of data ?? []){
    names.set(String(row.id), String(row.display_name ?? "Opponent"));
  }
  return names;
}
async function computeSeriesScores(matchId, participantUserIds) {
  const scores = new Map();
  for (const userId of participantUserIds){
    scores.set(userId, 0);
  }
  const { data: dayRows, error } = await supabaseAdmin.from("match_days").select("winner_user_id, status, is_void").eq("match_id", matchId).eq("status", "finalized");
  if (error) {
    throw error;
  }
  for (const row of dayRows ?? []){
    if (row.is_void || !row.winner_user_id) {
      continue;
    }
    const winnerId = String(row.winner_user_id);
    scores.set(winnerId, (scores.get(winnerId) ?? 0) + 1);
  }
  return scores;
}
