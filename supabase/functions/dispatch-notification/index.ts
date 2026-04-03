import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import { corsHeaders, jsonResponse, readJsonBody } from "../_shared/http.ts";
import { apnsConfigured, sendAlertPush, sendLiveActivityPush } from "../_shared/apns.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";

type DispatchNotificationRequest = {
  user_id?: string;
  user_ids?: string[];
  event_type: string;
  payload?: Record<string, unknown>;
  title?: string;
  body?: string;
};

serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed." });
  }

  try {
    const body = await readJsonBody<DispatchNotificationRequest>(request);
    if (!body.event_type || body.event_type.trim().length === 0) {
      return jsonResponse(400, { error: "event_type is required." });
    }

    const userIds = normalizeUserIds(body.user_id, body.user_ids);
    if (userIds.length === 0) {
      return jsonResponse(400, { error: "At least one user_id is required." });
    }

    const eventType = body.event_type.trim();
    const payload = normalizePayload(body.payload);
    const rows = userIds.map((userId) => ({
      user_id: userId,
      event_type: eventType,
      payload,
      status: "pending",
    }));

    const { data: insertedRows, error } = await supabaseAdmin
      .from("notification_events")
      .insert(rows)
      .select("id, user_id, payload");

    if (error) {
      throw error;
    }

    let sent = 0;
    let failed = 0;

    for (const row of insertedRows ?? []) {
      const eventId = String(row.id);
      const userId = String(row.user_id);
      const rowPayload = normalizePayload(row.payload as Record<string, unknown> | null | undefined);

      try {
        const enforceCap = eventType !== "live_activity_update";
        if (enforceCap) {
          const capReached = await reachedDailyCap(userId);
          if (capReached) {
            failed += 1;
            await markFailed(eventId, rowPayload, "daily_cap_reached");
            continue;
          }
        }

        const recipient = await loadRecipient(userId);
        if (!recipient.notificationsEnabled) {
          failed += 1;
          await markFailed(eventId, rowPayload, "notifications_disabled");
          continue;
        }

        if (eventType === "live_activity_update") {
          if (!recipient.liveActivityPushToken) {
            failed += 1;
            await markFailed(eventId, rowPayload, "missing_live_activity_token");
            continue;
          }
          const enrichedPayload = await enrichLiveActivityPayload(userId, rowPayload);
          const liveActivityResult = await sendLiveActivityPush({
            pushToken: recipient.liveActivityPushToken,
            payload: buildLiveActivityPayload(enrichedPayload),
          });
          if (liveActivityResult.ok) {
            sent += 1;
            await markSent(eventId);
          } else {
            failed += 1;
            await markFailed(eventId, rowPayload, `apns_live_activity_${liveActivityResult.status}`);
          }
          continue;
        }

        if (!recipient.apnsToken) {
          failed += 1;
          await markFailed(eventId, rowPayload, "missing_apns_token");
          continue;
        }
        if (!apnsConfigured()) {
          failed += 1;
          await markFailed(eventId, rowPayload, "apns_not_configured");
          continue;
        }

        const rendered = buildMessage(eventType, rowPayload, body.title, body.body);
        const result = await sendAlertPush({
          deviceToken: recipient.apnsToken,
          title: rendered.title,
          body: rendered.body,
          payload: {
            event_type: eventType,
            ...rowPayload,
          },
        });

        if (result.ok) {
          sent += 1;
          await markSent(eventId);
        } else {
          failed += 1;
          await markFailed(eventId, rowPayload, `apns_alert_${result.status}`);
        }
      } catch (processingError) {
        failed += 1;
        const reason = processingError instanceof Error
          ? processingError.message.slice(0, 120)
          : "dispatch_processing_error";
        await markFailed(eventId, rowPayload, reason);
      }
    }

    return jsonResponse(200, {
      inserted: rows.length,
      sent,
      failed,
      status: "processed",
    });
  } catch (error) {
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "dispatch-notification failed.",
    });
  }
});

function normalizeUserIds(userId?: string, userIds?: string[]): string[] {
  const values = new Set<string>();
  if (typeof userId === "string" && userId.trim().length > 0) {
    values.add(userId.trim());
  }
  if (Array.isArray(userIds)) {
    for (const value of userIds) {
      if (typeof value === "string" && value.trim().length > 0) {
        values.add(value.trim());
      }
    }
  }
  return [...values];
}

function normalizePayload(payload: Record<string, unknown> | null | undefined): Record<string, unknown> {
  if (!payload || typeof payload !== "object") {
    return {};
  }
  return payload;
}

