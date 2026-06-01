# early_clinch readonly audit results (pre-deploy)

- Date (UTC): 2026-06-01
- Project ref: `uushejbizmlxzxonkuki`
- Runner: Cursor agent (readonly MCP `execute_sql` only)
- Source audit file: `supabase/manual_sql/early_clinch_00_readonly_audit.sql`

## 0) Sanity

```json
[{"db":"postgres","role":"postgres","server_now":"2026-06-01 07:04:49.81056+00"}]
```

## 1) Current active matches/day status

```json
[]
```

## 2) Clinched-active detector

```json
[]
```

## 3) Historical clinch-delay signal (3-day 2-0)

```json
[{"total_2_0_sweeps":10,"delayed_over_1h":10,"min_delay":"21:25:03.978","max_delay":"1 day 03:06:20.268"}]
```

## 4) Completed invariant verifier

```json
[{"completed_matches":27,"completed_all_days_finalized":27,"completed_clinched_with_pending":0,"completed_pending_but_not_clinched":0}]
```

## 5) Function assumptions scan (`state='completed'`)

```json
[
  {"schema":"public","name":"get_my_rival_stats","args":"p_limit integer"},
  {"schema":"public","name":"head_to_head_stats","args":"p_opponent_id uuid"},
  {"schema":"public","name":"health_battle_stats","args":""}
]
```

### 5b) Completed + match_days without finalized filter

```json
[]
```

### 5c) Watch item definition

`public.home_daily_battle_margins` definition confirms:
- uses `m.state in ('active','completed')`
- does not require `md.status='finalized'`
- uses `coalesce(finalized_value, metric_total)` day totals

(Full function body fetched during audit run.)

## 6) Cron / trigger / function sanity

### 6a) cron jobs

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

### 6b) triggers

```json
[
  {"event_object_table":"match_day_participants","trigger_name":"tr_finalize_when_all_confirmed","event_manipulation":"INSERT","action_timing":"AFTER"},
  {"event_object_table":"match_day_participants","trigger_name":"tr_finalize_when_all_confirmed","event_manipulation":"UPDATE","action_timing":"AFTER"},
  {"event_object_table":"match_day_participants","trigger_name":"tr_notify_lead_changed","event_manipulation":"UPDATE","action_timing":"AFTER"},
  {"event_object_table":"match_day_participants","trigger_name":"tr_push_live_activity_updates","event_manipulation":"UPDATE","action_timing":"AFTER"},
  {"event_object_table":"match_day_participants","trigger_name":"tr_push_live_activity_updates","event_manipulation":"INSERT","action_timing":"AFTER"},
  {"event_object_table":"match_participants","trigger_name":"tr_on_all_accepted_after_participant","event_manipulation":"INSERT","action_timing":"AFTER"},
  {"event_object_table":"match_participants","trigger_name":"tr_on_all_accepted_after_participant","event_manipulation":"UPDATE","action_timing":"AFTER"},
  {"event_object_table":"matches","trigger_name":"tr_notify_public_matchmaking_declined","event_manipulation":"UPDATE","action_timing":"AFTER"}
]
```

### 6c) key function presence

```json
[
  {"oid":23742,"schema":"private","name":"invoke_edge_function","args":"p_function_name text, p_payload jsonb"},
  {"oid":22574,"schema":"private","name":"invoke_finalize_match_day","args":"p_match_day_id uuid"},
  {"oid":22577,"schema":"public","name":"day_cutoff_check","args":""},
  {"oid":22575,"schema":"public","name":"finalize_when_all_confirmed","args":""},
  {"oid":32247,"schema":"public","name":"reconcile_stuck_match_completions","args":""}
]
```

## 7) Recent cron failures

```json
[]
```

## Summary

- No active matches at check time.
- No current clinched-active backlog.
- Historical 3-day 2-0 delay still confirms pre-fix behavior.
- Completed matches currently all-days-finalized (pre-deploy baseline).
- Cron, triggers, and key functions are present and healthy.
- Watch item remains `public.home_daily_battle_margins`.

