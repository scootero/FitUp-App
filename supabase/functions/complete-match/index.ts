import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders, jsonResponse, readJsonBody } from "../_shared/http.ts";
import { invokeInternalFunction, supabaseAdmin } from "../_shared/supabase.ts";
serve(async (request)=>{
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
    const matchId = body.match_id?.trim();
    if (!matchId) {
      return jsonResponse(400, {
        error: "match_id is required."
      });
    }
    const { data: match, error: matchError } = await supabaseAdmin.from("matches").select("id, state, metric_type, duration_days").eq("id", matchId).limit(1).maybeSingle();
    if (matchError) {
      throw matchError;
    }
    if (!match) {
      return jsonResponse(404, {
        error: "Match not found."
      });
    }
    if (match.state === "completed") {
      return jsonResponse(200, {
        status: "already_completed",
        match_id: matchId
      });
    }
    const { data: dayRows, error: dayError } = await supabaseAdmin.from("match_days").select("id, status").eq("match_id", matchId);
    if (dayError) {
      throw dayError;
    }
    const hasPending = (dayRows ?? []).some((row)=>row.status !== "finalized");
    if (hasPending) {
      return jsonResponse(409, {
        status: "not_ready",
        match_id: matchId,
        message: "Cannot complete match until all days are finalized."
      });
    }
    const nowIso = new Date().toISOString();
    const { error: updateError } = await supabaseAdmin.from("matches").update({
      state: "completed",
      completed_at: nowIso
    }).eq("id", matchId).neq("state", "completed");
    if (updateError) {
      throw updateError;
    }
    const participantIds = await loadParticipantIds(matchId);
    const participantNames = await loadParticipantNames(participantIds);
    const seriesScores = await computeSeriesScores(matchId, participantIds);
    const seriesWinner = resolveSeriesWinner(seriesScores);
    if (seriesWinner) {
      for (const userId of participantIds){
        const opponentId = participantIds.find((value)=>value !== userId) ?? null;
        const opponentName = opponentId ? participantNames.get(opponentId) ?? "Opponent" : "Opponent";
        const myScore = seriesScores.get(userId) ?? 0;
        const theirScore = opponentId ? seriesScores.get(opponentId) ?? 0 : 0;
        const eventType = userId === seriesWinner ? "match_won" : "match_lost";
        await invokeInternalFunction("dispatch-notification", {
          user_id: userId,
          event_type: eventType,
          payload: {
            match_id: matchId,
            metric_type: match.metric_type ?? "steps",
            duration_days: Number(match.duration_days ?? 1),
            opponent_display_name: opponentName,
            my_score: myScore,
            their_score: theirScore,
            deep_link_target: "match_details"
          }
        });
      }
    }
    return jsonResponse(200, {
      status: "completed",
      match_id: matchId,
      completed_at: nowIso
    });
  } catch (error) {
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "complete-match failed."
    });
  }
});
async function loadParticipantIds(matchId) {
  const { data, error } = await supabaseAdmin.from("match_participants").select("user_id").eq("match_id", matchId);
  if (error) {
    throw error;
  }
  return Array.from(new Set((data ?? []).map((row)=>String(row.user_id))));
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
  const { data, error } = await supabaseAdmin.from("match_days").select("winner_user_id, status, is_void").eq("match_id", matchId).eq("status", "finalized");
  if (error) {
    throw error;
  }
  for (const row of data ?? []){
    if (row.is_void || !row.winner_user_id) {
      continue;
    }
    const winnerId = String(row.winner_user_id);
    scores.set(winnerId, (scores.get(winnerId) ?? 0) + 1);
  }
  return scores;
}
function resolveSeriesWinner(scores) {
  let winner = null;
  let topScore = -1;
  let hasTie = false;
  for (const [userId, score] of scores.entries()){
    if (score > topScore) {
      topScore = score;
      winner = userId;
      hasTie = false;
    } else if (score === topScore) {
      hasTie = true;
    }
  }
  if (hasTie) {
    return null;
  }
  return winner;
}
