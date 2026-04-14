# [APP_NAME] — App Builder Doc (template)

*Single source of truth for what the system IS. Update the Decisions Log after every meaningful session.*

*Last updated: [DATE_YYYY_MM_DD]*

---

## How to use these docs

Two files make up the complete spec for building this iOS app with Cursor:

| Doc | Role |
|-----|------|
| `[PATH_TO_APP_BUILDER_DOC]` (this file) | Product, architecture, data model, design system, backend contract |
| `[PATH_TO_APP_BUILD_SLICES_DOC]` | How to **build** it slice by slice — follow that file’s execution rules |

**Slice progress:** Copy [`slice-tracker-template.md`](slice-tracker-template.md) to `[SLICE_TRACKER_PATH]` (commonly `docs/slice-tracker.md`) for this project. **Append** an entry after each completed slice — do not replace the whole file.

**UI source of truth:** `[MOCKUP_PATH]` (e.g. `docs/mockups/[MOCKUP_FILENAME].jsx` or `.html`). See **Mockup system** below. Cursor must read the relevant mockup components before implementing UI. Sections marked `[MOCK_DATA]` in mockups must be replaced with real data per **Data flow**.

**Priority for implementers:** State machine (if any), data model, domain rules, design system, interaction map, and **Cursor Rules** snippet at the end of this doc.

Items marked **`[CONFIRM]`** need a final answer before the relevant slice is built. Everything else is treated as locked once filled in.

---

## Project setup

Use this section when starting or onboarding a new machine. Adjust paths to match `[REPO_ROOT]`.

### Git

- **Repo root:** `[REPO_ROOT]` — open this folder in Cursor (not a random subdirectory unless your team standard says otherwise).
- **Branches:** `[GIT_BRANCH_STRATEGY]` (e.g. `main` for release, short-lived `feature/*`).
- **Secrets:** Never commit API keys or `Secrets.xcconfig` (or equivalent). Keep a committed **`[SECRETS_EXAMPLE_FILE]`** (e.g. `Secrets.example.xcconfig`) and document the copy step locally → `[SECRETS_LOCAL_FILE]`.
- **Optional:** Commit after each slice that passes acceptance criteria (see build-slices doc).

### Supabase CLI (if using Supabase)

From `[REPO_ROOT]` (or `[SUPABASE_DIR]` if the CLI project lives in a subfolder):

1. **`supabase init`** — creates `supabase/config.toml` and folder structure for functions and migrations.
2. **`supabase link --project-ref [PROJECT_REF]`** — links the local project to the hosted Supabase project (requires login).
3. **`supabase db pull`** — **baseline / introspection**: pulls the **current remote** schema into a new migration (or migration history, depending on CLI version). Use it to align local migration history with an already-provisioned database. It is **not** a substitute for intentional schema design: you still author tables, RLS, and policies deliberately; `db pull` helps sync when the remote was created manually or drifted.

**Workflow note:** Prefer versioned SQL in `supabase/migrations/` (or `supabase/sql/` per team convention) for reproducible environments. Document any one-off dashboard steps in your setup guide.

### Environment and config

| Item | Description |
|------|-------------|
| `[SUPABASE_URL]` | Public project URL — inject via build config, not hardcoded in source |
| `[SUPABASE_ANON_KEY]` | Anon key — same |
| Other keys | `[OTHER_ENV_VARS]` (e.g. third-party SDK keys) |
| Pattern | Xcode: `[xcconfig pattern]`; never check in real values |

### Xcode project

| Item | Value |
|------|--------|
| Project file | `[XCODEPROJ_PATH]` |
| App target | `[APP_TARGET_NAME]` |
| Swift sources root | `[SWIFT_SOURCE_ROOT]` |
| Minimum iOS | `[MIN_IOS]` |
| Swift / toolchain | `[SWIFT_VERSION]` |

**Rules:**

- Every new Swift file must have correct **target membership** for `[APP_TARGET_NAME]`.
- If the project uses **SPM**, list dependencies in `[PATH_TO_APP_BUILD_SLICES_DOC]` Slice 0 or here: `[SPM_PACKAGES]`.

