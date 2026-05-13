# Intraday step ticks — implementation plan & slices

This document captures agreed architecture for **server-stored opponent (and optionally self) intraday cumulative step progression**, Home hero refresh behavior, downsampling, and SQL workflow. Use each **slice** as a standalone agent prompt; order and parallelism are noted at the end.

---

## Supabase / SQL workflow (required)

Follow **`FitUp/docs/sql-cmd-instructions.md`**:

- SQL is run **manually** in the Supabase SQL Editor (no auto-migrations, no auto-apply from the agent unless you explicitly change that policy).
- Agent creates **`supabase/manual_sql/`** files with clear names and states **whether you must run** each script and in **what order**.
- No Edge Function deploys from the agent without explicit deploy commands from repo root.

Any slice that adds schema or RPCs should end with: *“Manual SQL files added under `supabase/manual_sql/` — see slice checklist.”*

---

## Locked decisions (summary)

| Topic | Decision |
|--------|-----------|
| Storage | **New narrow table** (not overloading `metric_snapshots` for this timeline). |
| Row model | **Append** cumulative steps for a **calendar day** anchored to the **writer’s profile timezone** (`calendar_date` as `yyyy-MM-dd` + `timezone_identifier` at write time). Store **`recorded_at`** as `timestamptz` (UTC is how Postgres stores it; semantics are “instant in time”). |
| Upload debounce | **~5 minutes** minimum between successful uploads for the same user/day (unless you define an exception for day-end). |
| Meaningful change | Only upload if cumulative steps increased by **≥ 100** vs last **uploaded** value for that calendar day (still subject to debounce). |
| Micro-optimization | **Skip upload** if cumulative is **unchanged** since last uploaded value for that day. |
| Featured opponent | **Unchanged authoritative rule:** “closest” / featured opponent still comes from **existing Home match snapshot + comparable margin logic** (e.g. `HomeActiveMatch.featuredStepMatch` and totals from current RPC/home load). **Ticks table is for the curve and freshness only**, not for picking which opponent is featured. |
| Latest opponent steps | For “most recent step count per active opponent,” use **last tick per opponent for `calendar_date`** (or fall back to existing `theirToday` / `match_days` if no ticks yet). |
| Viewer chart TZ | Chart axis and “today” for the **viewer** use **viewer local/profile TZ**. |
| Opponent sample times | Store **writer’s `timezone_identifier` + `calendar_date`** with each row; when rendering for the viewer, **convert sample instants** into the viewer’s local timeline for plotting (library: Swift `TimeZone` / `Calendar`). |
| My line | **HealthKit intraday** on device for the current user (existing `HealthKitService` patterns). |
| Opponent line | **Query new table** (full day series, optionally **incremental `since`** cursor). |
| Home first paint | **Existing local hero snapshot cache** first; then network + HK refresh. |
| Fetch orchestration | **Parallel:** HK intraday + opponent tick fetch. **Single combined UI update** when both succeed. If either **fails by timeout (3–5s)** or hard error, **update with partial data** (whatever succeeded). |
| Freshness UI | Per side: **last successful local HK read** and **last opponent tick / sync time** (from latest sample `recorded_at` or explicit copy from server). |
| Raw row volume | Target **≤ ~30 stored points per user per calendar day** after pruning (see algorithm below). |
| Retention | Keep intraday tick history **~7 days** (TTL delete job or manual SQL template first; cron later if you want). |

---

## 30-point cap — deterministic prune algorithm (Visvalingam–Whyatt style)

**When** a new row is inserted for `(user_id, calendar_date)` and the count of rows for that pair would exceed **30**:

1. **Always keep** the earliest sample of the day (by `recorded_at`) and the **latest** sample of the day (so start-of-day and “now” are never dropped by the prune pass).
2. Among **interior** points only, compute the **area of the triangle** formed with its immediate neighbors in a normalized plane:  
   - x = normalized time in `[0,1]` across `[first.recorded_at, last.recorded_at]`  
   - y = normalized cumulative steps in `[0,1]` across `[min_cumulative, max_cumulative]` for that day’s series  
3. **Delete the interior point with the smallest triangle area** (ties broken by earlier `recorded_at`, then by `id`).
4. Repeat step 2–3 until count ≤ 30.

**Why:** smallest area ≈ “this point is almost collinear with its neighbors” → least visual loss. Deterministic, standard in geospatial/chart simplification.

**Where it runs:** Prefer a **small Postgres RPC** (e.g. `prune_user_intraday_step_ticks`) invoked after insert, *or* equivalent logic in the app after batching reads (server-side keeps all clients consistent). **Ideal:** server RPC after insert so DB stays bounded without trusting every client version.

---

## Suggested table sketch (for Slice 1 SQL)

Name (example): **`user_intraday_step_ticks`**

