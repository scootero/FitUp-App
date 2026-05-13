import { serve } from "https://deno.land/std@0.224.0/http/server.ts";
import { battleScore } from "../_shared/battleScore.ts";
import { corsHeaders, jsonResponse } from "../_shared/http.ts";
import { invokeInternalFunction, supabaseAdmin } from "../_shared/supabase.ts";

type CandidateRow = {
  user_id: string;
  local_date: string;
};

serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", {
      headers: corsHeaders,
    });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, {
      error: "Method not allowed.",
    });
  }
  try {
    const { data: candidateRows, error: rpcError } = await supabaseAdmin.rpc("evening_checkin_candidates");
    if (rpcError) {
      throw rpcError;
    }
    const candidates = (candidateRows ?? []) as CandidateRow[];
    let dispatched = 0;
    for (const row of candidates) {
      const userId = String(row.user_id);
      const localDate = String(row.local_date);
      const already = await alreadySentThisLocalDate(userId, localDate);
      if (already) {
        continue;
      }
      const pick = await pickClosestActiveMatchForUser(userId);
      if (!pick) {
        await invokeInternalFunction("dispatch-notification", {
          user_id: userId,
          event_type: "evening_checkin",
          payload: {
            local_date: localDate,
            deep_link_target: "home",
          },
        });
        dispatched += 1;
        continue;
      }
      const opponentName = pick.opponentName;
      await invokeInternalFunction("dispatch-notification", {
        user_id: userId,
        event_type: "evening_checkin",
        payload: {
          local_date: localDate,
          match_id: pick.matchId,
          metric_type: pick.metricType,
          scoring_mode: pick.scoringMode || undefined,
          opponent_display_name: opponentName,
          day_number: pick.dayNumber,
          duration_days: pick.durationDays,
          standing_label: pick.standing,
          my_score: pick.myScore,
          their_score: pick.theirScore,
          my_day_total: pick.myDayTotal,
          their_day_total: pick.theirDayTotal,
          checkin_gap: pick.checkinGap,
          deep_link_target: "match_details",
        },
      });
      dispatched += 1;
    }
    return jsonResponse(200, {
      status: "ok",
      dispatched,
      candidates: candidates.length,
    });
  } catch (error) {
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "send-evening-checkins failed.",
    });
  }
});

async function alreadySentThisLocalDate(userId: string, localDate: string) {
  const { count, error } = await supabaseAdmin
    .from("notification_events")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("event_type", "evening_checkin")
    .contains("payload", { local_date: localDate });
  if (error) {
    throw error;
  }
  return (count ?? 0) > 0;
}

type ClosestMatchPick = {
  matchId: string;
  metricType: string;
  scoringMode: string;
  durationDays: number;
  seriesMargin: number;
  dayGap: number;
  opponentName: string;
  dayNumber: number;
  myScore: number;
  theirScore: number;
  myDayTotal: number;
  theirDayTotal: number;
  standing: string;
  checkinGap: number;
};

