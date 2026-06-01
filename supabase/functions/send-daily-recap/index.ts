import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { battleScore } from "../_shared/battleScore.ts";
import { corsHeaders, jsonResponse } from "../_shared/http.ts";
import { invokeEdgeFunctionAsync, supabaseAdmin } from "../_shared/supabase.ts";

/** Local wall-clock hour for bundled yesterday recap (aligns with day cutoff). */
const RECAP_LOCAL_HOUR = 10;
/** Local wall-clock hour for final-day trailing comeback. */
const COMEBACK_LOCAL_HOUR = 16;

const MAX_RECAP_CARDS = 5;

type RecapCard = {
  match_id: string;
  rival_display_name: string;
  yesterday_winner: "you" | "opponent" | "void" | "none";
  yesterday_margin: number;
  yesterday_margin_label: string;
  series_my: number;
  series_their: number;
  days_left: number;
  is_final_day: boolean;
  final_day_standing: "ahead" | "behind" | "tied";
  scoring_mode: string;
  metric_type: string;
  urgency_rank: number;
};

serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed." });
  }

  try {
    const { data: participantRows, error: participantError } = await supabaseAdmin
      .from("match_participants")
      .select("user_id, profiles!inner(id, timezone), matches!inner(state)")
      .eq("matches.state", "active");
    if (participantError) {
      throw participantError;
    }

    const usersById = new Map<string, { timezone: string }>();
    for (const row of participantRows ?? []) {
      const uid = String(row.user_id);
      const prof = row.profiles as { id: string; timezone: string | null };
      if (!usersById.has(uid)) {
        usersById.set(uid, { timezone: asString(prof?.timezone) ?? "America/New_York" });
      }
    }

    let recapDispatched = 0;
    let recapSkippedNoCards = 0;
    let comebackDispatched = 0;

    for (const [userId, meta] of usersById) {
      const tz = meta.timezone;
      const { hour, localDate } = userLocalParts(tz);
      const yesterdayDate = offsetLocalDate(localDate, -1);

      if (hour === RECAP_LOCAL_HOUR) {
        const already = await alreadySentForLocalDate(userId, "yesterday_recap", localDate);
        if (already) {
          continue;
        }
        const cards = await buildRecapCardsForUser(userId, yesterdayDate);
        if (cards.length === 0) {
          recapSkippedNoCards += 1;
          continue;
        }
        const teaser = buildRecapTeaser(cards);
        await invokeEdgeFunctionAsync("dispatch-notification", {
          user_id: userId,
          event_type: "yesterday_recap",
          payload: {
            recap_date: localDate,
            teaser,
            match_count: cards.length,
            recap_cards: cards,
            deep_link_target: "recap_inbox",
          },
        });
        recapDispatched += 1;
      }

      if (hour === COMEBACK_LOCAL_HOUR) {
        const picks = await finalDayComebackPicks(userId, localDate);
        for (const pick of picks) {
          const already = await alreadySentComeback(userId, pick.matchId, localDate);
          if (already) {
            continue;
          }
          await invokeEdgeFunctionAsync("dispatch-notification", {
            user_id: userId,
            event_type: "final_day_comeback",
            payload: {
              local_date: localDate,
              match_id: pick.matchId,
              metric_type: pick.metricType,
              scoring_mode: pick.scoringMode || undefined,
              opponent_display_name: pick.opponentName,
              my_score: pick.myScore,
              their_score: pick.theirScore,
              checkin_gap: pick.gap,
              standing_label: "behind",
              deep_link_target: "match_details",
            },
          });
          comebackDispatched += 1;
        }
      }
    }

    return jsonResponse(200, {
      status: "ok",
      recap_dispatched: recapDispatched,
      recap_skipped_no_cards: recapSkippedNoCards,
      comeback_dispatched: comebackDispatched,
      users_with_active_matches: usersById.size,
      recap_local_hour: RECAP_LOCAL_HOUR,
    });
  } catch (error) {
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "send-daily-recap failed.",
    });
  }
});

