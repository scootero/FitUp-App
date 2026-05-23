# Notifications v1 — Debug fix runbook (May 2026)

**Root cause:** `finalize-match-day` is **entered** with Vault JWT (works), then calls `update-leaderboard` via `invokeInternalFunction` (Edge env key — 401). Day 2 stayed `pending`; recap built zero cards.

**Do NOT change `_shared/supabase.ts`.** Your 200s for `dispatch-notification` (pg_net + Vault JWT), `send-evening-checkins`, and `send-daily-recap` are consistent with the working pattern or zero inner dispatches (wrong local hour).

**Fix:** `finalize-match-day` only → `supabaseAdmin.rpc('invoke_edge_function_async', …)` (new SQL wrapper, same as lead-change). Plus `send-daily-recap` card rules.

---

## 1. Read-only checks (SQL Editor)

Run the readonly block in section **Appendix A** below (or copy to `supabase/manual_sql/notifications_v1_06_debug_recap_failure_readonly.sql`).

Expect after fix: `yesterday_recap` / `sent` rows; Day 2 `status = finalized`.

---

## 2. SQL wrapper (you run first)

Run `notifications_v1_09_invoke_edge_function_async.sql` — exposes Vault/pg_net path to Edge via RPC (see revised plan).

---

## 3. Code fix A — `finalize-match-day/index.ts` only

Replace `invokeInternalFunction("update-leaderboard" | "complete-match")` with `supabaseAdmin.rpc("invoke_edge_function_async", …)`. Try/catch leaderboard so finalize returns 200 after DB write.

**Deploy:** `finalize-match-day` only (minimum).

---

## 4. Code fix B — `send-daily-recap/index.ts`

**Yesterday:** After finalized lookup fails, load `match_days` for `calendar_date = yesterday` with `status IN ('pending','open')` and compute provisional winner from `metric_total` (same void/tie rules as finalize).

**Final day:** Replace `isFinalDay = dayNumber >= durationDays` with: any non-finalized day has `day_number >= duration_days`.

**Logging:** Return `recap_skipped_users` count or per-user skip reason in JSON (optional).

---

---

## 5. (merged into §3) try/catch on leaderboard RPC

---

## 6. Unstick Day 2 (manual SQL — after deploy)

Run **Appendix B** after `finalize-match-day` deploy + SQL **#09** (mutating).

---

## 7. Test recap without waiting until 10 AM

1. Temporarily change `RECAP_LOCAL_HOUR` in `send-daily-recap` to current local hour, deploy, POST invoke `send-daily-recap`, revert hour.
2. Or wait for next cron hour.
3. Confirm `notification_events` (`yesterday_recap`, `sent`) and iOS inbox cards.

---

## 8. Do NOT run yet

[`notifications_v1_05_pause_legacy_crons.sql`](../supabase/manual_sql/notifications_v1_05_pause_legacy_crons.sql) until recap is verified.

---

## Deploy checklist

| Function | Why |
|----------|-----|
| `finalize-match-day` | RPC downstream via Vault (no shared.ts change) |
| `send-daily-recap` | Recap rules + logging |
| `dispatch-notification` | Only if copy changed |

MCP `execute_sql` was unavailable (OAuth refresh token). Use SQL Editor for readonly scripts.

---

## Appendix A — readonly debug SQL

```sql
SELECT now() AS server_now;

SELECT event_type, status, count(*) AS n, max(created_at) AS latest
FROM notification_events
WHERE event_type = 'yesterday_recap'
  AND created_at >= now() - interval '7 days'
GROUP BY event_type, status
ORDER BY latest DESC;

SELECT event_type, status, count(*) AS n, max(created_at) AS latest
FROM notification_events
WHERE created_at >= date_trunc('day', now())
GROUP BY event_type, status
ORDER BY n DESC;

SELECT m.id AS match_id, m.state, m.duration_days,
  md.day_number, md.calendar_date, md.status, md.finalized_at, md.winner_user_id
FROM matches m
JOIN match_days md ON md.match_id = m.id
WHERE m.state = 'active'
ORDER BY m.id, md.day_number;

SELECT id, status_code, left(coalesce(content::text, error_msg::text, ''), 400) AS body_preview, created
FROM net._http_response
WHERE created >= now() - interval '24 hours'
  AND (content::text ILIKE '%finalize-match-day%'
    OR content::text ILIKE '%update-leaderboard%'
    OR status_code >= 400)
ORDER BY created DESC
LIMIT 25;

SELECT j.jobname, d.status, d.start_time, left(d.return_message::text, 300) AS msg
FROM cron.job_run_details d
JOIN cron.job j ON j.jobid = d.jobid
WHERE j.jobname IN ('send-daily-recap', 'day-cutoff-check')
ORDER BY d.start_time DESC
LIMIT 15;
```

---

## Appendix B — retry finalize stuck day (mutating)

```sql
-- Preview
SELECT md.id AS match_day_id, md.match_id, md.day_number, md.calendar_date, md.status
FROM match_days md
JOIN matches m ON m.id = md.match_id
WHERE m.state = 'active'
  AND md.status <> 'finalized'
  AND md.calendar_date < (current_date AT TIME ZONE 'America/New_York')::date
ORDER BY md.match_id, md.day_number;

-- Then invoke (set UUID from preview):
-- SELECT private.invoke_finalize_match_day('MATCH_DAY_UUID'::uuid);
```

---

## Appendix C — `notifications_v1_09_invoke_edge_function_async.sql`

```sql
CREATE OR REPLACE FUNCTION public.invoke_edge_function_async(
  p_function_name text,
  p_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, private, extensions
AS $$
BEGIN
  PERFORM private.invoke_edge_function(p_function_name, p_payload);
END;
$$;

REVOKE ALL ON FUNCTION public.invoke_edge_function_async(text, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.invoke_edge_function_async(text, jsonb) TO service_role;
```

---

## Appendix D — `send-daily-recap` changes

1. Rename `loadYesterdayFinalizedDay` usage to `loadYesterdayDay` that tries finalized first, then pending/open with provisional winner from `metric_total`.
2. Add `matchHasOpenFinalCompetitionDay(matchId, durationDays)` — true if any non-finalized row has `day_number >= duration_days`.
3. In cron response add `recap_skipped_no_cards` counter when hour matches but cards empty.
