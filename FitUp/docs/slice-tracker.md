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

## Slice [N] — [name]
Date: [date]
Status: Complete
Files created: [list]
Files modified: [list]
Supabase changes: [list any tables/functions touched]
Notes: [anything notable or deferred]
