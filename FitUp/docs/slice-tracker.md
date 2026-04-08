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

## Slice 7 — HealthKit sync and live match totals
Date: 2026-03-27
Status: Complete
Files created:
- `FitUp/FitUp/FitUp/Repositories/MetricSnapshotRepository.swift`
- `FitUp/FitUp/FitUp/Repositories/MatchDayRepository.swift`
- `FitUp/FitUp/FitUp/Services/MetricSyncCoordinator.swift`
Files modified:
- `FitUp/FitUp/FitUp/Services/HealthKitService.swift`
- `FitUp/FitUp/FitUp/Repositories/HomeRepository.swift`
- `FitUp/FitUp/FitUp/Repositories/MatchDetailsRepository.swift`
- `FitUp/FitUp/FitUp/ViewModels/MatchDetailsViewModel.swift`
- `FitUp/FitUp/FitUp/ViewModels/LiveMatchViewModel.swift`
- `FitUp/FitUp/FitUp/Views/Home/Cards/MatchCardView.swift`
- `FitUp/FitUp/FitUp/ContentView.swift`
Supabase changes:
- No schema changes. Added client sync pipeline that writes `metric_snapshots`, updates `match_day_participants.metric_total` + `last_updated_at`, and upserts `user_health_baselines` (`rolling_avg_7d_steps`, `rolling_avg_7d_calories`).
- Home and Match Details now subscribe via Supabase Realtime channels instead of local polling loops.
Notes:
- HealthKit sync now runs on app foreground and HK observer wakes via `MetricSyncCoordinator`, including yesterday full-day reads and anomaly logging (`healthkit_sync`) when values exceed thresholds.
- `MatchCardView` today pip now matches slice behavior: 22pt with pulsing glow; non-today pips remain 16pt static.
- `HomeRepository.deriveDayPips` now marks only actual calendar-today rows as `.today`; non-finalized non-today rows render as future/dim.
- Verified build success: `xcodebuild -project "/Users/scott/Documents/FitUp-App-All/FitUp-App/FitUp/FitUp/FitUp.xcodeproj" -scheme "FitUp" -configuration Debug -destination "generic/platform=iOS Simulator" build`.

## Slice 8 — Day finalization and match scoring
Date: 2026-03-29
Status: Complete
Files created:
- `supabase/functions/_shared/http.ts`, `_shared/supabase.ts`
- `supabase/functions/finalize-match-day/index.ts`, `complete-match/index.ts`, `update-leaderboard/index.ts`, `dispatch-notification/index.ts`
- `supabase/sql/slice8-finalization.sql`
- `FitUp/FitUp/FitUp/Repositories/ActivityRepository.swift`
- `FitUp/FitUp/FitUp/ViewModels/ActivityViewModel.swift`
- `FitUp/FitUp/FitUp/Views/Activity/ActivityView.swift`
Files modified:
- `FitUp/FitUp/FitUp/Services/HealthKitService.swift` (calendar-day metric totals for any date/timezone)
- `FitUp/FitUp/FitUp/Repositories/MatchDayRepository.swift` (provisional `match_days`, historical `data_status = confirmed`, skip finalized days for live target)
- `FitUp/FitUp/FitUp/Services/MetricSyncCoordinator.swift` (historical day confirmation + snapshots)
- `FitUp/FitUp/FitUp/ContentView.swift` (Activity tab: completed matches list → Match Details)
Supabase changes:
- Deploy Edge Functions listed above; `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are provided by the platform when using Supabase CLI deploy.
- Run `supabase/sql/slice8-finalization.sql` after storing Vault secrets `fitup_project_url` and `fitup_service_role_key` (see `FitUp/docs/supabase-setup-guide.md` Slice 8 section). Enables `pg_net` + `pg_cron`, trigger `finalize_when_all_confirmed` → `finalize-match-day`, and hourly `day_cutoff_check` job.
Notes:
- Client never writes `finalized_value`; Edge Function `finalize-match-day` copies `metric_total` → `finalized_value`, sets winner/void, calls `update-leaderboard` and `complete-match` when all days finalized; `dispatch-notification` queues `notification_events`.
- Minimal Activity tab lists `matches.state = completed'` with series score from `match_days`; full Activity UI remains Slice 10.
- Verify build: `xcodebuild -project "FitUp/FitUp/FitUp.xcodeproj" -scheme "FitUp" -destination "generic/platform=iOS Simulator" build`.

