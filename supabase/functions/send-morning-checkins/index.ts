import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders, jsonResponse } from "../_shared/http.ts";
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
    const { data: activeRows, error: activeError } = await supabaseAdmin.from("matches").select("id, metric_type, duration_days").eq("state", "active");
    if (activeError) {
      throw activeError;
    }
    const matches = activeRows ?? [];
    let dispatched = 0;
    for (const match of matches){
      const { data: participantRows, error: participantError } = await supabaseAdmin.from("match_participants").select("user_id").eq("match_id", match.id);
      if (participantError) {
        throw participantError;
      }
      const participants = participantRows ?? [];
      if (participants.length < 2) {
        continue;
      }
      const seriesScores = await loadSeriesScores(match.id);
      const currentDay = await currentDayNumber(match.id);
      const totals = await currentDayTotals(match.id);
      for (const participant of participants){
        const alreadySent = await alreadySentToday(participant.user_id, "morning_checkin", match.id);
        if (alreadySent) {
          continue;
        }
        const opponentId = participants.find((row)=>row.user_id !== participant.user_id)?.user_id;
        const opponentName = opponentId ? await fetchDisplayName(opponentId) : "Opponent";
        const myTotal = totals.get(participant.user_id) ?? 0;
        const theirTotal = opponentId ? totals.get(opponentId) ?? 0 : 0;
        const standingLabel = myTotal == theirTotal ? "tied" : myTotal > theirTotal ? "ahead" : "behind";
        const myScore = seriesScores.get(participant.user_id) ?? 0;
        const theirScore = opponentId ? seriesScores.get(opponentId) ?? 0 : 0;
        await invokeInternalFunction("dispatch-notification", {
          user_id: participant.user_id,
          event_type: "morning_checkin",
          payload: {
            match_id: match.id,
            metric_type: match.metric_type,
            opponent_display_name: opponentName,
            day_number: currentDay,
            duration_days: match.duration_days,
            standing_label: standingLabel,
            my_score: myScore,
            their_score: theirScore,
            deep_link_target: "match_details"
          }
        });
        dispatched += 1;
      }
    }
    return jsonResponse(200, {
      status: "ok",
      dispatched,
      matches_scanned: matches.length
    });
  } catch (error) {
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "send-morning-checkins failed."
    });
  }
});
async function alreadySentToday(userId, eventType, matchId) {
  const utcStart = new Date();
  utcStart.setUTCHours(0, 0, 0, 0);
  const { count, error } = await supabaseAdmin.from("notification_events").select("id", {
    count: "exact",
    head: true
  }).eq("user_id", userId).eq("event_type", eventType).gte("created_at", utcStart.toISOString()).contains("payload", {
    match_id: matchId
  });
  if (error) {
    throw error;
  }
  return (count ?? 0) > 0;
}
async function fetchDisplayName(userId) {
  const { data, error } = await supabaseAdmin.from("profiles").select("display_name").eq("id", userId).limit(1).maybeSingle();
  if (error) {
    return "Opponent";
  }
  return data?.display_name ?? "Opponent";
}
async function currentDayNumber(matchId) {
  const { data, error } = await supabaseAdmin.from("match_days").select("day_number, status").eq("match_id", matchId).neq("status", "finalized").order("day_number", {
    ascending: true
  }).limit(1).maybeSingle();
  if (error || !data) {
    return 1;
  }
  return Number(data.day_number) || 1;
}
async function currentDayTotals(matchId) {
  const map = new Map();
  const { data: dayRows, error: dayError } = await supabaseAdmin.from("match_days").select("id, day_number, status").eq("match_id", matchId).neq("status", "finalized").order("day_number", {
    ascending: true
  }).limit(1);
  if (dayError || !dayRows || dayRows.length === 0) {
    return map;
  }
  const dayId = String(dayRows[0].id);
  const { data: participantRows, error: participantError } = await supabaseAdmin.from("match_day_participants").select("user_id, metric_total").eq("match_day_id", dayId);
  if (participantError) {
    return map;
  }
  for (const row of participantRows ?? []){
    map.set(String(row.user_id), toNumber(row.metric_total));
  }
  return map;
}
async function loadSeriesScores(matchId) {
  const scores = new Map();
  const { data: participantRows, error: participantError } = await supabaseAdmin.from("match_participants").select("user_id").eq("match_id", matchId);
  if (!participantError) {
    for (const row of participantRows ?? []){
      scores.set(String(row.user_id), 0);
    }
  }
  const { data: dayRows, error: dayError } = await supabaseAdmin.from("match_days").select("winner_user_id, status, is_void").eq("match_id", matchId).eq("status", "finalized");
  if (dayError) {
    return scores;
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
function toNumber(value) {
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return 0;
}