async function buildRecapCardsForUser(userId: string, yesterdayDate: string): Promise<RecapCard[]> {
  const { data: rows, error } = await supabaseAdmin
    .from("match_participants")
    .select("match_id, matches!inner(id, state, metric_type, duration_days, scoring_mode)")
    .eq("user_id", userId);
  if (error) {
    throw error;
  }

  const cards: RecapCard[] = [];
  for (const row of rows ?? []) {
    const m = row.matches as {
      id: string;
      state: string;
      metric_type: string;
      duration_days: number;
      scoring_mode: string | null;
    };
    if (!m || m.state !== "active") {
      continue;
    }
    const matchId = String(row.match_id);
    const card = await buildRecapCard(userId, matchId, m, yesterdayDate);
    if (card) {
      cards.push(card);
    }
  }

  cards.sort((a, b) => b.urgency_rank - a.urgency_rank);
  return cards.slice(0, MAX_RECAP_CARDS);
}

async function buildRecapCard(
  userId: string,
  matchId: string,
  match: { metric_type: string; duration_days: number; scoring_mode: string | null },
  yesterdayDate: string,
): Promise<RecapCard | null> {
  const { data: partRows, error: pErr } = await supabaseAdmin
    .from("match_participants")
    .select("user_id, baseline_steps")
    .eq("match_id", matchId);
  if (pErr) {
    throw pErr;
  }
  const parts = partRows ?? [];
  if (parts.length < 2) {
    return null;
  }
  const opponentId = parts.map((p) => String(p.user_id)).find((id) => id !== userId);
  if (!opponentId) {
    return null;
  }

  const baselines = new Map<string, number | null>();
  for (const pr of parts) {
    const raw = pr.baseline_steps;
    baselines.set(String(pr.user_id), raw == null ? null : toNumber(raw));
  }

  const scoringMode = match.scoring_mode != null ? String(match.scoring_mode) : "";
  const metricType = String(match.metric_type);
  const isBalancedSteps = scoringMode === "balanced" && metricType === "steps";
  const marginLabel = isBalancedSteps ? "Battle Score" : metricType === "active_calories" ? "cal" : "steps";

  const [opponentName, seriesScores, currentTotals, yesterdayDay] = await Promise.all([
    fetchDisplayName(opponentId),
    loadSeriesScores(matchId),
    currentDayTotals(matchId),
    loadYesterdayDay(
      matchId,
      yesterdayDate,
      userId,
      opponentId,
      isBalancedSteps,
      baselines,
    ),
  ]);

  const myScore = seriesScores.get(userId) ?? 0;
  const theirScore = seriesScores.get(opponentId) ?? 0;
  const durationDays = Number(match.duration_days) || 1;
  const finalizedCount = await countFinalizedDays(matchId);
  const daysLeft = Math.max(0, durationDays - finalizedCount);
  const isFinalDay = daysLeft === 1;

  let yesterdayWinner: RecapCard["yesterday_winner"] = "none";
  let yesterdayMargin = 0;
  if (yesterdayDay) {
    if (yesterdayDay.is_void) {
      yesterdayWinner = "void";
    } else if (yesterdayDay.winner_user_id === userId) {
      yesterdayWinner = "you";
      yesterdayMargin = Math.abs(yesterdayDay.myValue - yesterdayDay.theirValue);
    } else if (yesterdayDay.winner_user_id === opponentId) {
      yesterdayWinner = "opponent";
      yesterdayMargin = Math.abs(yesterdayDay.myValue - yesterdayDay.theirValue);
    }
  }

  const myTotal = currentTotals.get(userId) ?? 0;
  const theirTotal = currentTotals.get(opponentId) ?? 0;
  let finalDayStanding: RecapCard["final_day_standing"] = "tied";
  if (isBalancedSteps) {
    const myB = baselines.get(userId) ?? null;
    const ob = baselines.get(opponentId) ?? null;
    const myBS = battleScore(myTotal, myB, ob);
    const theirBS = battleScore(theirTotal, ob, myB);
    finalDayStanding = myBS === theirBS ? "tied" : myBS > theirBS ? "ahead" : "behind";
  } else {
    finalDayStanding = myTotal === theirTotal ? "tied" : myTotal > theirTotal ? "ahead" : "behind";
  }

  const includeCard = yesterdayWinner !== "none" || isFinalDay;
  if (!includeCard) {
    return null;
  }

  let urgency = 0;
  if (isFinalDay) urgency += 1000;
  if (myScore === theirScore) urgency += 500;
  if (daysLeft <= 1) urgency += 300;
  if (yesterdayWinner === "opponent") urgency += 200;
  if (yesterdayMargin > 0 && yesterdayMargin < 800) urgency += 100;

  return {
    match_id: matchId,
    rival_display_name: opponentName,
    yesterday_winner: yesterdayWinner,
    yesterday_margin: Math.round(yesterdayMargin),
    yesterday_margin_label: marginLabel,
    series_my: myScore,
    series_their: theirScore,
    days_left: daysLeft,
    is_final_day: isFinalDay,
    final_day_standing: finalDayStanding,
    scoring_mode: scoringMode,
    metric_type: metricType,
    urgency_rank: urgency,
  };
}

