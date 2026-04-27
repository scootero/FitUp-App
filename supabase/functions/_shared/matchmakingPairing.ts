import { invokeInternalFunction, supabaseAdmin } from "./supabase.ts";

export type MatchmakingPairingResult =
  | { status: "waiting" }
  | { status: "paired"; match_id: string; warning?: string };

export async function runMatchmakingPairing(requestId: string): Promise<MatchmakingPairingResult> {
  const trimmed = requestId.trim();
  if (!trimmed) {
    throw new Error("match_search_request_id is required.");
  }

  const { data: matchId, error: rpcError } = await supabaseAdmin.rpc(
    "matchmaking_pair_atomic",
    { p_request_id: trimmed },
  );
  if (rpcError) {
    throw rpcError;
  }

  if (matchId == null || matchId === "") {
    return { status: "waiting" };
  }

  const matchIdStr = String(matchId);

  const { data: matchRow, error: matchErr } = await supabaseAdmin
    .from("matches")
    .select("metric_type, duration_days")
    .eq("id", matchIdStr)
    .limit(1)
    .maybeSingle();
  if (matchErr) {
    throw matchErr;
  }

  const { data: participantRows, error: participantErr } = await supabaseAdmin
    .from("match_participants")
    .select("user_id")
    .eq("match_id", matchIdStr);
  if (participantErr) {
    throw participantErr;
  }

  const userIds = Array.from(
    new Set((participantRows ?? []).map((row) => String(row.user_id))),
  );
  if (userIds.length !== 2) {
    return {
      status: "paired",
      match_id: matchIdStr,
      warning: "expected_two_participants",
    };
  }

  const names = await loadDisplayNames(userIds);
  const metricType = String(matchRow?.metric_type ?? "steps");
  const durationDays = Number(matchRow?.duration_days ?? 1);

  for (const userId of userIds) {
    const opponentId = userIds.find((id) => id !== userId) ?? null;
    const opponentDisplayName = opponentId ? (names.get(opponentId) ?? "Opponent") : "Opponent";

    await invokeInternalFunction("dispatch-notification", {
      user_id: userId,
      event_type: "match_found",
      payload: {
        match_id: matchIdStr,
        metric_type: metricType,
        duration_days: durationDays,
        opponent_display_name: opponentDisplayName,
        deep_link_target: "home",
      },
    });
  }

  return { status: "paired", match_id: matchIdStr };
}

async function loadDisplayNames(userIds: string[]): Promise<Map<string, string>> {
  const map = new Map<string, string>();
  if (userIds.length === 0) {
    return map;
  }

  const { data, error } = await supabaseAdmin
    .from("profiles")
    .select("id, display_name")
    .in("id", userIds);
  if (error) {
    throw error;
  }

  for (const row of data ?? []) {
    const id = String((row as { id: string }).id);
    const name = (row as { display_name: string | null }).display_name;
    map.set(id, name?.trim() || "Opponent");
  }
  return map;
}
