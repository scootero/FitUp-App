# FitUp — Supabase (repo layout)

This folder tracks **Edge Functions**, **manual SQL** (Supabase SQL Editor workflow), and **historical migrations**. Production database state may not match `migrations/` line-for-line because changes are often applied manually.

## Active source of truth

- **Edge Functions**: [`functions/`](functions/) — canonical TypeScript source. Deploy from your machine (e.g. `supabase functions deploy <name>`) using the target project’s credentials. Do not deploy from duplicate/backup trees (see below).

## Manual SQL workflow

- **[`manual_sql/`](manual_sql/)** — primary place for **runnable** scripts, **verification** queries, **slice notes** (sometimes comment-only), and **one-off** maintenance.  
  **Convention:** Before running anything, open the file and read the header comments (intent, idempotency, and warnings).  
  **Physical cleanup** (subfolders such as `active_to_run/`, `verification/`, etc.) is **planned for later** after a full inventory; paths are not reorganized yet.

## Migrations (reference / history)

- **[`migrations/`](migrations/)** — timestamped history and team reference. **Not guaranteed to be a complete or accurate replay of production** while SQL Editor apply is the day-to-day workflow.  
  Use for code review, diffing intent, and onboarding; verify against the live project before assuming prod matches a file.

## Root-level Supabase files (special attention)

These affect **local CLI**, **cron**, or **database roles**:

- **[`config.toml`](config.toml)** — Supabase project config for CLI/local workflows. Review when linking projects or changing local settings; not a substitute for documenting what was applied in SQL Editor on remote.
- **[`cron.sql`](cron.sql)** — `pg_cron` scheduling (`cron.schedule`). **Production-impacting:** duplicate job names or wrong schedules cause duplicate invocations or missed jobs. Do not run blindly; reconcile with what is already registered in the target database.
- **[`roles.sql`](roles.sql)** — role/session settings (e.g. `ALTER ROLE`). **High impact** on client behavior and security. Treat as **review-only** unless you intend to change cluster role defaults.

## Non-active / duplicate trees

Do **not** use these for deploys or as source of truth:

- **[`supabase copy/`](../supabase%20copy/)** (path outside this folder; space in name) — stale duplicate of older functions/SQL fragments. Only compare to [`supabase/functions/`](functions/) when auditing history; do not deploy from here.
- **[`supabase_old_backup/`](../supabase_old_backup/)** — backup snapshot; same rule.

If both exist, **only** [`supabase/functions/`](functions/) and curated content under [`manual_sql/`](manual_sql/) should drive current work.

## Inventory and cleanup

- **Now:** stabilize diagnostics (e.g. Edge logs, readonly checks) and keep a written map of what was applied on remote.
- **Later:** optional subfolders under `manual_sql/`, archiving obvious duplicates, and tightening naming—**after** inventory, not during active incident/debug passes.

## Future: migrations as source of truth (deferred)

Long-term, the team should **reconcile live remote schema** (and/or periodic schema dumps) with this repo and move toward **Supabase migrations as the single source of truth** for DDL/RPC/RLS changes. That reduces drift and makes staging/prod reproducible.

**Explicitly out of scope during current Edge Function diagnostic work:** converting manual SQL to migrations, baselining remote into a new migration chain, or large repo moves. Pick a calm window after diagnostics and prod behavior are understood.

## Related paths

- **[`scripts/sql-editor/`](scripts/sql-editor/)** — older or numbered SQL fragments; may overlap `migrations/` or `manual_sql/`. Treat as **reference** unless you confirm a file is still the authoritative apply path.
