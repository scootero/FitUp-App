# FitUp — Build Slices
*Implementation guide. Reference fitup-docs-pack.md and FitUp_Final_Mockup.jsx for all decisions.*
*Build in order. Do not begin a slice until I ask you to, and only build the slice I ask you to*

**# As-built notes:** Sections and lines prefixed with **`#`** (heading or bullet) are *rebuild metadata* added April 2026 — they record what was actually implemented so you can recreate the project without losing auth, Supabase, widgets, or reliability work. They do **not** change the original slice order for greenfield execution. The running log with file lists is `FitUp/docs/slice-tracker.md`.

---

## How to use this file

1. Work through slices **in exact order** — each depends on the previous
2. For every slice, use the **Cursor Execution Template** at the bottom
3. Commit after each slice passes all acceptance criteria
4. The JSX file at `FitUp/docs/mockups/FitUp_Final_Mockup.jsx` is the visual source of truth — read the relevant components **before** implementing any UI
5. All `[MOCK DATA]` sections in the JSX must be replaced with real HealthKit or backend data
6. Every slice must wire real data — do not stop at working mock UI

---

## Slice 0 — Foundation, design system, and mockup-to-SwiftUI mapping

**Goal:** Existing Xcode project extended with all dependencies, the complete design token system implemented in Swift, folder structure established, and Supabase connection verified.

**Important:** The Xcode project already exists. Do NOT create a new project. Work inside `FitUp/FitUp/` (Xcode app sources under the `FitUp/` project folder).

---

### Part A — Mockup-to-SwiftUI mapping (read before writing any code)

**JSX reference:** Read the entire `T` object, `BG_STYLE`, `glassCard()`, `neonPill()`, `ghostBtn()`, `solidBtn()`, `Av`, `Badge`, `CircleProgress`, `DayBar`, and `BottomNav` at the top of `FitUp_Final_Mockup.jsx`. These define the complete design system.

**Translation approach:**

The JSX mockup uses inline styles built from a `T` token object. In SwiftUI, these become:

| JSX pattern | SwiftUI equivalent |
|---|---|
| `T.neon.cyan`, `T.neon.orange`, etc. | `static let` Color constants in `DesignTokens.swift` |
| `T.radius.lg`, `T.radius.pill` | `static let` CGFloat constants in `DesignTokens.swift` |
| `T.font.display`, `T.font.mono` | `static func` Font helpers in `DesignTokens.swift` |
| `glassCard("win")` | `.glassCard(.win)` ViewModifier |
| `glassCard("lose")` | `.glassCard(.lose)` ViewModifier |
| `glassCard("base")` | `.glassCard(.base)` ViewModifier |
| `glassCard("pending")` | `.glassCard(.pending)` ViewModifier |
| `glassCard("gold")` | `.glassCard(.gold)` ViewModifier |
| `solidBtn(color)` | `.solidButton(color:)` ViewModifier or `SolidButtonStyle` |
| `ghostBtn(color)` | `.ghostButton(color:)` ViewModifier or `GhostButtonStyle` |
| `neonPill(color)` | `NeonBadge` view (pill shape, tinted bg + border) |
| `BG_STYLE` radial gradient | `BackgroundGradientView` (ZStack backing all screens) |
| `ScreenIn` fade+slide wrapper | `.screenTransition()` ViewModifier or `.transition()` |
| `Av` component | `AvatarView(initials:color:size:glow:)` |
| `CircleProgress` | `RingGaugeView(score:size:)` |
| `DayBar` | `DayBarView(day:myVal:theirVal:myWon:finalized:isToday:)` |
| `BottomNav` | `FloatingTabBar` — custom ZStack overlay, NOT native TabView tab bar |
| `SecHead` | `SectionHeader(title:action:)` |
| `Badge` | `NeonBadge(label:color:)` |

**File organization principle:** Keep shared components in `Views/Shared/`. Do not duplicate card logic across screens. Aim for one view file per logical component — avoid splitting a single simple component across multiple files.

**Bottom nav implementation:** The JSX `BottomNav` is a floating card (rounded all 4 corners, horizontal padding, not edge-to-edge). In SwiftUI, implement as a `ZStack` overlay at the root level, NOT as a native `TabView` tab bar. Use `safeAreaInset(edge: .bottom)` so scroll content clears the nav. The center ⚔️ BATTLE button uses `offset(y: -14)` to float above the bar.

**Glass card ViewModifier:** Each glass card variant applies a specific `background` (linear gradient from `T.glass`), `border`, `cornerRadius`, and `shadow`. Use `.background(RoundedRectangle(...).fill(...).overlay(RoundedRectangle(...).stroke(...)))` and `.shadow(...)` modifiers composed inside the ViewModifier. Optionally back with `.ultraThinMaterial` for blur.

**Screen transitions:** Every screen fade-in + translateY slide-up (0.26s). Implement as a `.transition(.opacity.combined(with: .move(edge: .bottom)))` or a custom `ScreenTransitionModifier`. Apply on every NavigationStack push and tab switch.

---

### Part B — Deliverables

**Do not create a new Xcode project.** Work inside the existing project.

- **Folder structure:** Add Xcode groups inside `FitUp/FitUp/` (under the `FitUp` Xcode project) for: `Design/`, `Views/Shared/`, `Views/Auth/`, `Views/Onboarding/`, `Views/Home/`, `Views/Challenge/`, `Views/MatchDetails/`, `Views/LiveMatch/`, `Views/Activity/`, `Views/Leaderboard/`, `Views/Health/`, `Views/Profile/`, `ViewModels/`, `Services/`, `Repositories/`, `Models/`, `Utilities/`
- **`DesignTokens.swift`** (in `Design/` group) — created FIRST before any other new Swift file:
  - All `T.neon.*`, `T.text.*`, `T.bg.*` colors as `static let Color` constants
  - All `T.radius.*` as `static let CGFloat` constants
  - Font helpers mapping to SF Pro Display / Text / Mono
  - `GlassCardModifier` for all 5 variants (base, win, lose, pending, gold)
  - `SolidButtonModifier`, `GhostButtonModifier`
  - `BackgroundGradientView` — multi-radial gradient matching `BG_STYLE`
  - `ScreenTransitionModifier` — fade + slide-up