| Column | Type | Notes |
|--------|------|--------|
| `id` | `uuid` PK | `gen_random_uuid()` |
| `user_id` | `uuid` FK → `profiles` | Who took the steps (the writer). |
| `calendar_date` | `date` | **Writer’s** local calendar date for “today’s steps” (computed in app using `profiles.timezone` or device calendar when syncing). |
| `timezone_identifier` | `text` | IANA TZ used to compute `calendar_date` (e.g. `America/Chicago`). |
| `cumulative_steps` | `int` | HK cumulative for that calendar day at sample time. |
| `recorded_at` | `timestamptz` | When sample was recorded (client clock or server `now()` on insert—pick one policy and stick to it). |
| `created_at` | `timestamptz` default `now()` | Server receipt (optional, useful for audit). |

**Indexes (minimum):** `(user_id, calendar_date, recorded_at DESC)` for day pulls and “latest row”; optional partial index for retention deletes by `calendar_date`.

**RLS (high level):**  
- **INSERT:** authenticated user may insert **only** rows where `user_id = auth.uid()`.  
- **SELECT:** only for users in an **active match relationship** with the viewer (implement via **RPC** or security-definer function to avoid leaking arbitrary users’ series).

---

## Implementation slices (copy-paste prompts)

### Slice 1 — Database: table, indexes, RLS, retention template

**Prompt to agent:**

> Implement **Slice 1** from `FitUp/docs/intraday-step-ticks-implementation-slices.md`: add `supabase/manual_sql/` scripts (numbered or clearly named) to create `user_intraday_step_ticks` (columns as in the doc), indexes, RLS policies, and a read-only verification query file. Include a **second** manual SQL file for optional **7-day TTL delete** (document as “run periodically in SQL Editor or later cron”). Do **not** apply migrations automatically. Reference `FitUp/docs/sql-cmd-instructions.md` in PR/summary and list **exact run order** for the human.

**Human:** Run scripts in Supabase SQL Editor in the order the agent specifies.

---

### Slice 2 — RPCs: insert + prune + fetch (security definer as needed)

**Prompt to agent:**

> Implement **Slice 2** from `FitUp/docs/intraday-step-ticks-implementation-slices.md`: add manual SQL for Postgres functions/RPCs: (1) **insert tick** (validates `user_id = auth.uid()`), (2) **prune to ≤30** per `(user_id, calendar_date)` using the triangle-area algorithm in the doc, (3) **fetch ticks for a day** for a **permitted opponent** (match participant check), optional (4) **fetch ticks since `recorded_at` cursor** for incremental updates. Grant execute to `authenticated`. Again: files only under `supabase/manual_sql/`, no auto-run.

**Depends on:** Slice 1 run successfully.

**Human:** Run new SQL files after review.

---

### Slice 3 — Swift: `MetricSnapshotRepository`-style client for ticks

**Prompt to agent:**

> Implement **Slice 3** from `FitUp/docs/intraday-step-ticks-implementation-slices.md`: add a small repository (e.g. `UserIntradayStepTicksRepository`) calling Supabase RPCs for insert + optional fetch helpers. Unit-test or document request/response shapes. No UI yet.

**Depends on:** Slice 2 RPCs deployed manually (or stubs with `#if DEBUG` only if you must compile before SQL exists—avoid if possible).

**Parallel:** Can start **after** Slice 1 is merged to repo **if** RPC signatures are frozen in the SQL file first (define RPC names in Slice 1/2 before Swift lands).

---

### Slice 4 — Upload pipeline: debounce, ±100 steps, skip unchanged, tie into HK sync

**Prompt to agent:**

> Implement **Slice 4** from `FitUp/docs/intraday-step-ticks-implementation-slices.md`: extend the HealthKit → Supabase sync path (e.g. `MetricSyncCoordinator` + helpers) to **upload intraday ticks** with: **5 min** debounce per user/day, **≥100 steps** increase vs last **uploaded** value, **skip** if cumulative unchanged. Call the insert RPC after successful today step read. Ensure day-boundary uses **profile timezone** (same source as `MetricSyncCoordinator` / profile). Log with existing `AppLogger` categories where appropriate.

**Depends on:** Slice 3 repository.

**Parallel:** **Not** with Slice 5/6 until insert path exists; **can** overlap with Slice 2 **only if** RPC contract is already in the manual SQL file.

---

### Slice 5 — Home / hero: parallel HK + opponent ticks, combined update, timeout, incremental fetch

**Prompt to agent:**

> Implement **Slice 5** from `FitUp/docs/intraday-step-ticks-implementation-slices.md`: On Home (featured step match / energy hero path): (1) keep **instant** paint from existing disk snapshot; (2) load **viewer HK intraday** and **opponent tick series** **in parallel**; (3) apply **one** `@MainActor` update when both complete; (4) if **3–5s** timeout or hard failure on one side, refresh with **partial** data; (5) optional `since` parameter for opponent fetch using last known `recorded_at`. **Do not** change featured-opponent selection logic except where needed to consume new data; featured opponent still from existing home snapshot rules.

