After completing each slice, append an entry:

## Slice 0 — Foundation, design system, and mockup-to-SwiftUI mapping
Date: 2026-03-24
Status: Complete
Files created:
- `FitUp/FitUp/Config/Debug.xcconfig`, `Secrets.example.xcconfig`, `Info-Additional.plist`, `FitUp.entitlements`
- `FitUp/FitUp/FitUp/Design/DesignTokens.swift`
- `FitUp/FitUp/FitUp/Views/Shared/AvatarView.swift`, `NeonBadge.swift`, `RingGaugeView.swift`, `DayBarView.swift`, `SectionHeader.swift`, `FloatingTabBar.swift`
- `FitUp/FitUp/FitUp/Services/SupabaseProvider.swift`, `HealthKitService.swift`, `SupabaseSmoke.swift`
- `FitUp/FitUp/FitUp/Utilities/AppLogger.swift`
- `FitUp/docs/supabase-slice0-schema.sql`
- `.cursor/rules.md` (repo root)
Files modified:
- `FitUp/FitUp/FitUp.xcodeproj/project.pbxproj` (SPM: Supabase, RevenueCat; xcconfig base; Info/entitlements paths; project IPHONEOS_DEPLOYMENT_TARGET 18.6)
- `FitUp/FitUp/FitUp/FitUpApp.swift`, `ContentView.swift`
- `.gitignore` (Secrets.xcconfig)
Supabase changes:
- Documented supplemental DDL in `docs/supabase-slice0-schema.sql` (`app_logs`, `user_health_baselines`, `direct_challenges`, `notification_events`, `all_time_bests`). Run in dashboard after Section 7 core tables.
Notes:
- `Info-Additional.plist` and `FitUp.entitlements` live under `Config/` (outside PBXFileSystemSynchronizedRootGroup) so they are not copied as bundle resources.
- Do not use `.gitkeep` inside the synced `FitUp/` folder — Xcode copies them all to `.gitkeep` in the app bundle and fails the build.
- Copy `Config/Secrets.example.xcconfig` → `Config/Secrets.xcconfig` for local keys.

## Slice 2 — Onboarding
Date: 2026-03-26
Status: Complete
Files created:
- `FitUp/FitUp/FitUp/Services/NotificationService.swift`
- `FitUp/FitUp/FitUp/Repositories/MatchSearchRepository.swift`
- `FitUp/FitUp/FitUp/ViewModels/OnboardingViewModel.swift`
- `FitUp/FitUp/FitUp/Views/Onboarding/OnboardingView.swift`, `TutorialCardsView.swift`, `PermissionExplainerView.swift`, `FindFirstMatchView.swift`
Files modified:
- `FitUp/FitUp/FitUp/Services/HealthKitService.swift`
- `FitUp/FitUp/FitUp/ViewModels/SessionStore.swift`
- `FitUp/FitUp/FitUp/ContentView.swift`
Supabase changes:
- No schema changes. Added client write to `match_search_requests` for onboarding first-match flow (`metric_type='steps'`, `duration_days=1`, `start_mode='today'`, optional `creator_baseline`).
Notes:
- Onboarding now follows: Tutorial → Health explainer + prompt → Notification explainer + prompt → Find First Match.
- `HealthKitService` now computes real 7-day step average via `HKStatisticsCollectionQuery`.
- Verified build success with `xcodebuild` (iOS Simulator destination). If insert fails in app, verify RLS permits authenticated user inserts into `match_search_requests` for their own `creator_id`.

## Slice 3 — Home shell and tab navigation
Date: 2026-03-26
Status: Complete
Files created:
- `FitUp/FitUp/FitUp/Repositories/HomeRepository.swift`
- `FitUp/FitUp/FitUp/ViewModels/HomeViewModel.swift`
- `FitUp/FitUp/FitUp/Views/Home/HomeView.swift`
- `FitUp/FitUp/FitUp/Views/Home/Sections/SearchingSection.swift`, `ActiveSection.swift`, `PendingSection.swift`, `DiscoverSection.swift`
- `FitUp/FitUp/FitUp/Views/Home/Cards/MatchCardView.swift`
Files modified:
- `FitUp/FitUp/FitUp/ContentView.swift`
Supabase changes:
- No schema changes. Added Home read/write flows for `match_search_requests`, `matches`, `match_participants`, `match_days`, `match_day_participants`, `direct_challenges`, `profiles`, `leaderboard_entries`, and `metric_snapshots`.
Notes:
- Root app shell now uses the floating tab bar and hides it on match/challenge subscreen seams.
- Home section order is locked to: Searching → Active → Pending → Discover Players.
- Verified build success with `xcodebuild` (iOS Simulator destination).