- **Shared components** (in `Views/Shared/`):
  - `AvatarView.swift`
  - `NeonBadge.swift`
  - `RingGaugeView.swift`
  - `DayBarView.swift`
  - `SectionHeader.swift`
  - `FloatingTabBar.swift`
- **Supabase Swift SDK** — installed via SPM, configured with env-based keys (not hardcoded)
- **RevenueCat SDK** — installed, `Purchases.configure(withAPIKey:)` called in `FitUpApp.swift`
- **`HealthKitService.swift`** stub in `Services/` — authorization method wired, no reads yet
- **`AppLogger.swift`** in `Utilities/` — writes structured entries to `app_logs` Supabase table
- **`.cursor/rules.md`** at repository root (e.g. `FitUp-App/.cursor/rules.md` if the repo folder is named `FitUp-App`) — copy from Section 19 of docs pack
- **Supabase tables** — run all CREATE TABLE scripts from Section 7 of docs pack in Supabase dashboard
- **Git** — initial commit with foundation pushed to remote

**Supabase setup (manual — not done by Cursor):**
- Create Supabase project if not already done
- Run all CREATE TABLE scripts
- Enable Row Level Security on all tables
- Enable Apple + Email auth providers
- Create `SUPABASE_URL` and `SUPABASE_ANON_KEY` env config accessible to the app

**Acceptance criteria:**
- [ ] App builds and runs on simulator with zero errors and zero warnings
- [ ] `DesignTokens.swift` exists with all colors, radii, and 5 glass card ViewModifiers
- [ ] `.glassCard(.win)`, `.glassCard(.base)`, `.glassCard(.lose)`, `.glassCard(.pending)`, `.glassCard(.gold)` compile and render correctly in SwiftUI Preview
- [ ] `FloatingTabBar` renders with correct visual (floating card, all 4 corners rounded)
- [ ] All shared components (`AvatarView`, `NeonBadge`, etc.) compile
- [ ] Supabase test query returns without error
- [ ] HealthKit authorization dialog triggers when called manually
- [ ] All 13 tables exist in Supabase with correct columns
- [ ] `.cursor/rules.md` present at repository root
- [ ] Git remote exists, initial commit pushed

---

## Slice 1 — Auth and session

**Goal:** Users can sign up, sign in with Apple or email, and session persists across launches with correct routing.

**JSX reference:** `StatusBar` (static header shape), `ProfileScreen` (user data shape). No auth screen in JSX — design using `glassCard(.base)` and design tokens.

**Files to create:**
- `Views/Auth/AuthView.swift`
- `ViewModels/SessionStore.swift`
- `Repositories/ProfileRepository.swift`

**Files to modify:**
- `FitUpApp.swift` — inject `SessionStore`, handle launch routing
- `ContentView.swift` — replace with root routing logic (or replace with `RootView.swift`)

**Deliverables:**
- `AuthView`: Sign in with Apple button + email/password form — dark background, glass card styling from design tokens
- Supabase Auth methods: `signInWithApple()`, `signInWithEmail()`, `signUp(email:password:)`
- `SessionStore` (ObservableObject): holds `currentProfile`, `isAuthenticated`, exposes `signOut()`
- `ProfileRepository.createProfile()`: writes `profiles` row on first sign-up (sets `initials` from `display_name`, `timezone` from `TimeZone.current.identifier`)
- Root routing: no session → `AuthView`, session + first-time → `OnboardingView`, session + returning → `HomeView`
- Session restore: on launch, call `supabase.auth.session` — if valid, skip auth and go directly to Home
- Log all auth events to `app_logs` (category: `auth`)

**Data wired:**
- Reads: `supabase.auth.session` on launch
- Writes: `profiles` row on first sign-up

**Acceptance criteria:**
- [ ] New user signs up with email — `profiles` row appears in Supabase with initials and timezone
- [ ] Sign in with Apple works and creates/links profile
- [ ] Returning user auto-signs-in on launch — no credentials re-entered
- [ ] Sign out clears session, returns to `AuthView`
- [ ] First-time launch → onboarding; returning launch → Home
- [ ] Auth events logged to `app_logs`

---

## Slice 2 — Onboarding

**Goal:** First-time users understand the app, grant all permissions, and reach Home with an open search request visible.

**JSX reference:** No onboarding screen in JSX. Use `glassCard(.win)` for "Find First Match" card and `solidBtn(cyan)` style for the CTA button. Tutorial cards use `glassCard(.base)`.

**Files to create:**
- `Views/Onboarding/OnboardingView.swift`
- `Views/Onboarding/TutorialCardsView.swift`
- `Views/Onboarding/PermissionExplainerView.swift`
- `Views/Onboarding/FindFirstMatchView.swift`
- `Services/HealthKitService.swift` (authorization only this slice)
- `Services/NotificationService.swift` (authorization only this slice)

**Deliverables:**
- Multi-step onboarding with tutorial cards explaining the core loop
- `PermissionExplainerView` — shown before each system permission prompt
- `HealthKitService.requestAuthorization()` — requests `stepCount`, `activeEnergyBurned`, `restingHeartRate`, `sleepAnalysis`
- `UNUserNotificationCenter.requestAuthorization(options: [.alert, .badge, .sound])`
- `FindFirstMatchView`:
  - Displays user's 7-day step average (from `HKStatisticsCollectionQuery` over past 7 days)
  - Config locked and displayed (not editable): Steps · 1 day · Start today
  - Single explicit tap "Find Opponent" — does NOT auto-start
  - On tap: write `match_search_requests` row (metric_type: 'steps', duration_days: 1, start_mode: 'today') → redirect to Home
- Short searching animation/message shown briefly before Home redirect
- Onboarding completion flag: `UserDefaults.standard.set(true, forKey: "onboardingComplete")`
- Log each step to `app_logs` (category: `onboarding`)