function buildMessage(
  eventType: string,
  payload: Record<string, unknown>,
  explicitTitle?: string,
  explicitBody?: string,
): { title: string; body: string } {
  if (explicitBody && explicitBody.trim().length > 0) {
    return {
      title: explicitTitle?.trim() || "FitUp",
      body: explicitBody.trim(),
    };
  }

  const opponent = stringFromPayload(payload, "opponent_display_name", "Opponent");
  const metricLabel = stringFromPayload(payload, "metric_type", "steps") === "active_calories" ? "calories" : "steps";
  const dayNumber = numberFromPayload(payload, "day_number", 1);
  const durationDays = numberFromPayload(payload, "duration_days", 1);
  const myScore = numberFromPayload(payload, "my_score", 0);
  const theirScore = numberFromPayload(payload, "their_score", 0);
  const leadDelta = numberFromPayload(payload, "lead_delta", 0);
  const morningState = stringFromPayload(payload, "standing_label", "tied");

  switch (eventType) {
    case "match_found":
      return { title: "FitUp", body: "Your match is ready - tap to accept" };
    case "challenge_received":
      return { title: "FitUp", body: `${opponent} challenged you - tap to respond` };
    case "challenge_declined":
      return { title: "FitUp", body: `${opponent} declined your challenge` };
    case "match_active":
      return { title: "FitUp", body: "Your match is live. Day 1 starts now." };
    case "lead_changed":
      return { title: "FitUp", body: `${opponent} just passed you - they're up ${leadDelta} ${metricLabel}` };
    case "morning_checkin":
      return { title: "FitUp", body: `Day ${dayNumber} of ${durationDays} - you're ${morningState}. Today matters.` };
    case "pending_reminder":
      return { title: "FitUp", body: `You have a pending match - ${opponent} is waiting` };
    case "day_won":
      return { title: "FitUp", body: `You won Day ${dayNumber}! Series: ${myScore}-${theirScore}` };
    case "day_lost":
      return { title: "FitUp", body: `${opponent} won Day ${dayNumber}. Series: ${myScore}-${theirScore} - fight back tomorrow.` };
    case "day_void":
      return { title: "FitUp", body: `Day ${dayNumber} was voided - data unavailable for both.` };
    case "match_won":
      return { title: "FitUp", body: `You won the match ${myScore}-${theirScore}. Rematch?` };
    case "match_lost":
      return { title: "FitUp", body: `${opponent} won ${theirScore}-${myScore}. Rematch?` };
    default:
      return { title: "FitUp", body: "You have a new FitUp update." };
  }
}

function buildLiveActivityPayload(payload: Record<string, unknown>): Record<string, unknown> {
  return {
    match_id: stringFromPayload(payload, "match_id", ""),
    metric_type: stringFromPayload(payload, "metric_type", "steps"),
    my_total: numberFromPayload(payload, "my_total", 0),
    opponent_total: numberFromPayload(payload, "opponent_total", 0),
    my_score: numberFromPayload(payload, "my_score", 0),
    their_score: numberFromPayload(payload, "their_score", 0),
    day_number: numberFromPayload(payload, "day_number", 1),
    duration_days: numberFromPayload(payload, "duration_days", 1),
    my_display_name: stringFromPayload(payload, "my_display_name", "You"),
    opponent_display_name: stringFromPayload(payload, "opponent_display_name", "Opponent"),
  };
}

async function reachedDailyCap(userId: string): Promise<boolean> {
  const utcStart = new Date();
  utcStart.setUTCHours(0, 0, 0, 0);
  const utcEnd = new Date(utcStart.getTime() + 24 * 60 * 60 * 1000);

  const { count, error } = await supabaseAdmin
    .from("notification_events")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("status", "sent")
    .gte("sent_at", utcStart.toISOString())
    .lt("sent_at", utcEnd.toISOString());

  if (error) {
    throw error;
  }
  return (count ?? 0) >= 10;
}

async function loadRecipient(userId: string): Promise<{
  apnsToken: string | null;
  liveActivityPushToken: string | null;
  notificationsEnabled: boolean;
}> {
  let selectColumns = "apns_token, notifications_enabled, live_activity_push_token";
  let response = await supabaseAdmin
    .from("profiles")
    .select(selectColumns)
    .eq("id", userId)
    .limit(1)
    .maybeSingle();

  if (response.error) {
    selectColumns = "apns_token";
    response = await supabaseAdmin
      .from("profiles")
      .select(selectColumns)
      .eq("id", userId)
      .limit(1)
      .maybeSingle();
  }
  if (response.error) {
    throw response.error;
  }

  const profile = (response.data ?? {}) as Record<string, unknown>;
  const notificationsEnabled = profile.notifications_enabled === undefined
    ? true
    : Boolean(profile.notifications_enabled);

  return {
    apnsToken: asString(profile.apns_token),
    liveActivityPushToken: asString(profile.live_activity_push_token),
    notificationsEnabled,
  };
}