## Slice 4 backend — matchmaking + activation (Supabase)
Date: 2026-04-02
Status: Complete
Files created:
- `supabase/sql/slice4-matchmaking.sql`
- `supabase/functions/matchmaking-pairing/index.ts`
- `supabase/functions/on-all-accepted/index.ts`
Files modified:
- `FitUp/FitUp/FitUp/Repositories/MatchRepository.swift` (direct challenge `match_participants`: `role`, `joined_via`)
- `FitUp/docs/supabase-setup-guide.md` (Slice 4 deploy + SQL instructions)
- `FitUp/docs/slice-tracker.md` (this entry)
Supabase changes:
- RPCs `matchmaking_pair_atomic`, `activate_match_with_days` (service_role only); triggers on `match_search_requests` INSERT and `match_participants` INSERT/UPDATE of `accepted_at` → Edge Functions via `pg_net` + Vault; drops conflicting `slice9-notifications.sql` triggers if present.
Notes:
- Deploy `matchmaking-pairing` and `on-all-accepted` after Slice 8 Vault secrets; run `slice4-matchmaking.sql` in SQL Editor.
- `MatchRepository` direct challenge inserts now include `role` and `joined_via` for `match_participants`.

## Slice 10 — Activity screen
Date: 2026-04-02
Status: Complete
Files created:
- `FitUp/FitUp/FitUp/Views/Activity/Rows/ActiveMatchRow.swift`
- `FitUp/FitUp/FitUp/Views/Activity/Rows/PastMatchRow.swift`
Files modified:
- `FitUp/FitUp/FitUp/Repositories/HomeRepository.swift` (exposed `loadActiveMatches(for:)` for Activity tab reuse)
- `FitUp/FitUp/FitUp/ViewModels/ActivityViewModel.swift` (active matches + stats + unified reload)
- `FitUp/FitUp/FitUp/Views/Activity/ActivityView.swift` (header, stats row, active/past sections, empty states)
- `FitUp/docs/slice-tracker.md` (this entry)
Supabase changes:
- No schema or Edge Function changes. Slice 10 reuses existing reads from `matches`, `match_participants`, `match_days`, and `match_day_participants` via repository layer.
Notes:
- Activity tab now matches Slice 10 scope: stats row (Matches, Wins, Win Rate), live Active Battles rows, and Past Matches rows with tap-through to Match Details.
- New Swift files are under the existing synchronized root group, so no manual `project.pbxproj` target membership edits were required.

