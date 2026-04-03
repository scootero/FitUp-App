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

## Slice [N] — [name]
Date: [date]
Status: Complete
Files created: [list]
Files modified: [list]
Supabase changes: [list any tables/functions touched]
Notes: [anything notable or deferred]