### Apple Developer and capabilities

| Item | Value |
|------|--------|
| Bundle ID | `[BUNDLE_ID]` |
| Team | `[APPLE_TEAM_ID]` |

**Capabilities (enable only what this app needs):**

- [ ] Push Notifications (`[APNS_ENVIRONMENT]`: development vs production)
- [ ] Sign in with Apple
- [ ] App Groups (if `[WIDGET_OR_APP_GROUP_ID]`)
- [ ] Background modes: `[BACKGROUND_MODES_IF_ANY]`
- [ ] HealthKit (if `[DEVICE_HEALTH_OR_SENSORS]`)
- [ ] Other: `[OTHER_CAPABILITIES]`

**Sign in with Apple + Supabase (checklist):**

1. In Apple Developer: App ID with Sign in with Apple enabled; Service ID (if using web flow); key for JWT.
2. In Supabase Dashboard: Auth → Providers → Apple — paste Service ID, secret key, redirect URLs per Supabase docs.
3. In Xcode: Sign in with Apple capability on the app target; correct bundle ID matches Supabase redirect configuration.

### Mockup system

- **Location:** Store UI reference files under `[MOCKUPS_DIR]` (e.g. `docs/mockups/`).
- **Formats:** JSX/React-style or HTML/CSS prototypes are acceptable; pick one primary file: `[MOCKUP_PATH]`.
- **Rule:** The mockup is the **visual** source of truth for layout, hierarchy, spacing relationships, and component names. **Do not** hardcode hex colors, radii, or font sizes in SwiftUI except inside a single design token layer: `[DESIGN_TOKENS_FILE]`.
- **Mapping:** Every reusable mockup component (e.g. `[MOCKUP_COMPONENT_NAME]`) maps to a SwiftUI view (e.g. `[SWIFTUI_VIEW_NAME]`). List them in **Design Tokens** and **Interaction Map** as you implement.
- **`[MOCK_DATA]`:** Replace with real data per **Data flow** — never ship permanent fake data for production paths when integration is in scope.

---

## Backend planning

Use this section to define how the backend supports the app **before** or **in parallel** with client slices.

### Tables

For each table, capture:

| Table | Purpose | RLS / access notes |
|-------|---------|---------------------|
| `[TABLE_NAME]` | `[PURPOSE]` | `[RLS_NOTE]` |

### Relationships

Describe foreign keys and cardinality:

- `[PARENT_TABLE]` **1 — N** `[CHILD_TABLE]` via `[FK_COLUMN]`
- (Add rows or a small diagram)

```text
[ENTITY_A] ──< [ENTITY_B] ──< [ENTITY_C]
```

### Edge Functions

| Function name | Trigger | Auth | Responsibility | Idempotency note |
|---------------|---------|------|----------------|------------------|
| `[EDGE_FUNCTION_NAME]` | `[HTTP_OR_DB_TRIGGER]` | `[JWT_OR_SERVICE_ROLE]` | `[WHAT_IT_DOES]` | `[SAFE_TO_RETRY]` |

### Cron jobs (e.g. pg_cron)

| Job name | Schedule | Calls | Purpose |
|----------|----------|-------|---------|
| `[CRON_JOB_NAME]` | `[CRON_EXPRESSION]` | `[RPC_OR_EDGE_FN]` | `[PURPOSE]` |

### Schema definition template

Use as a starting point for new tables (adjust types and constraints):

```sql
CREATE TABLE [TABLE_NAME] (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  -- [FK_COLUMN] uuid REFERENCES [OTHER_TABLE](id) ON DELETE [CASCADE|SET NULL],
  [COLUMN_NAME] [TYPE] NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now()
);

-- RLS: [ENABLE_RLS_AND_POLICY_SUMMARY]
```

---

## Data flow

Document **where** each piece of data lives. This prevents “mock UI” drift.

### Matrix

| Data / concept | Device / local | Backend | Computed locally |
|----------------|----------------|---------|------------------|
| `[CONCEPT_1]` | `[DEVICE_OR_LOCAL_SOURCE]` | `[TABLE_OR_ENDPOINT]` | `[PURE_FUNCTION_OR_CACHE]` |
| `[CONCEPT_2]` | | | |

