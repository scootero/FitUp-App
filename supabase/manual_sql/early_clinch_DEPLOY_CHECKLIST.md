# early_clinch deploy checklist

This checklist is for manual execution after repo changes are reviewed.

## Scope lock (from plan)

- Required:
  - `finalize-match-day`
  - `complete-match`
  - iOS Home/Match Details safeguards
  - audit/checklist/smoke docs
- Recommended and included:
  - `day_cutoff_check` active-match filter
  - clinch-aware `reconcile_stuck_match_completions`
- Deferred:
  - `update-leaderboard` match bonus parity unless a true correctness issue appears
  - optional helper abstractions if they expand diff too much

## Hard constraints

- Do not execute SQL mutations from Cursor.
- Do not deploy from Cursor.
- Do not change cron schedules.
- Do not mutate Supabase production from Cursor.
- Run SQL manually in Supabase SQL Editor when instructed.

## Pre-deploy (read-only)

1. Open SQL Editor on target project (`uushejbizmlxzxonkuki`).
2. Run `supabase/manual_sql/early_clinch_00_readonly_audit.sql`.
3. Save output snapshots for:
   - clinched-active rows
   - completed-with-pending summary
   - cron jobs list
   - function/trigger sanity
   - watch query results

## Deploy order (manual)

Order matters to avoid reconcile hitting old complete behavior.

1. Deploy Edge function: `finalize-match-day`
2. Deploy Edge function: `complete-match`
3. Apply SQL: `early_clinch_01_reconcile_clinched_active_matches.sql`
4. Apply SQL: `early_clinch_02_day_cutoff_active_matches_only.sql`
5. Deploy iOS build with display safeguards

If `update-leaderboard` stays deferred, do not deploy it in this slice.

## Example manual commands (run outside Cursor)

```bash
supabase functions deploy finalize-match-day --project-ref uushejbizmlxzxonkuki
supabase functions deploy complete-match --project-ref uushejbizmlxzxonkuki
```

Apply SQL files manually in SQL Editor (copy/paste each file in order).

## Post-deploy verification (read-only)

Run `early_clinch_00_readonly_audit.sql` again and verify:

1. Clinched-active rows trend to zero (or reconcile handles quickly).
2. No completed rows in `completed_pending_but_not_clinched`.
3. Cron jobs are unchanged and active.
4. Function/trigger presence unchanged except intended function bodies.
5. Spot-check active matches:
   - clinched match should complete without waiting all scheduled days.
   - remaining days should not be finalized post-clinch.

## Watch item (explicit)

`public.home_daily_battle_margins` mixes active/completed matches and non-finalized totals.

Post deploy:
- sanity-check outputs for unexpected shifts
- if anomalies appear, investigate separately (not part of this slice)

## Rollback order (manual)

1. SQL rollback: `early_clinch_02_day_cutoff_active_matches_only_ROLLBACK.sql`
2. SQL rollback: `early_clinch_01_reconcile_clinched_active_matches_ROLLBACK.sql`
3. Re-deploy previous Edge function versions for:
   - `finalize-match-day`
   - `complete-match`
4. Re-run readonly audit and compare against pre-deploy baseline.

