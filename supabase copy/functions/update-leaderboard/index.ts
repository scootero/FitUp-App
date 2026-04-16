import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import { corsHeaders, jsonResponse, readJsonBody } from "../_shared/http.ts";
import { supabaseAdmin } from "../_shared/supabase.ts";

type UpdateLeaderboardRequest = {
  match_day_id: string;
  match_id?: string;
  winner_user_id?: string | null;
  is_void?: boolean;
};

type ParticipantRow = {
  user_id: string;
  finalized_value: number | string | null;
};

type LeaderboardRow = {
  id: string;
  user_id: string;
  points: number;
  wins: number;
  losses: number;
  streak: number;
  rank: number | null;
  updated_at: string | null;
};

serve(async (request) => {
  if (request.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (request.method !== "POST") {
    return jsonResponse(405, { error: "Method not allowed." });
  }

  try {
    const body = await readJsonBody<UpdateLeaderboardRequest>(request);
    const matchDayId = body.match_day_id?.trim();
    if (!matchDayId) {
      return jsonResponse(400, { error: "match_day_id is required." });
    }

    const { data: dayRow, error: dayError } = await supabaseAdmin
      .from("match_days")
      .select("id, match_id, finalized_at")
      .eq("id", matchDayId)
      .limit(1)
      .maybeSingle();
    if (dayError) {
      throw dayError;
    }
    if (!dayRow) {
      return jsonResponse(404, { error: "match_day not found." });
    }

    const matchId = (body.match_id?.trim() || dayRow.match_id) as string;
    const { data: matchRow, error: matchError } = await supabaseAdmin
      .from("matches")
      .select("id, metric_type")
      .eq("id", matchId)
      .limit(1)
      .maybeSingle();
    if (matchError) {
      throw matchError;
    }
    if (!matchRow) {
      return jsonResponse(404, { error: "match not found." });
    }

    const finalizedAt = dayRow.finalized_at ? new Date(dayRow.finalized_at) : new Date();
    const weekStart = weekStartIsoDate(finalizedAt);
    const nowIso = new Date().toISOString();

    const { data: participantRows, error: participantError } = await supabaseAdmin
      .from("match_day_participants")
      .select("user_id, finalized_value")
      .eq("match_day_id", matchDayId);
    if (participantError) {
      throw participantError;
    }
    const participants = (participantRows ?? []) as ParticipantRow[];
    if (participants.length === 0) {
      return jsonResponse(200, {
        status: "noop",
        reason: "no_participants",
      });
    }

    const seedRows = participants.map((participant) => ({
      user_id: participant.user_id,
      week_start: weekStart,
      updated_at: nowIso,
    }));
    const { error: seedError } = await supabaseAdmin
      .from("leaderboard_entries")
      .upsert(seedRows, { onConflict: "user_id,week_start", ignoreDuplicates: true });
    if (seedError) {
      throw seedError;
    }

    const isVoid = body.is_void === true;
    const winnerId = body.winner_user_id ?? null;

    if (!isVoid && winnerId) {
      await applyDayResult({
        matchId,
        weekStart,
        winnerId,
        participants,
        metricType: matchRow.metric_type as string,
        nowIso,
      });
      await applyMatchWinBonusIfCompleted(matchId, weekStart, nowIso);
    }

    await rerankWeek(weekStart);

    return jsonResponse(200, {
      status: "ok",
      week_start: weekStart,
      winner_user_id: winnerId,
      is_void: isVoid,
    });
  } catch (error) {
    return jsonResponse(500, {
      error: error instanceof Error ? error.message : "update-leaderboard failed.",
    });
  }
});

async function applyDayResult(args: {
  matchId: string;
  weekStart: string;
  winnerId: string;
  participants: ParticipantRow[];
  metricType: string;
  nowIso: string;
}): Promise<void> {
  const { weekStart, winnerId, participants, metricType, nowIso } = args;
  const winnerParticipant = participants.find((row) => row.user_id === winnerId);
  if (!winnerParticipant) {
    return;
  }

  const loserIds = participants
    .filter((row) => row.user_id !== winnerId)
    .map((row) => row.user_id);

  const winnerEntry = await fetchEntry(winnerId, weekStart);
  const priorStreak = winnerEntry?.streak ?? 0;
  const nextStreak = priorStreak + 1;
  const streakBonus = Math.min(nextStreak, 5) * 25;
  const stepsBonus = metricType === "steps" ? computeStepsBonus(winnerParticipant.finalized_value) : 0;
  const pointsDelta = 50 + streakBonus + stepsBonus;

  await upsertEntry(
    winnerId,
    weekStart,
    {
      points: (winnerEntry?.points ?? 0) + pointsDelta,
      wins: (winnerEntry?.wins ?? 0) + 1,
      losses: winnerEntry?.losses ?? 0,
      streak: nextStreak,
      updated_at: nowIso,
    },
  );

  for (const loserId of loserIds) {
    const loserEntry = await fetchEntry(loserId, weekStart);
    await upsertEntry(
      loserId,
      weekStart,
      {
        points: loserEntry?.points ?? 0,
        wins: loserEntry?.wins ?? 0,
        losses: (loserEntry?.losses ?? 0) + 1,
        streak: 0,
        updated_at: nowIso,
      },
    );
  }
}

async function applyMatchWinBonusIfCompleted(
  matchId: string,
  weekStart: string,
  nowIso: string,
): Promise<void> {
  const { data: dayRows, error: dayError } = await supabaseAdmin
    .from("match_days")
    .select("status, winner_user_id, is_void")
    .eq("match_id", matchId);
  if (dayError) {
    throw dayError;
  }

  const rows = dayRows ?? [];
  const allFinalized = rows.length > 0 && rows.every((row) => row.status === "finalized");
  if (!allFinalized) {
    return;
  }

  const winCounts = new Map<string, number>();
  for (const row of rows) {
    if (row.is_void || !row.winner_user_id) {
      continue;
    }
    const key = String(row.winner_user_id);
    winCounts.set(key, (winCounts.get(key) ?? 0) + 1);
  }

  let seriesWinnerId: string | null = null;
  let topWins = -1;
  for (const [userId, wins] of winCounts.entries()) {
    if (wins > topWins) {
      topWins = wins;
      seriesWinnerId = userId;
    }
  }
  if (!seriesWinnerId) {
    return;
  }

  const winnerEntry = await fetchEntry(seriesWinnerId, weekStart);
  await upsertEntry(
    seriesWinnerId,
    weekStart,
    {
      points: (winnerEntry?.points ?? 0) + 200,
      wins: winnerEntry?.wins ?? 0,
      losses: winnerEntry?.losses ?? 0,
      streak: winnerEntry?.streak ?? 0,
      updated_at: nowIso,
    },
  );
}

async function rerankWeek(weekStart: string): Promise<void> {
  const { data: rows, error } = await supabaseAdmin
    .from("leaderboard_entries")
    .select("id, user_id, points, wins, losses, streak, rank, updated_at")
    .eq("week_start", weekStart)
    .order("points", { ascending: false })
    .order("wins", { ascending: false })
    .order("streak", { ascending: false })
    .order("updated_at", { ascending: true });
  if (error) {
    throw error;
  }

  const entries = (rows ?? []) as LeaderboardRow[];
  for (let index = 0; index < entries.length; index += 1) {
    const rank = index + 1;
    const entry = entries[index];
    if (entry.rank === rank) {
      continue;
    }
    const { error: updateError } = await supabaseAdmin
      .from("leaderboard_entries")
      .update({ rank })
      .eq("id", entry.id);
    if (updateError) {
      throw updateError;
    }
  }
}

async function fetchEntry(userId: string, weekStart: string): Promise<LeaderboardRow | null> {
  const { data, error } = await supabaseAdmin
    .from("leaderboard_entries")
    .select("id, user_id, points, wins, losses, streak, rank, updated_at")
    .eq("user_id", userId)
    .eq("week_start", weekStart)
    .limit(1)
    .maybeSingle();
  if (error) {
    throw error;
  }
  return (data as LeaderboardRow | null) ?? null;
}

async function upsertEntry(
  userId: string,
  weekStart: string,
  values: {
    points: number;
    wins: number;
    losses: number;
    streak: number;
    updated_at: string;
  },
): Promise<void> {
  const { error } = await supabaseAdmin
    .from("leaderboard_entries")
    .upsert(
      {
        user_id: userId,
        week_start: weekStart,
        points: values.points,
        wins: values.wins,
        losses: values.losses,
        streak: values.streak,
        updated_at: values.updated_at,
      },
      { onConflict: "user_id,week_start" },
    );
  if (error) {
    throw error;
  }
}

function computeStepsBonus(rawFinalizedValue: number | string | null): number {
  const value = toNumber(rawFinalizedValue);
  if (value <= 10_000) {
    return 0;
  }
  const blocks = Math.floor((value - 10_000) / 1_000);
  return Math.min(blocks * 10, 100);
}

function toNumber(value: number | string | null | undefined): number {
  if (typeof value === "number") {
    return value;
  }
  if (typeof value === "string") {
    const parsed = Number(value);
    if (!Number.isNaN(parsed)) {
      return parsed;
    }
  }
  return 0;
}

function weekStartIsoDate(date: Date): string {
  const utc = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  const weekday = utc.getUTCDay(); // Sun=0, Mon=1, ...
  const offsetFromMonday = (weekday + 6) % 7;
  utc.setUTCDate(utc.getUTCDate() - offsetFromMonday);
  return utc.toISOString().slice(0, 10);
}
