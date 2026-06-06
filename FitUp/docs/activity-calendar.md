# Activity calendar (Battles + Steps)

Full-screen month grid opened from the **STATS** tab date/calendar chip, plus an inline card on the arcade stats page.

## Entry

- [`StatsMockShellView`](../FitUp/FitUp/Views/Health/StatsMockShellView.swift) — tap the date chip → [`ActivityCalendarSheet`](../FitUp/FitUp/Views/Health/Calendar/ActivityCalendarSheet.swift) (bottom dock)
- [`StatsArcadeSliceOneView`](../FitUp/FitUp/Views/Health/StatsArcadeSliceOneView.swift) — inline [`ActivityCalendarCard`](../FitUp/FitUp/Views/Health/Calendar/ActivityCalendarCard.swift) (sheet on day tap)

## Modes

### Battles (default)

Per profile calendar date (`yyyy-MM-dd`, profile timezone):

| State | UI | Rule |
|-------|-----|------|
| `none` / no match days | Muted ghost ring | No `match_days` rows, or calendar date is after today |
| `inProgress` | Cyan partial ring (Steps-style) | Live day not finalized; center label `+850` / `-320` from `home_daily_battle_margins` when available, else `LIVE` |
| All wins (1+ matches) | Green filled circle + `W` | Every finalized non-void match day is a win |
| All losses | Red filled circle + `L` | Every finalized non-void match day is a loss |
| All void/tie | Gray filled circle + `T` | Only void or no-winner finalized days |
| Mixed multi-battle | Filled circle + net label | `+N` (teal) if wins > losses; `-N` (orange) if losses > wins; `T` (gray) if tied |
| Multi-battle count | Small `x2`, `x3`, … below ring | Only when more than one match that day |

Future calendar dates always show a quiet ghost ring (no W/L/T until finalized).

Data: [`CalendarRepository`](../FitUp/FitUp/Repositories/CalendarRepository.swift) → `match_participants` + `match_days` filtered by `calendar_date` range. Win/loss counts are aggregated client-side in [`CalendarDayBattleSummary`](../FitUp/FitUp/Models/CalendarDayBattleState.swift).

### Steps

Per calendar date from **HealthKit** (not `user_daily_step_totals`):

- Ghost ring when 0 steps
- Cyan trim ring = `steps / ReadinessGoals.stepsGoal` (capped at 1)
- Green ring + label when goal met
- Center label: abbreviated count (`8.2k`, `12k`, or raw if &lt; 10k)

## Navigation

- Month title + previous / next chevrons + **Today**
- 6-week Monday-first grid (padding days outside month show muted day numbers only, no ring)
- In-memory cache per month for battles and steps

## Day tap detail

Tap any in-month day to open a **shimmer dock** (full-screen sheet) or **sheet** (inline stats card). Tap again, chevron, or outside to dismiss.

### Battles detail

- Centered date header + summary line applies to all matches shown
- **Single match:** stacked you + rival avatars, vertical step bars, all-time W–L, rivalry emblem strip
- **Multiple matches:** all match cards stacked with dividers; scroll when content exceeds ~45% of screen height; emblem strip per match card
- Opponent ordering: highest rival steps first (repository sort)

### Steps detail

- Daily total vs goal
- Home-style cumulative sparkline from HealthKit (`fetchIntradayCumulativeSeries`); falls back to 0 → total line when few samples

## Analytics

- Screen key: `activity_calendar` via `trackProductScreen`
- Additional `screen_viewed` properties on mode/month change: `mode`, `month`

## Battle Steps (Stats top card)

- **Scope:** steps battles only; **literal HealthKit** full-day steps (not battle score, balanced score, or opponent totals).
- **Dedupe:** one count per profile-local calendar day even with multiple active steps matches.
- **Storage:** `user_battle_step_totals` — absolute upsert per day (`steps` replaced, never incremented on sync).
- **All-time:** `SUM` of finalized rows; **today** adds live HK while the day is not finalized.
- **Sync:** provisional HK rows from `MetricSyncCoordinator`; finalized rows from `reconcile_user_battle_step_total` on `finalize-match-day`.

## Related

- Deferred long-range history: [`health-history-charts-deferred.md`](health-history-charts-deferred.md)
