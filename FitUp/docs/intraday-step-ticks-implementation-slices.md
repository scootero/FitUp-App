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

**Slice 1 artifacts (repo):**

| Order | File | Action |
|-------|------|--------|
| 1 | `supabase/manual_sql/intraday_step_ticks_slice1_create_table_rls.sql` | **Must run** — creates `user_intraday_step_ticks`, indexes, RLS, grants. |
| 2 | `supabase/manual_sql/intraday_step_ticks_slice1_retention_ttl_7d.sql` | **Optional** — periodic 7-day TTL `DELETE` (UTC `calendar_date` cutoff; adjust later if needed). |
| 3 | `supabase/manual_sql/verify_user_intraday_step_ticks.sql` | **Optional** — read-only verification. |

---

### Slice 2 — RPCs: insert + prune + fetch (security definer as needed)

**Prompt to agent:**

> Implement **Slice 2** from `FitUp/docs/intraday-step-ticks-implementation-slices.md`: add manual SQL for Postgres functions/RPCs: (1) **insert tick** (validates `user_id = auth.uid()`), (2) **prune to ≤30** per `(user_id, calendar_date)` using the triangle-area algorithm in the doc, (3) **fetch ticks for a day** for a **permitted opponent** (match participant check), optional (4) **fetch ticks since `recorded_at` cursor** for incremental updates. Grant execute to `authenticated`. Again: files only under `supabase/manual_sql/`, no auto-run.

**Depends on:** Slice 1 run successfully.

**Human:** Run new SQL files after review.

**Slice 2 artifacts (repo):**

| Order | File | Action |
|-------|------|--------|
| 1 | `supabase/manual_sql/intraday_step_ticks_slice2_rpcs.sql` | **Must run** — `intraday_step_ticks_prune_one_victim` (internal, no client grant), `append_user_intraday_step_tick`, `prune_user_intraday_step_tick_day`, `fetch_opponent_intraday_step_ticks` + `GRANT EXECUTE` to `authenticated`. |
| 2 | `supabase/manual_sql/verify_intraday_step_ticks_rpcs.sql` | **Optional** — read-only verification. |

**RPC summary:**

| RPC | Purpose |
|-----|---------|
| `append_user_intraday_step_tick(p_calendar_date, p_timezone_identifier, p_cumulative_steps, p_recorded_at default now())` | Insert one tick for `auth.uid()`’s profile; prune that day to ≤30 rows. Returns new `uuid`. |
| `prune_user_intraday_step_tick_day(p_calendar_date)` | Prune only (repair/backfill); returns number of rows removed. |
| `fetch_opponent_intraday_step_ticks(p_opponent_profile_id, p_calendar_date, p_since default null)` | Returns opponent’s ticks if **active** match with both `accepted_at` set; optional `p_since` for incremental fetch. |

---

### Slice 3 — Swift: `MetricSnapshotRepository`-style client for ticks

**Prompt to agent:**

> Implement **Slice 3** from `FitUp/docs/intraday-step-ticks-implementation-slices.md`: add a small repository (e.g. `UserIntradayStepTicksRepository`) calling Supabase RPCs for insert + optional fetch helpers. Unit-test or document request/response shapes. No UI yet.

**Depends on:** Slice 2 RPCs deployed manually (or stubs with `#if DEBUG` only if you must compile before SQL exists—avoid if possible).

**Slice 3 artifacts (repo):**

| Item | Location |
|------|-----------|
| Repository + models | `FitUp/FitUp/FitUp/Repositories/UserIntradayStepTicksRepository.swift` |

**Public API:**

- `appendTick(calendarDate:profileTimeZoneIdentifier:cumulativeSteps:recordedAt:)` → `UUID` (RPC `append_user_intraday_step_tick`)
- `pruneDay(calendarDate:profileTimeZoneIdentifier:)` → `Int` rows removed (RPC `prune_user_intraday_step_tick_day`)
- `fetchOpponentTicks(opponentProfileId:calendarDate:opponentTimezoneIdentifier:sinceRecordedAt:)` → `[OpponentIntradayStepTick]` (RPC `fetch_opponent_intraday_step_ticks`)