## Slice 9 — Notifications and Live Activities
Date: 2026-04-02
Status: Complete
Files created:
- `FitUp/FitUp/FitUp/Services/NotificationService.swift` (full rewrite — APNs registration, UNUserNotificationCenterDelegate, foreground presentation, deep-link routing, Live Activity token upload)
- `FitUp/FitUp/FitUp/Views/LiveActivity/FitUpActivityAttributes.swift` (shared ActivityKit attributes + ContentState — compiled into both FitUp and FitUpWidgetExtension)
- `FitUp/FitUp/FitUp/Views/LiveActivity/LiveActivityCoordinator.swift` (start/end Live Activity, pushTokenUpdates subscription, local update helper)
- `FitUp/FitUp/FitUpWidgetExtension/FitUpLiveActivity.swift` (Widget Extension entry point — lock-screen + Dynamic Island views, WidgetBundle)
- `supabase/functions/_shared/apns.ts` (token-based JWT APNs client — alert push + Live Activity push)
- `supabase/functions/send-pending-reminders/index.ts` (pg_cron daily job — finds pending matches without acceptance, fires `pending_reminder`)
- `supabase/functions/send-morning-checkins/index.ts` (pg_cron daily job — fires `morning_checkin` for all active matches)
- `supabase/sql/slice9-notifications.sql` (triggers, helper functions, pg_cron schedules)
Files modified:
- `FitUp/FitUp/FitUp/FitUpApp.swift` (added `UIApplicationDelegateAdaptor` + `AppDelegate` for APNs token callbacks)
- `FitUp/FitUp/FitUp/ContentView.swift` (inject `NotificationService` as environment object; call `registerForRemoteNotifications` after session restore; wire `pendingDeepLink` → `MatchDetailsContext` / tab switch)
- `FitUp/FitUp/FitUp/Repositories/ProfileRepository.swift` (added `updatePushTokens(apnsToken:liveActivityPushToken:)`)
- `FitUp/FitUp/FitUp/ViewModels/HomeViewModel.swift` (added `syncLiveActivity()` — starts/ends `LiveActivityCoordinator` on each snapshot reload)
- `FitUp/FitUp/Config/FitUp.entitlements` (`aps-environment = development` added)
- `FitUp/FitUp/Config/Info-Additional.plist` (`NSSupportsLiveActivities` + `NSSupportsLiveActivitiesFrequentUpdates` added)
- `FitUp/FitUp/FitUp.xcodeproj/project.pbxproj` (`FitUpWidgetExtension` target added: `PBXFileSystemSynchronizedRootGroup`, build phases, `PBXCopyFilesBuildPhase` embed, `PBXTargetDependency`, build configs with `INFOPLIST_KEY_NSExtensionPointIdentifier = com.apple.widgetkit-extension`)
- `supabase/functions/dispatch-notification/index.ts` (enriches `live_activity_update` payloads with per-user totals, display names, series scores, and `duration_days` before sending to APNs)
Supabase changes:
- `profiles` table: added `notifications_enabled boolean DEFAULT true` and `live_activity_push_token text` columns (via `slice9-notifications.sql`)
- New DB triggers: `tr_notify_match_found_on_pairing`, `tr_notify_challenge_received`, `tr_notify_challenge_declined`, `tr_activate_match_when_all_accepted`, `tr_notify_lead_changed`, `tr_push_live_activity_updates`
- New private schema helpers: `invoke_edge_function`, `invoke_dispatch_notification`, `notification_sent_today`, `resolve_leader_user`
- pg_cron jobs: `send-pending-reminders` (daily 16:15 UTC), `send-morning-checkins` (daily 13:00 UTC)
- Deployed Edge Functions: `dispatch-notification` (updated), `send-pending-reminders` (new), `send-morning-checkins` (new)
- APNs secrets required in Supabase Edge Function secrets: `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY`, `APNS_BUNDLE_ID`, `APNS_USE_SANDBOX`
Notes:
- Live Activity widget uses token-based push (`pushType: .token`) — server sends updates via APNs liveactivity push type to `profiles.live_activity_push_token`.
- `FitUpActivityAttributes` is compiled into both targets via a traditional `PBXBuildFile` in the widget extension Sources phase referencing the file at `SOURCE_ROOT/FitUp/Views/LiveActivity/FitUpActivityAttributes.swift`.
- `FitUpWidgetExtension` bundle ID: `com.ScottOliver.FitUp.FitUpWidgetExtension` — register in Apple Developer portal Identifiers.
- `aps-environment = development` in entitlements requires Push Notifications capability enabled on the App ID in the Developer portal for device installs.
- Daily cap of 10 push notifications per user enforced in `dispatch-notification`; `live_activity_update` events are exempt from the cap.
- Verify build: `xcodebuild -project "FitUp/FitUp/FitUp.xcodeproj" -scheme "FitUp" -destination "generic/platform=iOS Simulator" build` → BUILD SUCCEEDED.

