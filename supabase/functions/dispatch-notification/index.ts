import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { battleScore } from "../_shared/battleScore.ts";
import { corsHeaders, jsonResponse, readJsonBody } from "../_shared/http.ts";
import { apnsConfigured, sendAlertPush, sendLiveActivityPush } from "../_shared/apns.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";

const HARD_DAILY_ALERT_CAP = 12;
const LEAD_MAX_PER_LOCAL_DAY = 3;
const LEAD_COOLDOWN_HOURS = 3;
const LEAD_MATCH_COOLDOWN_HOURS = 6;
const LEAD_RAW_MIN_SWING = 500;
const LEAD_BS_MIN_SWING = 30;
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
    if (!body.event_type || body.event_type.trim().length === 0) {
      return jsonResponse(400, {
        error: "event_type is required."
      });
    }
    const userIds = normalizeUserIds(body.user_id, body.user_ids);
    if (userIds.length === 0) {
      return jsonResponse(400, {
        error: "At least one user_id is required."
      });
    }
    const eventType = body.event_type.trim();
    const payload = normalizePayload(body.payload);
    const rows = userIds.map((userId)=>({
        user_id: userId,
        event_type: eventType,
        payload,
        status: "pending"
      }));
    const { data: insertedRows, error } = await supabaseAdmin.from("notification_events").insert(rows).select("id, user_id, payload");
    if (error) {
      throw error;
    }
    let sent = 0;
    let failed = 0;
    for (const row of insertedRows ?? []){
      const eventId = String(row.id);
      const userId = String(row.user_id);
      const rowPayload = normalizePayload(row.payload);
      try {
        const enforceCap = eventType !== "live_activity_update" && !isCapExemptEventType(eventType);
        if (enforceCap) {
          const capReached = await reachedHardDailyCap(userId);
          if (capReached) {
            failed += 1;
            await markFailed(eventId, rowPayload, "daily_cap_reached");
            continue;
          }
        }
        if (eventType === "lead_changed") {
          const leadGate = await evaluateLeadChangeGate(userId, rowPayload);
          if (!leadGate.ok) {
            failed += 1;
            await markFailed(eventId, rowPayload, leadGate.reason);
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
            payload: buildLiveActivityPayload(enrichedPayload)
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
            ...rowPayload
          }
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
        const reason = processingError instanceof Error ? processingError.message.slice(0, 120) : "dispatch_processing_error";
        await markFailed(eventId, rowPayload, reason);
      }
    }
    return jsonResponse(200, {
      inserted: rows.length,
      sent,
      failed,
      status: "processed"
    });
  } catch (error) {
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "dispatch-notification failed."
    });
  }
});
function normalizeUserIds(userId, userIds) {
  const values = new Set();
  if (typeof userId === "string" && userId.trim().length > 0) {
    values.add(userId.trim());
  }
  if (Array.isArray(userIds)) {
    for (const value of userIds){
      if (typeof value === "string" && value.trim().length > 0) {
        values.add(value.trim());
      }
    }
  }
  return [
    ...values
  ];
}
function normalizePayload(payload) {
  if (!payload || typeof payload !== "object") {
    return {};
  }
  return payload;
}
/** Short footer for steps battles when `scoring_mode` is present (day/match outcome). */
function stepsResultFooter(payload) {
  const m = stringFromPayload(payload, "metric_type", "steps");
  if (m !== "steps") {
    return "";
  }
  const sm = stringFromPayload(payload, "scoring_mode", "").toLowerCase();
  if (sm === "balanced") {
    return " Final result uses Battle Score.";
  }
  if (sm === "raw") {
    return " Final result uses actual steps.";
  }
  return "";
}
function buildMessage(eventType, payload, explicitTitle, explicitBody) {
  if (explicitBody && explicitBody.trim().length > 0) {
    return {
      title: explicitTitle?.trim() || "FitUp",
      body: explicitBody.trim()
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
  switch(eventType){
    case "match_found":
      return {
        title: "FitUp",
        body: "Your match is ready - tap to accept"
      };
    case "challenge_received":
      return {
        title: "FitUp",
        body: `${opponent} challenged you - tap to respond`
      };
    case "challenge_declined":
      return {
        title: "FitUp",
        body: `${opponent} declined your challenge`
      };
    case "match_active":
      return {
        title: "FitUp",
        body: "Your match is live. Day 1 starts now."
      };
    case "lead_changed": {
      const scoringModeLc = stringFromPayload(payload, "scoring_mode", "").toLowerCase();
      const isBalancedSteps = scoringModeLc === "balanced" && metricLabel === "steps";
      const syncLine = " Open FitUp to sync your latest activity.";
      if (isBalancedSteps) {
        const bsGap = numberFromPayload(payload, "lead_delta_bs", leadDelta);
        return {
          title: "FitUp",
          body: `${opponent} has taken the lead by ${bsGap} Battle Score.${syncLine}`,
        };
      }
      const unitLead = metricLabel === "steps" ? "steps" : metricLabel;
      return {
        title: "FitUp",
        body: `${opponent} has taken the lead by ${leadDelta} ${unitLead}.${syncLine}`,
      };
    }
    case "yesterday_recap": {
      const teaser = stringFromPayload(payload, "teaser", "Open your scoreboard");
      return {
        title: "Yesterday's Results",
        body: teaser,
      };
    }
    case "final_day_comeback": {
      const scoringModeFd = stringFromPayload(payload, "scoring_mode", "").toLowerCase();
      const mTypeFd = stringFromPayload(payload, "metric_type", "steps");
      const isBalancedFd = scoringModeFd === "balanced" && mTypeFd === "steps";
      const gap = numberFromPayload(payload, "checkin_gap", 0);
      const unit = isBalancedFd ? "Battle Score" : mTypeFd === "active_calories" ? "cal" : "steps";
      return {
        title: "FINAL DAY",
        body: `You trail ${opponent} by ${gap} ${unit}. Still time today.`,
      };
    }
    case "morning_checkin": {
      const mTypeMc = stringFromPayload(payload, "metric_type", "steps");
      const scoringModeMc = stringFromPayload(payload, "scoring_mode", "").toLowerCase();
      const balancedMorning = scoringModeMc === "balanced" && mTypeMc === "steps";
      let standingPhrase = morningState;
      if (balancedMorning) {
        if (morningState === "tied") standingPhrase = "tied on Battle Score";
        else if (morningState === "ahead") standingPhrase = "ahead on Battle Score";
        else standingPhrase = "behind on Battle Score";
      }
      return {
        title: "FitUp",
        body: `Day ${dayNumber} of ${durationDays} - you're ${standingPhrase}. Today matters.`
      };
    }
    case "evening_checkin": {
      const matchIdForEvening = stringFromPayload(payload, "match_id", "");
      if (!matchIdForEvening) {
        return {
          title: "FitUp",
          body: "Time to check in—open FitUp to sync today’s stats."
        };
      }
      const mType = stringFromPayload(payload, "metric_type", "steps");
      const scoringModeEv = stringFromPayload(payload, "scoring_mode", "").toLowerCase();
      const isBalancedStepsEv = scoringModeEv === "balanced" && mType === "steps";
      const myD = numberFromPayload(payload, "my_day_total", 0);
      const thD = numberFromPayload(payload, "their_day_total", 0);
      const st = stringFromPayload(payload, "standing_label", "tied");
      let dayPart = "tied today";
      if (isBalancedStepsEv) {
        dayPart = "tied on Battle Score today";
      }
      if (st !== "tied") {
        const gap = isBalancedStepsEv ? numberFromPayload(payload, "checkin_gap", 0) : Math.abs(myD - thD);
        const unitShort = mType === "active_calories" ? "cal" : isBalancedStepsEv ? "Battle Score" : "steps";
        if (st === "ahead") {
          dayPart = `${gap} ${unitShort} ahead today`;
        } else {
          dayPart = `${gap} ${unitShort} behind today`;
        }
      }
      return {
        title: "FitUp",
        body: `vs ${opponent} · ${myScore}-${theirScore} · ${dayPart} — open to sync.`
      };
    }
    case "pending_reminder":
      return {
        title: "FitUp",
        body: `You have a pending match - ${opponent} is waiting`
      };
    case "day_won": {
      const footDay = stepsResultFooter(payload);
      return {
        title: "FitUp",
        body: `You won Day ${dayNumber}! Series: ${myScore}-${theirScore}.${footDay}`
      };
    }
    case "day_lost": {
      const footDayL = stepsResultFooter(payload);
      return {
        title: "FitUp",
        body: `${opponent} won Day ${dayNumber}. Series: ${myScore}-${theirScore} - fight back tomorrow.${footDayL}`
      };
    }
    case "day_void":
      return {
        title: "FitUp",
        body: `Day ${dayNumber} was voided - data unavailable for both.`
      };
    case "match_won": {
      const footMw = stepsResultFooter(payload);
      return {
        title: "Match complete",
        body: `You won ${myScore}–${theirScore} vs ${opponent}. Run it back?${footMw}`,
      };
    }
    case "match_lost": {
      const footMl = stepsResultFooter(payload);
      return {
        title: "Match complete",
        body: `${opponent} won ${theirScore}–${myScore}. Run it back?${footMl}`,
      };
    }
    case "friend_request_received": {
      const fromName = stringFromPayload(
        payload,
        "from_display_name",
        stringFromPayload(payload, "opponent_display_name", "Someone")
      );
      return {
        title: "FitUp",
        body: `${fromName} sent you a friend request`
      };
    }
    case "friend_request_accepted": {
      const accepter = stringFromPayload(
        payload,
        "accepter_display_name",
        stringFromPayload(payload, "opponent_display_name", "Your friend")
      );
      return {
        title: "FitUp",
        body: `${accepter} accepted your friend request`
      };
    }
    case "message_received": {
      const sender = stringFromPayload(
        payload,
        "sender_display_name",
        stringFromPayload(payload, "opponent_display_name", "A friend")
      );
      const preview = stringFromPayload(payload, "message_preview", "");
      const body = preview.length > 0 ? `${sender}: ${preview}` : `${sender} sent you a message`;
      return {
        title: "New message",
        body
      };
    }
    default:
      return {
        title: "FitUp",
        body: "You have a new FitUp update."
      };
  }
}
function isFriendRequestEventType(eventType) {
  return eventType === "friend_request_received" || eventType === "friend_request_accepted";
}
function isCapExemptEventType(eventType) {
  return eventType === "live_activity_update" ||
    isFriendRequestEventType(eventType) ||
    eventType === "yesterday_recap" ||
    eventType === "message_received";
}
function buildLiveActivityPayload(payload) {
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
    opponent_display_name: stringFromPayload(payload, "opponent_display_name", "Opponent")
  };
}
async function reachedHardDailyCap(userId) {
  const exempt = new Set([
    "live_activity_update",
    "yesterday_recap",
    "friend_request_received",
    "friend_request_accepted",
  ]);
  const tz = await loadProfileTimezone(userId);
  const { startIso, endIso } = localDayBoundsUtc(tz);
  const { data, error } = await supabaseAdmin.from("notification_events").select("event_type").eq("user_id", userId)
    .eq("status", "sent").gte("sent_at", startIso).lt("sent_at", endIso);
  if (error) {
    throw error;
  }
  const counted = (data ?? []).filter((row) => !exempt.has(String(row.event_type))).length;
  return counted >= HARD_DAILY_ALERT_CAP;
}
type LeadGateResult = { ok: boolean; reason: string };
async function evaluateLeadChangeGate(userId, payload) {
  const matchId = stringFromPayload(payload, "match_id", "");
  if (!matchId) {
    return { ok: false, reason: "lead_missing_match_id" };
  }
  const tz = await loadProfileTimezone(userId);
  const { startIso } = localDayBoundsUtc(tz);
  const threeHoursAgo = new Date(Date.now() - LEAD_COOLDOWN_HOURS * 60 * 60 * 1000).toISOString();
  const sixHoursAgo = new Date(Date.now() - LEAD_MATCH_COOLDOWN_HOURS * 60 * 60 * 1000).toISOString();

  const { count: dayCount, error: dayErr } = await supabaseAdmin.from("notification_events").select("id", {
    count: "exact",
    head: true,
  }).eq("user_id", userId).eq("event_type", "lead_changed").eq("status", "sent").gte("sent_at", startIso);
  if (dayErr) {
    throw dayErr;
  }
  if ((dayCount ?? 0) >= LEAD_MAX_PER_LOCAL_DAY) {
    return { ok: false, reason: "lead_throttled_daily_cap" };
  }

  const { data: recentGlobal, error: globalErr } = await supabaseAdmin.from("notification_events").select("sent_at").eq(
    "user_id",
    userId,
  ).eq("event_type", "lead_changed").eq("status", "sent").gte("sent_at", threeHoursAgo).order("sent_at", {
    ascending: false,
  }).limit(1);
  if (globalErr) {
    throw globalErr;
  }
  if ((recentGlobal ?? []).length > 0) {
    return { ok: false, reason: "lead_throttled_cooldown" };
  }

  const { count: matchCount, error: matchErr } = await supabaseAdmin.from("notification_events").select("id", {
    count: "exact",
    head: true,
  }).eq("user_id", userId).eq("event_type", "lead_changed").eq("status", "sent").gte("sent_at", sixHoursAgo).contains(
    "payload",
    { match_id: matchId },
  );
  if (matchErr) {
    throw matchErr;
  }
  if ((matchCount ?? 0) > 0) {
    return { ok: false, reason: "lead_throttled_match_cooldown" };
  }

  const swing = await measureLeadSwing(userId, matchId, payload);
  if (!swing.ok) {
    return { ok: false, reason: swing.reason };
  }
  if (swing.leadDeltaBs != null) {
    payload.lead_delta_bs = swing.leadDeltaBs;
  }
  return { ok: true, reason: "ok" };
}
async function measureLeadSwing(userId, matchId, payload) {
  const scoringMode = stringFromPayload(payload, "scoring_mode", "").toLowerCase();
  const metricType = stringFromPayload(payload, "metric_type", "steps");
  const leadDeltaRaw = numberFromPayload(payload, "lead_delta", 0);

  const { data: dayRows } = await supabaseAdmin.from("match_days").select("id").eq("match_id", matchId).neq(
    "status",
    "finalized",
  ).order("day_number", { ascending: true }).limit(1);
  if (!dayRows?.length) {
    return { ok: false, reason: "lead_no_active_day" };
  }
  const dayId = String(dayRows[0].id);
  const { data: mdpRows } = await supabaseAdmin.from("match_day_participants").select("user_id, metric_total").eq(
    "match_day_id",
    dayId,
  );
  const opponentRow = (mdpRows ?? []).find((r) => String(r.user_id) !== userId);
  const myRow = (mdpRows ?? []).find((r) => String(r.user_id) === userId);
  if (!opponentRow || !myRow) {
    return { ok: false, reason: "lead_missing_participants" };
  }
  const myTotal = toNumber(myRow.metric_total);
  const theirTotal = toNumber(opponentRow.metric_total);
  const gapRaw = Math.abs(myTotal - theirTotal);
  if (scoringMode === "balanced" && metricType === "steps") {
    const { data: partRows } = await supabaseAdmin.from("match_participants").select("user_id, baseline_steps").eq(
      "match_id",
      matchId,
    );
    const baselines = new Map();
    for (const pr of partRows ?? []) {
      baselines.set(String(pr.user_id), pr.baseline_steps == null ? null : toNumber(pr.baseline_steps));
    }
    const opponentId = String(opponentRow.user_id);
    const myBS = battleScore(myTotal, baselines.get(userId), baselines.get(opponentId));
    const theirBS = battleScore(theirTotal, baselines.get(opponentId), baselines.get(userId));
    const gapBs = Math.abs(myBS - theirBS);
    if (gapBs < LEAD_BS_MIN_SWING) {
      return { ok: false, reason: "lead_throttled_min_swing" };
    }
    return { ok: true, reason: "ok", leadDeltaBs: gapBs };
  }
  const minSwing = Math.max(LEAD_RAW_MIN_SWING, Math.round(Math.max(myTotal, theirTotal) * 0.01));
  if (gapRaw < minSwing && leadDeltaRaw < minSwing) {
    return { ok: false, reason: "lead_throttled_min_swing" };
  }
  return { ok: true, reason: "ok", leadDeltaBs: null };
}
async function loadProfileTimezone(userId) {
  const { data } = await supabaseAdmin.from("profiles").select("timezone").eq("id", userId).limit(1).maybeSingle();
  const tz = data?.timezone;
  if (typeof tz === "string" && tz.trim().length > 0) {
    return tz.trim();
  }
  return "America/New_York";
}
function localDayBoundsUtc(timezone) {
  const tz = timezone.trim() || "America/New_York";
  const localDate = new Intl.DateTimeFormat("en-CA", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(new Date());
  const [y, m, d] = localDate.split("-").map((v) => parseInt(v, 10));
  const startUtc = new Date(Date.UTC(y, m - 1, d, 0, 0, 0));
  const endUtc = new Date(startUtc.getTime() + 24 * 60 * 60 * 1000);
  return { startIso: startUtc.toISOString(), endIso: endUtc.toISOString(), localDate };
}
async function loadRecipient(userId) {
  let selectColumns = "apns_token, notifications_enabled, live_activity_push_token";
  let response = await supabaseAdmin.from("profiles").select(selectColumns).eq("id", userId).limit(1).maybeSingle();
  if (response.error) {
    selectColumns = "apns_token";
    response = await supabaseAdmin.from("profiles").select(selectColumns).eq("id", userId).limit(1).maybeSingle();
  }
  if (response.error) {
    throw response.error;
  }
  const profile = response.data ?? {};
  const notificationsEnabled = profile.notifications_enabled === undefined ? true : Boolean(profile.notifications_enabled);
  return {
    apnsToken: asString(profile.apns_token),
    liveActivityPushToken: asString(profile.live_activity_push_token),
    notificationsEnabled
  };
}
async function markSent(eventId) {
  const { error } = await supabaseAdmin.from("notification_events").update({
    status: "sent",
    sent_at: new Date().toISOString()
  }).eq("id", eventId);
  if (error) {
    throw error;
  }
}
async function markFailed(eventId, payload, reason) {
  const nextPayload = {
    ...payload,
    failure_reason: reason
  };
  await supabaseAdmin.from("notification_events").update({
    status: "failed",
    payload: nextPayload
  }).eq("id", eventId);
}
function asString(value) {
  if (typeof value !== "string") {
    return null;
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : null;
}
function stringFromPayload(payload, key, fallback) {
  const value = payload[key];
  if (typeof value === "string" && value.trim().length > 0) {
    return value.trim();
  }
  return fallback;
}
function numberFromPayload(payload, key, fallback) {
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
async function enrichLiveActivityPayload(userId, payload) {
  const matchId = stringFromPayload(payload, "match_id", "");
  const matchDayId = stringFromPayload(payload, "match_day_id", "");
  if (!matchId || !matchDayId) {
    return payload;
  }
  try {
    const [matchRow, dayParticipants, matchParticipants] = await Promise.all([
      supabaseAdmin.from("matches").select("duration_days, metric_type").eq("id", matchId).limit(1).maybeSingle(),
      supabaseAdmin.from("match_day_participants").select("user_id, metric_total").eq("match_day_id", matchDayId),
      supabaseAdmin.from("match_participants").select("user_id").eq("match_id", matchId)
    ]);
    const durationDays = matchRow.data ? Number(matchRow.data.duration_days) || 1 : 1;
    const myRow = (dayParticipants.data ?? []).find((r)=>String(r.user_id) === userId);
    const opponentRow = (dayParticipants.data ?? []).find((r)=>String(r.user_id) !== userId);
    const myTotal = toNumber(myRow?.metric_total);
    const opponentTotal = toNumber(opponentRow?.metric_total);
    const opponentId = opponentRow ? String(opponentRow.user_id) : null;
    const participantIds = (matchParticipants.data ?? []).map((r)=>String(r.user_id));
    const seriesScores = await computeSeriesScores(matchId, participantIds);
    const myScore = seriesScores.get(userId) ?? 0;
    const theirScore = opponentId ? seriesScores.get(opponentId) ?? 0 : 0;
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
      opponent_display_name: opponentDisplayName
    };
  } catch  {
    return payload;
  }
}
async function computeSeriesScores(matchId, participantIds) {
  const scores = new Map();
  for (const id of participantIds){
    scores.set(id, 0);
  }
  const { data, error } = await supabaseAdmin.from("match_days").select("winner_user_id, is_void").eq("match_id", matchId).eq("status", "finalized");
  if (error) {
    return scores;
  }
  for (const row of data ?? []){
    if (row.is_void || !row.winner_user_id) continue;
    const wid = String(row.winner_user_id);
    scores.set(wid, (scores.get(wid) ?? 0) + 1);
  }
  return scores;
}
async function fetchDisplayName(userId) {
  const { data } = await supabaseAdmin.from("profiles").select("display_name").eq("id", userId).limit(1).maybeSingle();
  return data?.display_name?.trim() || "Opponent";
}
function toNumber(value) {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string") {
    const parsed = Number(value);
    if (Number.isFinite(parsed)) return parsed;
  }
  return 0;
}