Calendar strings use `HomeRepository.formatProfileCalendarDate` with the same `yyyy-MM-dd` convention as the rest of Home.

**Parallel:** Can start **after** Slice 1 is merged to repo **if** RPC signatures are frozen in the SQL file first (define RPC names in Slice 1/2 before Swift lands).

---

### Slice 4 — Upload pipeline: debounce, ±100 steps, skip unchanged, tie into HK sync

**Prompt to agent:**

> Implement **Slice 4** from `FitUp/docs/intraday-step-ticks-implementation-slices.md`: extend the HealthKit → Supabase sync path (e.g. `MetricSyncCoordinator` + helpers) to **upload intraday ticks** with: **5 min** debounce per user/day, **≥100 steps** increase vs last **uploaded** value, **skip** if cumulative unchanged. Call the insert RPC after successful today step read. Ensure day-boundary uses **profile timezone** (same source as `MetricSyncCoordinator` / profile). Log with existing `AppLogger` categories where appropriate.

**Depends on:** Slice 3 repository.

**Slice 4 artifacts (repo):**

| Item | Location |
|------|-----------|
| Throttle policy (UserDefaults) | `FitUp/FitUp/FitUp/Services/IntradayStepTickUploadPolicy.swift` |
| HK sync integration | `FitUp/FitUp/FitUp/Services/MetricSyncCoordinator.swift` — after successful `fetchTodayStepCount`, calls `UserIntradayStepTicksRepository.appendTick` when policy allows; `metric sync finished` metadata key `intraday_tick` (`appended`, `skip_*`, `append_failed`, `no_steps`). |

**Rules:** 300s minimum between **successful** uploads per profile+calendar day; first upload of that day has no ±100 requirement; later uploads require **≥100** net increase vs last uploaded cumulative while steps are **increasing**; HK **decreases** (corrections) can upload after debounce without the +100 rule; exact duplicate cumulative vs last upload → skip.

