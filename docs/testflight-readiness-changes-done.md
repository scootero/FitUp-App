# TestFlight Readiness — Changes Done

> **This file is a changelog, not your checklist.**  
> **Start here for what to do next:** [testflight-README.md](testflight-README.md)  
> Runbook: [external compliance](testflight-external-compliance-checklist.md) · Push: [push verification](testflight-push-verification.md) · Xcode/portal: [xcode and apple developer](testflight-xcode-and-apple-developer.md)

Agent log of code and doc changes for the TestFlight readiness pass (Slices A–C implementation, D–E documentation only).

**Date:** 2026-05-28  
**Scope:** iOS app + `docs/` only. No Supabase, migrations, Edge Functions, RevenueCat, `FITUP_TESTFLIGHT_BYPASS`, Privacy row, Connected Apps, or Account Deletion changes.

---

## Slice A — HealthKit plist cleanup

**File:** `FitUp/FitUp/FitUp.xcodeproj/project.pbxproj` (Debug + Release app target)

| Setting | Before | After |
|---------|--------|-------|
| `INFOPLIST_KEY_NSHealthClinicalHealthRecordsShareUsageDescription` | `"FitUp reads your steps, active calories, and resting heart rate to score matches and show your health stats. Data is never entered manually."` | **Removed** (no clinical HealthKit API in app) |
| `INFOPLIST_KEY_NSHealthUpdateUsageDescription` | Same string as above | **Removed** (app only reads HealthKit; `toShare: []` in `HealthKitService`) |
| `INFOPLIST_KEY_NSHealthShareUsageDescription` | `"FitUp reads your steps, active calories, and resting heart rate to score matches and show your health stats. Data is never entered manually."` | `"FitUp reads your steps, active calories, and resting heart rate from Apple Health to score 1v1 battles and show your stats. This data is not used for advertising and is never entered manually."` |

**Not changed:** `HealthKitService.requestAuthorization()`, entitlements, HealthKit read types.

---

## Slice B — Reviewer-facing polish

### `FitUp/FitUp/FitUp/Views/Profile/PeerProfileView.swift`

| Location | Before | After |
|----------|--------|-------|
| Peer profile body | Included `comingSoonCard` below message button | Removed `comingSoonCard` from layout |
| `comingSoonCard` view | `"Competition history — coming soon."` | **Deleted** entire view |

### `FitUp/FitUp/FitUp/Views/Profile/HealthDataBreakdownView.swift`

| Location | Before | After |
|----------|--------|-------|
| File header comment | `…per-source attribution (debug).` | `…per-source attribution.` |
| Debug `Section` (sample counts, timezones) | Always visible in Release | Wrapped in `#if DEBUG` only |

### `FitUp/FitUp/FitUp/Views/Profile/SettingsGroupView.swift`

| Location | Before | After |
|----------|--------|-------|
| `#Preview` ACCOUNT group | Notifications + dead Privacy chevron | Notifications only (removed stale Privacy preview row) |

---

## Slice C — No-opponent / matchmaking clarity (copy only)

### `FitUp/FitUp/FitUp/Views/Onboarding/FindFirstMatchView.swift`

| Location | Before | After |
|----------|--------|-------|
| Intro paragraph | `"We use your recent activity to match you with a fair first opponent."` | `"We use your recent activity to match you with another FitUp player at a similar level."` |
| New paragraph | *(none)* | `"FitUp is 1v1—you need another player in the queue. Turn on notifications so we can alert you when you're matched. For TestFlight, two accounts or devices make testing much easier."` |

### `FitUp/FitUp/FitUp/ViewModels/OnboardingViewModel.swift`

| Location | Before | After |
|----------|--------|-------|
| `submitFindOpponent` success `statusMessage` | `"We'll notify you when your match is found."` | `"Searching for another player—we'll notify you when you're matched."` |

### `FitUp/FitUp/FitUp/Views/Home/Sections/SearchingSection.swift`

| Location | Before | After |
|----------|--------|-------|
| Card title | `"Searching for random opponent..."` | `"Waiting for another player to join the queue…"` |

### `FitUp/FitUp/FitUp/ViewModels/HomeViewModel.swift`

| Location | Before | After |
|----------|--------|-------|
| `statusStripMessage` `.searching` case | `"Searching for random opponent..."` | `"Waiting for another player…"` |

### `FitUp/FitUp/FitUp/Views/Home/HomeView.swift`

| Location | Before | After |
|----------|--------|-------|
| `zeroState` subtitle | `"Start a battle to compete today."` | `"FitUp battles are 1v1—you need another player. Start a search or challenge someone you know."` |
| `zeroState` tip | *(none)* | `"Tip: New Battle → pick an opponent to send a direct challenge."` |

---

## Slice D — Documentation only (no code/config changes)

**Created:** [`docs/testflight-push-verification.md`](testflight-push-verification.md)

No entitlements, signing, provisioning, APNs, backend push, or app code changed.

---

## Slice E — Documentation only

**Created:** [`docs/testflight-external-compliance-checklist.md`](testflight-external-compliance-checklist.md)

---

## Manual follow-up (outside this pass)

Use the ordered workflow in **[testflight-README.md](testflight-README.md)** instead of duplicating steps here:

1. [Xcode & Apple Developer](testflight-xcode-and-apple-developer.md) — archive & upload  
2. Install TestFlight build; confirm Health prompt text (Slice A)  
3. [Push verification](testflight-push-verification.md)  
4. [External compliance](testflight-external-compliance-checklist.md)  
5. Two accounts: one match or direct challenge  
