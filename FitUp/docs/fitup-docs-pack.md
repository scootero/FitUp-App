# FitUp — Docs Pack
*Single source of truth. Update the Decisions Log after every session.*
*Last updated: March 2026*

---

## How to use these docs

Two files make up the complete spec:
- **fitup-docs-pack.md** (this file) — what the system IS
- **fitup-build-slices.md** — how to BUILD it, slice by slice

**UI reference file:** `FitUp-App/FitUp/docs/mockups/FitUp_Final_Mockup.jsx`
This JSX file is the single source of truth for all visual design. Every screen, component, animation, color, spacing, and layout must be implemented to match it as closely as practical in SwiftUI. Cursor must read the relevant components before implementing any UI. Sections marked `[MOCK DATA]` must be replaced with real data from HealthKit or the backend.

For Cursor: highest-priority sections are **6 (State Machine)**, **7 (Data Model)**, **8 (Scoring)**, **9 (Design System)**, **10 (Interaction Map)**, and **16 (Cursor Rules)**.

Items marked **`[CONFIRM]`** need a final answer before the relevant slice is built. Everything else is locked.

---

## 1. Product Overview

FitUp is a challenge-first iOS fitness app. Users compete in 1v1 matches using real HealthKit data.

**Core loop:** Create or search → get matched → accept → compete daily → see who won each day → rematch.

| Field | Value |
|---|---|
| Platform | iOS only, SwiftUI, minimum iOS 18 |
| Backend | Supabase (Postgres, Edge Functions, Realtime) |
| Health data | Apple HealthKit — on-device authorized reads only |
| Subscriptions | RevenueCat — configured day one |
| Notifications | APNs + ActivityKit (Live Activities) |
| UI reference | `FitUp-App/FitUp/docs/mockups/FitUp_Final_Mockup.jsx` |

---

## 2. V1 Scope

### In scope

- 1v1 matches only
- Metrics: steps, active calories
- Durations: 1, 3, 5, 7 days (displayed as Daily, First to 3, Best of 5, Best of 7 in Challenge flow UI)
- Start options: today (includes steps already accumulated today) or tomorrow (begins at midnight)
- Public matchmaking search (longest-waiting compatible user first)
- Direct challenges to any user in the discovery list
- Home screen: Searching, Active, Pending sections + Discover Players list
- Match Details: per-day bar chart, live totals, series score, provisional/finalized indicators
- Live Match screen: real-time step race (accessible from active Match Details only — not in nav)
- Challenge creation flow: 4-step (Sport → Format → Opponent → Review/Send)
- Activity screen: all active and past matches
- Leaderboard / Ranks screen: global and friends rankings, podium, points system
- Health screen: Battle Readiness score, steps/calories stats, sleep quality, HR zones
- Profile / Settings: log viewer, log export, Dev Mode toggle
- Push notifications for all key events
- Live Activities during active matches
- Paywall via RevenueCat (free tier: 1 match slot total)
- Dev Mode: bypasses all limits, absent from production builds
- No manual metric entry — ever, under any circumstance
- Anomaly detection: flag extreme values in metric_snapshots

### Out of scope / deferred

- Teams (2v2, FFA) — v2
- Multi-metric combined matches — v2
- Profile photos — v2 (avatar initials for v1)
- Social feed — v2 or never
- Google Fit / Android — v2
- In-app chat or taunts — v2 (requires Apple UGC compliance)
- Custom durations beyond the four fixed options — later
- Tournament brackets — later

---

## 3. Project Structure

**This is an existing Xcode project. Do not restructure it.**

Repo root: `FitUp-App/`
Open in Cursor: `FitUp-App/` (not a subdirectory)
Xcode project: `FitUp-App/FitUp/FitUp.xcodeproj`

Current layout (preserve this exactly):
```
FitUp-App/
├── .cursor/
│   └── rules.md
├── docs/
│   ├── fitup-docs-pack.md
│   ├── fitup-build-slices.md
│   └── mockups/
│       └── FitUp_Final_Mockup.jsx
└── FitUp/
    ├── FitUp.xcodeproj
    └── FitUp/
        ├── FitUpApp.swift          ← entry point, already exists
        ├── ContentView.swift       ← replace/extend, do not delete
        ├── Assets.xcassets
        └── [new Swift files added here as slices progress]
```

**Adding new files:** All new Swift files are added inside `FitUp-App/FitUp/FitUp/`. Organize using Xcode groups (which map to folders). The target membership of every new Swift file must be the FitUp app target.

**Recommended group structure inside `FitUp/FitUp/`:**
```
FitUp/FitUp/
├── App/                ← FitUpApp.swift lives here (move or reference)
├── Design/             ← DesignTokens.swift
├── Views/
│   ├── Auth/
│   ├── Onboarding/
│   ├── Home/
│   ├── Challenge/      ← 4-step challenge creation flow
│   ├── MatchDetails/
│   ├── LiveMatch/
│   ├── Activity/
│   ├── Leaderboard/
│   ├── Health/
│   ├── Profile/
│   └── Shared/         ← reusable view components
├── ViewModels/
├── Services/
├── Repositories/
├── Models/
└── Utilities/
```

Cursor should add files to these groups without touching the Xcode project file structure beyond what is needed. If a group folder does not exist, create it.

---

## 4. Auth and Onboarding

### Auth options
- Sign in with Apple (primary)
- Email + password via Supabase Auth

**Supabase auth setup required:**
- Enable Apple and Email providers in Supabase dashboard
- Configure Site URL and redirect URLs
- For Sign in with Apple: configure Apple Service ID and key in Supabase