**Data wired:**
- Reads: HealthKit `HKStatisticsCollectionQuery` for 7-day step average
- Writes: `match_search_requests` row on "Find Opponent" tap

**Acceptance criteria:**
- [ ] Onboarding shown on first launch only (flag check in `SessionStore` or `RootView`)
- [ ] Tutorial cards render with correct styling
- [ ] Permission explainer shown before each system prompt
- [ ] HealthKit permissions requested for all 4 types
- [ ] Notification permissions requested
- [ ] 7-day step average displayed on `FindFirstMatchView` (real HealthKit value)
- [ ] "Find Opponent" tap creates `match_search_requests` row in Supabase
- [ ] Redirect to Home after tap — Searching card visible
- [ ] Second launch skips onboarding

---

## Slice 3 — Home shell and tab navigation

**Goal:** Complete floating tab bar, Home screen with all 4 sections in correct order, and correct empty states. Visual output must match JSX as closely as practical.

**JSX reference:** `BottomNav`, `HomeScreen`, `MatchCard`, `SecHead`. Read all of them carefully, especially `BottomNav` floating card spec and section order.

**Home section order (locked): Searching → Active → Pending → Discover Players**

**Files to create:**
- `Views/Home/HomeView.swift`
- `Views/Home/Sections/SearchingSection.swift`
- `Views/Home/Sections/ActiveSection.swift`
- `Views/Home/Sections/PendingSection.swift`
- `Views/Home/Sections/DiscoverSection.swift`
- `Views/Home/Cards/MatchCardView.swift`
- `ViewModels/HomeViewModel.swift`

**Files to modify:**
- `Views/Shared/FloatingTabBar.swift` — complete implementation
- `ContentView.swift` or `RootView.swift` — integrate tab structure

**Deliverables:**
- `FloatingTabBar` — complete floating card implementation:
  - 6 tabs: Home, Activity, [BATTLE center], Health, Profile, Ranks
  - `glassCard(.base)` backing + blur, 28pt corner radius, 12pt horizontal padding, 10pt bottom + safe area
  - Center ⚔️ button: `54×54pt`, `18pt` corner radius, cyan→blue gradient, `offset(y: -14)`
  - Active tab: full opacity icon + cyan glow + cyan label
  - Inactive: 35% opacity icon + tertiary label
  - Tab bar hidden when navigating to Match Details, Live Match, or Challenge flow
- `HomeViewModel` (ObservableObject): loads searching requests, pending matches, active matches, discover users — all from Supabase
- Supabase Realtime subscriptions: `matches` and `match_search_requests` for current user
- **Searching section:** Purple glass cards with animated dots ("Finding opponent..."), elapsed wait time, Cancel button
  - Cancel tap: updates `match_search_requests.status = 'cancelled'`
- **Active section:** `MatchCardView` for each active match:
  - Win/lose glass card, 2pt colored top accent bar
  - Sport + Series badge, days left
  - You vs Opponent with today's step counts (from `match_day_participants.metric_total`)
  - Score pill (dark bg, black border), WINNING/LOSING label
  - Day pip row (one pip per day per JSX spec)
  - Entrance animation: fade + translateY(14) → 0, staggered by card index
- **Pending section:** Blue glass cards with opponent info, Accept ✓ + Decline ✗ buttons
- **Discover section:** Opponent avatar, name, today steps + win record, Challenge button
- Zero state: all sections empty → large CTA ("Find Your First Match")
- Background gradient applied via `BackgroundGradientView`

**Data wired:**
- Reads: `match_search_requests` (status: searching), `matches` + `match_participants` (pending + active), `profiles` for discover list
- Writes: `match_search_requests.status = 'cancelled'` on Cancel tap
- Writes: `match_participants.accepted_at` on Accept tap
- Writes: `direct_challenges.status = 'declined'` on Decline tap
- Realtime: subscribe to `matches` and `match_search_requests` for live updates

**Acceptance criteria:**
- [ ] Floating tab bar renders correctly — floating card, all 4 corners rounded, correct colors
- [ ] Center BATTLE button floats above bar, correct gradient and shadow
- [ ] Home sections appear in order: Searching → Active → Pending → Discover Players
- [ ] Each section hides independently when no data
- [ ] Match cards have colored top accent bar, score pill, day pips, entrance animation
- [ ] Searching cards show animated dots, wait time, Cancel button
- [ ] Cancel tap updates database row and removes card from UI
- [ ] Accept tap writes `accepted_at`, card updates to active when backend confirms
- [ ] Decline tap removes card from pending section

- [ ] Realtime updates: opening a search on another device appears in Home without manual refresh
- [ ] Background gradient visible behind all content

---

## Slice 4 — Challenge creation flow

**Goal:** 4-step Challenge flow working end to end. Submissions create correct database rows. Flow returns to Home.

**JSX reference:** `ChallengeScreen` — all 4 steps + sent confirmation state. Read all step layouts and the sent confirmation layout.

**Files to create:**
- `Views/Challenge/ChallengeFlowView.swift`
- `Views/Challenge/Steps/SportStepView.swift`
- `Views/Challenge/Steps/FormatStepView.swift`
- `Views/Challenge/Steps/OpponentStepView.swift`
- `Views/Challenge/Steps/ReviewStepView.swift`
- `Views/Challenge/ChallengeSentView.swift`
- `Services/MatchmakingService.swift`
- `Services/DirectChallengeService.swift`
- `Repositories/MatchRepository.swift`

**Deliverables:**
- Challenge flow launched from BATTLE center button (full-screen cover, no tab bar visible)
- 4-step progress stepper bar at top (matches JSX exactly)
- **Step 0 — Sport:** Steps (cyan card) or Calories (orange card)
- **Step 1 — Format:**
  - Daily (1 day)
  - First to 3 (3 days)
  - Best of 5 (5 days)
  - Best of 7 (7 days)
