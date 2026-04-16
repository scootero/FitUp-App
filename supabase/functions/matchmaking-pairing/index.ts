import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders, jsonResponse, readJsonBody } from "../_shared/http.ts";
import { runMatchmakingPairing } from "../_shared/matchmakingPairing.ts";
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
    const requestId = body.match_search_request_id?.trim();
    if (!requestId) {
      return jsonResponse(400, {
        error: "match_search_request_id is required."
      });
    }
    const result = await runMatchmakingPairing(requestId);
    if (result.status === "waiting") {
      return jsonResponse(200, {
        status: "waiting"
      });
    }
    if (result.warning) {
      return jsonResponse(200, {
        status: "paired",
        match_id: result.match_id,
        warning: result.warning
      });
    }
    return jsonResponse(200, {
      status: "paired",
      match_id: result.match_id
    });
  } catch (error) {
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "matchmaking-pairing failed."
    });
  }
});
