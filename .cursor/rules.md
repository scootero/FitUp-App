# FitUp — Cursor Rules

## Repo and project
- Repo root: FitUp-App/ (workspace root containing the `FitUp/` folder)
- Open the repo root in Cursor (not only a nested folder)
- Xcode project: `FitUp/FitUp/FitUp.xcodeproj`
- Do NOT restructure the Xcode project layout
- Add new Swift files inside `FitUp/FitUp/FitUp/` (synced app source folder)

## Primary references
1. `FitUp/docs/fitup-docs-pack.md` — architecture, state machine, data model, scoring rules
2. `FitUp/docs/mockups/FitUp_Final_Mockup.jsx` — single source of truth for ALL UI  
   Read the relevant JSX components before implementing any screen.  
   Every color, spacing, animation, and layout must match this file as closely as practical.  
   Sections marked [MOCK DATA] must be replaced with real HealthKit or backend data.

## Architecture rules (never violate)
- Views never query Supabase directly
- Views never call HKHealthStore directly
- All Supabase access through repository or service layers
- All HealthKit access through HealthKitService only
- Match state transitions owned by Supabase Edge Functions
- Client reads state — never writes transitions or finalizes days
- Series score derived from match_days rows — never stored, never in views
- ReadinessCalculator is a pure function — not in views

## Design rules
- All design values from DesignTokens.swift — no hardcoded hex, sizes, or radii elsewhere
- Glass card styles via .glassCard(variant) ViewModifier
- Bottom nav is a floating card — all 4 corners rounded, safe area aware
- Nav hidden on: Match Details, Live Match, Challenge flow

## Home section order
Searching → Active → Pending → Discover Players  
(If a screen shows a different order, that is a bug — fix it)

## Code rules
- Do not refactor files unrelated to the current slice
- Additive changes only — do not delete working code without being asked
- SwiftUI previews must always compile
- If a change affects match state, scoring, finalization, or HealthKit flow:  
  STOP, explain the impact, and wait for confirmation before writing any code

## V1 scope
- 1v1 only; metrics: steps and active_calories; durations: 1/3/5/7 days
- No manual entry, no team matches, no social feed
- Paywall via RevenueCat — never hardcode tier logic

## Naming
Tables (snake_case plural): matches, match_days, match_day_participants,  
  metric_snapshots, match_search_requests, direct_challenges,  
  notification_events, app_logs, profiles, user_health_baselines,  
  leaderboard_entries, all_time_bests

Swift types (PascalCase): Match, MatchDay, Profile, LeaderboardEntry  
Swift properties (camelCase): matchId, dayNumber, metricTotal, finalizedValue

Enum string values:  
  match.state: 'searching' | 'pending' | 'active' | 'completed' | 'cancelled'  
  match_days.status: 'pending' | 'provisional' | 'finalized'  
  metric_type: 'steps' | 'active_calories'  
  start_mode: 'today' | 'tomorrow'  
  data_status: 'pending' | 'confirmed'

## Ambiguity rule
If a change could affect match state, scoring, finalization, HealthKit data flow,  
or the design system — stop and ask. Do not guess.