**Definitions:**

- **Device / local:** On-device APIs (e.g. sensors, keychain, file storage, calendar), or `UserDefaults` / SwiftData for client-only prefs.
- **Backend:** Postgres tables, Storage buckets, Edge Functions — source of truth for shared or authoritative state.
- **Computed locally:** Derived in Swift (pure functions, view models) — never duplicated as authoritative on server unless you explicitly want both.

---

## 1. Product Overview

[APP_NAME] is a [APP_TYPE] app. [ELEVATOR_PITCH]

**Core loop:** `[CORE_LOOP_STEPS]`

| Field | Value |
|-------|--------|
| Platform | iOS only, SwiftUI, minimum iOS [MIN_IOS] |
| Backend | [BACKEND_STACK] (e.g. Supabase: Postgres, Edge Functions, Realtime) |
| Local data / device | [DEVICE_INTEGRATION_SUMMARY] |
| Subscriptions | [MONETIZATION_ENGINE_OR_NONE] |
| Notifications | [PUSH_AND_OR_LIVE_ACTIVITIES] |
| UI reference | `[MOCKUP_PATH]` |

---

## 2. V1 Scope

### In scope

- `[FEATURE_NAME]`
- (Add bullets)

### Out of scope / deferred

- `[FEATURE_NAME]` — [DEFERRED_TO_VERSION_OR_NEVER]

---

## 3. Project Structure

**Greenfield vs existing project (pick one):**

- [ ] **Existing Xcode project** — Do not restructure unnecessarily. Add files under `[SWIFT_SOURCE_ROOT]` only.
- [ ] **New project** — Create with `[TEMPLATE_OR_STEPS]` and then fix paths below.

**Repo root:** `[REPO_ROOT]`

**Xcode project:** `[XCODEPROJ_PATH]`

**Recommended layout (adapt names):**

```text
[REPO_ROOT]/
├── .cursor/
│   └── rules.md
├── docs/
│   ├── app-builder-doc-template.md   (or your filled copy)
│   ├── app-build-slices-template.md
│   ├── slice-tracker.md
│   └── mockups/
│       └── [MOCKUP_FILENAME]
└── [IOS_APP_FOLDER]/
    ├── [PROJECT_NAME].xcodeproj
    └── [APP_SOURCE_FOLDER]/
        ├── [APP_ENTRY_SWIFT]
        ├── [ROOT_VIEW_SWIFT]
        └── Assets.xcassets
```

**Adding files:** New Swift files go under `[SWIFT_SOURCE_ROOT]` and match Xcode groups / folders per team convention.

**Suggested groups (optional):**

```text
[SWIFT_SOURCE_ROOT]/
├── App/
├── Design/              ← [DESIGN_TOKENS_FILE]
├── Views/
│   ├── [FEATURE_AREA]/
│   └── Shared/
├── ViewModels/
├── Services/
├── Repositories/
├── Models/
└── Utilities/
```

---

## 4. Auth and Onboarding

### Auth options

- `[AUTH_PROVIDER_PRIMARY]` (e.g. Sign in with Apple)
- `[AUTH_PROVIDER_SECONDARY]` (e.g. email + password via Supabase Auth)

**Backend auth setup:**

- `[AUTH_PROVIDER_CONFIG_STEPS]`

### First-time onboarding flow

```text
1. [STEP]
2. [STEP]
3. ...
```

**Completion:** Stored in `[ONBOARDING_COMPLETION_STORAGE]` (e.g. `UserDefaults` key `[KEY]`).

**Session restore:** On launch, `[SESSION_CHECK_LOGIC]` → route to `[SCREEN_IF_VALID]` or `[SCREEN_IF_INVALID]`.

---

## 5. Navigation and Screen Flow

### Shell navigation

[Describe tab bar, nav stack, split view, or custom shell — e.g. floating bar, hidden on subflows.]

**Key layout constants** (must map to `[DESIGN_TOKENS_FILE]`, not hardcoded in random views):

| Constant | Value |
|----------|--------|
| `[LAYOUT_TOKEN_NAME]` | `[VALUE]` |

