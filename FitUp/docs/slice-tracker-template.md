# [APP_NAME] — Slice tracker (template)

## How to use this file

1. **Copy** this file to `[SLICE_TRACKER_PATH]` (commonly `docs/slice-tracker.md`) when starting a **new** project — or merge the table below into your existing tracker.
2. After **each** slice is completed and verified, **append** a new section (or update the table row + add detail). **Do not** delete history or replace the entire file unless you intentionally archive to a backup.
3. Keep statuses accurate: `not started` → `in progress` → `complete`.
4. Record **issues** and **decisions** so future sessions (human or Cursor) know why something changed.

---

## Master table (compact view)

| Slice # | Title | Status | Date | Notes | Issues | Decisions |
|---------|-------|--------|------|-------|--------|-----------|
| `[N]` | `[SLICE_TITLE]` | not started / in progress / complete | `[YYYY-MM-DD]` | `[SHORT_NOTE]` | `[ISSUE_OR_DASH]` | `[DECISION_OR_DASH]` |

**Status values:** `not started` · `in progress` · `complete`

---

## Optional per-slice detail (verbose — append after each slice)

Copy the block below after each slice finishes.

### Slice [N] — [SLICE_TITLE]

**Date:** [YYYY-MM-DD]  
**Status:** not started | in progress | complete

**Files created:**

- `[PATH]`

**Files modified:**

- `[PATH]`

**Backend / Supabase changes:**

- `[MIGRATION_OR_FUNCTION_OR_NONE]`

**Verification:**

- `[BUILD_COMMAND_OR_MANUAL_STEPS]`

**Notes:**

- `[WHAT_CHANGED_OR_CONTEXT]`

**Issues:**

- `[OPEN_OR_RESOLVED_ISSUES]`

**Decisions made:**

- `[DECISION_AND_RATIONALE]`

---

## Example entry (replace with real content)

### Slice 0 — Foundation, design system, and environment

**Date:** [YYYY-MM-DD]  
**Status:** complete

**Files created:**

- `[SWIFT_SOURCE_ROOT]/Design/[DESIGN_TOKENS_FILE]`
- `.cursor/rules.md`

**Files modified:**

- `[PATH_TO_APP_ENTRY]`

**Backend / Supabase changes:**

- `[NONE_OR_LIST]`

**Verification:**

- `xcodebuild -project [XCODEPROJ_PATH] -scheme [SCHEME] -destination 'platform=iOS Simulator,name=[DEVICE_NAME]' build`

**Notes:**

- Tokens and mockup path documented in app builder doc.

**Issues:**

- —

**Decisions made:**

- Chose `[DESIGN_TOKEN_APPROACH]` for shared styling.

---

*End of slice tracker template*