- **Step 2 — Opponent:** Search field (glass pill), Quick Match button (purple glass), skill-matched player list from Supabase `profiles` + `user_health_baselines`
- **Step 3 — Review:** VS card (`glassCard(.win)`), sport + format badges, Send Challenge button with loading state
- **Sent confirmation:** "Challenge Sent!" with back to Home button
- Paywall check at Challenge flow entry: if free tier at 1-slot limit, show paywall sheet instead
- **Quick Match path:** Writes `match_search_requests` row
- **Direct challenge path:** Writes `direct_challenges` row + `matches` row + `match_participants` rows (sender auto-accepted)
- Back chevron at each step goes to previous step

**Format → duration_days mapping:**
- Daily → 1 | First to 3 → 3 | Best of 5 → 5 | Best of 7 → 7

**Backend functions triggered:**
- INSERT on `match_search_requests` → `matchmaking-pairing` Edge Function runs
- INSERT on `match_participants` with all accepted → `on-all-accepted` Edge Function runs

**Data wired:**
- Reads: `profiles` + `user_health_baselines` for opponent discover list (Step 2)
- Writes (Quick Match): `match_search_requests` row
- Writes (Direct challenge): `direct_challenges` + `matches` + `match_participants` rows

**Acceptance criteria:**
- [ ] BATTLE button opens Challenge flow (no tab bar visible)
- [ ] All 4 steps render and navigate correctly with back chevron
- [ ] Progress stepper shows correct active step
- [ ] Quick Match creates `match_search_requests` row with correct metric_type + duration_days
- [ ] Direct challenge creates `direct_challenges` + `matches` + `match_participants` rows
- [ ] Sender's `match_participants.accepted_at` set immediately (auto-accept)
- [ ] Sent confirmation displays correctly
- [ ] Back to Home from sent confirmation navigates to Home
- [ ] Free tier user at 1-slot limit sees paywall before Step 0
- [ ] Paywall shows annual plan prominently

---

## Slice 5 — Match Details screen

**Goal:** Match Details renders correctly for all 3 states. Accept/decline work. Watch Live button navigates to stub.

**JSX reference:** `MatchDetailsScreen` — read all 3 variant states (active/pending/completed). `DayBar` component. Day results list logic.

**Files to create:**
- `Views/MatchDetails/MatchDetailsView.swift`
- `Views/MatchDetails/DayBarChartView.swift`
- `Views/MatchDetails/DayResultsListView.swift`
- `ViewModels/MatchDetailsViewModel.swift`

**Deliverables:**
- Match Details presented with back chevron, no tab bar
- **Pending state:** VS layout, blue badge, Accept (cyan solid) + Decline (pink) buttons
- **Active state:** VS layout with live scores, day bar chart (Swift Charts), day results list, Watch Live button (green glass)
- **Completed state:** VS layout, winner badge (cyan on winner), Rematch button (orange solid)
- Day chart: two bars per day — you (cyan) + opponent (their color). Use Swift Charts `BarMark`.
- Day results list: one row per day with mini comparison bars and winner indicator
- Accept: writes `match_participants.accepted_at = now()` for current user → backend detects all accepted → match becomes active
- Decline: writes `direct_challenges.status = 'declined'` → navigates back to Home
- Watch Live: navigates to `LiveMatchView` stub (implemented in Slice 6)
- Rematch: opens Challenge flow pre-filled with same opponent and same settings (sport + format)
- Supabase Realtime: subscribe to this match's `match_day_participants` for live total updates

**Data wired:**
- Reads: `matches`, `match_participants`, `match_days`, `match_day_participants` for this match
- Writes: `match_participants.accepted_at` on Accept
- Writes: `direct_challenges.status = 'declined'` on Decline
- Realtime: `match_day_participants` for live updates

**Acceptance criteria:**
- [ ] Match Details opens from Home card — no tab bar visible
- [ ] Pending state: VS layout, blue badge, Accept + Decline buttons
- [ ] Active state: VS layout, live scores, day chart, results list, Watch Live button
- [ ] Completed state: VS layout, winner badge, Rematch button
- [ ] Accept writes `accepted_at` to Supabase
- [ ] When both participants accepted, `match.state` becomes `active` (verify in Supabase)
- [ ] Decline updates `direct_challenges.status`, navigates back
- [ ] Day chart renders correct bars (cyan = you, opponent color = them)
- [ ] Back chevron returns to previous screen with tab bar reappearing
- [ ] Realtime: opponent's today count updates without manual refresh

---

## Slice 6 — Live Match screen

**Goal:** Live Match screen renders the real-time step race. Connects to Supabase Realtime for opponent updates. Toasts display correctly.

**JSX reference:** `LiveMatchScreen` — read entire component. Replace the `setInterval` simulation with Supabase Realtime. Replace all `[MOCK DATA]` values.

**Files to create:**
- `Views/LiveMatch/LiveMatchView.swift`
- `Views/LiveMatch/LiveToastView.swift`
- `ViewModels/LiveMatchViewModel.swift`

**Deliverables:**
- Accessed from Match Details Watch Live button — no tab bar
- Back chevron returns to Match Details
- Your step count: real value from `match_day_participants.metric_total` (current user)
- Opponent count: Supabase Realtime subscription on `match_day_participants` for this match day
- Progress bars: both users' counts as percentage of daily goal (12,000 default, from `UserDefaults`)
- Lead/lag: `myCount - theirCount`, signed, correct color (cyan if positive, orange if negative)
- Toast system: `LiveToastView` overlay — appear from top, auto-dismiss after 2.2 seconds, fade + slide-down animation
  - Toast triggers: lead changes (crossing from behind to ahead), milestone steps
- Pause button: pauses local display animation (does not stop data updates)

**Data wired:**
- Reads: `match_day_participants.metric_total` for both users (initial load)
- Realtime: subscribe to `match_day_participants` for this match_day — update opponent count on any change
- Your count still comes from HealthKit foreground sync (not from backend)