### Navigation map

```text
App Launch
  └── [ROOT]
        ├── [SCREEN_A]
        └── [SCREEN_B]
              └── [SUBSCREEN]
```

### Deep links / notification entry

| Event | Opens |
|-------|--------|
| `[NOTIFICATION_OR_URL_TYPE]` | `[DESTINATION_SCREEN]` |

---

## 6. State machine (if applicable)

If **authoritative** lifecycle exists for `[ENTITY_NAME]` (e.g. orders, matches, jobs), define it here. **Server vs client ownership** must be explicit.

### States

| State | Meaning |
|-------|---------|
| `[STATE_NAME]` | `[DESCRIPTION]` |

### Transition map

```text
[STATE_A] ──[EVENT]──► [STATE_B]
```

### Transition rules

| Transition | Trigger | Owner (client / server) | Side effects |
|------------|---------|-------------------------|--------------|
| `[FROM]` → `[TO]` | `[TRIGGER]` | `[OWNER]` | `[NOTIFICATIONS_OR_DB]` |

---

## 7. Data Model

### Table inventory

| Table | Purpose |
|-------|---------|
| `[TABLE_NAME]` | `[PURPOSE]` |

### Key schemas

Paste or link migrations. For each critical table, include `CREATE TABLE` or point to `[MIGRATION_FILE_PATH]`.

#### `[TABLE_NAME]`

```sql
-- [SCHEMA_OR_LINK]
```

### Persist vs derive

| Data | Where | Rule |
|------|-------|------|
| `[FIELD_OR_CONCEPT]` | `[TABLE_OR_NOWHERE]` | `[STORE_OR_DERIVE_RULE]` |

---

## 8. Domain rules (scoring, cutoffs, business logic)

**[DOMAIN_RULES_SECTION_TITLE]**

- **Principles:** `[PRINCIPLE_1]`, `[PRINCIPLE_2]`
- **Formulas:** `[FORMULA_OR_REFERENCE]`
- **Cutoffs / timezones:** `[CUTOFF_RULES]`
- **Edge cases:** `[EDGE_CASES]`

---

## 9. Design System

**Source of truth:** `[MOCKUP_PATH]` — token object / CSS variables / theme section.

**Swift:** All values live in `[DESIGN_TOKENS_FILE]` under `Design/` (or your convention). **No hardcoded hex, sizes, or radii elsewhere.**

### Colors

| Token | Hex / value | Semantic use |
|-------|-------------|--------------|
| `[TOKEN_NAME]` | `[VALUE]` | `[USE]` |

### Components (mockup → SwiftUI)

| Mockup component | SwiftUI | Notes |
|------------------|---------|-------|
| `[MOCKUP_COMPONENT]` | `[SWIFTUI_VIEW]` | `[NOTES]` |

### Motion / transitions

`[TRANSITION_SPEC]` — map to SwiftUI modifiers in one place.

---

## 10. Interaction Map

For each major screen, capture:

| Screen | Tap target | Action | Navigates to | Backend write |
|--------|------------|--------|--------------|----------------|
| `[SCREEN_NAME]` | `[TARGET]` | `[ACTION]` | `[DEST]` | `[WRITE_OR_NONE]` |

---

## 11. Device integration (optional appendix)

**[DEVICE_INTEGRATION_SECTION_TITLE]**

**API:** `[DEVICE_API_NAME]` (or third-party SDK).

**Types / permissions requested:**

| Type / permission | Used for |
|-------------------|----------|
| `[TYPE]` | `[PURPOSE]` |

**Sync strategy:** `[WHEN_SYNC_RUNS]` — **do not** promise fixed background intervals if the OS does not guarantee them.

---

## 12. Notifications (optional appendix)

**Channels:** `[APNS_AND_OR_LOCAL]` | `[LIVE_ACTIVITIES_OR_WIDGETS]`

### Event types

| Event | Recipient | Message |
|-------|-----------|---------|
| `[EVENT_TYPE]` | `[WHO]` | `[COPY]` |

**Payload shape (example):**

