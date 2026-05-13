# Edge Function 401 follow-up — read-only SQL results

**Source script:** [`edge_function_401_followup_readonly_checks.sql`](edge_function_401_followup_readonly_checks.sql)

**Captured:** `2026-05-13 01:56:55 UTC` (from query 0 `server_now`; project `postgres` as role `postgres`)

**How captured:** Supabase MCP `execute_sql` against FitUp dev project (`uushejbizmlxzxonkuki`).  
**Note:** Some parallel MCP calls briefly returned `Unauthorized` and were re-run successfully.

---

## 0) Sanity

```json
[
  {
    "db": "postgres",
    "role": "postgres",
    "server_now": "2026-05-13 01:56:55.069202+00"
  }
]
```

---

## 1) Cron jobs (Edge-related command shape)

```json
[
  {
    "jobid": 1,
    "jobname": "day-cutoff-check",
    "schedule": "5 * * * *",
    "active": true,
    "command_preview": " SELECT public.day_cutoff_check(); "
  },
  {
    "jobid": 11,
    "jobname": "matchmaking-retry-stale",
    "schedule": "*/5 * * * *",
    "active": true,
    "command_preview": " SELECT public.matchmaking_retry_stale_searches(5, 30); "
  },
  {
    "jobid": 9,
    "jobname": "reconcile-stuck-match-completions",
    "schedule": "*/10 * * * *",
    "active": true,
    "command_preview": " SELECT public.reconcile_stuck_match_completions(); "
  },
  {
    "jobid": 10,
    "jobname": "send-evening-checkins",
    "schedule": "0 * * * *",
    "active": true,
    "command_preview": "SELECT private.invoke_edge_function('send-evening-checkins', '{}'::jsonb);"
  },
  {
    "jobid": 3,
    "jobname": "send-morning-checkins",
    "schedule": "0 13 * * *",
    "active": true,
    "command_preview": " SELECT private.invoke_edge_function('send-morning-checkins', '{}'::jsonb); "
  },
  {
    "jobid": 2,
    "jobname": "send-pending-reminders",
    "schedule": "15 16 * * *",
    "active": true,
    "command_preview": " SELECT private.invoke_edge_function('send-pending-reminders', '{}'::jsonb); "
  }
]
```

---

## 2) Recent cron failures (non-`succeeded`)

```json
[]
```

No rows returned — no recorded non-success statuses in the last 50 failing-detail rows (or none match filter).

---

## 3) `net._http_response`

### 3a) Table exists

```json
[
  { "net__http_response_exists": true }
]
```

### 3b) Status histogram

```json
[
  { "status_code": 200, "n": 11 },
  { "status_code": null, "n": 2 }
]
```

### 3c) Recent rows with `status_code >= 400` (limit 40)

```json
[]
```

### 3d) Recent rows with `status_code IN (401, 403, 500)` (limit 25)

```json
[]
```

At capture time, retained `net._http_response` rows showed no 4xx/5xx in these slices (consistent with short retention or successful recent pg_net responses).

---

## 4) `private` Edge invoke helpers (existence)

```json
[
  {
    "oid": 23743,
    "schema": "private",
    "name": "invoke_dispatch_notification",
    "args": "p_user_ids uuid[], p_event_type text, p_payload jsonb"
  },
  {
    "oid": 23742,
    "schema": "private",
    "name": "invoke_edge_function",
    "args": "p_function_name text, p_payload jsonb"
  },
  {
    "oid": 22574,
    "schema": "private",
    "name": "invoke_finalize_match_day",
    "args": "p_match_day_id uuid"
  }
]
```

---

## Re-run

Re-execute the SQL script in the Supabase SQL Editor (or re-run MCP) after incidents or deploys to refresh this snapshot; consider saving a new dated `*_results_*.md` copy for comparison.