## Slice 4 — Challenge creation flow
Date: 2026-03-26
Status: Complete
Files created:
- `FitUp/FitUp/FitUp/Views/Challenge/ChallengeFlowView.swift`
- `FitUp/FitUp/FitUp/Views/Challenge/ChallengeSentView.swift`
- `FitUp/FitUp/FitUp/Views/Challenge/Steps/SportStepView.swift`, `FormatStepView.swift`, `OpponentStepView.swift`, `ReviewStepView.swift`
- `FitUp/FitUp/FitUp/Services/MatchmakingService.swift`, `DirectChallengeService.swift`
- `FitUp/FitUp/FitUp/Repositories/MatchRepository.swift`
Files modified:
- `FitUp/FitUp/FitUp/ContentView.swift`
- `FitUp/FitUp/FitUp/Views/Home/HomeView.swift`
Supabase changes:
- No schema changes. Added challenge flow reads/writes for `profiles`, `user_health_baselines`, `leaderboard_entries`, `metric_snapshots`, `match_search_requests`, `matches`, `match_participants`, and `direct_challenges`.
- Quick Match writes `match_search_requests` with `metric_type` (`steps` / `active_calories`), `duration_days` (1/3/5/7), `start_mode='today'`.
- Direct challenge writes `matches` + both `match_participants` rows (sender auto-accepted via `accepted_at`) + `direct_challenges`.
Notes:
- Replaced the slice 4 placeholder full-screen cover with a real 4-step `ChallengeFlowView`.
- Added entry paywall gate at challenge launch (free tier slot limit = 1) with annual plan shown prominently.
- Discover row challenge launch now passes prefilled opponent context into challenge flow.
- Verified build success: `xcodebuild -project "FitUp/FitUp.xcodeproj" -scheme "FitUp" -destination "platform=iOS Simulator,name=iPhone 17" build`.

## Slice 5 — Match Details screen
Date: 2026-03-27
Status: Complete
Files created:
- `FitUp/FitUp/FitUp/Repositories/MatchDetailsRepository.swift`
- `FitUp/FitUp/FitUp/ViewModels/MatchDetailsViewModel.swift`
- `FitUp/FitUp/FitUp/Views/MatchDetails/MatchDetailsView.swift`, `DayBarChartView.swift`, `DayResultsListView.swift`
- `FitUp/FitUp/FitUp/Views/LiveMatch/LiveMatchView.swift` (Slice 5 stub for Watch Live)
Files modified:
- `FitUp/FitUp/FitUp/ContentView.swift`
- `FitUp/FitUp/FitUp/Views/Challenge/ChallengeFlowView.swift`
- `FitUp/FitUp/FitUp/Views/Home/HomeView.swift`
- `FitUp/FitUp/FitUp/Views/Home/Sections/PendingSection.swift`
Supabase changes:
- No schema changes. Added Match Details read flow for `matches`, `match_participants`, `direct_challenges`, `match_days`, and `match_day_participants`.
- Accept action writes `match_participants.accepted_at`; decline action updates `direct_challenges.status = 'declined'` (reusing Home repository actions).
- Added live refresh loop on Match Details for day totals (`match_day_participants`) so values update without manual refresh.
Notes:
- Match Details now supports pending, active, and completed variants and includes Swift Charts day breakdown + results list.
- Rematch now launches Challenge flow prefilled with opponent, sport, and format and jumps to Review when prefill is complete.
- Verified build success: `xcodebuild -project "FitUp/FitUp/FitUp.xcodeproj" -scheme "FitUp" -destination "platform=iOS Simulator,name=iPhone 17" build`.
- New Swift files were picked up by the existing Xcode synchronized root group; no manual `project.pbxproj` target-entry edits were required.

## Slice 6 — Live Match screen
Date: 2026-03-27
Status: Complete
Files created:
- `FitUp/FitUp/FitUp/Repositories/LiveMatchRepository.swift`
- `FitUp/FitUp/FitUp/ViewModels/LiveMatchViewModel.swift`
- `FitUp/FitUp/FitUp/Views/LiveMatch/LiveToastView.swift`
Files modified:
- `FitUp/FitUp/FitUp/Services/HealthKitService.swift`
- `FitUp/FitUp/FitUp/Views/LiveMatch/LiveMatchView.swift`
- `FitUp/FitUp/FitUp/Views/MatchDetails/MatchDetailsView.swift`
Supabase changes:
- No schema changes. Added Live Match bootstrap reads from `matches`, `match_participants`, `match_days`, `match_day_participants`, and `profiles`.
- Added Supabase Realtime subscription to `match_day_participants` filtered by `match_day_id` so opponent totals update live in-session.
Notes:
- Live Match now uses HealthKit foreground reads for your total and Realtime backend updates for opponent total, with lead-change and milestone toasts (2.2s auto-dismiss).
- Pause toggle only pauses local UI bar animation and does not stop Realtime or HealthKit refresh.
- Verified build success: `xcodebuild -project "/Users/scott/Documents/FitUp-App-All/FitUp-App/FitUp/FitUp/FitUp.xcodeproj" -scheme "FitUp" -destination "generic/platform=iOS Simulator" build`.

## Slice [N] — [name]
Date: [date]
Status: Complete
Files created: [list]
Files modified: [list]
Supabase changes: [list any tables/functions touched]
Notes: [anything notable or deferred]
