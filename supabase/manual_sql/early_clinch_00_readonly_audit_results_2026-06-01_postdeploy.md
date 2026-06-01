# early_clinch readonly audit results (post-deploy)

- Date (UTC): 2026-06-01
- Project ref: `uushejbizmlxzxonkuki`
- Runner: Cursor agent (readonly MCP `execute_sql` only)
- Source audit file: `supabase/manual_sql/early_clinch_00_readonly_audit.sql`

## 0) Sanity

```json
[{"db":"postgres","role":"postgres","server_now":"2026-06-01 07:11:22.671946+00"}]
```

## 1) Clinched-active detector

```json
[]
```

## 2) Completed invariant verifier

```json
[{"completed_matches":27,"completed_all_days_finalized":27,"completed_clinched_with_pending":0,"completed_pending_but_not_clinched":0}]
```

## 3) Cron jobs

```json
[
  {"jobid":1,"jobname":"day-cutoff-check","schedule":"5 * * * *","command":" SELECT public.day_cutoff_check(); ","active":true},
  {"jobid":11,"jobname":"matchmaking-retry-stale","schedule":"*/5 * * * *","command":" SELECT public.matchmaking_retry_stale_searches(5, 30); ","active":true},
  {"jobid":9,"jobname":"reconcile-stuck-match-completions","schedule":"*/10 * * * *","command":" SELECT public.reconcile_stuck_match_completions(); ","active":true},
  {"jobid":13,"jobname":"send-daily-recap","schedule":"0 * * * *","command":"SELECT private.invoke_edge_function('send-daily-recap', '{}'::jsonb);","active":true},
  {"jobid":10,"jobname":"send-evening-checkins","schedule":"0 * * * *","command":"SELECT private.invoke_edge_function('send-evening-checkins', '{}'::jsonb);","active":true},
  {"jobid":3,"jobname":"send-morning-checkins","schedule":"0 13 * * *","command":" SELECT private.invoke_edge_function('send-morning-checkins', '{}'::jsonb); ","active":true},
  {"jobid":2,"jobname":"send-pending-reminders","schedule":"15 16 * * *","command":" SELECT private.invoke_edge_function('send-pending-reminders', '{}'::jsonb); ","active":true}
]
```

## 4) Recent cron failures

```json
[]
```

## 5) Function body verification (new SQL paths)

### 5a) reconcile_stuck_match_completions

Observed body includes:

- Existing all-days-finalized path
- Added clinched-active path:
  - finalized, non-void day wins grouped by `winner_user_id`
  - threshold `wins >= ((m.duration_days + 1) / 2)`
- Continues invoking `private.invoke_edge_function('complete-match', ...)`

### 5b) day_cutoff_check

Observed body includes active-match guard in both phases:

- Phase 1:
  - `JOIN matches m ON m.id = md.match_id`
  - `AND m.state = 'active'`
- Phase 2:
  - `JOIN matches m ON m.id = md.match_id`
  - `AND m.state = 'active'`

## 6) Key function presence sanity

```json
[
  {"oid":23742,"schema":"private","name":"invoke_edge_function","args":"p_function_name text, p_payload jsonb"},
  {"oid":22574,"schema":"private","name":"invoke_finalize_match_day","args":"p_match_day_id uuid"},
  {"oid":22577,"schema":"public","name":"day_cutoff_check","args":""},
  {"oid":22575,"schema":"public","name":"finalize_when_all_confirmed","args":""},
  {"oid":32247,"schema":"public","name":"reconcile_stuck_match_completions","args":""}
]
```

## 7) Completed-assumption function scan

```json
[
  {"schema":"public","name":"get_my_rival_stats","args":"p_limit integer"},
  {"schema":"public","name":"head_to_head_stats","args":"p_opponent_id uuid"},
  {"schema":"public","name":"health_battle_stats","args":""}
]
```

## 8) Watch item check

`public.home_daily_battle_margins` still:

- mixes `m.state in ('active','completed')`
- uses non-finalized-capable totals via `coalesce(finalized_value, metric_total)`

No change observed in definition during this check.

## Summary

- Post-deploy readonly checks are healthy.
- Cron jobs active and unchanged.
- No recent cron failures.
- New SQL function bodies for reconcile/day_cutoff are present as expected.
- No clinched-active backlog visible at check time.
- Completed-with-pending remains zero at this moment (expected if no new clinched series yet).

