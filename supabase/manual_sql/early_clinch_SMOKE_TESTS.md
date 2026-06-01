# early_clinch smoke test plan

This plan is for manual execution after deployment steps in the checklist.

## Test data guidance

- Use test users only.
- Prefer isolated test matches where possible.
- Capture IDs/timestamps for each case.

## Backend smoke tests

### B1: 1-day match finalizes normally

- Setup: 1-day active match, both participants confirm.
- Expected:
  - day 1 finalizes
  - match completes
  - behavior unchanged from baseline

### B2: 3-day match 2-0 clinches early

- Setup: same player wins finalized day 1 and day 2.
- Expected:
  - match completes after day 2 finalization
  - day 3 remains non-finalized
  - no additional day wins after completion

### B3: 3-day match 1-1 remains active

- Setup: split wins on day 1/day 2.
- Expected:
  - still active after day 2
  - no premature completion
  - day 3 remains playable/finalizable

### B4: 5-day match 3-0 clinches early

- Setup: same player wins finalized day 1/day 2/day 3.
- Expected:
  - match completes after day 3 finalization
  - day 4/day 5 remain non-finalized

### B5: Pending/unconfirmed days do not clinch

- Setup: create scenario where day(s) not finalized yet.
- Expected:
  - clinch is not computed from pending/unconfirmed data
  - no completion until enough finalized non-void wins exist

### B6: Completed match does not continue processing future days

- Setup: clinched-completed match with remaining scheduled days.
- Expected:
  - no later finalization of remaining days
  - no additional winner assignments on future days

### B7: Reconcile heals stuck clinched-active

- Setup: induce or identify a match where clinch exists but state remains active.
- Expected:
  - reconcile cron path completes the match
  - state transitions to completed without manual mutation

## iOS smoke tests

### I1: Clinched active match not shown as hero

- Expected:
  - clinched-active match excluded from hero selection
  - may appear as pending/finalizing row if designed that way

### I2: Pending-finalization match not shown as hero

- Expected:
  - existing pending-finalization exclusion still works

### I3: Normal active match shown as hero

- Expected:
  - non-clinched, non-pending-finalization active match can be hero

### I4: Match Details reflects effectively-over state

- Expected:
  - no active day-progress/intraday UI when clinched-active
  - series score based on finalized days only

### I5: Live Activity behavior

- Expected:
  - effectively-over matches are not newly selected for Live Activity
  - existing activity ends/updates per revised selection logic

## Readonly verification queries after smoke

- Re-run `early_clinch_00_readonly_audit.sql`
- Confirm:
  - clinched-active rows are zero or transient
  - no completed rows that are pending but not clinched
  - watch-item checks remain acceptable

## Report template

For each test:

- test id
- setup
- observed result
- pass/fail
- evidence (match_id, timestamps, screenshots/log snippets)

