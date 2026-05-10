# Stats Snapshot Contract (Slice 4B)

This document defines the proposed backend payload contract for the Stats page snapshot.
No SQL/RPC/schema changes are implemented in this slice.

## Proposed RPC

- `get_profile_stats_snapshot(p_range_key text)`
- Range keys expected by app:
  - `7D`
  - `30D`
  - `3M`
  - `1Y`
  - `ALL`

## Response shape

```json
{
  "range_key": "30D",
  "effective_range_key": "30D",
  "date_chip_text": "May 7 - Jun 5",
  "saved_at": "2026-05-08T13:00:00Z",
  "scope_flags": {
    "win_rate_scope": "range",
    "streak_scope": "range",
    "rivals_scope": "range"
  },
  "summary": {
    "net_margin": 12843,
    "previous_period_percent": 18,
    "wins": 34,
    "losses": 16,
    "win_rate_percent": 68,
    "streak_days": 4
  },
  "chart": {
    "unit": "steps",
    "points": [
      { "date": "2026-05-07", "margin": -1200 }
    ]
  },
  "rivals": [
    {
      "opponent_id": "uuid",
      "display_name": "Jake Daniels",
      "initials": "JD",
      "days_competed": 28,
      "wins": 16,
      "losses": 12,
      "win_rate_percent": 57,
      "avg_margin": 842,
      "is_active_now": true,
      "last_played_at": "2026-06-05T01:00:00Z",
      "can_rematch": true
    }
  ],
  "rival_insight": {
    "most_wins_against_opponent_id": "uuid",
    "closest_record_opponent_id": "uuid"
  },
  "personal_bests": {
    "battle_win_streak_days": 4,
    "best_step_day_value": 15892,
    "best_step_day_date": "2026-05-28",
    "avg_steps": 8432,
    "biggest_comeback_day_deficit_recovered": 1800,
    "biggest_comeback_series_net_swing": 4221
  },
  "insights": [
    {
      "kind": "month_over_month_activity_percent",
      "value_text": "You are 22% more active this month vs last month."
    }
  ]
}
```

## Confirmed metric definitions

- `streak_days`: battle win streak from match outcomes.
- `biggest_comeback_day_deficit_recovered`: largest same-match day-level deficit recovered later in that match.
- `biggest_comeback_series_net_swing`: largest match-level net swing from behind to win.

## Metric definitions still requiring confirmation

- `days_competed`: count of finalized match days vs opponent or unique calendar days.
- `avg_margin`: per-day average or per-series average.
- `outperformed_percent`: percentile against head-to-head opponents or leaderboard cohort.

## App behavior before backend support lands

- `7D` and `30D`: use existing real margin path.
- `3M`, `1Y`, `ALL`: app can show fallback scope note until backend range snapshot support ships.
- Scope labels should remain explicit for any lifetime-derived fields.
