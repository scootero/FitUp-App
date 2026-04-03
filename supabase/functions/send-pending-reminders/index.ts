import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import { corsHeaders, jsonResponse } from "../_shared/http.ts";
import { invokeInternalFunction, supabaseAdmin } from "../_shared/supabase.ts";

type PendingMatch = {
  id: string;
  metric_type: string;
};

type MatchParticipant = {
  user_id: string;
  accepted_at: string | null;
};

serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed." });
  }

  try {
    const { data: pendingRows, error: pendingError } = await supabaseAdmin
      .from("matches")
      .select("id, metric_type")
      .eq("state", "pending");
    if (pendingError) {
      throw pendingError;
    }

    const pendingMatches = (pendingRows ?? []) as PendingMatch[];
    let dispatched = 0;

    for (const match of pendingMatches) {
      const { data: participantRows, error: participantError } = await supabaseAdmin
        .from("match_participants")
        .select("user_id, accepted_at")
        .eq("match_id", match.id);
      if (participantError) {
        throw participantError;
      }
      const participants = (participantRows ?? []) as MatchParticipant[];
      if (participants.length < 2) {
        continue;
      }

      const waiting = participants.find((row) => row.accepted_at !== null);
      if (!waiting) {
        continue;
      }

      const waitingName = await fetchDisplayName(waiting.user_id);
      const recipients = participants.filter((row) => row.accepted_at === null);
      for (const recipient of recipients) {
        const alreadySent = await alreadySentToday(recipient.user_id, "pending_reminder", match.id);
        if (alreadySent) {
          continue;
        }
        await invokeInternalFunction("dispatch-notification", {
          user_id: recipient.user_id,
          event_type: "pending_reminder",
          payload: {
            match_id: match.id,
            metric_type: match.metric_type,
            opponent_display_name: waitingName,
            deep_link_target: "match_details",
          },
        });
        dispatched += 1;
      }
    }

    return jsonResponse(200, {
      status: "ok",
      dispatched,
      matches_scanned: pendingMatches.length,
    });
  } catch (error) {
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "send-pending-reminders failed.",
    });
  }
});

async function alreadySentToday(
  userId: string,
  eventType: string,
  matchId: string,
): Promise<boolean> {
  const utcStart = new Date();
  utcStart.setUTCHours(0, 0, 0, 0);

  const { count, error } = await supabaseAdmin
    .from("notification_events")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("event_type", eventType)
    .gte("created_at", utcStart.toISOString())
    .contains("payload", { match_id: matchId });
  if (error) {
    throw error;
  }
  return (count ?? 0) > 0;
}

async function fetchDisplayName(userId: string): Promise<string> {
  const { data, error } = await supabaseAdmin
    .from("profiles")
    .select("display_name")
    .eq("id", userId)
    .limit(1)
    .maybeSingle();
  if (error) {
    return "Opponent";
  }
  return (data?.display_name as string | undefined) ?? "Opponent";
}
