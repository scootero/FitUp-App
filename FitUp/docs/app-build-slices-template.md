# [APP_NAME] — Build Slices (template)

*Implementation guide. Reference `[PATH_TO_APP_BUILDER_DOC]` and `[MOCKUP_PATH]` for all decisions.*

*Build in order unless `[SLICE_DEPENDENCY_NOTE]` says otherwise. **Do not** begin a slice until the user explicitly asks for that slice.*

---

## HOW TO USE THIS FILE (for Cursor and humans)

1. **Read `[PATH_TO_APP_BUILDER_DOC]` first** — especially project setup, data model, data flow, domain rules, design tokens, and backend contract.
2. **Read the UI mockup before writing SwiftUI** — open `[MOCKUP_PATH]` under `[MOCKUPS_DIR]`; identify components and tokens that correspond to the slice.
3. **Work slices in numerical order** — each slice may depend on files or infrastructure from earlier slices. If you must skip, document the dependency in `[SLICE_TRACKER_PATH]`.
4. **Do not start the next slice until the user asks** — one slice per explicit request unless the user batches slices.
5. **Wire real data** — follow the **Data flow** matrix in the app builder doc. Do not leave production paths on placeholder data when the integration is in scope for that slice.
6. **After each slice:** **append** a new entry to `[SLICE_TRACKER_PATH]` (see [`slice-tracker-template.md`](slice-tracker-template.md)). Never replace the entire tracker file.
7. **Commit** when the slice meets all acceptance criteria (optional but recommended).
8. **Design tokens only** — colors, radii, spacing, and typography come from `[DESIGN_TOKENS_FILE]`; mockups inform values once, then Swift references tokens.

---

## Strict Cursor execution system

- **Slice gating:** Do not build the next slice until the user explicitly asks. Do not “finish early” by starting the following slice.
- **Docs first:** Read the app builder doc and this slice’s sections before editing code.
- **Mockups before UI:** Read the relevant mockup components (JSX/HTML/CSS) before implementing or changing SwiftUI screens.
- **No mock data in shipped paths** when real backend or device data is in scope for that slice — replace `[MOCK_DATA]` with actual sources per Data flow.
- **Additive changes:** Prefer adding files and small edits; do not refactor unrelated modules.
- **Architecture boundaries:** Views do not call the backend client or device APIs directly — use repositories/services as defined in the app builder doc.
- **Ambiguity stop:** If requirements conflict, or the change touches auth, payments, privacy, or authoritative state transitions, **stop and ask** before coding.
- **Tracker:** Append to `[SLICE_TRACKER_PATH]` after the slice is verified.

---

## Required slice format (author one block per slice)

Copy this skeleton for **Slice N** and fill in bracketed fields.

### Slice [N] — [SLICE_TITLE]

**Goal:** [ONE_LINE_GOAL]

**Mockup / UI reference (read first):** `[MOCKUP_COMPONENTS_OR_SECTIONS]`

**Files to create:**

- `[PATH/NEW_FILE.swift]`
- (list)

**Files to modify:**

- `[PATH/EXISTING_FILE.swift]`
- (list)

**Deliverables:**

- [Bullet list of user-visible and technical outcomes]

**Data wiring:**

- **Reads:** `[SOURCE_TABLE_OR_SERVICE]`
- **Writes:** `[DESTINATION_TABLE_OR_SERVICE]`
- **Realtime / subscriptions:** `[CHANNELS_IF_ANY]`

**Backend work (if any):**

- SQL / migrations: `[DESCRIPTION_OR_FILE]`
- Edge Functions: `[NAME]`
- Cron / triggers: `[NAME]`

**Acceptance criteria:**

- [ ] `[TESTABLE_CRITERION_1]`
- [ ] `[TESTABLE_CRITERION_2]`

**Verification steps:**

- **Build:** `[XCODEBUILD_OR_XCODE_ACTION]`
- **Manual test:** `[STEPS]`
- **Expected DB / backend state:** `[WHAT_TO_VERIFY]`

---

## Slice 0 — Foundation, design system, and environment

**Goal:** Xcode project ready for feature work; `[DESIGN_TOKENS_FILE]` exists; shared shell components stubbed or implemented; backend smoke test possible; Cursor rules on disk.

**Important:** If an Xcode project **already exists**, do **not** create a new project. Work inside `[SWIFT_SOURCE_ROOT]`. If **greenfield**, create the project per app builder doc **Project setup** and then continue.

### Part A — Mockup → SwiftUI mapping (read before feature code)

**UI reference:** Read the global token object / theme section in `[MOCKUP_PATH]` first.

**Translation approach (example pattern — replace with your app’s tokens):**