### First-time onboarding flow

```
1. Sign in / Sign up (AuthView)
2. Tutorial screens — explain core loop with screenshots
3. Pre-permission explainer: Apple Health
4. HealthKit permission prompt
   → Request: stepCount, activeEnergyBurned, restingHeartRate, sleepAnalysis
5. Pre-permission explainer: Notifications
6. Notification permission prompt
7. "Find Your First Match" screen
   → Shows user's 7-day step average (from HealthKit)
   → Config locked: steps, 1 day, start today (not editable)
   → User taps "Find Opponent" explicitly — does NOT auto-start
8. Short searching/loading state (~3 seconds visual)
9. Message: "We'll notify you when your match is found"
10. Redirect to Home → Searching card visible in Searching section
```

**Target:** User in first active competition within 2 minutes of download.

**Onboarding completion:** Stored in `UserDefaults`. Never shown again after first completion.

**Session restore:** On every launch, check Supabase session. If valid → go to Home directly (skip auth and onboarding). If invalid → go to AuthView.

---

## 5. Navigation and Screen Flow

### Bottom nav — floating card

The bottom nav is a **floating card** — it does NOT stretch edge to edge.

```
Horizontal padding: 12pt each side
Bottom padding: 10pt + safe area inset
Corner radius: 28pt (all 4 corners — key to floating look)
Background: rgba(5,5,10,0.92) + backdropFilter blur(28px)
Border: 1px solid rgba(255,255,255,0.09)
Box shadow: 0 -4px 40px rgba(0,0,0,0.6)
```

Tab order (6 tabs):
```
Home | Activity | ⚔️ BATTLE (center, floats 14pt above bar) | Health | Profile | Ranks
```

