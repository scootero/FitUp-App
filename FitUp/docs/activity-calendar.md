# Activity calendar (Battles + Steps)

Full-screen month grid opened from the **STATS** tab date/calendar chip.

## Entry

- [`StatsMockShellView`](../FitUp/FitUp/Views/Health/StatsMockShellView.swift) — tap the date chip → [`ActivityCalendarSheet`](../FitUp/FitUp/Views/Health/Calendar/ActivityCalendarSheet.swift)

## Modes

### Battles (default)

Per profile calendar date (`yyyy-MM-dd`, profile timezone):

| State | UI | Rule |
|-------|-----|------|
| `none` | Empty (no chip) | No match days, or calendar date is after today |
| `inProgress` | Margin tone chip | Live day not finalized; tone from `home_daily_battle_margins` when available |
| `wonAny` / `lostAll` / `voidOnly` | Margin tone chip | Green → cyan → purple → orange → red by signed step margin (same scale as BATTLE MARGIN chart); fallback tiers when margin row missing |

Future scheduled match days (e.g. day 2–3 of a 3-day battle before that date) show **no** chip — only today and past dates.

**Multi-match:** green if the user beat at least one opponent that day; red only if they had competitive finalized days and won none.

Data: [`CalendarRepository`](../FitUp/FitUp/Repositories/CalendarRepository.swift) → `match_participants` + `match_days` filtered by `calendar_date` range.

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

## Day tap detail (bottom dock)

Tap any in-month day to open a **shimmer dock** at the bottom (tap again or chevron to dismiss).

### Battles dock

- Stacked you + rival avatars
- Vertical step bars (taller = more steps) with counts
- All-time W–L vs that rival (`head_to_head_stats`)
- **Rivalry run**: battle emblems slam in left-to-right (green = series win, red = series loss)
- Multiple matches that day: dot pager switches rival

### Steps dock

- Daily total vs goal
- Home-style cumulative sparkline from HealthKit (`fetchIntradayCumulativeSeries`); falls back to 0 → total line when few samples

## Analytics

- Screen key: `activity_calendar` via `trackProductScreen`
- Additional `screen_viewed` properties on mode/month change: `mode`, `month`

## Related

- Deferred long-range history: [`health-history-charts-deferred.md`](health-history-charts-deferred.md)