**Acceptance criteria:**
- [ ] Live Match opens from Watch Live — no tab bar
- [ ] Back returns to Match Details
- [ ] Your step count matches real HealthKit today total
- [ ] Opponent count updates via Realtime when they sync (test with two devices)
- [ ] Progress bars correct percentage of goal
- [ ] Lead/lag correct and correct color
- [ ] Toast appears, shows for 2.2s, then dismisses
- [ ] Pause toggle works

---

## Slice 7 — HealthKit sync and live match totals

**Goal:** Real HealthKit data flows into all active matches continuously. Match cards and Match Details show live today totals for both users.

**JSX reference:** `MatchCard` — `match.myToday` and `match.theirToday` values. Day pip behavior (pulsing for today, `width: 22` vs `16`).

**Files to create/extend:**
- `Services/HealthKitService.swift` (full implementation — was stub in Slice 0)
- `Repositories/MetricSnapshotRepository.swift`
- `Repositories/MatchDayRepository.swift`

**Deliverables:**
- `HealthKitService` full implementation:
  - `HKStatisticsQuery` for today's `stepCount` and `activeEnergyBurned`
  - `HKObserverQuery` for background delivery on both types
  - `HKStatisticsQuery` for yesterday's full date range (for finalization window)
  - Handle `HKErrorAuthorizationDenied` gracefully — show re-enable prompt in Settings, do not crash
- On every sync:
  - Write `metric_snapshots` row (with `source_date`, `synced_at`)
  - Update `match_day_participants.metric_total` for all active match days
  - Update `user_health_baselines.rolling_avg_7d` for each metric
  - Flag if value > 50,000 steps: `flagged = true` + `app_logs` entry (category: `healthkit_sync`)
- `match_days` rows: created when match becomes `active` (one per day for duration)
- `match_day_participants` rows: created with `match_days` (one per user per day)
- Today pip on match card: `22pt` wide (vs `16pt` for other days), pulsing animation

**Backend function triggered:**
- Client calls `sync-metric-snapshot` Edge Function (or writes directly to Supabase via repository) — backend updates totals

**Data wired:**
- Reads: HealthKit `HKStatisticsQuery` (foreground), `HKObserverQuery` (background)
- Writes: `metric_snapshots`, `match_day_participants.metric_total`, `user_health_baselines`

**Acceptance criteria:**
- [ ] Today step count appears in active match cards and Match Details for both users
- [ ] Today calories appear for calorie-metric matches
- [ ] Opponent total updates via Realtime when they sync
- [ ] Every sync writes a `metric_snapshots` row with correct `source_date`
- [ ] Background delivery wakes app and triggers sync
- [ ] Values > 50,000: `flagged = true` + `app_logs` entry
- [ ] `user_health_baselines` updated on every sync
- [ ] Today pip is 22pt wide and pulsing vs 16pt static for other days

---

## Slice 8 — Day finalization and match scoring

**Goal:** Days finalize correctly at 10am cutoff. Winners locked. Series score always correct. Completed matches move to Activity.

**JSX reference:** `DayBar` — `finalized` prop controls pip style. `match.days[].winner = "me" | "them" | null`.

**Supabase work:**
- Edge Function: `finalize-match-day`
- Edge Function: `complete-match`
- Edge Function: `update-leaderboard`
- pg_cron job: `day-cutoff-check` (hourly)

**Deliverables:**
- `finalize-match-day` Edge Function:
  - Input: `match_day_id`
  - Guard: `status != 'finalized'`
  - Writes `finalized_value` for each `match_day_participants` row (copies from `metric_total`)
  - Computes winner: higher `finalized_value` wins
  - Sets `match_days.winner_user_id`, `status = 'finalized'`, `finalized_at`
  - Identical values → `is_void = true`, no winner
  - Calls `update-leaderboard` with match and day result
  - Calls `complete-match` if all match_days for this match are now finalized
  - Fires day result push notifications via `dispatch-notification`
- `day-cutoff-check` pg_cron (runs hourly):
  - Finds `match_day_participants` where `data_status = 'pending'` and user's local time is past 10:00 AM
  - Force-sets `data_status = 'confirmed'`, `finalized_value` = best available `metric_total` (or 0)
  - Triggers `finalize-match-day`
- `complete-match` Edge Function:
  - Guard: check all `match_days` are finalized
  - Sets `match.state = 'completed'`, `completed_at`
  - Fires match result notifications
- `update-leaderboard` Edge Function:
  - Updates `leaderboard_entries` for current week
  - Adds points per formula (Section 8 of docs pack)
  - Re-ranks all users for the week
- UI: day chart finalized pips are solid (cyan = won, orange = lost); today pip pulses

**Acceptance criteria:**
- [ ] Day finalizes immediately when all participants have `data_status = 'confirmed'`
- [ ] Day force-finalizes at 10am if any participant still `pending`
- [ ] `finalized_value` correct and never changes after set (verify in Supabase)
- [ ] `winner_user_id` correct (higher value wins)
- [ ] Void day: `is_void = true`, `winner_user_id = null`, no points
- [ ] Series score counted correctly (non-void finalized days only)
- [ ] Completed match appears in Activity tab
- [ ] Day chart pips: solid for finalized, pulsing for today
- [ ] `leaderboard_entries` updated after each finalization

---

## Slice 9 — Notifications and Live Activities

**Goal:** All key events fire push notifications. Active matches show a Live Activity.

**Supabase work:**
- Edge Function: `dispatch-notification`
- pg_cron: `send-pending-reminders` (daily)
- pg_cron: `send-morning-checkins` (daily, morning)

**Files to create:**
- `Services/NotificationService.swift` (full implementation)
- `Views/LiveActivity/FitUpLiveActivity.swift` (ActivityKit widget)

**Deliverables:**
- APNs device token: registered on `FitUpApp` launch, stored in `profiles.apns_token`
- `dispatch-notification` Edge Function:
  - Writes `notification_events` row (status: 'pending')
  - Checks daily cap: COUNT(notification_events WHERE user_id AND sent_at >= today AND status = 'sent') < 10
  - Sends APNs push if under cap
  - Updates `notification_events.status` to 'sent' or 'failed'