## Slice 11 — Leaderboard / Ranks screen
Date: 2026-04-03
Status: Complete
Files created:
- `FitUp/FitUp/FitUp/Utilities/ProfileAccentColor.swift`
- `FitUp/FitUp/FitUp/Models/LeaderboardDisplayRow.swift`
- `FitUp/FitUp/FitUp/Repositories/LeaderboardRepository.swift`
- `FitUp/FitUp/FitUp/ViewModels/LeaderboardViewModel.swift`
- `FitUp/FitUp/FitUp/Views/Leaderboard/LeaderboardView.swift`, `PodiumView.swift`, `RankedRowView.swift`
Files modified:
- `FitUp/FitUp/FitUp/ContentView.swift` (Ranks tab → `LeaderboardView` + challenge prefill)
- `FitUp/docs/slice-tracker.md` (this entry)
Supabase changes:
- None. Reads `leaderboard_entries` (by `week_start` UTC Monday aligned with `update-leaderboard` Edge Function), `profiles`, and `match_participants` for Friends (opponent user ids on shared matches). RLS unchanged.
Notes:
- **Friends** = users who share any `match_participants.match_id` with the current user (opponents); ranks recomputed client-side by points for that filtered set.
- **Week start** uses UTC Monday to match backend `weekStartIsoDate`.
- Pinned “You” bar shows when the current user’s list row scrolls out of the visible viewport (`LeaderboardUserRowVisibilityPreferenceKey` + global frame intersection).
- New Swift files live under the synchronized `FitUp/` root; no manual `project.pbxproj` edits expected.

## Slice 13 — Paywall and Dev Mode
Date: 2026-04-03
Status: Complete
Files created:
- `FitUp/FitUp/FitUp/Services/SubscriptionService.swift` (RevenueCat entitlement wrapper; `isPremium`, `canCreateMatch`, `canShowPaywall`, `markFirstMatchWon`, `refreshEntitlement`, `purchase`, `restorePurchases`; Dev Mode bypass in `#if DEBUG`)
- `FitUp/FitUp/FitUp/Views/Paywall/PaywallView.swift` (annual plan gold-glass prominent + monthly plan base-glass, RevenueCat package fetch, purchase + restore flows, "Not now" dismiss)
Files modified:
- `FitUp/FitUp/FitUp/Services/MatchmakingService.swift` (removed `isPremiumUser`; `evaluateEntryGate` now delegates to `SubscriptionService.shared.isPremium` and `canShowPaywall` — paywall never blocks before first match is completed)
- `FitUp/FitUp/FitUp/Views/Challenge/ChallengeFlowView.swift` (replaced inline `ChallengeEntryPaywallSheet` with `PaywallView`)
- `FitUp/FitUp/FitUp/ViewModels/MatchDetailsViewModel.swift` (calls `markFirstMatchWon()` or `markFirstMatchCompleted()` when a completed match loads)
- `FitUp/FitUp/FitUp/ContentView.swift` (`ProfilePlaceholderView` extended: upgrade banner shown for free users after first win `glassCard(.pending)`; `#if DEBUG` Dev Mode toggle with `@AppStorage("devMode")` + status indicator)
- `FitUp/FitUp/FitUp/FitUpApp.swift` (`Task { await SubscriptionService.shared.refreshEntitlement() }` called on init)
- `FitUp/docs/slice-tracker.md` (this entry)
Supabase changes:
- None. No schema changes, no new Edge Functions.
Notes:
- Paywall timing per spec: `canShowPaywall` returns false until `UserDefaults.bool("hasCompletedFirstMatch")` is true. This means free-tier users can complete their first match without ever hitting the paywall.
- Soft upsell (upgrade banner) shows in Profile after `firstMatchWon` is set — not a hard block.
- Dev Mode toggle is `#if DEBUG` only; toggling it ON makes `SubscriptionService.shared.isPremium` return `true` immediately without a RevenueCat call.
- RevenueCat entitlement ID used: `"pro"`. Create products `fitup_pro_annual` and `fitup_pro_monthly` in App Store Connect + matching offering in RevenueCat dashboard before testing purchases on device.
- `PaywallView` gracefully falls back to hardcoded price strings (`$29.99/year`, `$4.99/month`) when RevenueCat packages are unavailable.
- Build verified: no linter errors. Run `xcodebuild -project "FitUp/FitUp/FitUp.xcodeproj" -scheme "FitUp" -destination "generic/platform=iOS Simulator" build` to verify.

