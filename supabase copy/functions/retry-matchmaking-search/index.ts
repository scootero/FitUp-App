import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import { corsHeaders, jsonResponse, readJsonBody } from "../_shared/http.ts";
import { runMatchmakingPairing } from "../_shared/matchmakingPairing.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";

type RetryBody = {
  match_search_request_id?: string;
};

serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed." });
  }

  const authHeader = request.headers.get("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ") ? authHeader.slice("Bearer ".length).trim() : "";
  if (!token) {
    return jsonResponse(401, { error: "Missing Authorization bearer token." });
  }

  try {
    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);
    if (userError || !userData.user) {
      return jsonResponse(401, { error: "Invalid or expired session." });
    }
    const userId = userData.user.id;

    const body = await readJsonBody<RetryBody>(request);
    const requestId = body.match_search_request_id?.trim();
    if (!requestId) {
      return jsonResponse(400, { error: "match_search_request_id is required." });
    }

    const { data: row, error: rowError } = await supabaseAdmin
      .from("match_search_requests")
      .select("creator_id, status")
      .eq("id", requestId)
      .maybeSingle();

    if (rowError) {
      throw rowError;
    }
    if (!row) {
      return jsonResponse(404, { error: "Search request not found." });
    }

    if (String(row.creator_id) !== userId) {
      return jsonResponse(403, { error: "Not allowed for this search request." });
    }

    if (row.status !== "searching") {
      return jsonResponse(200, { status: "already_resolved" });
    }

    const result = await runMatchmakingPairing(requestId);

    if (result.status === "waiting") {
      return jsonResponse(200, { status: "waiting" });
    }

    if (result.warning) {
      return jsonResponse(200, {
        status: "paired",
        match_id: result.match_id,
        warning: result.warning,
      });
    }

    return jsonResponse(200, {
      status: "paired",
      match_id: result.match_id,
    });
  } catch (error) {
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "retry-matchmaking-search failed.",
    });
  }
});