- All event types from Section 14 of docs pack wired to `dispatch-notification`
- `send-pending-reminders` pg_cron: daily — find all pending matches without `accepted_at` → fire `pending_reminder`
- `send-morning-checkins` pg_cron: daily morning — find all active matches → fire `morning_checkin`
- Live Activity widget (`FitUpLiveActivity`):
  - Starts when `match.state → active`
  - Content: both display names, current day metric totals, series score, day N of M
  - Updated via ActivityKit push from backend on every `match_day_participants` update
  - Dismissed when `match.state → completed`

**Acceptance criteria:**
- [ ] `match_found` notification arrives on both devices
- [ ] `challenge_received` notification arrives on recipient
- [ ] `match_active` arrives on both
- [ ] `lead_changed` arrives on trailing user
- [ ] `morning_checkin` fires once per active match per day
- [ ] `day_won` / `day_lost` arrive after finalization
- [ ] `match_won` / `match_lost` arrive after completion
- [ ] `pending_reminder` fires daily until accepted
- [ ] Daily cap of 10 enforced (verify `notification_events` count)
- [ ] Live Activity appears on lock screen for active match
- [ ] Live Activity updates when opponent syncs
- [ ] Live Activity dismisses when match completes

---

## Slice 10 — Activity screen

**Goal:** Full Activity screen with stats row, active matches, and completed match history.

**JSX reference:** `ActivityScreen` — stats row, active list, past matches list, won/lost badge styling.

**Files to create:**
- `Views/Activity/ActivityView.swift`
- `Views/Activity/Rows/ActiveMatchRow.swift`
- `Views/Activity/Rows/PastMatchRow.swift`
- `ViewModels/ActivityViewModel.swift`

**Deliverables:**
- Stats row: Matches count, Wins count, Win Rate — Win Rate highlighted in `neon.cyan` glass card
- Active section: compact match rows, today's step counts, win/lose badge
- Past Matches section: final score, sport + date range, won/lost badge (cyan = won, orange = lost)
- Tap any row → Match Details for that match
- Back from Match Details returns to Activity (not Home)
- Load all matches from Supabase where current user is a participant

**Data wired:**
- Reads: `matches` + `match_participants` + `match_days` + `match_day_participants` for current user

**Acceptance criteria:**
- [ ] Stats row shows correct Matches, Wins, Win Rate values
- [ ] Active section shows live today totals
- [ ] Past matches show correct final scores, dates, won/lost badges
- [ ] Tap opens Match Details; back returns to Activity
- [ ] Empty states render without crash

---

## Slice 11 — Leaderboard / Ranks screen

**Goal:** Full Leaderboard screen with real data, correct podium, ranked list, and pinned current-user row.

**JSX reference:** `LeaderboardScreen` — podium layout, ranked rows, global/friends toggle, current user pinned row, LIVE badge. Read entire component.

**Files to create:**
- `Views/Leaderboard/LeaderboardView.swift`
- `Views/Leaderboard/PodiumView.swift`
- `Views/Leaderboard/RankedRowView.swift`
- `Repositories/LeaderboardRepository.swift`
- `ViewModels/LeaderboardViewModel.swift`

**Deliverables:**
- Header: "Leaderboard" title, current week date range (`Mon – Sun`), LIVE badge (`neon.green`)
- Global / Friends toggle (custom segmented control, cyan active state)
- Podium — exact layout from JSX:
  - 2nd place (left, medium height): base glass card, 🥈, name, points
  - 1st place (center, tallest): `glassCard(.gold)`, 👑 above avatar (floating), 🥇, name, points in `neon.yellow`
  - 3rd place (right, shortest): base glass card, 🥉, name, points
  - 1st place avatar has glow ring (see `Av` JSX component with `glow=true`)
- Ranked list (rank 4+): rank number, `AvatarView`, name, wins/losses, streak, points
- Current user row: `glassCard(.win)` styling, pinned at bottom of scroll if not in visible range
- Week range computed from current date (Monday → Sunday)
- Tap other user row → opens Challenge flow pre-filled with that opponent

**Data wired:**
- Reads: `leaderboard_entries` for current `week_start` + `profiles` for display names

**Acceptance criteria:**
- [ ] Podium renders with correct heights and medals
- [ ] 1st place has 👑 floating above avatar and gold glass card
- [ ] Ranked list shows rank, stats, points
- [ ] Current user row highlighted in cyan glass
- [ ] Current user row pinned at bottom when out of scroll view
- [ ] Week date range computed correctly
- [ ] LIVE badge visible
- [ ] Tapping other user opens Challenge flow

---

## Slice 12 — Health screen

**Goal:** Full Health screen with real HealthKit data, computed Battle Readiness score, all sub-cards matching JSX.

**JSX reference:** `HealthScreen`, `CircleProgress`, `HEALTH_MOCK` data shape. Read every card and its data inputs.

**Files to create:**
- `Views/Health/HealthView.swift`
- `Views/Health/Cards/BattleReadinessCard.swift`
- `Views/Health/Cards/WeekChartCard.swift`
- `Views/Health/Cards/ComponentBreakdownCard.swift`
- `Views/Health/Cards/SleepQualityCard.swift`
- `Views/Health/Cards/HRZonesCard.swift`
- `Services/ReadinessCalculator.swift`

**Files to extend:**
- `Services/HealthKitService.swift` — add HR and sleep queries

**Deliverables:**
- **`ReadinessCalculator.compute(sleep:hr:steps:cals:goals:) -> Int`** — pure function, unit tested:
  - Formula exactly as in Section 12 of docs pack
  - Missing-data handling: redistribute weight proportionally if a factor has no data
- **Battle Readiness card** (`glassCard(.win)`, animated glow):
  - `RingGaugeView(score:)` — exact circle progress from JSX `CircleProgress`
  - Label: Strong / Moderate / Low Readiness + description text
  - Quick stats row: Sleep, Resting HR, Steps, Cals — small `glassCard(.base)` chips