type YesterdayDay = {
  winner_user_id: string | null;
  is_void: boolean;
  myValue: number;
  theirValue: number;
};

async function loadYesterdayDay(
  matchId: string,
  calendarDate: string,
  userId: string,
  opponentId: string,
  useBalancedWinner: boolean,
  baselineByUser: Map<string, number | null>,
): Promise<YesterdayDay | null> {
  const finalized = await loadYesterdayFromDayRow(
    matchId,
    calendarDate,
    userId,
    opponentId,
    "finalized",
    true,
  );
  if (finalized) {
    return finalized;
  }
  return await loadYesterdayFromDayRow(
    matchId,
    calendarDate,
    userId,
    opponentId,
    "pending",
    false,
    useBalancedWinner,
    baselineByUser,
  );
}

async function loadYesterdayFromDayRow(
  matchId: string,
  calendarDate: string,
  userId: string,
  opponentId: string,
  status: string,
  useStoredWinner: boolean,
  useBalancedWinner = false,
  baselineByUser?: Map<string, number | null>,
): Promise<YesterdayDay | null> {
  const { data: dayRow, error: dayErr } = await supabaseAdmin
    .from("match_days")
    .select("id, winner_user_id, is_void")
    .eq("match_id", matchId)
    .eq("calendar_date", calendarDate)
    .eq("status", status)
    .limit(1)
    .maybeSingle();
  if (dayErr || !dayRow) {
    return null;
  }
  const { data: mdpRows, error: mdpErr } = await supabaseAdmin
    .from("match_day_participants")
    .select("user_id, finalized_value, metric_total")
    .eq("match_day_id", dayRow.id);
  if (mdpErr || !mdpRows || mdpRows.length < 2) {
    return null;
  }
  const byUser = new Map<string, number>();
  for (const r of mdpRows) {
    byUser.set(String(r.user_id), toNumber(r.finalized_value ?? r.metric_total));
  }
  const myValue = byUser.get(userId) ?? 0;
  const theirValue = byUser.get(opponentId) ?? 0;

  if (useStoredWinner) {
    return {
      winner_user_id: dayRow.winner_user_id ? String(dayRow.winner_user_id) : null,
      is_void: Boolean(dayRow.is_void),
      myValue,
      theirValue,
    };
  }

  let winnerUserId: string | null = null;
  let isVoid = false;
  if (useBalancedWinner && baselineByUser) {
    const ratios: { userId: string; ratio: number }[] = [];
    for (const [uid, value] of byUser) {
      const rawBaseline = baselineByUser.get(uid);
      const baselineNum = rawBaseline === null || rawBaseline === undefined ? 0 : toNumber(rawBaseline);
      const effectiveBaseline = baselineNum > 0 ? Math.max(3000, baselineNum) : 3000;
      ratios.push({ userId: uid, ratio: effectiveBaseline > 0 ? value / effectiveBaseline : 0 });
    }
    const ratioValues = ratios.map((r) => r.ratio);
    const maxR = Math.max(...ratioValues);
    const minR = Math.min(...ratioValues);
    isVoid = maxR === minR;
    if (!isVoid) {
      winnerUserId = ratios.reduce((best, cur) => (cur.ratio > best.ratio ? cur : best)).userId;
    }
  } else {
    const values = [...byUser.entries()];
    const nums = values.map(([, v]) => v);
    const maxV = Math.max(...nums);
    const minV = Math.min(...nums);
    isVoid = maxV === minV;
    if (!isVoid) {
      winnerUserId = values.reduce((best, cur) => (cur[1] > best[1] ? cur : best))[0];
    }
  }

  return {
    winner_user_id: winnerUserId,
    is_void: isVoid,
    myValue,
    theirValue,
  };
}