```json
{
  "[KEY]": "[TYPE]",
  "deep_link_target": "[TARGET]"
}
```

---

## 13. Monetization (optional appendix)

| Feature | Free | Paid |
|---------|------|------|
| `[FEATURE]` | `[LIMIT]` | `[LIMIT]` |

**Paywall timing:** `[WHEN_PAYWALL_APPEARS]`

**Engine:** `[REVENUECAT_OR_STOREKIT2_OR_OTHER]`

---

## 14. Backend contract (Edge Functions and jobs)

| Function / job | Trigger | Responsibility | Idempotency |
|----------------|---------|----------------|-------------|
| `[NAME]` | `[TRIGGER]` | `[RESPONSIBILITY]` | `[NOTE]` |

**Auth expectations:** `[JWT_VALIDATION_RULES]`

**Realtime subscriptions (if any):**

- `[TABLE_OR_CHANNEL]` — `[WHAT_CLIENT_LISTENS_FOR]`

---

## 15. Logging

### Categories

`[CATEGORY_1]` · `[CATEGORY_2]` · `[CATEGORY_3]`

### Requirements

- `[LOGGING_RULES]`
- **Dev-only UI:** `[DEV_LOG_VIEWER_RULES]`

---

## 16. Architecture

### Layers

| Layer | Responsibility |
|-------|----------------|
| SwiftUI Views | `[RESPONSIBILITY]` |
| ViewModels | `[RESPONSIBILITY]` |
| Services | `[RESPONSIBILITY]` |
| Repositories | `[RESPONSIBILITY]` |
| Backend | `[RESPONSIBILITY]` |
| External SDKs | `[RESPONSIBILITY]` |

### Architecture rules (non-negotiable)

- Views **never** query `[BACKEND_CLIENT_DIRECTLY]` directly — use `[REPOSITORY_OR_SERVICE]`.
- Views **never** call `[DEVICE_API]` directly — use `[DEVICE_SERVICE_NAME]`.
- `[STATE_TRANSITION_OWNER]` owns `[ENTITY]` transitions.
- `[PURE_LOGIC_RULES]`

---

## 17. Cursor Rules (paste into `.cursor/rules.md`)

*Save as `[PATH_TO_CURSOR_RULES]` (or merge into your existing rules). Replace bracketed placeholders.*

```markdown
# [APP_NAME] — Cursor Rules

## Repo and project
- Repo root: [REPO_ROOT]
- Xcode project: [XCODEPROJ_PATH]
- Swift sources: [SWIFT_SOURCE_ROOT]
- Do NOT restructure the Xcode project without explicit permission
- New files must target [APP_TARGET_NAME]

## Primary references
1. [PATH_TO_APP_BUILDER_DOC] — architecture, data model, domain rules
2. [MOCKUP_PATH] — visual source of truth; read relevant components before UI
3. [PATH_TO_APP_BUILD_SLICES_DOC] — slice order and acceptance criteria

## Architecture rules
- [ARCHITECTURE_RULES_BULLETS]

## Design rules
- All design values from [DESIGN_TOKENS_FILE] — no stray hex or radii in feature views
- [DESIGN_RULES_BULLETS]

## Code rules
- Do not refactor files unrelated to the current slice
- Additive changes unless asked to remove code
- SwiftUI previews must compile
- If a change affects [AUTH_OR_PRIVACY_OR_MONEY_OR_STATE], STOP and explain before coding

## Naming
- SQL tables: [TABLE_NAMING_CONVENTION]
- Swift types: [SWIFT_TYPE_CONVENTION]
- Swift properties: [SWIFT_PROPERTY_CONVENTION]

## Ambiguity rule
If a change could affect [DOMAIN], [DATA_INTEGRITY], or [DESIGN_SYSTEM], stop and ask.
```

---

## 18. Decisions Log

### Confirmed and locked

| Decision | Value |
|----------|--------|
| `[DECISION_TOPIC]` | `[VALUE]` |

### Open items — `[CONFIRM]`

| Question | Affects |
|----------|---------|
| `[QUESTION]` | `[SLICE_OR_AREA]` |

---

*End of app builder doc — keep Section 18 current as decisions land.*
