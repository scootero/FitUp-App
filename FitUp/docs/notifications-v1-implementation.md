# Notifications v1 — Implementation notes

Sports-style notification stack: morning recap, throttled lead change, final-day comeback, match complete.

## What changed (code)

| Area | Files |
|------|--------|
| Day result pushes removed at finalize | `supabase/functions/finalize-match-day/index.ts` |
| Morning recap + final-day comeback cron | `supabase/functions/send-daily-recap/index.ts` |
| Throttle, copy, recap payloads | `supabase/functions/dispatch-notification/index.ts` |
| Match complete payload | `supabase/functions/complete-match/index.ts` |
| iOS recap inbox | `RecapMatchCard.swift`, `NotificationService.swift`, `HomeView.swift`, `ContentView.swift` |

## Manual SQL (you run in Supabase SQL Editor)

**Order:**

1. [`notifications_v1_00_readonly_checks.sql`](../supabase/manual_sql/notifications_v1_00_readonly_checks.sql) — before deploy
2. Deploy Edge Functions (see below)
3. [`notifications_v1_02_schedule_daily_recap.sql`](../supabase/manual_sql/notifications_v1_02_schedule_daily_recap.sql) — hourly cron
4. [`notifications_v1_04_notify_lead_changed_scoring_mode.sql`](../supabase/manual_sql/notifications_v1_04_notify_lead_changed_scoring_mode.sql) — only if readonly check shows `lead_fn_has_scoring_mode = false`
5. [`notifications_v1_05_pause_legacy_crons.sql`](../supabase/manual_sql/notifications_v1_05_pause_legacy_crons.sql) — **after** recap verified; unschedules **morning** only; **keeps evening_checkin**

**Debug fix (May 2026):** Step-by-step: [`notifications-v1-debug-YOUR-STEPS.md`](notifications-v1-debug-YOUR-STEPS.md). SQL: `notifications_v1_09` then deploy `finalize-match-day` + `send-daily-recap`, then `notifications_v1_08`. No `_shared/supabase.ts` change.

## Deploy commands (repo root — you run)

```bash
supabase functions deploy send-daily-recap
supabase functions deploy dispatch-notification
supabase functions deploy finalize-match-day
supabase functions deploy complete-match
```

## Behavior summary

- **10:00 local:** `yesterday_recap` (bundled cards, max 5 active matches)
- **16:00 local:** `final_day_comeback` if trailing on final competition day
- **Lead change:** max 3/local day, 3h global cooldown, 6h per-match, min swing (500 steps / 30 BS)
- **Evening check-in:** unchanged until you run slice 7 SQL
- **Day won/lost push:** removed; outcomes appear in morning recap

## Test tips

- Temporarily set `RECAP_LOCAL_HOUR` / `COMEBACK_LOCAL_HOUR` in `send-daily-recap` to current local hour for one test.
- Invoke `send-daily-recap` via Edge Function POST with service role.
- Confirm `notification_events` rows and tap → Home inbox recap cards → Match Details.