## Slice 14 — Profile screen and Dev Tools
Date: 2026-04-03
Status: Complete
Files created:
- `FitUp/FitUp/FitUp/ViewModels/ProfileViewModel.swift` (stats from ActivityRepository + LeaderboardRepository, log fetch with time/level filters, JSON export)
- `FitUp/FitUp/FitUp/Views/Profile/ProfileView.swift` (hero card, upgrade banner, settings groups, dev tools section, sign out row)
- `FitUp/FitUp/FitUp/Views/Profile/SettingsGroupView.swift` (reusable `SettingsGroupView<Content>` + `SettingsRowView` with chevron/toggle/badge actions)
- `FitUp/FitUp/FitUp/Views/Profile/LogViewerView.swift` (monospace green log list, time-range + level filter chips, ShareLink JSON export)
Files modified:
- `FitUp/FitUp/FitUp/Models/Profile.swift` (added `notificationsEnabled: Bool?` / `notifications_enabled` CodingKey — column added in Slice 9)
- `FitUp/FitUp/FitUp/Repositories/ProfileRepository.swift` (added `updateNotificationsEnabled()`, `fetchLogs(userId:since:levelFilter:)`, `AppLogEntry` Codable model)
- `FitUp/FitUp/FitUp/ContentView.swift` (replaced `ProfilePlaceholderView` with `ProfileView`; added `showingPaywall` state + `.sheet`; removed dead `ProfilePlaceholderView` and `TabPlaceholderView`)
- `FitUp/docs/slice-tracker.md` (this entry)
Supabase changes:
- None. No schema changes, no new Edge Functions. Reads `app_logs` (existing table) and `leaderboard_entries` (existing). Writes `profiles.notifications_enabled` (column added in Slice 9 migration).
Notes:
- Stats row (Matches / Wins / Streak) pulls from `ActivityRepository.loadCompletedMatches` + current-week `leaderboard_entries` streak.
- Notifications toggle writes `profiles.notifications_enabled` via PATCH on `ProfileRepository.updateNotificationsEnabled()`. Make sure the Slice 9 `notifications_enabled` column exists on the `profiles` table before testing.
- Log viewer fetches `app_logs` filtered by `user_id`, `created_at >= since`, and optional `level` filter. Entries show in monospace green; errors in red, warnings in yellow.
- Dev Mode toggle and entire DEVELOPER group are `#if DEBUG` only — absent from release/production builds.
- Sign Out sits in a standalone glassCard(.base) row at the bottom (always visible in all build configurations).
- Build verified: `xcodebuild` → BUILD SUCCEEDED (no Swift compilation errors).