async function pickClosestActiveMatchForUser(userId: string): Promise<ClosestMatchPick | null> {
  const { data: rows, error } = await supabaseAdmin
    .from("match_participants")
    .select("match_id, matches!inner(id, state, metric_type, duration_days, scoring_mode)")
    .eq("user_id", userId);
  if (error) {
    throw error;
  }
  const active = (rows ?? []).filter(
    (r: {
      match_id: string;
      matches: { state: string; metric_type: string; duration_days: number; scoring_mode: string | null };
    }) => r.matches?.state === "active",
  );
  if (active.length === 0) {
    return null;
  }
  const selfId = String(userId);
  const scored: ClosestMatchPick[] = [];
  for (const row of active) {
    const m = row.matches;
    const matchId = String(row.match_id);
    const scoringMode = m.scoring_mode != null ? String(m.scoring_mode) : "";
    const { data: pRows, error: pErr } = await supabaseAdmin
      .from("match_participants")
      .select("user_id, baseline_steps")
      .eq("match_id", matchId);
    if (pErr) {
      throw pErr;
    }
    const parts = pRows ?? [];
    if (parts.length < 2) {
      continue;
    }
    const opponentId = parts.map((p) => String(p.user_id)).find((id) => id !== selfId);
    if (!opponentId) {
      continue;
    }
    const baselines = new Map<string, number | null>();
    for (const pr of parts) {
      const raw = pr.baseline_steps;
      baselines.set(String(pr.user_id), raw == null ? null : toNumber(raw));
    }
    const [seriesScores, totals, dayNumber, opponentName] = await Promise.all([
      loadSeriesScores(matchId),
      currentDayTotals(matchId),
      currentDayNumber(matchId),
      fetchDisplayName(opponentId),
    ]);
    const myTotal = totals.get(selfId) ?? 0;
    const theirTotal = totals.get(opponentId) ?? 0;
    const isBalancedSteps = scoringMode === "balanced" && String(m.metric_type) === "steps";

    let standing: string;
    let dayGap: number;
    let checkinGap: number;

    if (isBalancedSteps) {
      const myB = baselines.get(selfId) ?? null;
      const ob = baselines.get(opponentId) ?? null;
      const myBS = battleScore(myTotal, myB, ob);
      const theirBS = battleScore(theirTotal, ob, myB);
      standing = myBS === theirBS ? "tied" : myBS > theirBS ? "ahead" : "behind";
      dayGap = Math.abs(myBS - theirBS);
      checkinGap = dayGap;
    } else {
      standing = myTotal == theirTotal ? "tied" : myTotal > theirTotal ? "ahead" : "behind";
      dayGap = Math.abs(myTotal - theirTotal);
      checkinGap = dayGap;
    }

    const myScore = seriesScores.get(selfId) ?? 0;
    const theirScore = seriesScores.get(opponentId) ?? 0;
    const seriesMargin = Math.abs(myScore - theirScore);
    scored.push({
      matchId,
      metricType: String(m.metric_type),
      scoringMode,
      durationDays: Number(m.duration_days) || 1,
      seriesMargin,
      dayGap,
      opponentName,
      dayNumber: dayNumber,
      myScore,
      theirScore,
      myDayTotal: myTotal,
      theirDayTotal: theirTotal,
      standing,
      checkinGap,
    });
  }
  if (scored.length === 0) {
    return null;
  }
  scored.sort((a, b) => {
    if (a.seriesMargin !== b.seriesMargin) {
      return a.seriesMargin - b.seriesMargin;
    }
    if (a.dayGap !== b.dayGap) {
      return a.dayGap - b.dayGap;
    }
    return a.matchId < b.matchId ? -1 : a.matchId > b.matchId ? 1 : 0;
  });
  return scored[0] ?? null;
}

async function fetchDisplayName(uid: string) {
  const { data, error } = await supabaseAdmin.from("profiles").select("display_name").eq("id", uid).limit(1).maybeSingle();
  if (error) {
    return "Opponent";
  }
  return data?.display_name ?? "Opponent";
}

async function currentDayNumber(matchId: string) {
  const { data, error } = await supabaseAdmin
    .from("match_days")
    .select("day_number, status")
    .eq("match_id", matchId)
    .neq("status", "finalized")
    .order("day_number", { ascending: true })
    .limit(1)
    .maybeSingle();
  if (error || !data) {
    return 1;
  }
  return Number(data.day_number) || 1;
}

async function currentDayTotals(matchId: string) {
  const map = new Map<string, number>();
  const { data: dayRows, error: dayError } = await supabaseAdmin
    .from("match_days")
    .select("id, day_number, status")
    .eq("match_id", matchId)
    .neq("status", "finalized")
    .order("day_number", { ascending: true })
    .limit(1);
  if (dayError || !dayRows || dayRows.length === 0) {
    return map;
  }
  const dayId = String(dayRows[0].id);
  const { data: participantRows, error: participantError } = await supabaseAdmin
    .from("match_day_participants")
    .select("user_id, metric_total")
    .eq("match_day_id", dayId);
  if (participantError) {
    return map;
  }
  for (const row of participantRows ?? []) {
    map.set(String(row.user_id), toNumber(row.metric_total));
  }
  return map;
}

async function loadSeriesScores(matchId: string) {
  const scores = new Map<string, number>();
  const { data: participantRows, error: participantError } = await supabaseAdmin
    .from("match_participants")
    .select("user_id")
    .eq("match_id", matchId);
  if (!participantError) {
    for (const row of participantRows ?? []) {
      scores.set(String(row.user_id), 0);
    }
  }
  const { data: dayRows, error: dayError } = await supabaseAdmin
    .from("match_days")
    .select("winner_user_id, status, is_void")
    .eq("match_id", matchId)
    .eq("status", "finalized");
  if (dayError) {
    return scores;
  }
  for (const row of dayRows ?? []) {
    if (row.is_void || !row.winner_user_id) {
      continue;
    }
    const winnerId = String(row.winner_user_id);
    scores.set(winnerId, (scores.get(winnerId) ?? 0) + 1);
  }
  return scores;
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
