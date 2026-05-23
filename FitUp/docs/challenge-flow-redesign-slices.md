# Challenge flow redesign — implementation plan & slices

**Status: Complete (slices 1A–5, 2026-05).** Replaces the legacy **4-step** challenge flow (`Sport → Format → Opponent → Review`) with a **3-step** steps-only flow (`Opponent → Duration → Difficulty`), plus sent-screen behavior and Rematch wiring.

**Related docs:** `FitUp/docs/fitup-build-slices.md` (original Slice 4 + as-built note), `FitUp/docs/fitup-docs-pack.md` (interaction map), `FitUp/docs/slice-tracker.md` (as-built log).

---

## Locked product decisions

| # | Decision |
|---|----------|
| 1 | **Quick Battle** goes to **Duration** (step 1), not straight to Difficulty. |
| 2 | **Direct opponent / Rematch** preselects opponent and **starts at Duration** (skips Opponent). |
| 3 | **No Sport step** — all new battles are **steps** (`metricType = steps` / `ChallengeMetricType.steps`). |
| 4 | **Stepper:** 3 steps only — **Opponent → Duration → Difficulty**. |
| 5 | **Direct-opponent difficulty rule** — see [Direct-opponent difficulty (recommended rule)](#direct-opponent-difficulty-recommended-rule) below. |
| 6 | **Battle Setup dock** hidden on the **sent** confirmation screen. |
| 7 | **Sent screen** auto-returns Home after **~2 seconds** (fade when motion allowed); **Back to Home** remains as manual fallback. **Reduce Motion:** still auto-return after ~2s, **no** fade animation. |
| 8 | **Rematch** uses the **new** flow (not `.rematch` jumping to old step 3 with full prefill). |


---

## Current vs target flow

### Today (as-built)

| `stepIndex` | Screen | Stepper label |
|-------------|--------|---------------|
| 0 | `SportStepView` | SPORT |
| 1 | `FormatStepView` | FORMAT |
| 2 | `OpponentStepView` | OPPONENT |
| 3 | `ReviewStepView` (scoring + difficulty + send) | SEND |

**Launch quirks:**

- `.prefilled(opponent)` — opponent set; may still show Sport first.
- `.rematch(opponent, metric, format)` — jumps to **Review** with everything filled.
- Quick Battle from Opponent — jumps to **Review** (`stepIndex = 3`).
- `makeRematchLaunchContext()` returns `nil` when `durationDays` ∉ `{1,3,5,7}` → Rematch button no-ops silently.

### Target

| `stepIndex` | Screen | Stepper label | Notes |
|-------------|--------|---------------|--------|
| 0 | `OpponentStepView` | OPPONENT | Quick Battle card prominent; search/list below |
| 1 | `DurationStepView` (rename from Format) | DURATION | “Choose battle duration” + “How this works” |
| 2 | `DifficultyStepView` (evolve from Review) | DIFFICULTY | VS card, scoring, difficulty, Send |
| — | `ChallengeSentView` | *(hidden)* | No dock; auto-fade home |

**Metric:** Set once in `prepareFlow()`: `selectedMetric = .steps` (no UI).

**Navigation matrix:**

| Entry | Start step | Opponent state | Quick Battle |
|-------|------------|----------------|--------------|
| BATTLE tab / generic New Battle | 0 | nil | user chooses |
| Leaderboard / Discover / friend CTA | 0 or 1 | prefilled | — |
| **Rematch** / **prefilled opponent** | **1** | prefilled | `false` |
| **Quick Battle** on Opponent | **1** | nil | `true` |
| After Duration selected | 2 | unchanged | unchanged |
| After Send success | sent | — | — |

---

## Direct-opponent difficulty (recommended rule)

**Goal:** Avoid misleading Raw difficulty controls (Easy / Fair / Hard) on **direct** challenges, where difficulty only affects **random matchmaking**, not head-to-head invites.

**Definitions:**

- **`isQuickMatch`** — user chose Quick Battle (random opponent).
- **`isDirectedOpponent`** — `!isQuickMatch && selectedOpponent != nil` (includes Rematch and pick-from-list).

### Recommended safest rule

| Mode | Quick Battle (random) | Directed opponent (direct / Rematch) |
|------|----------------------|--------------------------------------|
| **Balanced Battle** | Allowed; no difficulty picker | Allowed; no difficulty picker |
| **Raw Battle** | Full difficulty picker (Easy / Fair / Hard); default **Fair** | **Fair only** — Easy/Hard **disabled** (greyed); difficulty segment shows **Fair** selected; helper copy: *“Difficulty settings apply to random matches only. Direct battles use Fair matchmaking rules when you use Raw.”* or shorter: *“Choose difficulty in random matches only.”* |
| **Default on Difficulty step** | Raw + Fair | **Raw** scoring default (per product ask); if user switches to Balanced, difficulty UI hidden as today |

**Submit payload (must stay consistent with backend):**

- Directed + Raw → always send `difficulty: .fair` (even if UI once showed other values).
- Directed + Balanced → send `difficulty: nil` (unchanged).
- Quick + Raw → send selected difficulty.
- Quick + Balanced → `difficulty: nil`.

**Why this rule:** Prevents users thinking Easy/Hard changes a direct invite; keeps Balanced path unchanged; preserves full difficulty UX for Quick Battle where matchmaking runs.

---

## Shared UI: Battle Setup dock

Persistent **bottom summary** on steps **0–2 only** (hidden when `isSent`).

**Example (Opponent step):**

```text
Battle Setup

STEPS BATTLE
>> Select Opponent <<
<Duration placeholder or “—”>
<Difficulty placeholder or “—”>
```

**Example (Duration step, opponent chosen):**

```text
Battle Setup

STEPS BATTLE
Opponent: David
>> 3-Days <<
<Difficulty placeholder>
```

**Example (Difficulty step):**

```text
Battle Setup

STEPS BATTLE
Opponent: David (or “Random Opponent”)
3-Days
>> Select Difficulty <<
```

Use `>> … <<` around the **current** step label; completed lines show resolved values.

**New file (likely):** `Views/Challenge/ChallengeBattleSetupDock.swift`

---

## Layout principle (all steps)

- Main step content **top-aligned** with consistent top padding below header/stepper (not vertically centered in remaining space).
- Battle Setup dock **pinned toward bottom** of the flow content area so the main card does not jump vertically between steps.
- Implement via shared padding / `Spacer(minLength:)` pattern in `ChallengeFlowView` or a thin `ChallengeFlowStepShell` wrapper.

---

## Slice overview

| Slice | Title | Depends on | User-visible outcome |
|-------|--------|------------|----------------------|
| **1A** | Sent auto-fade + Home landing | — | Sent screen returns Home ~2s; lands on Home tab |
| **1B** | Flow engine + Rematch/prefill | 1A | 3-step navigation; Rematch at Duration |
| **2** | Battle Setup dock | 1B | Bottom summary on all builder steps |
| **3** | Opponent + Duration steps | 1–2 | New order, Quick Battle UX, duration copy/cards |
| **4** | Difficulty step polish | 1–2 | Themed VS/setup; direct-opponent difficulty rule |
| **5** | Docs & tracker | 1–4 | `slice-tracker.md` + cross-links updated |

**Do not start Slice 1B until Slice 1A is reviewed/accepted**, unless explicitly batched.

---

## Slice 1A — Sent auto-fade + Home landing

**Goal:** After sending a battle, the confirmation screen auto-returns to Home (~2s) while keeping **Back to Home**; closing the flow selects the **Home** tab.

### Behavior changes

1. **`ChallengeSentView`:** Fade in on appear (unless Reduce Motion). Schedule auto-dismiss after ~2s **always** (including Reduce Motion — no animation, still auto-return).
2. Manual **Back to Home** cancels timer and exits immediately (with fade when motion allowed).
3. **`ContentView` challenge `onClose`:** Set `selectedTab = .home` before snapshot refresh.

### Files touched

| File | Change |
|------|--------|
| `Views/Challenge/ChallengeSentView.swift` | Auto-dismiss + opacity |
| `ContentView.swift` | `selectedTab = .home` on flow close |

### Acceptance criteria (1A)

- [ ] Send battle → Sent screen → auto-dismiss flow ~2s → **Home** tab visible.
- [ ] **Back to Home** works immediately; no double-dismiss.
- [ ] Reduce Motion: no fade; still auto-return ~2s.
- [ ] Battle Setup dock N/A on sent (dock is Slice 2; sent has no dock today).

**Status:** Implemented — pending review.

---

## Slice 1B — Flow engine + Rematch/prefill

**Status:** Implemented — pending review.

**Goal:** Replace the 4-step state machine with 3 steps (steps-only), correct launch/rematch/quick paths, no Battle Setup dock yet (optional stub OK).

### Behavior changes

1. Remove `SportStepView` from the active switch; auto-set `selectedMetric = .steps` in `prepareFlow()`.
2. Renumber steps: `0 = Opponent`, `1 = Duration`, `2 = Difficulty` (current `ReviewStepView` logic).
3. **Quick Battle:** `isQuickMatch = true`, `selectedOpponent = nil`, `stepIndex = 1`.
4. **Select opponent:** `isQuickMatch = false`, set opponent, `stepIndex = 1` (not 3).
5. **Duration selected:** `stepIndex = 2`.
6. **`applyLaunchStepIfNeeded()`** (rewrite):
   - Prefilled opponent only → `stepIndex = 1`, opponent hydrated.
   - Prefilled opponent + format (legacy `.rematch`) → treat as **opponent + duration prefilled**, `stepIndex = 2` *or* normalize Rematch to opponent-only (preferred: **Rematch → `.prefilled(opponent)` only**, duration chosen again on step 1).
7. **Rematch button:** `makeRematchLaunchContext()` returns `.prefilled(opponent:)` (not `.rematch(...)`). Map `durationDays` failures: if unsupported, still open flow at Duration with opponent set (optional: default `.firstTo3` only for display, not pre-selected).
8. **`handleBack()`:** step down 2 → 1 → 0; from 0 close flow; from sent → close.
9. **Progress stepper labels:** `["OPPONENT", "DURATION", "DIFFICULTY"]`.
10. *(Moved to Slice 1A.)* Sent auto-return + Home tab.
11. Hide rival strip on sent (already hidden when `isSent`); ensure dock not shown (dock is Slice 2).

### Files touched (1B)

| File | Change |
|------|--------|
| `Views/Challenge/ChallengeFlowView.swift` | 3-step machine, launch, back, stepper, rival strip |
| `ViewModels/MatchDetailsViewModel.swift` | `makeRematchLaunchContext()` → `.prefilled(opponent:)` only |
| `Views/Challenge/Steps/SportStepView.swift` | **No runtime use** (file retained until cleanup) |
| `Views/Challenge/Steps/FormatStepView.swift` | Step 1 (Duration) |
| `Views/Challenge/Steps/OpponentStepView.swift` | Step 0; advances to Duration |
| `Views/Challenge/Steps/ReviewStepView.swift` | Step 2 (Difficulty / send) |

### Risks

| Risk | Mitigation |
|------|------------|
| Rematch/regression on `durationDays` not in 1/3/5/7 | Prefilled opponent + start Duration; don’t return nil from rematch helper |
| Old `.rematch` launch sites | Grep `ChallengeLaunchContext.rematch`; convert to `.prefilled` or keep branch mapping format → step 2 |
| Paywall gate still runs before step 0 | Unchanged; verify blocked users never see wrong step |
| Auto-fade fires after user left screen | Cancel `Task` in `onDisappear` |
| Calories legacy matches in Rematch | Force steps metric in `makeRematchLaunchContext()` for v1 |

### Acceptance criteria (1B)

- [ ] BATTLE opens step 0 (Opponent); no Sport screen.
- [ ] Pick opponent → Duration (step 1), not Send/Review.
- [ ] Quick Battle → Duration (step 1).
- [ ] Duration → Difficulty (step 2) → Send → Sent.
- [ ] Rematch from completed/active match opens flow at **Duration** with opponent set; user can change duration; Send works.
- [ ] Back navigation follows 2 → 1 → 0 → dismiss.
- [ ] Leaderboard/friend prefilled entry starts at **Duration** (skips Opponent) — intentional per decision #2.

---

## Slice 2 — Battle Setup dock

**Status:** Implemented — pending review.

**Goal:** Add `ChallengeBattleSetupDock` and show on steps 0–2 with `>> current <<` highlighting.

### Files touched (Slice 2)

| File | Change |
|------|--------|
| `Views/Challenge/ChallengeBattleSetupDock.swift` | **New** — summary dock with `>>` / `<<` on current step |
| `Views/Challenge/ChallengeFlowView.swift` | ScrollView for step body; dock pinned below; hidden when `isSent` |

### Risks

| Risk | Mitigation |
|------|------------|
| Dock pushes content off small phones | ScrollView wrapper for step body + dock |
| Quick Battle shows empty opponent | Display “Random opponent” on later steps |

### Acceptance criteria

- [ ] Dock visible on Opponent, Duration, Difficulty.
- [ ] Dock **hidden** on Sent.
- [ ] Current step indicated with `>> … <<`.
- [ ] Values update as user selects opponent/duration.

---

## Slice 3 — Opponent & Duration step UI

**Status:** Implemented — pending review.

**Goal:** Product polish for first two screens (no change to state machine).

### Opponent step

- Move **Quick Battle** card above “Who do you want to battle?” — taller, thicker border, neon/retro default-option styling.
- Order: stepper → header → **Quick Battle** → search → list.
- Top-aligned layout (Slice 1 shell + this slice visuals).

### Duration step

- Rename copy: **“Choose battle duration”** (file rename optional: `FormatStepView` → `DurationStepView`).
- Duration cards: stronger contrast/readability; pressable depth (shadow up / down on select).
- Bottom **“How this works”** section — one line per format, e.g. 3-day → “Up to 3 competition days — first to 2 day-wins.”

### Files likely touched

| File | Change |
|------|--------|
| `Views/Challenge/Steps/OpponentStepView.swift` | Layout + Quick Battle styling |
| `Views/Challenge/Steps/FormatStepView.swift` | Copy, cards, how-it-works (rename optional) |
| `Design/DesignTokens.swift` | Only if new shared button style warranted |

### Risks

| Risk | Mitigation |
|------|------------|
| Scope creep on animation | Keep press state simple (scale/shadow) |

### Acceptance criteria

- [x] Quick Battle visually reads as primary/default.
- [x] Duration title and cards match spec; how-it-works visible without scrolling on common devices (or inside scroll).
- [x] Selecting duration still advances to Difficulty.

### As-built (Slice 3)

| File | Change |
|------|--------|
| `Views/Challenge/Steps/OpponentStepView.swift` | Quick Battle moved above section header; taller neon “DEFAULT” card with gradient border, glow, press depth |
| `Views/Challenge/Steps/FormatStepView.swift` | Renamed struct to `DurationStepView` (file kept); title “Choose battle duration”; pressable duration cards; “How this works” panel |
| `Services/MatchmakingService.swift` | `ChallengeFormatType.howItWorksLine` for per-format explainer copy |
| `Views/Challenge/ChallengeFlowView.swift` | Uses `DurationStepView`; fixed `applyLaunchStepIfNeeded()` compile error (guard fallthrough) |

**How to test**

1. Open BATTLE tab → Opponent step: Quick Battle card is first (above “Who do you want to battle?”), taller with purple/cyan gradient border and “DEFAULT” badge; tap scales down slightly.
2. Search + opponent list appear below Quick Battle; selecting an opponent still advances to Duration.
3. Tap Quick Battle → Duration step: title reads “Choose battle duration”; four cards have stronger contrast and press feedback (scale + shadow).
4. Scroll if needed on small device — “How this works” lists all four formats with one-line rules (e.g. 3-day → first to 2 day-wins).
5. Tap any duration card → advances to Difficulty (unchanged navigation).
6. Rematch/prefilled entry still lands on Duration with opponent in dock (Slice 1B/2 regression).

---

## Slice 4 — Difficulty step polish + direct-opponent rules

**Status:** Implemented — pending review.

**Goal:** Rename “Battle setup” section mentally to **Battle difficulty** UX; VS card theming; defaults; enforce directed-opponent difficulty rule.

### UI

- Default scoring: **Raw Battle** (user asked); Balanced still selectable.
- VS card: cyan you / orange opponent, stronger glass, optional flame/glow accents (performance-safe).
- Scoring/difficulty descriptions: larger/contrast when segment selected.
- **Directed opponent:** Raw difficulty Easy/Hard disabled; Fair locked; explanatory footnote; Balanced unchanged.
- Send button unchanged behaviorally.

### Files likely touched

| File | Change |
|------|--------|
| `Views/Challenge/Steps/ReviewStepView.swift` | Layout, styling, directed-opponent gating |
| `Views/Challenge/ChallengeFlowView.swift` | `isDirectedOpponent` flag; submit payload enforcement |
| `Services/MatchmakingService.swift` | Comments only unless copy lives in enum |

### Risks

| Risk | Mitigation |
|------|------------|
| User confusion Balanced vs Raw on direct | Clear copy in dock + difficulty section |
| Submit sends wrong difficulty | Unit-style guard in `submitChallenge()` forcing `.fair` for directed Raw |

### Acceptance criteria

- [x] Default picker on Difficulty = Raw.
- [x] Directed + Raw: cannot select Easy/Hard; Fair shown; submit uses Fair.
- [x] Quick + Raw: full difficulty picker works.
- [x] Balanced: no difficulty row (existing behavior).
- [x] VS card matches app neon theme more strongly than today.

### As-built (Slice 4)

| File | Change |
|------|--------|
| `Views/Challenge/Steps/ReviewStepView.swift` | “Battle difficulty” section; cyan/orange VS card with liquid glass + flame; custom neon segment controls; directed Easy/Hard disabled with footnote |
| `Views/Challenge/ChallengeFlowView.swift` | Default scoring `.raw`; `isDirectedOpponent`; `resolvedSubmitDifficulty()` forces `.fair` on direct + Raw |
| `Services/MatchmakingService.swift` | `MatchDifficultyPreference.directedOpponentFootnote` |

**How to test**

1. Open BATTLE → complete Opponent + Duration → Difficulty: scoring defaults to **Raw Battle**; VS card shows cyan “You” / orange opponent with gradient border.
2. **Quick Battle path:** Raw selected → Easy / Fair / Hard all tappable; pick Hard → Send works.
3. **Direct opponent path** (pick from list or Rematch): Raw selected → Easy/Hard greyed out, Fair locked; footnote about random-only difficulty; Send still succeeds.
4. Switch to **Balanced Battle** → difficulty row hidden; Send uses `difficulty: nil`.
5. Direct + Raw + Send: backend payload uses Fair regardless of any stale UI state (`resolvedSubmitDifficulty` guard).

---

## Slice 5 — Documentation & tracker

**Status:** Implemented — pending review.

**Goal:** Keep repo docs honest for future agents.

### Files likely touched

| File | Change |
|------|--------|
| `FitUp/docs/slice-tracker.md` | Append entries per completed slice |
| `FitUp/docs/fitup-build-slices.md` | Optional `# As-built` note under Slice 4 pointing here |
| `FitUp/docs/fitup-docs-pack.md` | Update challenge interaction map (3 steps) |

### Acceptance criteria

- [x] Tracker lists slices 1–4 with files changed.
- [x] This plan cross-linked from tracker or build-slices.

### As-built (Slice 5)

| File | Change |
|------|--------|
| `FitUp/docs/slice-tracker.md` | **Challenge flow redesign — slices 1A through 4** entry with per-slice files |
| `FitUp/docs/fitup-build-slices.md` | `# As-built — Challenge flow redesign (2026-05)` under original Slice 4 |
| `FitUp/docs/fitup-docs-pack.md` | Challenge flow overview, interaction map, matchmaking copy → 3-step flow |
| `FitUp/docs/challenge-flow-redesign-slices.md` | Slice 5 status (this section) |

---

## Entry points to verify (regression checklist)

After all slices, manually verify launches from:

| Source | Expected first screen |
|--------|------------------------|
| FloatingTabBar BATTLE | Opponent |
| `FitUpAppChrome` + button | Opponent |
| Home “New Battle” | Opponent |
| Leaderboard row | Opponent (prefill) or Duration if we later skip — **Slice 1:** prefilled → **Duration** per decision #2 |
| Friend “Compete?” / celebration | Duration (prefilled) |
| Match Details **Rematch** | Duration (prefilled) |
| Challenge rival strip (in-flow) | Sets opponent; advance to Duration |

**Note:** Decision #2 says prefilled/rematch **starts at Duration**. Leaderboard/friend flows that today use `.prefilled` must use the same `applyLaunchStepIfNeeded` path (start step 1).

---

## Testing notes

- **Simulator:** Full flow × Quick Battle, direct opponent, Rematch.
- **Slot limit:** Free tier blocked at entry still shows paywall, not partial flow.
- **Reduce Motion:** Sent screen manual only.
- **Analytics:** Optional — add `challenge_step_viewed` properties for new step names (out of scope unless requested).

---

## Deferred (post-MVP polish)

- Delete or archive `SportStepView.swift`.
- Rename `FormatStepView` → `DurationStepView` on disk (Slice 3 optional).
- Leaderboard: intermediate competitor sheet (if ever desired) — **not** in this plan.
- Calories battles return — requires Sport step revival + backend.
- Haptic on duration card press.
- Custom dissolve transition on fullScreenCover dismiss (Slice 1 uses opacity on sent content only).

---

## Implementation order (reminder)

1. **Review this file** (you are here).
2. **Slice 1A** — sent + Home landing *(implemented; review before 1B)*.
3. **Slice 1B** when approved — flow + Rematch.
4. Slices 2 → 4 in order (or batch 2+3 after 1B stabilizes).
5. Slice 5 after code complete.

**Challenge flow redesign complete (slices 1A–5).** Original build Slice 4 spec remains historical; see as-built notes in `fitup-build-slices.md` and `challenge-flow-redesign-slices.md`.