function buildRecapTeaser(cards: RecapCard[]): string {
  const wins = cards.filter((c) => c.yesterday_winner === "you").length;
  const losses = cards.filter((c) => c.yesterday_winner === "opponent").length;
  const finalDay = cards.find((c) => c.is_final_day);
  const parts: string[] = [];
  if (wins + losses > 0) {
    parts.push(`W${wins}–L${losses}`);
  }
  if (finalDay) {
    parts.push(`FINAL DAY vs ${finalDay.rival_display_name}`);
  } else if (cards[0]) {
    parts.push(`vs ${cards[0].rival_display_name}`);
  }
  return parts.join(" · ") || "Open your scoreboard";
}

type ComebackPick = {
  matchId: string;
  metricType: string;
  scoringMode: string;
  opponentName: string;
  myScore: number;
  theirScore: number;
  gap: number;
};

async function finalDayComebackPicks(userId: string, localDate: string): Promise<ComebackPick[]> {
  const { data: rows, error } = await supabaseAdmin
    .from("match_participants")
    .select("match_id, matches!inner(id, state, metric_type, duration_days, scoring_mode)")
    .eq("user_id", userId);
  if (error) {
    throw error;
  }

  const picks: ComebackPick[] = [];
  for (const row of rows ?? []) {
    const m = row.matches as {
      state: string;
      metric_type: string;
      duration_days: number;
      scoring_mode: string | null;
    };
    if (!m || m.state !== "active") {
      continue;
    }
    const matchId = String(row.match_id);
    const durationDays = Number(m.duration_days) || 1;
    const finalizedCount = await countFinalizedDays(matchId);
    const daysLeft = Math.max(0, durationDays - finalizedCount);
    if (daysLeft !== 1) {
      continue;
    }

    const { data: partRows } = await supabaseAdmin
      .from("match_participants")
      .select("user_id, baseline_steps")
      .eq("match_id", matchId);
    const parts = partRows ?? [];
    const opponentId = parts.map((p) => String(p.user_id)).find((id) => id !== userId);
    if (!opponentId) {
      continue;
    }

    const baselines = new Map<string, number | null>();
    for (const pr of parts) {
      baselines.set(String(pr.user_id), pr.baseline_steps == null ? null : toNumber(pr.baseline_steps));
    }

    const scoringMode = m.scoring_mode != null ? String(m.scoring_mode) : "";
    const metricType = String(m.metric_type);
    const isBalancedSteps = scoringMode === "balanced" && metricType === "steps";
    const totals = await currentDayTotals(matchId);
    const myTotal = totals.get(userId) ?? 0;
    const theirTotal = totals.get(opponentId) ?? 0;

    let gap = 0;
    let trailing = false;
    if (isBalancedSteps) {
      const myBS = battleScore(myTotal, baselines.get(userId), baselines.get(opponentId));
      const theirBS = battleScore(theirTotal, baselines.get(opponentId), baselines.get(userId));
      gap = Math.abs(myBS - theirBS);
      trailing = myBS < theirBS;
      if (trailing && gap < 20) {
        continue;
      }
    } else {
      gap = Math.abs(myTotal - theirTotal);
      trailing = myTotal < theirTotal;
      if (trailing && gap < 300) {
        continue;
      }
    }
    if (!trailing) {
      continue;
    }

    const seriesScores = await loadSeriesScores(matchId);
    picks.push({
      matchId,
      metricType,
      scoringMode,
      opponentName: await fetchDisplayName(opponentId),
      myScore: seriesScores.get(userId) ?? 0,
      theirScore: seriesScores.get(opponentId) ?? 0,
      gap,
    });
  }
  return picks;
}

