# Notifications recap fix — your steps

Code changes are in the repo. **You** run SQL and deploy Edge functions (agent did not touch Supabase).

---

## Order

### 1. SQL Editor (readonly, optional)

`supabase/manual_sql/notifications_v1_06_debug_recap_failure_readonly.sql`

### 2. SQL Editor (required, mutating)

`supabase/manual_sql/notifications_v1_09_invoke_edge_function_async.sql`

Creates `public.invoke_edge_function_async` → same Vault JWT path as lead-change cron.

### 3. Deploy Edge functions (terminal, repo root)

```bash
supabase functions deploy finalize-match-day
supabase functions deploy send-daily-recap
```

`dispatch-notification` and `complete-match` are unchanged unless you pulled other edits.

### 4. SQL Editor (mutating, unstick pending days)

`supabase/manual_sql/notifications_v1_08_retry_finalize_stuck_day.sql`

- Run the **preview** `SELECT`.
- For each `match_day_id` still `pending`, uncomment and run:
  `SELECT private.invoke_finalize_match_day('…'::uuid);`

### 5. Verify

Re-run **#06** readonly SQL. Expect:

- `match_days` for yesterday → `finalized`
- `notification_events` with `yesterday_recap` / `sent` (after 10 AM local or a manual test invoke)

**Test recap without waiting:** temporarily set `RECAP_LOCAL_HOUR` in `send-daily-recap/index.ts` to your current local hour, deploy `send-daily-recap`, POST invoke `send-daily-recap`, then revert hour and redeploy.

### 6. Do NOT run yet

`notifications_v1_05_pause_legacy_crons.sql` until recap is verified on device.

---

## What changed in code

| File | Change |
|------|--------|
| `finalize-match-day/index.ts` | Downstream calls use `rpc('invoke_edge_function_async')` (Vault JWT). Leaderboard errors logged, finalize still returns 200. |
| `send-daily-recap/index.ts` | Provisional yesterday from `pending` days; fixed `isFinalDay`; `recap_skipped_no_cards` in response. |
| `_shared/supabase.ts` | **Not changed** |

---

## Deploy summary

| Function | Deploy? |
|----------|---------|
| `finalize-match-day` | **Yes** |
| `send-daily-recap` | **Yes** |
| `dispatch-notification` | No (unless you have other local changes) |
| `complete-match` | No |
| `update-leaderboard` | No |