- **Week chart card:**
  - Steps / Calories segmented toggle
  - Swift Charts `BarMark` — 7 days, bars colored by metric (cyan = steps, orange = cals)
  - Delta label: today vs 7-day average
- **Component Breakdown card** (collapsible):
  - 4 rows: Sleep, Resting HR, Step Pace, Calories
  - Each row: factor name, value, target, weight %, component score, progress bar
- **Sleep Quality card:**
  - 7-night average hours (large `font.display`)
  - Variance label
  - Stacked stage bar (Deep / Core / REM / Awake) — widths proportional to percentages
  - Legend dots with labels
  - Data from `HKCategoryTypeIdentifier.sleepAnalysis` — group by night, sum by stage
- **HR Zones card:**
  - Resting HR bpm
  - 5 zone progress bars (colors from JSX `hrZones` array)
  - Data from most recent workout `HKQuantityTypeIdentifier.heartRate` samples

**HealthKit additions:**
- `HealthKitService.fetchRestingHeartRate()` → most recent `restingHeartRate` sample
- `HealthKitService.fetchSleepAnalysis()` → last 7 nights, grouped by night, split by stage
- `HealthKitService.fetchHRZones()` → most recent workout's HR samples bucketed into zones

**Data wired:**
- Reads (all from HealthKit): today steps, today cals, 7-day steps array, 7-day cals array, resting HR, sleep stages, HR zone samples
- Computed: Battle Readiness score via `ReadinessCalculator`

**Acceptance criteria:**
- [ ] Battle Readiness ring renders in correct color (cyan ≥75, yellow 50–74, red <50)
- [ ] Score computed from real HealthKit data using exact formula
- [ ] Quick stats show real Sleep, HR, Steps, Cals values
- [ ] Week chart shows 7-day bar data for both steps and calories
- [ ] Toggle updates chart metric
- [ ] Component Breakdown shows per-factor scores and progress bars
- [ ] Sleep Quality shows correct hours, variance, stage percentages
- [ ] HR Zones shows 5 zones with correct colors and percentages
- [ ] `ReadinessCalculator` unit tests pass including missing-data cases

---

## Slice 13 — Paywall and Dev Mode

**Goal:** Free tier enforced everywhere. Paywall appears only at correct moments. Dev Mode fully functional.

**JSX reference:** `ProfileScreen` — upgrade banner (blue glass), Dev Mode toggle behavior (log viewer appears when on).

**Files to create:**
- `Services/SubscriptionService.swift`
- `Views/Paywall/PaywallView.swift`

**Deliverables:**
- RevenueCat entitlements: `free` and `premium`
- `SubscriptionService.currentTier` — reads RevenueCat entitlement
- `SubscriptionService.canCreateMatch()` — returns false if free tier at 1-slot limit
- Paywall sheet: annual plan prominent at top, monthly below, styled with design tokens
- Paywall triggered at Challenge flow entry when at limit — sheet instead of Step 0
- Soft upsell after winning first match (banner, not hard block)
- Dev Mode toggle in Profile (only compiled in `#if DEBUG`):
  - When ON: `SubscriptionService` returns `premium` always
  - Stored in `UserDefaults.standard.set(true, forKey: "devMode")`

**Acceptance criteria:**
- [ ] Free user blocked at 1 slot — paywall shows at Challenge entry
- [ ] Paywall never shown before first match
- [ ] Annual plan prominent in paywall UI
- [ ] Premium user has unlimited slots
- [ ] Dev Mode toggle visible in debug build only
- [ ] Dev Mode ON bypasses all paywall checks
- [ ] Dev Mode absent in production build (`#if DEBUG`)
- [ ] Subscription state persists across launches

---

## Slice 14 — Profile screen and Dev Tools

**Goal:** Full Profile screen matching JSX. Log viewer and export functional.

**JSX reference:** `ProfileScreen` — hero card, stats, upgrade banner, settings groups, dev tools section with log viewer.

**Files to create:**
- `Views/Profile/ProfileView.swift`
- `Views/Profile/SettingsGroupView.swift`
- `Views/Profile/LogViewerView.swift`

**Deliverables:**
- Profile hero card (`glassCard(.win)`, animated glow):
  - 72pt avatar with gradient background, cyan border, `AvatarView`
  - Display name, subscription tier `NeonBadge`
  - Stats row: Matches / Wins / Streak — dark inner `glassCard(.base)` chips
- Upgrade banner (`glassCard(.pending)`) — pitch + Upgrade button (opens `PaywallView`)
- Settings groups with correct icons, chevrons, toggles — match JSX layout
- Dev Tools section (`#if DEBUG` only):
  - Dev Mode toggle (when toggled ON: log viewer appears below)
  - Log viewer: monospace green text, fetches `app_logs` from Supabase for current user
  - Filters: time range (10m, 1h, 12h, 24h, 3d) + level (all / errors only)
  - Export: serialize filtered `app_logs` to JSON → iOS share sheet
- Sign Out: `supabase.auth.signOut()` → navigate to `AuthView`

**Data wired:**
- Reads: `profiles` for user info, `app_logs` for log viewer
- Writes: `supabase.auth.signOut()` on sign out, `UserDefaults` for dev mode

**Acceptance criteria:**
- [ ] Profile hero card matches JSX (avatar, name, tier badge, stats row)
- [ ] Settings groups render with correct icons and actions
- [ ] Dev Mode toggle only in debug build
- [ ] Log viewer appears when Dev Mode is on
- [ ] Entries in monospace green, filterable
- [ ] Export produces valid JSON and opens share sheet
- [ ] Sign Out works and returns to `AuthView`
- [ ] Dev Mode absent in production build

---

## Cursor Execution Template

Use for every Cursor session. Fill in all bracketed sections.

