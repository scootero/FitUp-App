# Slice 4 Rollup Follow-up (Rivals + Insights)

This document outlines the next backend/app layer for replacing remaining mocked
rivals and insights metrics with scalable real data.

## Goals

- Eliminate per-opponent fan-out queries at page open.
- Keep Stats page to one lightweight fetch per selected range.
- Support deterministic rival ranking and insight sentence generation.

## Proposed backend tables

- `profile_rival_stats`
  - `profile_id`
  - `opponent_id`
  - `range_key`
  - `days_competed`
  - `wins`
  - `losses`
  - `ties`
  - `win_rate_percent`
  - `avg_margin`
  - `last_played_at`
  - `is_active_now`
  - `can_rematch`
  - `updated_at`

- `profile_stats_snapshots`
  - `profile_id`
  - `range_key`
  - `summary_json`
  - `chart_json`
  - `rivals_json`
  - `insights_json`
  - `personal_bests_json`
  - `scope_flags_json`
  - `saved_at`
  - `updated_at`

## Recompute triggers

- Match day finalized.
- Match completed.
- Health sync confirms prior day.
- Manual pull-to-refresh (throttled).

## Insight generation logic

- `most wins against`:
  - opponent with max `wins` in `profile_rival_stats` for selected range.
- `closest record`:
  - opponent with minimum absolute `(wins - losses)`, tie-break by highest `days_competed`.

## Biggest comeback semantics (confirmed)

- `biggest_comeback_day_deficit_recovered`:
  largest day-level deficit recovered later in the same match.
- `biggest_comeback_series_net_swing`:
  largest match-level net swing from being behind to winning.

## App integration target

- Extend `get_profile_stats_snapshot` to return precomputed `rivals`, `rival_insight`,
  `insights`, and `personal_bests` from rollup/snapshot tables.
- Keep `StatsPageSnapshotCacheStore` as cache-first read path with existing TTL policy.
