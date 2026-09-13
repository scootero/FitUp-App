import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { corsHeaders, jsonResponse } from "../_shared/http.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";

serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed." });
  }

  const authHeader = request.headers.get("Authorization") ?? "";
  const token = authHeader.startsWith("Bearer ")
    ? authHeader.slice("Bearer ".length).trim()
    : "";
  if (!token) {
    return jsonResponse(401, { error: "Missing Authorization bearer token." });
  }

  try {
    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);
    if (userError || !userData.user) {
      return jsonResponse(401, { error: "Invalid or expired session." });
    }
    const userId = userData.user.id;

    // Soft-scrub profile row first so rival-facing history can remain anonymized if FKs block hard delete.
    await supabaseAdmin
      .from("profiles")
      .update({
        display_name: "Deleted User",
        initials: "DU",
        apns_token: null,
        live_activity_push_token: null,
        notifications_enabled: false,
      })
      .eq("id", userId);

    const { error: deleteError } = await supabaseAdmin.auth.admin.deleteUser(userId);
    if (deleteError) {
      throw deleteError;
    }

    return jsonResponse(200, { status: "deleted", user_id: userId });
  } catch (error) {
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "delete-account failed.",
    });
  }
});