## Slice 12 — Health screen
Date: 2026-04-03
Status: Complete
Files created:
- `FitUp/FitUp/FitUp/Services/ReadinessCalculator.swift`
- `FitUp/FitUp/FitUp/Repositories/HealthRepository.swift`
- `FitUp/FitUp/FitUp/ViewModels/HealthViewModel.swift`
- `FitUp/FitUp/FitUp/Views/Health/HealthView.swift`
- `FitUp/FitUp/FitUp/Views/Health/Cards/BattleReadinessCard.swift`, `ComponentBreakdownCard.swift`, `WeekChartCard.swift`, `SleepQualityCard.swift`, `HRZonesCard.swift`
Files modified:
- `FitUp/FitUp/FitUp/Services/HealthKitService.swift` (resting HR, sleep summary, HR zones from latest workout, 7-day step/cal arrays; read types: `heartRate`, `workout`)
- `FitUp/FitUp/FitUp/Design/DesignTokens.swift` (`FitUpColors.HealthSleepStage` — sleep stage colors from mockup)
- `FitUp/FitUp/FitUp/ContentView.swift` (Health tab → `HealthView`)
- `FitUp/docs/slice-tracker.md` (this entry)
Supabase changes:
- None. Reads `all_time_bests` (existing public SELECT RLS). Reuses `HomeRepository.loadActiveMatches` + `ActivityRepository.loadCompletedMatches` for Competition Edge and win rate.
Notes:
- Battle Readiness from `ReadinessCalculator.compute` (docs §12); `ReadinessCalculatorSanityTests.run()` in DEBUG SwiftUI Preview (`ReadinessCalculator.swift`).
- After pulling this slice: enable **Health** data permissions in Xcode scheme for simulator (HealthKit); add **Heart Rate** + **Workouts** read access — new `requestAuthorization` types. No new Edge Functions.
- If `all_time_bests` row is missing for the user, all-time cells show placeholders until backend populates bests.

## Matchmaking reliability — stuck `searching` fixes
Date: 2026-04-03
Status: Complete
Files created:
- `supabase/functions/_shared/matchmakingPairing.ts` (shared RPC + notifications)
- `supabase/functions/retry-matchmaking-search/index.ts` (JWT + ownership check → same pairing path)
- `supabase/sql/slice4b-matchmaking-stale-retry.sql` (`matchmaking_retry_stale_searches` + pg_cron `matchmaking-retry-stale`)
- `supabase/sql/verify-matchmaking.sql`, `supabase/sql/cleanup-duplicate-match-search-requests.sql`
- `scripts/matchmaking-pair-test.sh`
Files modified:
- `supabase/functions/matchmaking-pairing/index.ts` (uses shared module)
- `FitUp/FitUp/FitUp/Repositories/MatchRepository.swift` (cancel prior searching rows before new Quick Match; `retryMatchmakingSearch`)
- `FitUp/FitUp/FitUp/Repositories/MatchSearchRepository.swift` (cancel prior searching before onboarding insert)
- `FitUp/FitUp/FitUp/Services/MatchmakingService.swift` (scheduled retries at +5s and +15s via Edge Function)
- `FitUp/docs/supabase-setup-guide.md` (deploy `retry-matchmaking-search`, slice4b, verify/cleanup scripts)
Supabase changes:
- Deploy `retry-matchmaking-search` after pulling. Run `slice4b-matchmaking-stale-retry.sql` in SQL Editor (requires `slice4` + `slice8` pg_cron). Optional: run `cleanup-duplicate-match-search-requests.sql` once if duplicate queue rows exist.
Notes:
- Pairing still requires two **different** users with compatible `metric_type` / `duration_days` / `start_mode`; same user cannot match themselves.
- Retries address failed `pg_net` delivery and partners joining shortly after; cron sweeps stale rows every minute.

## Decline pending match (direct + random)
Date: 2026-04-08
Status: Complete
Files created:
- `supabase/sql/slice4e-decline-pending-match.sql` (`decline_pending_match` RPC + `tr_notify_public_matchmaking_declined`)
Files modified:
- `FitUp/FitUp/FitUp/Repositories/HomeRepository.swift` (`declinePendingMatch` → RPC)
- `FitUp/docs/supabase-setup-guide.md` (Slice 4 §7 run order)
Supabase changes:
- Run `slice4e-decline-pending-match.sql` after `slice9-notifications.sql`.
Notes:
- Cancels pending matches for both `direct_challenge` and `public_matchmaking`; Home hides rows when `state = 'cancelled'`. Opponent push for random match uses `challenge_declined` like direct decline.
