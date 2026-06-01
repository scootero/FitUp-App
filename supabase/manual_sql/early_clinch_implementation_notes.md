# early_clinch implementation notes (slice 1)

## Purpose

Capture the locked scope, risk review, and assumptions that must remain true while implementing slices 2-5.

## Locked scope

Required:

- `finalize-match-day`
- `complete-match`
- iOS Home/Match Details safeguards
- audit/checklist/smoke docs

Recommended and included:

- `day_cutoff_check` active-match filter
- clinch-aware `reconcile_stuck_match_completions`

Deferred:

- `update-leaderboard` match bonus parity unless true correctness issue appears
- optional helper abstractions if they expand the diff too much

## New invariant

Completed matches may have non-finalized remaining scheduled days, as long as series clinch is already reached from finalized non-void days.

Interpretation:

- Completed = all-days-finalized OR clinched.
- Remaining days are intentionally left non-finalized for safety/minimal diff.

## Risk notes

1. Post-clinch processing risk:
   - If future days continue finalizing, they can alter series and points.
   - Mitigate with `finalize-match-day` active/clinch guards + `day_cutoff_check` active filter.

2. Completion race risk:
   - `finalize-match-day` invokes `complete-match` asynchronously.
   - Mitigate with reconcile path for clinched-active.

3. Assumption drift risk:
   - Existing SQL/reporting paths may implicitly expect completed=>all-finalized.
   - Mitigate by explicit watch checks in readonly audit.

## Live assumption audit findings to track

Functions using `state='completed'` and finalized day logic (compatible):

- `public.head_to_head_stats`
- `public.get_my_rival_stats`
- `public.health_battle_stats`

Watch item:

- `public.home_daily_battle_margins` mixes active/completed and non-finalized totals.

This is not a blocker for this slice but must be checked post-deploy.

## Slice summary requirement

After each slice, report:

- files changed
- why changed
- risk level
- validation performed