```
Context:
  Slice: [Number and name — e.g. "Slice 4 — Challenge creation flow"]
  JSX components to read first: [List specific components from FitUp_Final_Mockup.jsx]
  Files to create: [From slice's Files section]
  Files to modify: [From slice's Files section]
  Current app state: [What's working — e.g. "Auth and onboarding complete, Home shell renders"]

  Reference docs:
    Primary: FitUp/docs/fitup-docs-pack.md
    UI source: FitUp/docs/mockups/FitUp_Final_Mockup.jsx
    Key sections: [e.g. "Section 6 State Machine, Section 10 Interaction Map"]

Goal:
  [Copy the slice Goal line verbatim]

Project structure rule:
  The Xcode project already exists at FitUp/FitUp/FitUp.xcodeproj (inside the `FitUp/` directory at repo root).
  Do NOT create a new project. Add new files inside FitUp/FitUp/FitUp/.
  All new files must be added to the FitUp app target.

Design rule:
  Read the JSX components listed above before writing any SwiftUI.
  All design values come from DesignTokens.swift — no hardcoded hex or sizes.
  [MOCK DATA] sections in JSX must be replaced with real data sources.

Constraints:
  - Do not refactor code unrelated to this slice
  - Additive changes only — do not delete working code without being asked
  - No business logic in SwiftUI views
  - All HealthKit access through HealthKitService only
  - All Supabase access through repository/service layers only
  - V1 scope: 1v1, steps and active_calories, 1/3/5/7 day durations only
  - No manual metric entry
  - If a change affects match state, scoring, finalization, or HealthKit flow:
    STOP and explain before writing any code

Implementation:
  Step 1: [First deliverable]
  Step 2: [Second deliverable]
  Step 3: [Continue as needed]

Supabase work needed (if any):
  [List Edge Functions, pg_cron jobs, or schema changes needed for this slice]

Verification:
  Visual check:
    [Compare rendered UI against JSX reference — list specific things to verify]
  Manual test:
    [Exact steps and what to observe]
  Database state expected after:
    [Which tables should have rows, what values]
  Acceptance criteria:
    [Paste checkbox list from this slice verbatim]
```

---

## # Appendix — Rebuild snapshot (as implemented)

Use this with **`FitUp/docs/slice-tracker.md`** (detailed file lists) and **`FitUp/docs/supabase-setup-guide.md`** (full SQL + Edge Function instructions; the **`## # Master run order (rebuild checklist)`** section is the phased overview). UI source: **`FitUp/docs/mockups/`** (paths are relative to the repository root).

### # Numbered slices — status

| Slice | Theme | As-built status |
|------|--------|-----------------|
| 0 | Foundation, design system | Complete (see tracker — xcconfig, SPM, `SupabaseProvider`, synced groups) |
| 1 | Auth and session | Complete — `AuthView`, `SessionStore`, `ProfileRepository`; not duplicated in early tracker entries |
| 2 | Onboarding | Complete |
| 3 | Home shell + tabs | Complete |
| 4 | Challenge flow | Complete |
| 4 (backend) | Matchmaking + activation | Complete — `matchmaking-pairing`, `on-all-accepted`, `supabase/sql/slice4-matchmaking.sql` |
| 5 | Match Details | Complete (includes early `LiveMatchView` stub) |
| 6 | Live Match | Complete |
| 7 | HealthKit sync | Complete — `MetricSyncCoordinator`, Realtime vs polling |
| 8 | Finalization + scoring | Complete — Edge Functions + `slice8-finalization.sql`, minimal Activity until Slice 10 |
| 9 | Notifications + Live Activities | Complete — widget extension target, APNs, `profiles` columns, cron jobs |
| 10 | Activity | Complete |
| 11 | Leaderboard | Complete — Friends = past opponents |
| 12 | Health | Complete — `ReadinessCalculator`, extra HK types (workouts, heart rate) |
| 13 | Paywall + Dev Mode | Complete — RevenueCat entitlement id **`pro`**, products `fitup_pro_annual` / `fitup_pro_monthly` |
| 14 | Profile + Dev Tools | Complete |

### # Extra work not in the original slice list (required for parity)

- **# Slice 4 backend (Supabase):** RPCs + triggers → `matchmaking-pairing` and `on-all-accepted`; `MatchRepository` direct-challenge rows include `role`, `joined_via`. See `supabase/sql/slice4-matchmaking.sql`.
- **# Matchmaking reliability (Slice 4b):** Shared `matchmakingPairing.ts`, `retry-matchmaking-search` Edge Function, `slice4b-matchmaking-stale-retry.sql` (cron), client retries + cancel-duplicate-search behavior. See tracker + `supabase-setup-guide.md`.
- **# RLS / SQL fixes:** e.g. `slice4c-direct-challenge-rls.sql`, `slice4d-create-direct-challenge-rpc.sql`, `fix-match-participants-rls-recursion.sql` — follow setup guide run order.
- **# Decline pending match (Slice 4e):** `supabase/sql/slice4e-decline-pending-match.sql` — `decline_pending_match` RPC + notification trigger; `HomeRepository.declinePendingMatch` calls RPC for direct + public matchmaking pending rows.
- **# iOS config (not all in original Slice 0 bullet list):** `FitUp/FitUp/Config/` — `Debug.xcconfig`, `Secrets.example.xcconfig` → copy to **`Secrets.xcconfig`** (gitignored), `Info-Additional.plist`, `FitUp.entitlements`; deployment target **18.6**; HealthKit + Push capabilities; widget extension **`FitUpWidgetExtension`** for Live Activities (`FitUpActivityAttributes.swift` shared into extension).
- **# Authentication / “portal” work:** There is **no separate admin web app** in this repo. “Portal” in practice means **Apple Developer Portal** (App ID, Push Notifications, Sign in with Apple, Widget Extension ID) and **Supabase Dashboard** (Auth providers, SQL, Edge Functions, secrets, Vault for service role / `pg_net`). See **`FitUp/docs/supabase-setup-guide.md`** Step 8+ and Slice 9 notes in **`slice-tracker.md`**.

### # Git history (high level)

Initial foundation through large batch commits; detailed per-slice work is reflected in **`slice-tracker.md`** (authoritative for files). Use `git log` on `FitUp/` and `supabase/` for forensic diffs.

---

*End of fitup-build-slices.md*