async function markSent(eventId: string): Promise<void> {
  const { error } = await supabaseAdmin
    .from("notification_events")
    .update({
      status: "sent",
      sent_at: new Date().toISOString(),
    })
    .eq("id", eventId);

  if (error) {
    throw error;
  }
}

async function markFailed(
  eventId: string,
  payload: Record<string, unknown>,
  reason: string,
): Promise<void> {
  const nextPayload = {
    ...payload,
    failure_reason: reason,
  };

  await supabaseAdmin
    .from("notification_events")
    .update({
      status: "failed",
      payload: nextPayload,
    })
    .eq("id", eventId);
}

function asString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}

function stringFromPayload(
  payload: Record<string, unknown>,
  key: string,
  fallback: string,
): string {
  const value = payload[key];
  if (typeof value === "string" && value.trim().length > 0) {
    return value.trim();
  }
  return fallback;
}

function numberFromPayload(
  payload: Record<string, unknown>,
  key: string,
  fallback: number,
): number {
  const value = payload[key];
  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) {
      return parsed;
    }
  }
  return fallback;
}

async function enrichLiveActivityPayload(
  userId: string,
  payload: Record<string, unknown>,
): Promise<Record<string, unknown>> {
  const matchId = stringFromPayload(payload, "match_id", "");
  const matchDayId = stringFromPayload(payload, "match_day_id", "");

  if (!matchId || !matchDayId) {
    return payload;
  }

  try {
    const [matchRow, dayParticipants, matchParticipants] = await Promise.all([
      supabaseAdmin
        .from("matches")
        .select("duration_days, metric_type")
        .eq("id", matchId)
        .limit(1)
        .maybeSingle(),
      supabaseAdmin
        .from("match_day_participants")
        .select("user_id, metric_total")
        .eq("match_day_id", matchDayId),
      supabaseAdmin
        .from("match_participants")
        .select("user_id")
        .eq("match_id", matchId),
    ]);

    const durationDays = matchRow.data ? Number(matchRow.data.duration_days) || 1 : 1;

    const myRow = (dayParticipants.data ?? []).find((r) => String(r.user_id) === userId);
    const opponentRow = (dayParticipants.data ?? []).find((r) => String(r.user_id) !== userId);
    const myTotal = toNumber(myRow?.metric_total);
    const opponentTotal = toNumber(opponentRow?.metric_total);
    const opponentId = opponentRow ? String(opponentRow.user_id) : null;

    const participantIds = (matchParticipants.data ?? []).map((r) => String(r.user_id));
    const seriesScores = await computeSeriesScores(matchId, participantIds);
    const myScore = seriesScores.get(userId) ?? 0;
    const theirScore = opponentId ? (seriesScores.get(opponentId) ?? 0) : 0;

    const myDisplayName = await fetchDisplayName(userId);
    const opponentDisplayName = opponentId ? await fetchDisplayName(opponentId) : "Opponent";

    return {
      ...payload,
      duration_days: durationDays,
      my_total: myTotal,
      opponent_total: opponentTotal,
      my_score: myScore,
      their_score: theirScore,
      my_display_name: myDisplayName,
      opponent_display_name: opponentDisplayName,
    };
  } catch {
    return payload;
  }
}

async function computeSeriesScores(matchId: string, participantIds: string[]): Promise<Map<string, number>> {
  const scores = new Map<string, number>();
  for (const id of participantIds) {
    scores.set(id, 0);
  }
  const { data, error } = await supabaseAdmin
    .from("match_days")
    .select("winner_user_id, is_void")
    .eq("match_id", matchId)
    .eq("status", "finalized");
  if (error) {
    return scores;
  }
  for (const row of data ?? []) {
    if (row.is_void || !row.winner_user_id) continue;
    const wid = String(row.winner_user_id);
    scores.set(wid, (scores.get(wid) ?? 0) + 1);
  }
  return scores;
}

async function fetchDisplayName(userId: string): Promise<string> {
  const { data } = await supabaseAdmin
    .from("profiles")
    .select("display_name")
    .eq("id", userId)
    .limit(1)
    .maybeSingle();
  return (data?.display_name as string | undefined)?.trim() || "Opponent";
}

function toNumber(value: unknown): number {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return 0;
}
