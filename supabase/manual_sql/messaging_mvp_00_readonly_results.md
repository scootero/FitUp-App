# messaging_mvp_00_readonly_results

Paste SQL Editor output from `messaging_mvp_00_readonly_checks.sql` here after each run.

## Run metadata

- **Date:** 2026-05-21 (agent)
- **Project:** fitup-dev (MCP `execute_sql` unavailable — refresh token; run checks in SQL Editor)
- **Runner:** Cursor agent

### MCP note

`project-0-FitUp-App-supabase-fitup-dev` returned OAuth refresh failure. Run `messaging_mvp_00_readonly_checks.sql` manually in Dashboard.

### iOS fix applied (same session)

- **Root cause:** `fetchThreadId` used `.select("id")` but decoded `[MessageThreadRecord]` (missing keys → decode error → generic banner).
- **Fix:** `ThreadIdRow` decoder + improved error logging / PostgREST messages.

## Section notes

| Section | Pass? | Notes |
|---------|-------|-------|
| 0 Sanity | | |
| 1 Tables | | Expect 4 rows including message_threads, messages |
| 2 Trigger | | Both flags true |
| 3 RLS policies | | 4 policies on message_threads + messages |
| 4 Grants | | authenticated: SELECT, INSERT |
| 5 Volume | | |
| 6b Recent threads | | |
| 7 Orphans | | |
| 8 Sample messages | | |

## Section 6 (your pair)

Uncomment block in SQL file with your `profiles.id` and peer id from inbox.

## Action taken

- [ ] `messaging_mvp.sql` applied
- [ ] iOS error logging verified in Xcode
- [ ] Chat tap verified on device