async function alreadySentForLocalDate(userId: string, eventType: string, localDate: string) {
  const { count, error } = await supabaseAdmin
    .from("notification_events")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("event_type", eventType)
    .contains("payload", { recap_date: localDate });
  if (error) {
    throw error;
  }
  return (count ?? 0) > 0;
}

async function alreadySentComeback(userId: string, matchId: string, localDate: string) {
  const { count, error } = await supabaseAdmin
    .from("notification_events")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("event_type", "final_day_comeback")
    .contains("payload", { local_date: localDate, match_id: matchId });
  if (error) {
    throw error;
  }
  return (count ?? 0) > 0;
}

async function fetchDisplayName(uid: string) {
  const { data } = await supabaseAdmin.from("profiles").select("display_name").eq("id", uid).limit(1).maybeSingle();
  return data?.display_name?.trim() || "Opponent";
}

async function countFinalizedDays(matchId: string) {
  const { count } = await supabaseAdmin
    .from("match_days")
    .select("id", { count: "exact", head: true })
    .eq("match_id", matchId)
    .eq("status", "finalized");
  return count ?? 0;
}

async function currentDayTotals(matchId: string) {
  const map = new Map<string, number>();
  const { data: dayRows } = await supabaseAdmin
    .from("match_days")
    .select("id")
    .eq("match_id", matchId)
    .neq("status", "finalized")
    .order("day_number", { ascending: true })
    .limit(1);
  if (!dayRows?.length) {
    return map;
  }
  const { data: participantRows } = await supabaseAdmin
    .from("match_day_participants")
    .select("user_id, metric_total")
    .eq("match_day_id", dayRows[0].id);
  for (const row of participantRows ?? []) {
    map.set(String(row.user_id), toNumber(row.metric_total));
  }
  return map;
}

async function loadSeriesScores(matchId: string) {
  const scores = new Map<string, number>();
  const { data: participantRows } = await supabaseAdmin.from("match_participants").select("user_id").eq("match_id", matchId);
  for (const row of participantRows ?? []) {
    scores.set(String(row.user_id), 0);
  }
  const { data: dayRows } = await supabaseAdmin
    .from("match_days")
    .select("winner_user_id, is_void")
    .eq("match_id", matchId)
    .eq("status", "finalized");
  for (const row of dayRows ?? []) {
    if (row.is_void || !row.winner_user_id) {
      continue;
    }
    const wid = String(row.winner_user_id);
    scores.set(wid, (scores.get(wid) ?? 0) + 1);
  }
  return scores;
}

function userLocalParts(timezone: string): { hour: number; localDate: string } {
  const tz = timezone.trim() || "America/New_York";
  const now = new Date();
  const hour = parseInt(
    new Intl.DateTimeFormat("en-GB", { timeZone: tz, hour: "2-digit", hourCycle: "h23" }).format(now),
    10,
  );
  const localDate = new Intl.DateTimeFormat("en-CA", {
    timeZone: tz,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
  }).format(now);
  return { hour, localDate };
}

function offsetLocalDate(localDate: string, dayDelta: number): string {
  const [y, m, d] = localDate.split("-").map((v) => parseInt(v, 10));
  const dt = new Date(Date.UTC(y, m - 1, d));
  dt.setUTCDate(dt.getUTCDate() + dayDelta);
  return dt.toISOString().slice(0, 10);
}

function toNumber(value: unknown) {
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

function asString(value: unknown): string | null {
  if (typeof value !== "string") {
    return null;
  }
  const t = value.trim();
  return t.length > 0 ? t : null;
}