Center ⚔️ BATTLE button spec:
- `width: 54pt, height: 54pt, borderRadius: 18pt`
- Gradient: cyan (#00FFE0) → blue (#00AAFF)
- Floats 14pt above the nav bar (SwiftUI: `offset(y: -14)` inside a ZStack overlay)
- Tapping opens Challenge creation flow (full-screen, no nav visible)

**Nav is HIDDEN on sub-screens:** Match Details, Live Match, Challenge flow. These use a back chevron instead.

**In SwiftUI:** Implement as a custom overlay on a `ZStack`, not as a native `TabView` tab bar. Use `safeAreaInset(edge: .bottom)` to push scroll content above the floating nav.

### Navigation map

```
App Launch
  └── Auth / Session restore
        ├── Onboarding (first-time only) → Find First Match → Home
        └── Home (returning users)
              ├── tap Searching card → (no navigation, cancel inline)
              ├── tap Active match card → Match Details (active state)
              │     └── tap "Watch Live" → Live Match Screen
              │           └── back → Match Details
              ├── tap Pending card → Match Details (pending state)
              ├── tap Challenge button in Discover → Challenge flow (pre-filled)
              ├── BATTLE button → Challenge flow (step 0)
              │     └── back / done → Home
              ├── Activity tab → Activity Screen
              │     └── tap match row → Match Details
              ├── Health tab → Health Screen
              ├── Ranks tab → Leaderboard Screen
              └── Profile tab → Profile Screen
```

### Entry points from notifications

| Notification | Opens |
|---|---|
| Match found / challenge received | Home — Pending section |
| Match accepted / active | Match Details (active state) |
| Lead changed | Match Details (active state) |
| Day finalized | Match Details (active or completed state) |
| Match completed | Match Details (completed state) |
| Pending reminder | Match Details (pending state) |

---

### Screen details

#### Home

| | |
|---|---|
| Section order | **Searching → Active → Pending → Discover Players** |
| Searching cards | Purple glass, animated "Finding opponent..." dots, wait time display, Cancel button |
| Active cards | Win or lose glass card, colored top accent bar, You vs Opponent with today step counts, score pill, WINNING/LOSING label, day pip row |
| Pending cards | Blue glass, opponent info, sport + series, Accept ✓ and Decline ✗ buttons |
| Discover Players | Opponent avatar, name, today steps + win/loss record, Challenge button |
| Zero state | All sections empty → large CTA to find first match |
| JSX reference | `HomeScreen`, `MatchCard`, `SearchingCard`, `DiscoverCard` |

#### Match Details

| | |
|---|---|
| States | Pending, Active, Completed |
| Pending | VS layout, blue pending badge, Accept (cyan solid) + Decline (pink) buttons |
| Active | VS layout with live scores, "Watch Live" green button, day chart, day results list |
| Completed | VS layout, winner badge, Rematch (orange) button |
| Day chart | Two bars per day — you (cyan) and opponent (their color) |
| Day pip indicators | Cyan = won, orange = lost, pulsing = today in progress, dim = future |
| JSX reference | `MatchDetailsScreen` |

#### Live Match (not in nav)

| | |
|---|---|
| Access | Match Details "Watch Live" button — active matches only |
| Content | Real-time step race, both users' counts, progress to goal, lead/lag indicator |
| Toasts | Auto-dismiss overlays for live events (2.2 seconds) |
| Back | Returns to Match Details |
| JSX reference | `LiveMatchScreen` |

#### Challenge Flow (not in nav)

| | |
|---|---|
| Entry | BATTLE center button, or Challenge button from Discover |
| Steps | 0: Sport → 1: Format → 2: Opponent → 3: Review/Send |
| Confirmation | Sent state with "Waiting for [name]..." + Back to Home |
| Progress indicator | 4-step bar at top |
| JSX reference | `ChallengeScreen` |

#### Activity

| | |
|---|---|
| Stats row | Matches, Wins, Win Rate (cyan highlight) |
| Active section | Compact rows with today totals and win/lose badge |
| Past section | Final scores, sport + date range, won/lost badge |
| JSX reference | `ActivityScreen` |

#### Leaderboard

| | |
|---|---|
| Header | Title, current week range, LIVE badge |
| Toggle | Global / Friends |
| Podium | 2nd (left, medium), 1st (center, tallest, gold glass, 👑), 3rd (right, shortest) |
| Ranked list | Rank, avatar, name, wins/losses, streak, points |
| Current user | Pinned row at bottom (cyan glass) if not in visible range |
| JSX reference | `LeaderboardScreen` |

#### Health

| | |
|---|---|
| Battle Readiness | Ring gauge (0–100), Strong/Moderate/Low label, quick stats row |
| Week chart | 7-day bar chart (steps or calories), segmented toggle |
| Component Breakdown | Per-factor scores and progress bars (sleep, HR, step pace, cals) |
| Sleep Quality | 7-night average, variance, sleep stage stacked bar |
| HR Zones | Resting HR, 5-zone breakdown |
| JSX reference | `HealthScreen` |

#### Profile

| | |
|---|---|
| Hero | Avatar initials, name, tier badge, stats (Matches/Wins/Streak) |
| Upgrade banner | Blue glass, pitch + Upgrade button |
| Settings groups | Account, Preferences, About |
| Dev Tools | Dev Mode toggle, log viewer (when Dev Mode on), Export Logs |
| Sign out | Pink danger button |
| JSX reference | `ProfileScreen` |

---

## 6. Match State Machine

State transitions are owned by the backend. The client reads state and renders — it never writes transitions or finalizes days.

### States

| State | Meaning |
|---|---|
| `searching` | Search request open, waiting for compatible opponent |
| `pending` | Opponent found or direct challenge sent. All must accept. |
| `active` | All accepted. Match in progress. |
| `completed` | All days finalized. Winner determined. |
| `cancelled` | Creator cancelled before a match was found |
| `declined` | Opponent declined a direct challenge |

### Transition map

```
[User submits Quick Match or sends direct challenge]
         │
         ├── Quick Match → SEARCHING ──────────► CANCELLED (user cancels)
         │                    │
         │                    │ opponent found
         │                    ▼
         └── Direct challenge → PENDING ────────► DECLINED (opponent declines)
                                   │                  └── challenger auto-returns to SEARCHING
                                   │ all accept
                                   ▼
                                ACTIVE
                                   │
                                   │ all days finalized
                                   ▼
                              COMPLETED
                                   │
                            [Rematch → new match record]
```

### Transition rules

| Transition | Trigger | Owner | Notification |
|---|---|---|---|
| → `searching` | User submits Quick Match | Client writes `match_search_requests` row | None |
| `searching` → `pending` | Backend pairs two requests | Edge Function `matchmaking-pairing` | Both: "Match found" |
| `searching` → `cancelled` | User taps Cancel | Client updates status | None |
| `pending` → `active` | All `accepted_at` set | Edge Function `on-all-accepted` | Both: "Match is live" |
| `pending` → `declined` | Opponent taps Decline | Client updates `direct_challenges.status` | Challenger: "Declined" |
| `active` → `completed` | Last `match_day` finalized | Edge Function `complete-match` | Both: final result |

**Expiry rules:**
- Searching: **never expires automatically** — user must cancel manually
- Pending: **never expires automatically** — daily reminder notifications sent until accepted

---

## 7. Data Model

### Table inventory

| Table | Purpose |
|---|---|
| `profiles` | User identity, display name, initials, tier, apns_token, timezone |
| `user_health_baselines` | Rolling 7-day step/calorie averages — used for matchmaking skill pairing |
| `match_search_requests` | Open matchmaking queue entries |
| `direct_challenges` | Direct challenge invitations between two users |
| `matches` | Competition containers — state, metric, duration, timing |
| `match_participants` | Which users are in which match, acceptance state |
| `match_days` | One row per day per match — status, winner, void flag |
| `match_day_participants` | One row per user per day — live total, finalized value |
| `metric_snapshots` | Raw HealthKit audit log — every sync event |
| `leaderboard_entries` | Weekly rankings — points, wins, losses, streak |
| `all_time_bests` | Personal records per user |
| `notification_events` | Audit log of every sent/attempted notification |
| `app_logs` | In-app log stream for Dev Tools |

### Key SQL schemas

#### `profiles`
```sql
CREATE TABLE profiles (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  auth_user_id      uuid UNIQUE NOT NULL,
  display_name      text NOT NULL,
  initials          text NOT NULL,
  avatar_url        text,
  subscription_tier text NOT NULL DEFAULT 'free',
  apns_token        text,
  timezone          text,
  created_at        timestamptz NOT NULL DEFAULT now(),
  updated_at        timestamptz NOT NULL DEFAULT now()
);
```

#### `match_search_requests`
```sql
CREATE TABLE match_search_requests (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id       uuid NOT NULL REFERENCES profiles(id),
  metric_type      text NOT NULL,       -- 'steps' | 'active_calories'
  duration_days    int  NOT NULL,       -- 1 | 3 | 5 | 7
  start_mode       text NOT NULL,       -- 'today' | 'tomorrow'
  status           text NOT NULL DEFAULT 'searching',
                                        -- 'searching' | 'matched' | 'cancelled'
  creator_baseline numeric,
  matched_match_id uuid REFERENCES matches(id),
  created_at       timestamptz NOT NULL DEFAULT now()
  -- No expires_at — searches never auto-expire
);
```

#### `matches`
```sql
CREATE TABLE matches (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_type     text NOT NULL,   -- 'public_matchmaking' | 'direct_challenge'
  metric_type    text NOT NULL,
  duration_days  int  NOT NULL,
  start_mode     text NOT NULL,
  state          text NOT NULL DEFAULT 'pending',
  match_timezone text NOT NULL,
  starts_at      timestamptz,
  ends_at        timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now(),
  completed_at   timestamptz
);
```

#### `match_days`
```sql
CREATE TABLE match_days (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id       uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  day_number     int  NOT NULL,
  calendar_date  date NOT NULL,
  status         text NOT NULL DEFAULT 'pending',   -- 'pending' | 'provisional' | 'finalized'
  winner_user_id uuid REFERENCES profiles(id),
  is_void        boolean NOT NULL DEFAULT false,
  finalized_at   timestamptz,
  UNIQUE(match_id, day_number)
);
```

#### `match_day_participants`
```sql
CREATE TABLE match_day_participants (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_day_id    uuid NOT NULL REFERENCES match_days(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES profiles(id),
  metric_total    numeric NOT NULL DEFAULT 0,   -- live, updated continuously
  finalized_value numeric,                       -- set once at cutoff, NEVER changed after
  data_status     text NOT NULL DEFAULT 'pending',  -- 'pending' | 'confirmed'
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(match_day_id, user_id)
);
```

#### `metric_snapshots`
```sql
CREATE TABLE metric_snapshots (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id     uuid NOT NULL REFERENCES matches(id),
  user_id      uuid NOT NULL REFERENCES profiles(id),
  metric_type  text NOT NULL,
  value        numeric NOT NULL,
  source_date  date NOT NULL,
  synced_at    timestamptz NOT NULL DEFAULT now(),
  flagged      boolean NOT NULL DEFAULT false,
  metadata     jsonb
);
```

#### `leaderboard_entries`
```sql
CREATE TABLE leaderboard_entries (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES profiles(id),
  week_start date NOT NULL,
  points     int  NOT NULL DEFAULT 0,
  wins       int  NOT NULL DEFAULT 0,
  losses     int  NOT NULL DEFAULT 0,
  streak     int  NOT NULL DEFAULT 0,
  rank       int,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, week_start)
);
```

### Persist vs derive

| Data | Where | Rule |
|---|---|---|
| Raw HealthKit samples | `metric_snapshots` | Always written, never deleted |
| Live daily total | `match_day_participants.metric_total` | Updated continuously during the day |
| Locked daily total | `match_day_participants.finalized_value` | Set once at 10am cutoff, never changed |
| Day winner | `match_days.winner_user_id` | Set once at finalization |
| Match series score | **Never stored** | Derived: COUNT(match_days WHERE winner = user AND NOT void) |
| Live leader / gap | **Never stored** | Derived: compare metric_total values at read time |
| Battle Readiness score | **Never stored** | Computed on-device each time Health screen loads |
| Leaderboard rank | `leaderboard_entries.rank` | Cached by backend after weekly re-ranking |
| All-time bests | `all_time_bests` | Updated by backend after each finalized match day |

---

## 8. Scoring and Day Finalization

### Core principles

- **Backend owns finalization** — client never writes `finalized_value`
- **Provisional and finalized are visually distinct** — different pip styles in JSX
- **`finalized_value` written once, never changed**
- **Series score always derived** — never stored, never computed in views
- **Raw data always accepted** — `metric_snapshots` written regardless of finalization state

### Day status

| Status | Meaning | Visual in JSX |
|---|---|---|
| `pending` | No HealthKit data confirmed | Dim, no pip |
| `provisional` | Data arriving, not locked | Pulsing cyan pip (wider, 22pt) |
| `finalized` | Locked forever | Solid pip — cyan = won, orange = lost |

### Finalization flow

```
Midnight (each user's local timezone, independently)
  → match_day row created: status = 'pending'
  → match_day_participants rows created: data_status = 'pending'

App opens OR HealthKit background delivery fires:
  → HKStatisticsQuery for yesterday (00:00:00 → 23:59:59 local)
  → Write to metric_snapshots
  → Update match_day_participants.metric_total
  → Set data_status = 'confirmed' if full-day query returned
  → Set match_days.status = 'provisional' if not already

Backend monitors match_day_participants:
  → When ALL participants for a match_day have data_status = 'confirmed':
      → Write finalized_value for each
      → Compute winner (higher finalized_value wins)
      → Set match_days.winner_user_id, status = 'finalized', finalized_at
      → Fire day result push notifications
      → Update leaderboard_entries and all_time_bests

Hard cutoff: 10:00 AM each user's local timezone
  → Force-confirm any participant still 'pending'
  → Write finalized_value = best available metric_total (or 0 if no data)
  → Finalization runs regardless of confirmation status

Void rule: ALL participants at finalized_value = 0 → is_void = true, no winner, no points

Match completion: all match_days finalized → match.state = 'completed'
```

### Scoring rules

- Each finalized, non-void day = 1 point to the winner
- Identical `finalized_value` both sides → void day, no point
- Series score = COUNT(match_days WHERE winner = user AND NOT void)
- Only odd durations (1/3/5/7 days) → always a series winner — no ties possible by design

### Leaderboard points (backend-computed after each finalization)

- Win a match day: +50 points
- Win a match overall: +200 points
- Each active streak day bonus: +25 (capped at 5 streak days)
- Steps bonus: +10 per 1,000 steps above 10,000 (capped at +100/day)

---

## 9. Design System

**Source of truth:** `FitUp-App/FitUp/docs/mockups/FitUp_Final_Mockup.jsx` — the `T` object at the top.

In Swift: all values live in `DesignTokens.swift` inside `Design/` group. **No hardcoded hex, sizes, or radii anywhere else.**

### Colors

| Token | Hex | Semantic use |
|---|---|---|
| `bg.base` | `#04040A` | App background |
| `neon.cyan` | `#00FFE0` | Win state, user accent, primary CTA |
| `neon.blue` | `#00AAFF` | Pending/searching, secondary actions |
| `neon.orange` | `#FF6200` | Lose state, opponent accent |
| `neon.yellow` | `#FFE000` | Premium, gold, rank #1 |
| `neon.pink` | `#FF2D9B` | Decline, danger |
| `neon.purple` | `#BF5FFF` | Matchmaking, random opponent |
| `neon.green` | `#39FF14` | Live/synced badge, Watch Live button |
| `neon.red` | `#FF3B3B` | Error, low Battle Readiness |
| `text.primary` | `#FFFFFF` | Main text |
| `text.secondary` | `rgba(255,255,255,0.52)` | Supporting text |
| `text.tertiary` | `rgba(255,255,255,0.27)` | Labels, placeholders |

### Glass card variants

| Variant | Tint | Use case |
|---|---|---|
| `base` | White 5.5% | Neutral cards |
| `win` | Cyan 7% | Winning match state |
| `lose` | Orange 7% | Losing match state |
| `pending` | Blue 7% | Incoming challenge, searching |
| `gold` | Yellow 10% | Premium, leaderboard #1 |

In SwiftUI: implement each as a `ViewModifier` (`.glassCard(.win)` etc.) applying the exact background gradient, border, corner radius, and shadow from the JSX `T.glass` object. Use `UIBlurEffect` or `.ultraThinMaterial` as the blur backing.

### Border radius

| Name | Value |
|---|---|
| `sm` | 10pt |
| `md` | 16pt |
| `lg` | 22pt |
| `xl` | 28pt |
| `pill` | 999pt |

### Fonts

Map to system fonts (no custom font files needed):
- `font.display` → `Font.system(size:, weight: .bold, design: .default)` — SF Pro Display
- `font.body` → `Font.system(size:, weight:, design: .default)` — SF Pro Text
- `font.mono` → `Font.system(size:, weight:, design: .monospaced)` — SF Mono

### Background

Full-screen multi-radial gradient (`BG_STYLE` in JSX):
```
Blob 1: ellipse 90% 55% at 15% 8%  — rgba(0,255,224,0.038) — cyan glow top-left
Blob 2: ellipse 65% 45% at 85% 88% — rgba(0,170,255,0.038) — blue glow bottom-right
Blob 3: ellipse 55% 35% at 50% 50% — rgba(255,98,0,0.018)  — faint orange center
Base: #04040A
```

Apply via a `ZStack` background view behind all content.

### Screen transitions

All screens fade in + slide up from Y+12pt, duration 0.26s ease. The JSX calls this `ScreenIn`. In SwiftUI: `.transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .bottom)), removal: .opacity))` or a custom modifier.

### Reusable SwiftUI components (map from JSX)

| JSX component | SwiftUI component | Notes |
|---|---|---|
| `Av` | `AvatarView` | Initials, color, optional glow ring |
| `Badge` | `NeonBadge` | Pill shape, neon tint background + border |
| `CircleProgress` | `RingGaugeView` | Trim-based circle, score + label |
| `DayBar` | `DayBarView` | Two bars + day label + pip dot |
| `MatchCard` | `MatchCardView` | Full active match card with accent bar |
| `BottomNav` | `FloatingTabBar` | Custom ZStack overlay, 6 tabs |
| `StatusBar` | System status bar | Use native SwiftUI status bar |
| `SecHead` | `SectionHeader` | Label + optional action link |
| Glass card variants | `.glassCard(variant)` ViewModifier | All 5 variants |

Keep shared components in `Views/Shared/`. Do not duplicate card logic across screens.

---

## 10. Interaction Map

Tap targets, their actions, navigation destinations, and backend writes for each major screen. This is the primary reference for ensuring nothing is left unwired.

### Home

| Tap target | Action | Navigates to | Backend write |
|---|---|---|---|
| Active match card | Open match | Match Details (active) | None — read only |
| Active card "Fight Back" / "Hold Lead" | Open match | Match Details (active) | None |
| Pending card Accept ✓ | Accept challenge | Stays on Home (card updates to active) | `match_participants.accepted_at = now()` |
| Pending card Decline ✗ | Decline challenge | Stays on Home (card removed) | `direct_challenges.status = 'declined'`, new `match_search_requests` row for challenger |
| Searching card Cancel | Cancel search | Stays on Home (card removed) | `match_search_requests.status = 'cancelled'` |
| Discover row Challenge | Open challenge flow pre-filled | Challenge flow Step 1 (Sport) | None at this point |
| BATTLE center button | Open challenge flow | Challenge flow Step 0 (Sport) | None at this point |
| Zero state CTA | Open challenge flow | Challenge flow Step 0 | None |
| Tab bar items | Navigate | Respective tab screen | None |

### Challenge Flow

| Tap target | Action | Navigates to | Backend write |
|---|---|---|---|
| Sport card (Steps / Calories) | Select sport | Step 1 (Format) | None |
| Format card | Select format | Step 2 (Opponent) | None |
| Quick Match button | Select random opponent | Step 3 (Review) | None |
| Opponent row | Select specific opponent | Step 3 (Review) | None |
| Send Challenge button | Submit challenge | Sent confirmation | `direct_challenges` row + `matches` row + `match_participants` rows |
| Quick Match (Step 2 path) | Submit search | Sent confirmation | `match_search_requests` row |
| Back to Home | Dismiss flow | Home | None |
| Back chevron (any step) | Go to previous step | Previous step | None |

### Match Details

| Tap target | Action | Navigates to | Backend write |
|---|---|---|---|
| Accept button (pending) | Accept match | Stays (state updates to active) | `match_participants.accepted_at = now()` |
| Decline button (pending) | Decline match | Back to Home | `direct_challenges.status = 'declined'` |
| Watch Live button (active) | Open live view | Live Match Screen | None |
| Rematch button (completed) | Start new match | Challenge flow (pre-filled with same opponent + settings) | None at this point |
| Back chevron | Go back | Previous screen (Home or Activity) | None |

### Live Match

| Tap target | Action | Navigates to | Backend write |
|---|---|---|---|
| Pause/Play button | Toggle step simulation pause | Same screen | None |
| Back chevron | Go back | Match Details | None |

### Activity

| Tap target | Action | Navigates to | Backend write |
|---|---|---|---|
| Active match row | Open match | Match Details (active) | None |
| Past match row | Open match | Match Details (completed) | None |

### Leaderboard

| Tap target | Action | Navigates to | Backend write |
|---|---|---|---|
| Global / Friends toggle | Switch tab | Same screen (data reloads) | None |
| User row (other user) | Open challenge flow targeting that user | Challenge flow Step 1 | None |

### Health

| Tap target | Action | Navigates to | Backend write |
|---|---|---|---|
| Steps / Calories toggle | Switch week chart | Same screen | None |
| Battle Readiness ring | Open readiness detail | Same screen (expand component breakdown) | None |

### Profile

| Tap target | Action | Navigates to | Backend write |
|---|---|---|---|
| Upgrade button | Open paywall | Paywall sheet | None |
| Settings row (chevron) | Open sub-setting | Respective settings detail | Varies |
| Notifications toggle | Toggle notifications | Same screen | `profiles.notifications_enabled` |
| Dev Mode toggle | Toggle dev mode | Same screen (log viewer appears/hides) | `UserDefaults` |
| Export Logs button | Share JSON export | Share sheet | None |
| Sign Out | Sign out | Auth screen | Supabase `signOut()` |

---

## 11. HealthKit and Background Sync

### What HealthKit can and cannot do

- HealthKit data is read **on-device only** — the backend cannot pull another user's HealthKit data directly
- The app reads authorized data from the current user's device and syncs it to Supabase
- Opponent's data appears in the app because their device has already synced it to the shared backend
- Authorization is per data type, per user, per device

### HealthKit types requested in v1

| Type | Used for |
|---|---|
| `HKQuantityTypeIdentifier.stepCount` | Match metric, battle readiness, health stats |
| `HKQuantityTypeIdentifier.activeEnergyBurned` | Match metric, battle readiness, health stats |
| `HKQuantityTypeIdentifier.restingHeartRate` | Battle Readiness score (HR component) |
| `HKCategoryTypeIdentifier.sleepAnalysis` | Battle Readiness score (sleep), sleep quality card |

### Sync strategy — best effort, not guaranteed intervals

Background freshness is **best effort**. The app uses multiple complementary channels to stay as fresh as possible, but cannot guarantee exact polling intervals while backgrounded.

| Trigger | What happens |
|---|---|
| App enters foreground | Full sync — `HKStatisticsQuery` for today's totals for all active match days → write to Supabase |
| HealthKit background delivery (`HKObserverQuery`) | Incremental sync when HealthKit wakes the app — read new samples, write delta to Supabase |
| App opens (any reason) | Fresh HealthKit read and Supabase sync |
| Push-triggered silent notification | App wakes in background, reads HealthKit, syncs to Supabase |
| Health screen opened | Full health data fetch including HR and sleep stages |

**Do not imply** that data updates on a fixed schedule (e.g. "every 10 minutes") while the app is closed. HealthKit background delivery frequency is controlled by iOS and varies. Design the UI to show `last_updated_at` where relevant so users understand data freshness.

### Stale data indicator

If `match_day_participants.last_updated_at` for the opponent is more than **~2 hours** ago, show a subtle "last updated a while ago" indicator on that user's stat in Match Details and Live Match.

### Anomaly detection

- Any single-day value > 50,000 steps (or calorie equivalent): set `metric_snapshots.flagged = true`
- Flagged data still counts in v1 — no automatic disqualification
- All flagged rows logged to `app_logs` (category: `healthkit_sync`)

---

## 12. Battle Readiness Formula

Computed on-device by `ReadinessCalculator` — a pure Swift function. Not stored in the database.

**Inputs from HealthKit:**
- `sleepHrs` — last night's total sleep hours
- `restingHR` — most recent resting heart rate (bpm)
- `stepsToday` — today's step count
- `calsToday` — today's active calories

**User-configurable goals** (stored in `UserDefaults`, shown in Settings):
- `sleepGoal` — default 8.0 hours
- `stepsGoal` — default 12,000
- `calsGoal` — default 650

**Formula:**
```
sleepScore = min(100, (sleepHrs / sleepGoal) × 100)
hrScore    = clamp((100 − restingHR) / 60 × 100, 0, 100)  // lower HR = better
stepsScore = min(100, (stepsToday / stepsGoal) × 100)
calsScore  = min(100, (calsToday / calsGoal) × 100)

readiness = round(sleepScore × 0.35 + hrScore × 0.25 + stepsScore × 0.25 + calsScore × 0.15)
```

**Score → label → color:**
- ≥ 75: "Strong Readiness" → `neon.cyan`
- 50–74: "Moderate Readiness" → `neon.yellow`
- < 50: "Low Readiness" → `neon.red`

**Missing data handling:** If any input is unavailable (e.g. no resting HR sample), exclude that factor and redistribute its weight across the others proportionally. Never crash or show NaN.

---

## 13. Matchmaking Logic

### Search flow

```
User taps Quick Match (from Challenge flow Step 2)
  → match_search_requests row created (status = 'searching')
  → Backend Edge Function triggered on INSERT to match_search_requests

Algorithm:
  → Find oldest open request with:
      ✅ Same metric_type    (required)
      ✅ Same duration_days  (required)
      ✅ Same start_mode     (required)
      🎯 Closest creator_baseline (preferred, tie-break by oldest created_at)
  → If found: pair immediately
  → If not found: request stays open (status = 'searching')
  → No timeout — stays searching until user cancels or a match is found

On successful pairing:
  → Create matches row (state = 'pending')
  → Create match_participants rows for both users
  → Update both match_search_requests: status = 'matched'
  → Notify both users: "Match found — tap to accept"
```

### Direct challenge flow

```
User selects a specific opponent in Step 2 → completes Step 3 → taps Send
  → direct_challenges row created (status = 'pending')
  → matches row created (state = 'pending')
  → match_participants rows: sender auto-accepted (accepted_at set immediately)
  → Recipient sees pending card on Home
  → Recipient accepts → all accepted → match.state = 'active'
  → Recipient declines → direct_challenges.status = 'declined'
                       → challenger: new match_search_requests row with same settings
```

---

## 14. Notifications

### Event types and messages

| Event | Recipient | Message |
|---|---|---|
| `match_found` | Both | "Your match is ready — tap to accept" |
| `challenge_received` | Recipient | "[Name] challenged you — tap to respond" |
| `challenge_declined` | Challenger | "[Name] declined your challenge" |
| `match_active` | Both | "Your match is live. Day 1 starts now." |
| `lead_changed` | Trailing user | "[Name] just passed you — they're up X steps" |
| `morning_checkin` | Both | "Day N of M — you're [ahead/behind/tied]. Today matters." |
| `pending_reminder` | Non-accepting participant | "You have a pending match — [Name] is waiting" |
| `day_won` | Winner | "You won Day N! Series: X–Y" |
| `day_lost` | Loser | "[Name] won Day N. Series: X–Y — fight back tomorrow." |
| `day_void` | Both | "Day N was voided — data unavailable for both." |
| `match_won` | Winner | "You won the match X–Y. Rematch?" |
| `match_lost` | Loser | "[Name] won X–Y. Rematch?" |

**Daily cap:** Max 10 notifications per user per day.

**Pending reminders:** Fire daily until recipient accepts or match is cancelled.

**Notification payload** (every notification must include):
```json
{
  "match_id": "uuid",
  "opponent_display_name": "string",
  "metric_type": "steps | active_calories",
  "deep_link_target": "home | match_details | activity"
}
```

### Live Activities

- Start when match → `active`
- Content: both display names, current day metric totals, series score, day N of M
- Update via ActivityKit push on every backend sync
- Dismiss when match → `completed`

---

## 15. Backend Contract (Edge Functions and Jobs)

These are the backend responsibilities that must be implemented. None of the client code should duplicate this logic.

| Function / Job | Trigger | Responsibility | Idempotency note |
|---|---|---|---|
| `matchmaking-pairing` | INSERT on `match_search_requests` | Find compatible open request, create `matches` + `match_participants`, update both requests, notify both users | Safe to re-run — check if request is already matched before pairing |
| `on-all-accepted` | UPDATE on `match_participants.accepted_at` | Detect when all participants have `accepted_at` set → set `match.state = 'active'` → fire `match_active` notification | Check state before writing — avoid double-activation |
| `sync-metric-snapshot` | Called by client on every HealthKit sync | Write `metric_snapshots` row, update `match_day_participants.metric_total`, update `user_health_baselines` | Safe — appends to snapshots, overwrites metric_total |
| `finalize-match-day` | Triggered when all `data_status = 'confirmed'` OR by cutoff cron | Write `finalized_value`, set `winner_user_id`, set `status = 'finalized'`, fire day notifications, update leaderboard + all-time bests, check for match completion | Guard on `status != 'finalized'` before writing |
| `day-cutoff-check` | pg_cron — runs hourly | Find any `match_day_participants` where user's local time is past 10am and `data_status = 'pending'` → force confirm → trigger `finalize-match-day` | Idempotent — only acts on pending rows |
| `complete-match` | Called by `finalize-match-day` when all days done | Set `match.state = 'completed'`, set `completed_at`, fire match result notifications | Guard on `state != 'completed'` |
| `update-leaderboard` | Called by `finalize-match-day` | Update `leaderboard_entries` for current week — add points, update wins/losses/streak, re-rank | Additive — safe to re-run with same inputs |
| `dispatch-notification` | Called by other functions | Write `notification_events` row, check daily cap, send APNs push | Check cap before sending — do not exceed 10/day |
| `send-pending-reminders` | pg_cron — runs daily | Find all pending matches where recipient has not accepted → send `pending_reminder` notification | Only send one per match per day |
| `send-morning-checkins` | pg_cron — runs daily (morning) | Find all active matches → send `morning_checkin` notification to each participant | Only send one per match per day |

**Auth expectations:** All Edge Functions validate the requesting user via Supabase JWT. Client-facing functions (sync, accept, decline, cancel) verify the caller is a participant. Finalization functions run as service role.

**Realtime subscriptions the client listens to:**
- `matches` table — state changes for matches the user is in
- `match_day_participants` table — metric_total updates for active match days
- `match_search_requests` table — status changes for open searches

---

## 16. Logging System

### Categories
`auth` · `onboarding` · `matchmaking` · `match_state` · `healthkit_read` · `healthkit_sync` · `notifications` · `paywall` · `network` · `ui` · `error`

### Requirements
- Log ALL match state transitions with before/after state
- Log ALL HealthKit reads with returned value
- Log ALL matchmaking events
- Filterable by time range and level in Dev Tools UI
- Exportable as JSON via share sheet
- Dev Tools log viewer only shown when Dev Mode is on

---

## 17. Paywall and Monetization

| Feature | Free | Premium |
|---|---|---|
| Match slots (searching + pending + active combined) | 1 | Unlimited |
| Dev Mode | Dev builds only | Dev builds only |

**Paywall timing:** Never shown before user has completed at least one match. After winning first match = soft upsell (not hard block).

**Pricing:** $4.99/month · $29.99/year. RevenueCat from day one.

**Dev Mode:** Toggle in Profile / Settings. Only compiled into `#if DEBUG` builds. When on, `SubscriptionService` returns `premium` regardless of actual entitlement. Stored in `UserDefaults`.

---

## 18. Architecture

### Layers

| Layer | Responsibility |
|---|---|
| SwiftUI Views | Render state, handle taps, navigate — no logic |
| ViewModels | Hold UI state, call services, coordinate data |
| Services | Business logic — matchmaking, health sync, notifications, readiness, subscriptions |
| Repositories | All Supabase read/write — one repo per domain area |
| Backend | Edge Functions own all state transitions, finalization, notifications |
| External | HealthKit, APNs, ActivityKit, RevenueCat |

### Architecture rules (non-negotiable)

- Views **never** query Supabase directly
- Views **never** call `HKHealthStore` directly
- All Supabase access goes through repository or service layers
- All HealthKit access goes through `HealthKitService` only
- Match state transitions owned by backend Edge Functions
- Day finalization owned by backend — client never writes `finalized_value`
- Series score always derived — never stored, never computed in views
- `ReadinessCalculator` is a pure Swift function — unit testable, not in views
- Leaderboard points computed by backend after each finalization

---

## 19. Cursor Rules

*Save as `FitUp-App/.cursor/rules.md`.*

```markdown
# FitUp — Cursor Rules

## Repo and project
- Repo root: FitUp-App/
- Open FitUp-App/ in Cursor (not a subdirectory)
- Xcode project: FitUp-App/FitUp/FitUp.xcodeproj
- Do NOT restructure the Xcode project layout
- Add new Swift files inside FitUp-App/FitUp/FitUp/ using Xcode groups

## Primary references
1. FitUp-App/docs/fitup-docs-pack.md — architecture, state machine, data model, scoring rules
2. FitUp-App/FitUp/docs/mockups/FitUp_Final_Mockup.jsx — single source of truth for ALL UI
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
```

---

## 20. Decisions Log

### Confirmed and locked

| Decision | Value |
|---|---|
| Platform | iOS only, SwiftUI, min iOS 18, Swift 5 |
| UI reference | `FitUp_Final_Mockup.jsx` — source of truth for all UI |
| UI aesthetic | Dark/neon — cyan #00FFE0, near-black #04040A, glass cards |
| Project structure | Do not restructure Xcode project — add files within existing layout |
| Backend | Supabase (Postgres + Edge Functions + Realtime) |
| Auth | Sign in with Apple + email auth |
| V1 metrics | Steps and active calories |
| V1 team style | 1v1 only |
| V1 durations | 1, 3, 5, 7 days (odd only → always a winner) |
| Home section order | Searching → Active → Pending → Discover Players |
| Challenge flow | 4-step (Sport → Format → Opponent → Review/Send) |
| Bottom nav | 6 tabs, floating card, rounded all 4 corners |
| Live Match | V1 launch, from Match Details only |
| Leaderboard | V1, weekly points system, global + friends |
| HealthKit types | stepCount, activeEnergyBurned, restingHeartRate, sleepAnalysis |
| Health sync | Best-effort via observer queries, background delivery, foreground sync, push-triggered |
| Battle Readiness | On-device formula: 35% sleep + 25% HR + 25% steps + 15% cals |
| Start modes | Today / Tomorrow |
| Matchmaking | Longest-waiting compatible; creator_baseline as tie-break |
| Search expiry | Never — user cancels manually |
| Pending expiry | Never — daily reminders until accepted |
| Free tier | 1 total slot across searching + pending + active |
| No manual entry | Ever — zero exceptions |
| Timezone cutoffs | Each user's local timezone, independently |
| Finalization cutoff | 10:00 AM each user's local timezone |
| finalized_value | Written once, never changed |
| Void rule | All at 0 → void day, no point |
| Series score | Always derived — never stored |
| Notification cap | 10 per user per day |
| Paywall timing | Never before first match completed |
| Monthly price | $4.99 |
| Annual price | $29.99 |
| RevenueCat | Configured day one |
| Dev Mode | Debug builds only — absent from production |
| Onboarding first match | 1 day, steps, today — single tap to start |

### Open items — `[CONFIRM]`

| Question | Affects |
|---|---|
| Stale indicator exact threshold (currently ~2 hours) | Health sync UI copy |
| Leaderboard points formula — use as documented or adjust? | Slice 11 |

---

*End of fitup-docs-pack.md — update Section 20 after every session.*
