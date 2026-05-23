# Health history and charts — deferred backlog

MVP work for metric sync throttling lives in:

- iOS: `MetricSyncUploadPolicy.swift`, `MetricSyncCoordinator.swift`, `MetricSnapshotRepository.swift`
- Supabase (human SQL Editor only): `supabase/manual_sql/metric_snapshots_record_rpc.sql`

## In scope now (TestFlight)

- Throttle HK **observer** syncs (5 min debounce, ≥100 step delta, skip unchanged steps/calories)
- `record_metric_snapshot` RPC: **insert** when value changes, **update `synced_at`** when same value (no deletes)
- Rolling 7-day `user_daily_step_totals` on foreground/manual; observer runs that refresh **once per local day**
- Keep all historical `metric_snapshots` rows (no retention TTL on snapshots)

## Deferred (post-MVP)

| Feature | Why defer | Rough approach later |
|---------|-----------|----------------------|
| Match details: dual line chart for every past match day | Needs per-day tick history for both users; heavy UI + data | Store or re-query HK per calendar day; reuse hero sparkline components |
| Raw HealthKit sample timelines (all points in a day) | Large storage + CPU; not needed for scores | Optional `user_intraday_step_ticks` backfill or HK export |
| Collapse multi-match snapshot rows to one per user | Schema/audit change | Canonical user-day snapshot + match references |
| Scheduled snapshot cleanup / dedupe cron | Conflicts with “keep everything” unless soft-archive | Not planned while audit trail is append-only |

## Data paths today

| Use case | Table / source |
|----------|----------------|
| Live match total | `match_day_participants.metric_total` |
| Audit / anomaly | `metric_snapshots` via `record_metric_snapshot` |
| Today intraday chart | `user_intraday_step_ticks` (throttled, ≤30 points/day) |
| Leaderboard / 7-day averages | `user_daily_step_totals`, `user_health_baselines` |

## Human run order (Supabase SQL Editor)

**Agent must not execute these files.**

1. (Optional) `supabase/manual_sql/metric_snapshots_record_rpc_00_readonly_checks.sql`
2. `supabase/manual_sql/metric_snapshots_record_rpc.sql`
3. Ship iOS build that calls `record_metric_snapshot`
4. (Optional) Post-checks in readonly file again
5. TestFlight smoke (see plan)

## Rollback

1. Human runs `supabase/manual_sql/metric_snapshots_record_rpc_rollback.sql`
2. Revert iOS to direct `.insert()` on `metric_snapshots` and remove observer policy gate
3. Existing DB rows are unchanged

## Storage note

One row per **value change** per **match** per **source_date** (not per HK wake). Four active matches still means up to four rows per step plateau.