**Parallel:** Slice **5**/**6** need a **read** path (Slice **3** RPCs) for meaningful Home testing; **writes** (Slice **4**) make opponent series realistic in dev/prod but are not strictly required to **compile** Slice 5. Do not start Slice 5 assuming production opponent ticks exist until Slice 4 is deployed or you seed data manually. **Can** overlap with Slice 2 **only if** RPC names and params are frozen in the manual SQL file.

---

### Slice 5 — Home / hero: parallel HK + opponent ticks, combined update, timeout, incremental fetch

**Prompt to agent:**

> Implement **Slice 5** from `FitUp/docs/intraday-step-ticks-implementation-slices.md`: On Home (featured step match / energy hero path): (1) keep **instant** paint from existing disk snapshot; (2) load **viewer HK intraday** and **opponent tick series** **in parallel**; (3) apply **one** `@MainActor` update when both complete; (4) if **3–5s** timeout or hard failure on one side, refresh with **partial** data; (5) optional `since` parameter for opponent fetch using last known `recorded_at`. **Do not** change featured-opponent selection logic except where needed to consume new data; featured opponent still from existing home snapshot rules.

**Depends on:** Slice 3 (fetch RPC), Slice 4 optional for end-to-end testing (opponent data must exist).

**Slice 5 artifacts (Home hero sparkline pipeline):**

| Item | Location |
|------|-----------|
| Parallel fetch + ~4.5s budget + normalize to `[0…1]` | `FitUp/FitUp/FitUp/Services/HomeHeroSparklineLoader.swift` — `HomeHeroSparklineLoadResult` (`userSeries` / `opponentSeries` / `opponentLatestTickRecordedAt`); `HealthKitService.fetchIntradayCumulativeSeries` (steps) and `UserIntradayStepTicksRepository.fetchOpponentTicks` in sibling `Task`s; sleep then `cancel()`; `try? await` each `value` for partial results; `sinceRecordedAt` passed **`nil`** (full-day series required for interpolation; incremental `since` needs a merge/cache story later). |
| Published series + scheduling | `FitUp/FitUp/FitUp/ViewModels/HomeViewModel.swift` — `heroSparklineUserSeries` / `heroSparklineOpponentSeries`, `heroSparklineFetchTask`, `scheduleHeroSparklineRefresh()`; called from `applyHeroHealthKitPatch` and from `executeHeroHealthKitPatch` on HK **failure** so opponent ticks still load; clears on user switch, `stop()`, and home **local day** rollover; cancels in-flight fetch when rescheduling; ignores results if featured step match **id** changed. |
| Pass-through to energy hero | `FitUp/FitUp/FitUp/Views/Home/HomeView.swift` — `sparklineUserValues` / `sparklineOpponentValues` on `HomeEnergyBeamHeroCard`. |
| Mock fallback when side is `nil` | `FitUp/FitUp/FitUp/Views/Home/Sections/HomeEnergyBeamHeroCard.swift` — optional series parameters default to mock curves. |

**Featured opponent:** unchanged — still `HomeActiveMatch.featuredStepMatch(from: activeStepMatches)` / `featuredHomeStepMatch` in `HomeViewModel`.

**Parallel:** Slice **6** can start in parallel once these **stable anchors** exist (they do in the artifacts above): `@MainActor` `HomeViewModel`, hero HK patch entrypoints (`executeHeroHealthKitPatch` / `applyHeroHealthKitPatch`), and sparkline scheduling (`scheduleHeroSparklineRefresh`). Slice 6 adds **new** `@Published` freshness fields and UI; it should not change featured selection or the sparkline fetch contract without a new slice note.

---

### Slice 6 — Freshness UI: “Last synced …” per side

**Prompt to agent:**

> Implement **Slice 6** from `FitUp/docs/intraday-step-ticks-implementation-slices.md`: expose **last successful HK read time** and **opponent’s latest tick time** (or server message) to the hero / beam UI in a subtle, on-brand way (both sides). Wire from Slice 5 view model state.

**Depends on:** Slice 5 (or stub times until Slice 5 lands).

**Slice 6 artifacts (freshness UI):**

| Item | Location |
|------|-----------|
| Published timestamps | `FitUp/FitUp/FitUp/ViewModels/HomeViewModel.swift` — `heroViewerHealthKitStepsReadAt` (set when steps HK patch succeeds), `heroOpponentIntradayLatestTickAt` (from `HomeHeroSparklineLoadResult.opponentLatestTickRecordedAt`); cleared on user switch, day rollover, and sparkline schedule teardown paths aligned with Slice 5. |
| Opponent latest tick from fetch | `FitUp/FitUp/FitUp/Services/HomeHeroSparklineLoader.swift` — `HomeHeroSparklineLoadResult.opponentLatestTickRecordedAt` (`max(recordedAt)` over returned ticks). |
| Hero UI row | `FitUp/FitUp/FitUp/Views/Home/Sections/EnergyBeam/EnergyBeamHeroCore.swift` — `EnergyBeamIntradayFreshnessRow` under `DayBattleSparklinePreview`; `EnergyBeamHeroGlassCardView` optional `viewerIntradayHealthKitSyncedAt` / `opponentIntradayLatestTickAt`. |
| Wiring | `FitUp/FitUp/FitUp/Views/Home/Sections/HomeEnergyBeamHeroCard.swift`, `FitUp/FitUp/FitUp/Views/Home/HomeView.swift`. DEBUG prototype sample times: `FitUp/FitUp/FitUp/DevPrototypes/EnergyBeamHeroPrototypeView.swift`. |

**Parallel:** **Yes** — different files from Slice 4; can start once Slice 5 **interfaces** are known (protocol or placeholder VM).

---

### Slice 7 — Optional polish: “new closest opponent” handoff animation

**Prompt to agent:**

> Implement **Slice 7** (optional) from `FitUp/docs/intraday-step-ticks-implementation-slices.md`: When **featured opponent id** differs from **last cached featured opponent** on Home load, defer hero content swap until data is ready, then run a **2.5–3s** transition: temporary message (“[Name] is trying to beat you!”) + wipe/reveal animation, then show new opponent’s hero data **atomically**. Respect Reduce Motion. Keep data pipeline from Slice 5 unchanged behind a stable coordinator.

**Depends on:** Slice 5 (featured id + data readiness). **Can** be feature-flagged.

**Slice 7 artifacts:**

| Item | Location |
|------|-----------|
| Feature toggle (default on) | `HomeFeaturedOpponentHandoffFeature` in `FitUp/FitUp/FitUp/Views/Home/Sections/HomeFeaturedOpponentHandoffOverlay.swift` — UserDefaults key `fitup.hero_opponent_handoff_enabled`. |
| Overlay + message + wipe | `FitUp/FitUp/FitUp/Views/Home/Sections/HomeFeaturedOpponentHandoffOverlay.swift` |
| State + last opponent persistence | `FitUp/FitUp/FitUp/ViewModels/HomeViewModel.swift` — `HeroOpponentHandoffOverlayModel`, `heroOpponentHandoff`, `evaluateHeroOpponentHandoffIfNeeded` (after reload), `completeHeroOpponentHandoff`, `FeaturedOpponentHandoffStore` (UserDefaults per user). |
| Home wiring | `FitUp/FitUp/FitUp/Views/Home/HomeView.swift` — energy hero path shows overlay when `heroOpponentHandoff != nil`. |

**Behavior:** After each successful Home reload, if the **featured steps** opponent profile id differs from the last saved id for this user, the energy hero is replaced temporarily by the overlay; on finish, the saved id updates and `scheduleHeroSparklineRefresh()` runs. **Reduce Motion** shortens message and wipe. `stop()` / account switch clear in-flight handoff.

**Parallel:** **Art/design-heavy** — can be built against mock state while Slice 5 is in flight if you define a `HeroOpponentTransitionState` enum early.

---

### Slice 8 — Batch “latest tick per active opponent” (Home efficiency)

**Prompt to agent:**

> Implement **Slice 8** from `FitUp/docs/intraday-step-ticks-implementation-slices.md`: Add one RPC or query pattern: given `auth.uid()`, return **latest `cumulative_steps` + `recorded_at` per opponent user_id** for all **active** matches for **viewer’s local calendar today** (or document match TZ if product requires). Use on Home refresh to cheaply compare totals / freshness without pulling full series for every opponent first.

**Depends on:** Slice 1–2. **Can** land before Slice 5 if Home only needs “latest value” first; full series fetch remains Slice 5 for chart.

**Slice 8 artifacts:**

| Order | Item | Location |
|-------|------|-----------|
| 1 (human run) | RPC `fetch_latest_opponent_intraday_ticks_for_active_matches(p_calendar_date date)` | `supabase/manual_sql/intraday_step_ticks_slice8_batch_latest_rpcs.sql` |
| 2 | Swift client + model | `FitUp/FitUp/FitUp/Repositories/UserIntradayStepTicksRepository.swift` — `OpponentLatestIntradayStepTickSummary`, `fetchLatestOpponentTicksForActiveMatches` |
| 3 | Home refresh hook | `FitUp/FitUp/FitUp/ViewModels/HomeViewModel.swift` — `refreshFeaturedOpponentLatestTickFromBatch` after `persistFreshHeroSnapshot` on reload; merges with existing ``heroOpponentIntradayLatestTickAt`` via `max` so Slice 5/6 sparkline timestamps are not regressed. |

**Calendar key:** Caller passes **viewer profile local** `yyyy-MM-dd` (same helper as other tick calls). Opponent rows must use that same `calendar_date` key in `user_intraday_step_ticks` to appear (aligned with current Home opponent fetch MVP).

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