**Depends on:** Slice 3 (fetch RPC), Slice 4 optional for end-to-end testing (opponent data must exist).

**Parallel:** Slice 6 can be developed in parallel **only if** it consumes stable view-model hooks (see Slice 6).

---

### Slice 6 — Freshness UI: “Last synced …” per side

**Prompt to agent:**

> Implement **Slice 6** from `FitUp/docs/intraday-step-ticks-implementation-slices.md`: expose **last successful HK read time** and **opponent’s latest tick time** (or server message) to the hero / beam UI in a subtle, on-brand way (both sides). Wire from Slice 5 view model state.

**Depends on:** Slice 5 (or stub times until Slice 5 lands).

**Parallel:** **Yes** — different files from Slice 4; can start once Slice 5 **interfaces** are known (protocol or placeholder VM).

---

### Slice 7 — Optional polish: “new closest opponent” handoff animation

**Prompt to agent:**

> Implement **Slice 7** (optional) from `FitUp/docs/intraday-step-ticks-implementation-slices.md`: When **featured opponent id** differs from **last cached featured opponent** on Home load, defer hero content swap until data is ready, then run a **2.5–3s** transition: temporary message (“[Name] is trying to beat you!”) + wipe/reveal animation, then show new opponent’s hero data **atomically**. Respect Reduce Motion. Keep data pipeline from Slice 5 unchanged behind a stable coordinator.

**Depends on:** Slice 5 (featured id + data readiness). **Can** be feature-flagged.

**Parallel:** **Art/design-heavy** — can be built against mock state while Slice 5 is in flight if you define a `HeroOpponentTransitionState` enum early.

---

### Slice 8 — Batch “latest tick per active opponent” (Home efficiency)

**Prompt to agent:**

> Implement **Slice 8** from `FitUp/docs/intraday-step-ticks-implementation-slices.md`: Add one RPC or query pattern: given `auth.uid()`, return **latest `cumulative_steps` + `recorded_at` per opponent user_id** for all **active** matches for **viewer’s local calendar today** (or document match TZ if product requires). Use on Home refresh to cheaply compare totals / freshness without pulling full series for every opponent first.

**Depends on:** Slice 1–2. **Can** land before Slice 5 if Home only needs “latest value” first; full series fetch remains Slice 5 for chart.

**Parallel:** **Yes** with Slice 3–4 if RPC is specified in SQL first.

---

## Order & what you can run in parallel

```text
Slice 1 (SQL files) ──► human runs SQL
         │
         ▼
Slice 2 (RPC SQL) ──► human runs SQL
         │
         ├──────────────────────┐
         ▼                      ▼
    Slice 3 (Swift repo)   Slice 8 (batch latest RPC + Swift)
         │                      │
         ▼                      │
    Slice 4 (upload pipeline)     │
         │                      │
         └──────────┬───────────┘
                    ▼
              Slice 5 (Home parallel fetch + combined update)
                    │
         ┌──────────┴──────────┐
         ▼                     ▼
    Slice 6 (freshness UI)   Slice 7 (optional animation)
```

| Parallel combo | Notes |
|----------------|--------|
| **Slice 8 + Slice 3** | OK once Slice 2 signatures exist. |
| **Slice 6 + Slice 7** | OK with stubs; both touch UI—coordinate on same branch or sequence to avoid merge pain. |
| **Slice 4 + Slice 6** | Avoid until Slice 5 exposes times; or stub **Slice 6** with placeholders. |

**Strict sequence:** 1 → 2 → 3 → 4 → 5 → (6 and/or 7). **Slice 8** after 2, parallel to 3–4 before 5 is ideal.

---

## Checklist before calling the feature “done”

- [ ] Manual SQL run and verified (see `sql-cmd-instructions.md`).
- [ ] RLS: cannot read random users’ ticks; only match-scoped access.
- [ ] Upload: debounce + 100-step + skip-unchanged verified in logs or tests.
- [ ] Prune: never drops first/last of day; count ≤ 30 per user/day under load test.
- [ ] Home: cache-first paint; combined update; timeout partial update.
- [ ] TZ: `calendar_date` + `timezone_identifier` documented; viewer conversion tested across DST edge (optional test case).
- [ ] Retention: 7-day delete documented or automated per your ops comfort.

---

## Notifications (reminder)

Tapping notifications to foreground the app is a **valid supplement** to background HK delivery; implementation is **not** a separate DB slice—hook the **same upload pipeline** (Slice 4) on foreground / existing sync triggers. Add a one-line note in Slice 4 prompt if you want it explicit.

---

## File location

This plan lives at:

`FitUp/docs/intraday-step-ticks-implementation-slices.md`

Update it if RPC names, table names, or slice boundaries change during implementation.