| Mockup pattern | SwiftUI equivalent |
|----------------|-------------------|
| `[TOKEN_OR_STYLE]` | `[DESIGN_TOKENS_FILE]` — `Color` / `CGFloat` / `Font` |
| `[GLASS_OR_CARD_STYLE]` | `ViewModifier` or reusable container |
| `[BACKGROUND_STYLE]` | Root background view behind screens |

**Rule:** One place for design constants; feature views consume tokens only.

### Part B — Deliverables (checklist — customize)

- [ ] Folder / group layout under `[SWIFT_SOURCE_ROOT]` matches app builder doc
- [ ] `[DESIGN_TOKENS_FILE]` — colors, radii, typography helpers, shared modifiers
- [ ] `[MOCKUPS_DIR]` contains `[MOCKUP_PATH]` (or linked path documented)
- [ ] Backend client configured with env-based keys (`[SECRETS_PATTERN]`)
- [ ] `.cursor/rules.md` populated from app builder doc **Cursor Rules** section
- [ ] Optional: SPM packages listed in app builder doc installed
- [ ] Smoke test: `[SMOKE_TEST_DESCRIPTION]` (e.g. auth ping, health DB query)

**Supabase / backend (manual or scripted as per team):**

- `[BASELINE_MIGRATIONS_OR_SQL]`
- `[RLS_AND_AUTH_PROVIDER_STEPS]`

**Acceptance criteria (template — tighten per project):**

- [ ] App builds for Simulator with no errors
- [ ] Design tokens compile; at least one preview uses tokens
- [ ] No secrets committed; example secrets file documents required keys
- [ ] `.cursor/rules.md` present and points at correct doc paths
- [ ] Slice tracker initialized: copy [`slice-tracker-template.md`](slice-tracker-template.md) → `[SLICE_TRACKER_PATH]` and add Slice 0 row

---

## Slice [1] — [SLICE_TITLE]

**Goal:** [GOAL]

**Mockup / UI reference:** [COMPONENTS]

**Files to create:** [LIST]

**Files to modify:** [LIST]

**Data wiring:** [READS / WRITES / REALTIME]

**Backend work:** [OR “None”]

**Acceptance criteria:**

- [ ] [CRITERION]

**Verification steps:** [BUILD / MANUAL / DB]

---

## Slice [2] — [SLICE_TITLE]

*(Repeat the same structure. Add as many slices as needed.)*

---

## Cursor Execution Template (copy into every Cursor session)

Fill bracketed sections from the active slice.

```text
Context:
  Slice: [Number and title — e.g. "Slice 3 — Home shell"]
  Mockup components to read first: [From mockup file]
  Files to create: [From slice]
  Files to modify: [From slice]
  Current app state: [What already works]

  Reference docs:
    Primary: [PATH_TO_APP_BUILDER_DOC]
    UI source: [MOCKUP_PATH]
    Build slices: [PATH_TO_APP_BUILD_SLICES_DOC]
    Key sections: [e.g. "Data flow, Section 10 Interaction Map"]

Goal:
  [Slice goal line verbatim]

Project rules:
  Repo root: [REPO_ROOT]
  Xcode: [XCODEPROJ_PATH]
  Swift root: [SWIFT_SOURCE_ROOT]
  Do not create a duplicate Xcode project unless greenfield and explicitly requested.

Design rule:
  Read listed mockup components before SwiftUI.
  All design values from [DESIGN_TOKENS_FILE] — no ad-hoc hex or radii.
  Replace [MOCK_DATA] with real sources per Data flow.

Constraints:
  - Do not refactor unrelated code
  - Additive changes unless asked
  - No mock data for production paths when integration is in scope
  - Respect repository / service boundaries from app builder doc
  - Stop and ask if ambiguity touches auth, money, privacy, or state ownership

Implementation:
  Step 1: [DELIVERABLE]
  Step 2: [DELIVERABLE]
  Step 3: [...]

Backend work (if any):
  [Migrations, Edge Functions, cron]

Verification:
  Build: [COMMAND_OR_ACTION]
  Manual test: [STEPS]
  Database / backend: [EXPECTED_STATE]
  Acceptance criteria: [PASTE CHECKLIST]
```

---

## After each slice

1. Run verification steps until all acceptance criteria pass.
2. **Append** a dated entry to `[SLICE_TRACKER_PATH]` using the format in [`slice-tracker-template.md`](slice-tracker-template.md) (status, files, notes, issues, decisions).
3. Update `[PATH_TO_APP_BUILDER_DOC]` Decisions Log if this slice locked or changed a product decision.

---

*End of build slices template*
