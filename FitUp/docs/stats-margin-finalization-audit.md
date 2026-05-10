# Stats margin charts — finalized totals vs live data

This note documents how battle-margin chart inputs behave relative to **finalized** HealthKit-backed totals. No sync or SQL logic was changed for this audit.

## What the margin RPC reads

`home_daily_battle_margins` (see migration `20260428120000_home_daily_battle_margins_rpc.sql`) aggregates each viewer/opponent pair from `match_day_participants` using:

- `coalesce(finalized_value, metric_total)` for both sides.

So whenever **`finalized_value` is set**, that canonical finalized total wins for charts and opponent comparisons. If it is null, the row falls back to **`metric_total`** (live / in-progress snapshot).

## Prior calendar days

**Not immutable.** A past day’s displayed margin can change when:

1. **Late HealthKit data** arrives and the sync pipeline updates `metric_total` or sets **`finalized_value`** for that match day.
2. **`confirmHistoricalDayTotal`** runs for pending historical targets (see `MetricSyncCoordinator` → `MatchDayRepository.confirmHistoricalDayTotal`) and writes updated totals.

Until the server marks a day finalized, stored totals remain eligible to move as sync catches up.

## Today / in-progress day

The current calendar day typically behaves as **provisional**: `metric_total` reflects ongoing sync until finalization replaces it with **`finalized_value`** after your match-day rules (cutoff timing lives in match/day modeling and profile timezone handling).

## Practical takeaway for chart UX

- **Charts mix finalized history where available with live fallback** for rows not yet finalized.
- Users should treat **today** as live; **prior days** are stable once finalized but may still shift during backfill before that point.
