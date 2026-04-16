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
    const { data: activated, error: rpcError } = await supabaseAdmin.rpc("activate_match_with_days", {
      p_match_id: matchId
    });
    if (rpcError) {
      throw rpcError;
    }
    if (activated !== true) {
      return jsonResponse(200, {
        status: "skipped",
        match_id: matchId
      });
    }
    const { data: matchRow, error: matchErr } = await supabaseAdmin.from("matches").select("metric_type, duration_days").eq("id", matchId).limit(1).maybeSingle();
    if (matchErr) {
      throw matchErr;
    }
    const { data: participantRows, error: participantErr } = await supabaseAdmin.from("match_participants").select("user_id").eq("match_id", matchId);
    if (participantErr) {
      throw participantErr;
    }
    const userIds = Array.from(new Set((participantRows ?? []).map((row)=>String(row.user_id))));
    const names = await loadDisplayNames(userIds);
    const metricType = String(matchRow?.metric_type ?? "steps");
    const durationDays = Number(matchRow?.duration_days ?? 1);
    for (const userId of userIds){
      const opponentId = userIds.find((id)=>id !== userId) ?? null;
      const opponentDisplayName = opponentId ? names.get(opponentId) ?? "Opponent" : "Opponent";
      await invokeInternalFunction("dispatch-notification", {
        user_id: userId,
        event_type: "match_active",
        payload: {
          match_id: matchId,
          metric_type: metricType,
          duration_days: durationDays,
          day_number: 1,
          opponent_display_name: opponentDisplayName,
          deep_link_target: "match_details"
        }
      });
    }
    return jsonResponse(200, {
      status: "activated",
      match_id: matchId
    });
  } catch (error) {
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "on-all-accepted failed."
    });
  }
});
async function loadDisplayNames(userIds) {
  const map = new Map();
  if (userIds.length === 0) {
    return map;
  }
  const { data, error } = await supabaseAdmin.from("profiles").select("id, display_name").in("id", userIds);
  if (error) {
    throw error;
  }
  for (const row of data ?? []){
    const id = String(row.id);
    const name = row.display_name;
    map.set(id, name?.trim() || "Opponent");
  }
  return map;
}
