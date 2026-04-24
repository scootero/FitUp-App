# FitUp — Docs Pack
*Single source of truth. Update the Decisions Log after every session.*
*Last updated: April 2026 (migrations-as-truth pass + nav/design as-built)*

**# As-built rebuild:** Headings and table rows prefixed with **`#`** were added April 2026 to capture implementation reality (paths, backend slices, portals, config) for cloning the repo to the current app state. They supplement — not replace — the original spec.

---

## How to use these docs

Two files make up the complete spec:
- **fitup-docs-pack.md** (this file) — what the system IS
- **fitup-build-slices.md** — how to BUILD it, slice by slice

**# Path note:** From the repository root, docs live under **`FitUp/docs/`** (e.g. `FitUp/docs/fitup-docs-pack.md`). Older text may say `FitUp-App/docs/` — treat that as the same files inside the `FitUp` folder.

**UI reference file:** `FitUp/docs/mockups/FitUp_Final_Mockup.jsx`
This JSX file is the single source of truth for all visual design. Every screen, component, animation, color, spacing, and layout must be implemented to match it as closely as practical in SwiftUI. Cursor must read the relevant components before implementing any UI. Sections marked `[MOCK DATA]` must be replaced with real data from HealthKit or the backend.

For Cursor: highest-priority sections are **6 (State Machine)**, **7 (Data Model)**, **8 (Scoring)**, **9 (Design System)**, **10 (Interaction Map)**, **15 (Backend Contract)**, **16 (Supabase local / backup)**, and **20 (Cursor Rules)**.

Items marked **`[CONFIRM]`** need a final answer before the relevant slice is built. Everything else is locked.

---

## 1. Product Overview

FitUp is a challenge-first iOS fitness app. Users compete in 1v1 matches using real HealthKit data.

**Core loop:** Create or search → get matched → accept → compete daily → see who won each day → rematch.

| Field | Value |
|---|---|
| Platform | iOS only, SwiftUI, minimum **iOS 18.6** (as deployed; original spec was iOS 18) |
| Backend | Supabase (Postgres, Edge Functions, Realtime) |
| Health data | Apple HealthKit — on-device authorized reads only |
| Subscriptions | RevenueCat — configured day one |
| Notifications | APNs + ActivityKit (Live Activities) |
| UI reference | `FitUp/docs/mockups/FitUp_Final_Mockup.jsx` (repo root → `FitUp/` folder) |

---

## 2. V1 Scope

### In scope

- 1v1 matches only
- Metrics: steps, active calories
- Durations: 1, 3, 5, 7 days (displayed as Daily, First to 3, Best of 5, Best of 7 in Challenge flow UI)
- Start options: today (includes steps already accumulated today) or tomorrow (begins at midnight)
- Public matchmaking search (longest-waiting compatible user first)
- Direct challenges to any user in the discovery list
- Home screen: stats row, Searching, Pending, Active, past matches, Discover Players (**as built:** section order differs slightly from the original JSX order; there is **no separate Activity tab** — history and stats live on Home)
- Match Details: per-day bar chart, live totals, series score, provisional/finalized indicators
- Live Match screen: real-time step race (accessible from active Match Details only — not in nav)
- Challenge creation flow: 4-step (Sport → Format → Opponent → Review/Send)
- Activity / history: active and past matches surfaced on **Home** (and Match Details), backed by `ActivityRepository` — not a standalone tab in the shipped app
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

Current layout (preserve this exactly — **#** reconciled to actual repo roots):
```
<repo root>/
├── .cursor/
│   └── rules.md                 ← Cursor rules (repo root)
├── supabase/                    ← # AUTHORITATIVE backend: migrations, Edge Functions, cron.sql, roles.sql
│   ├── migrations/              ← # apply in filename order; full schema in 20260416114943_remote_schema.sql
│   ├── functions/               ← # one folder per Edge Function — deploy with Supabase CLI
│   ├── cron.sql                 ← # pg_cron schedules (apply to project after migrations)
│   ├── roles.sql                ← # optional: roles/grants dump
│   └── config.toml
└── FitUp/
    ├── docs/
    │   ├── fitup-docs-pack.md
    │   ├── fitup-build-slices.md
    │   ├── slice-tracker.md       ← # per-slice implementation log
    │   ├── supabase-setup-guide.md  ← # full Supabase runbook (architecture + manual path + CLI path); migrations still win on schema drift
    │   └── mockups/
    │       └── FitUp_Final_Mockup.jsx
    ├── FitUp.xcodeproj
    └── FitUp/
        ├── Config/                ← # xcconfig, Secrets.xcconfig (gitignored), entitlements, Info plists
        ├── FitUp/                 ← # main app target sources (synchronized group)
        │   ├── FitUpApp.swift
        │   ├── ContentView.swift
        │   ├── Design/            ← # DesignTokens.swift
        │   ├── Views/             ← # Auth, Home, Challenge, MatchDetails, LiveMatch, Health, Profile, Shared, LiveActivity/, Paywall/, etc.
        │   ├── ViewModels/
        │   ├── Services/
        │   ├── Repositories/
        │   ├── Models/
        │   └── Utilities/
        └── FitUpWidgetExtension/  ← # ActivityKit Live Activity extension (`FitUpLiveActivity.swift`)
```

**Adding new files:** All new Swift files are added inside `FitUp-App/FitUp/FitUp/`. Organize using Xcode groups (which map to folders). The target membership of every new Swift file must be the FitUp app target.

**Recommended group structure inside `FitUp/FitUp/` (main app sources):**
```
FitUp/FitUp/
├── Design/             ← DesignTokens.swift
├── Views/
│   ├── Auth/
│   ├── Onboarding/
│   ├── Home/
│   ├── Challenge/
│   ├── MatchDetails/
│   ├── LiveMatch/
│   ├── Activity/       ← row components used from Home / future screens
│   ├── Leaderboard/
│   ├── Health/
│   ├── Profile/
│   ├── Paywall/
│   ├── LiveActivity/   ← shared ActivityKit attributes / coordinator (extension target also has widget)
│   └── Shared/
├── ViewModels/
├── Services/
├── Repositories/
├── Models/
└── Utilities/
```

`FitUpApp.swift` and `ContentView.swift` live alongside the groups under `FitUp/FitUp/FitUp/`. Cursor should add files to these groups without unnecessary project churn. If a group folder does not exist, create it.

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

**As-built tab order (4 slots + center Battle — no separate Activity tab):**
```
Home | Health | ⚔️ BATTLE (center, floats 14pt above bar) | Ranks | Profile
```
The JSX mockup shows six labels; the shipped app uses **`MainTab`** with four edge tabs plus the floating Battle button (`FloatingTabBar.swift`). Past/active match history appears on **Home** (`PastMatchesSection`, stats row), not on a dedicated Activity tab.

Center ⚔️ BATTLE button spec:
- `width: 54pt, height: 54pt` — corner radius ~`16–18pt` (see `FloatingTabBar` implementation)
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
              ├── tap past match row (Home) → Match Details
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
| Section order (as built) | **Stats → Searching → Pending → Active → Past matches → Discover** (differs from original JSX order; Pending before Active) |
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

#### Activity (history on Home — as built)

| | |
|---|---|
| Stats row | On **Home**: Matches, Wins, Win Rate (see `HomeView`) |
| Past matches | On **Home**: `PastMatchesSection` — tap row → Match Details |
| JSX reference | Mockup `ActivityScreen` — behavior folded into Home in the current app |

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
| Sleep Quality | Last night: duration + hypnogram + Sleep Ratio (see **Section 11 — Sleep data**); 7-night average + variance + bars |
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

State transitions are owned by the backend (Postgres triggers + Edge Functions). The client reads state and renders — it never writes `finalized_value` or finalization fields.

**Use the right row type:** *Searching* lives on **`match_search_requests`**. *Declined* lives on **`direct_challenges`**. **`matches.state`** is constrained in migrations to: `'searching' | 'pending' | 'active' | 'completed' | 'cancelled'` — there is **no** `'declined'` value on `matches` (see `supabase/migrations/*_remote_schema.sql`).

### States — `match_search_requests.status`

| Status | Meaning |
|---|---|
| `searching` | Open queue row; waiting for compatible opponent |
| `matched` | Paired; `matched_match_id` set |
| `cancelled` | User cancelled search |

### States — `direct_challenges.status`

| Status | Meaning |
|---|---|
| `pending` | Recipient has not accepted/declined |
| `accepted` | Linked to a match |
| `declined` | Recipient declined |

### States — `matches.state` (database)

| State | Meaning |
|---|---|
| `searching` | Allowed by DB check (rare/legacy paths); most flows use `pending` after pairing |
| `pending` | Match created; participants must accept (where applicable) |
| `active` | All accepted; competition running |
| `completed` | All days finalized |
| `cancelled` | Cancelled (e.g. public matchmaking declined path) |

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
| `pending` → declined (challenge) | Opponent taps Decline | Client updates **`direct_challenges.status = 'declined'`** (not `matches.state`) | Challenger: "Declined" |
| `active` → `completed` | Last `match_day` finalized | Edge Function `complete-match` | Both: final result |

**Expiry rules:**
- Searching: **never expires automatically** — user must cancel manually
- Pending: **never expires automatically** — daily reminder notifications sent until accepted

---

## 7. Data Model

**Canonical schema:** `supabase/migrations/` — especially `20260416114943_remote_schema.sql` (the earlier migration file may be empty). Do **not** treat app-only guesses or old manual SQL files as authoritative.

### Table inventory (14 `public` tables)

| Table | Purpose |
|---|---|
| `profiles` | User identity, display name, initials, tier, **apns_token**, **live_activity_push_token**, **notifications_enabled**, timezone |
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
-- See migration for full RLS, indexes, and constraints. Shape (abridged):
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
  updated_at        timestamptz NOT NULL DEFAULT now(),
  notifications_enabled boolean NOT NULL DEFAULT true,
  live_activity_push_token text
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

**Visual source of truth:** `FitUp/docs/mockups/FitUp_Final_Mockup.jsx` — the `T` object at the top.

**Swift implementation:** `FitUp/FitUp/FitUp/Design/DesignTokens.swift`. The code uses **`FitUpColors`**, **`FitUpRadius`**, **`FitUpFont`**, **`GlassCardVariant`**, and view modifiers (`.glassCard`, `.solidButton`, `.ghostButton`, `BackgroundGradientView`, `ScreenTransitionModifier`) — these map 1:1 to JSX concepts (`T.neon.*`, `T.radius.*`, `glassCard()`, `BG_STYLE`, `ScreenIn`). **No ad hoc hex in feature code** — use tokens.

### Colors (JSX token → Swift)

| JSX / doc token | Swift (`DesignTokens.swift`) | Hex (approx.) | Semantic use |
|---|---|---|---|
| `bg.base` | `FitUpColors.Bg.base` | `#04040A` | App background |
| `neon.cyan` | `FitUpColors.Neon.cyan` | `#00FFE0` | Win state, user accent, primary CTA |
| `neon.blue` | `FitUpColors.Neon.blue` | `#00AAFF` | Pending/searching, secondary actions |
| `neon.orange` | `FitUpColors.Neon.orange` | `#FF6200` | Lose state, opponent accent |
| `neon.yellow` | `FitUpColors.Neon.yellow` | `#FFE000` | Premium, gold, rank #1 |
| `neon.pink` | `FitUpColors.Neon.pink` | `#FF2D9B` | Decline, danger |
| `neon.purple` | `FitUpColors.Neon.purple` | `#BF5FFF` | Matchmaking, random opponent |
| `neon.green` | `FitUpColors.Neon.green` | `#39FF14` | Live/synced badge, Watch Live button |
| `neon.red` | `FitUpColors.Neon.red` | `#FF3B3B` | Error, low Battle Readiness |
| `text.primary` | `FitUpColors.Text.primary` | `#FFFFFF` | Main text |
| `text.secondary` | `FitUpColors.Text.secondary` | ~52% white | Supporting text |
| `text.tertiary` | `FitUpColors.Text.tertiary` | ~27% white | Labels, placeholders |
| (Health sleep stages) | `FitUpColors.HealthSleepStage.*` | — | Hypnogram / sleep UI on Health |

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

| Name | Value | Swift |
|---|---|---|
| `sm` | 10pt | `FitUpRadius.sm` |
| `md` | 16pt | `FitUpRadius.md` |
| `lg` | 22pt | `FitUpRadius.lg` |
| `xl` | 28pt | `FitUpRadius.xl` |
| `pill` | 999pt | `FitUpRadius.pill` |

### Fonts

Map to system fonts via **`FitUpFont`** (no custom font files):
- `font.display` → `FitUpFont.display(size:weight:)` — SF system bold display style
- `font.body` → `FitUpFont.body(size:weight:)` — SF system text
- `font.mono` → `FitUpFont.mono(size:weight:)` — SF monospaced

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
| `BottomNav` | `FloatingTabBar` | Custom ZStack overlay, **4 tabs + center Battle** (as built) |
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
| Past match row | Open match | Match Details (completed) | None |
| Stats row (where present) | Informational | — | None |
| Tab bar items | Navigate | Home / Health / Ranks / Profile (no Activity tab) | None |

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
| Back chevron | Go back | Previous screen (typically Home) | None |

### Live Match

| Tap target | Action | Navigates to | Backend write |
|---|---|---|---|
| Pause/Play button | Pause **local** progress animation (Realtime + HealthKit still update) | Same screen | None |
| Back chevron | Go back | Match Details | None |

### Activity (same interactions on Home — as built)

There is no Activity tab; the mockup’s Activity list behaviors map to **Home** rows (see **Home** table above).

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
| Health screen opened | Full health data fetch including HR and sleep (last night uses **18:00 → 12:00 local** window; see **Section 11 — Sleep data**) |

**Do not imply** that data updates on a fixed schedule (e.g. "every 10 minutes") while the app is closed. HealthKit background delivery frequency is controlled by iOS and varies. Design the UI to show `last_updated_at` where relevant so users understand data freshness.

### Stale data indicator

If `match_day_participants.last_updated_at` for the opponent is more than **~2 hours** ago, show a subtle "last updated a while ago" indicator on that user's stat in Match Details and Live Match.

### Anomaly detection

- Any single-day value > 50,000 steps (or calorie equivalent): set `metric_snapshots.flagged = true`
- Flagged data still counts in v1 — no automatic disqualification
- All flagged rows logged to `app_logs` (category: `healthkit_sync`)

### Sleep data (HealthKit) — authoritative implementation

**Source:** `HKCategoryTypeIdentifier.sleepAnalysis` only. Apple does **not** expose a single “total sleep” API; FitUp computes all totals and percentages from raw `HKCategorySample` rows processed in [`HealthKitService`](FitUp/FitUp/FitUp/Services/HealthKitService.swift).

**Implementation slice:** **`fitup-build-slices.md` — Slice 15** (Sleep aggregation and stage percentages; depends on Slice 12). Locks the rules below. **Do not revert** to wake-day-only assignment, single-session selection, longest-block-only totals, or raw-sum-without-overlap handling without explicit review and Apple Health validation.

#### Definition: “Last night” (local time)

| Boundary | Rule |
|---|---|
| Window start | **Previous calendar day 18:00** (6 PM), **local** (`Calendar.current`) |
| Window end | **Current calendar day 12:00** (noon), **local** |

All `sleepAnalysis` samples that **overlap** `[window_start, window_end)` belong to that night. This is a **fixed clock window**, not `startOfDay` wake-day filtering and not “latest session” or “longest contiguous block” selection.

#### Aggregation pipeline

1. **Fetch** all `sleepAnalysis` samples whose time range intersects the night window (query range must cover the window; no Ring-only / single-source filtering — overlaps are resolved in software).
2. **Include** stages: `asleepDeep`, `asleepCore`, `asleepREM`, `asleepUnspecified` (mapped to “light” buckets in UI math where noted).
3. **Exclude** `awake` from **total sleep** and from **percentage denominators**.
4. **Overlap resolution:** use existing priority-based winner per sub-interval (`winningSleepCategory` / `sleepCategoryPriority`); **never** sum overlapping wall-clock time twice.
5. **Window clipping:** window edges are included in the boundary sweep so accumulation matches the 18:00–12:00 span (see `canonicalMetricsAccumulating` + `clipToMidpointsIn`).

#### Total sleep

`total_sleep` = **deep + core + rem + unspecified** (seconds summed after overlap resolution and window clip). Unspecified may be rolled into **light** for percentage math in `sleepRatioBreakdown`. **Awake** and **inBed** do not add to “time asleep” totals (see `HealthKitService` resolution rules).

#### Stage percentages (UI — critical)

Percents for the **Sleep Ratio** card come **only** from [`SleepRatioBreakdown`](FitUp/FitUp/FitUp/Services/HealthKitService.swift) (`deepPercent`, `lightPercent`, `remPercent`) — i.e. **not** from ad-hoc `deep`/`core`/`rem` fields that could accidentally include **awake** in the denominator.

| Concept | Formula |
|---|---|
| Denominator | `total_sleep = deep + core + rem` (core includes merged unspecified where applicable in `sleepRatioBreakdown`) |
| Deep % | `deep / total_sleep × 100` |
| Light % | `(core + unspecified) / total_sleep × 100` as **light** (labeled “Light” in UI) |
| REM % | `rem / total_sleep × 100` |

**Awake** is **never** in the denominator. [`SleepRatioCard`](FitUp/FitUp/FitUp/Views/Health/Cards/SleepRatioCard.swift) reads `summary.lastNightSleepRatio` only.

#### Seven-night aggregate

- **Bars / nightly hours:** wake-day canonical metrics may still be used for **7-night charts** (historical design); **last night** uses the **clock window** above.
- **Averages:** one value per night in range, then average over the last 7 nights (see `HealthSleepSummary` fields).

#### No data

- If there is no qualifying sleep in the window: total sleep = 0; UI shows **“No sleep data from last night”** (and related empty states).

#### Do / don’t (enforcement)

| Don’t | Do |
|---|---|
| Use `startOfDay` **alone** to define “last night” for the **primary** total now shown on Health | Use the **18:00 → 12:00** window for last-night totals and hypnogram |
| Select a single session or only the longest contiguous asleep block for **last night** | Aggregate **all** segments in the window after overlap resolution |
| Sum raw samples ignoring overlaps | Keep **priority merge** at duplicate instants |
| Include **awake** in total sleep or in % denominator for Sleep Ratio | Exclude **awake**; use `SleepRatioBreakdown` for displayed % |
| Restrict to one hardware source | Treat HealthKit as **multi-source**; dedupe by overlap rules, not by dropping sources |

Any change to the window bounds, aggregation pass, or percentage basis requires **product + engineering review** and re-validation against Apple Health.

---

## 12. Battle Readiness Formula

Computed on-device by `ReadinessCalculator` — a pure Swift function. Not stored in the database.

**Inputs from HealthKit:**
- `sleepHrs` — last night's total sleep hours (same **18:00 → 12:00 local** window as Health screen; see **Section 11 — Sleep data**)
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
  → Postgres trigger / `pg_net` invokes **`matchmaking-pairing`** Edge Function (see migrations — not a separate client call)

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

### # Match found celebration (as built)

When a push for a new pending match arrives, **`NotificationService`** can queue a match id on **`SessionStore`**. **`HomeViewModel`** + **`MatchFoundCelebrationStore`** (UserDefaults-backed dedupe per profile+match) show a one-time **“Match found”** overlay on Home so the moment is visible even if the user was not staring at Pending. Dismiss marks the celebration shown for that match.

---

## 15. Backend Contract (migrations, Edge Functions, cron)

**Canonical source:** `supabase/migrations/*.sql` — especially `20260416114943_remote_schema.sql`. **`supabase/cron.sql`** holds pg_cron schedules. **`supabase/functions/`** holds Edge Function source. Step-by-step setup (Dashboard vs CLI), diagrams, and checklists: **`FitUp/docs/supabase-setup-guide.md`**. If anything disagrees with migrations, **migrations win**.

### # Client — HealthKit → Postgres (no `sync-metric-snapshot` Edge Function)

The iOS app uses **`MetricSyncCoordinator`** + **`MetricSnapshotRepository`** + **`MatchDayRepository`** + **`HealthKitService`** to write **`metric_snapshots`**, update **`match_day_participants.metric_total`**, and upsert **`user_health_baselines`** using the Supabase Swift client with the user’s JWT. There is **no** `sync-metric-snapshot` function in `supabase/functions/` in this repo; do not document one as deployed unless you add it.

### # Postgres functions and triggers (non-exhaustive — see migration)

Notable **`public`** RPCs / jobs: `activate_match_with_days`, `create_direct_challenge`, `current_user_match_ids`, `day_cutoff_check`, `decline_pending_match`, `finalize_when_all_confirmed`, `head_to_head_stats`, `matchmaking_pair_atomic`, `matchmaking_retry_stale_searches`, `notify_*`, `push_live_activity_updates`, `tr_matchmaking_pairing_after_insert`, `tr_on_all_accepted_after_participant`, etc.

Notable **`private`** helpers: `invoke_edge_function`, `invoke_dispatch_notification`, `invoke_finalize_match_day`, `invoke_matchmaking_pairing`, `invoke_on_all_accepted`, `notification_sent_today`, `resolve_leader_user`.

**Triggers (from migration):** e.g. `tr_matchmaking_pairing_after_insert` on `match_search_requests`; `tr_on_all_accepted_after_participant` on `match_participants`; `tr_finalize_when_all_confirmed`, `tr_notify_lead_changed`, `tr_push_live_activity_updates` on `match_day_participants`; challenge notify triggers on `direct_challenges`; `tr_notify_public_matchmaking_declined` on `matches`.

### Edge Functions (`supabase/functions/`)

| Function | Role |
|---|---|
| `matchmaking-pairing` | Invoked after new search row (via trigger/`pg_net`); pairs compatible requests |
| `retry-matchmaking-search` | Authenticated client retry when pairing delivery failed (`MatchRepository.retryMatchmakingSearch`) |
| `on-all-accepted` | Activation when all participants accepted |
| `finalize-match-day` | Locks a match day, scores, notifications, leaderboard hook |
| `complete-match` | Marks match completed when all days finalized |
| `update-leaderboard` | Points / ranks for weekly leaderboard |
| `dispatch-notification` | APNs + `notification_events` audit |
| `send-pending-reminders` | Cron-invoked pending nudges |
| `send-morning-checkins` | Cron-invoked morning copy |

### pg_cron (`supabase/cron.sql`)

| Job name | Schedule | Purpose |
|---|---|---|
| `day-cutoff-check` | `5 * * * *` (hourly at :05) | `public.day_cutoff_check()` |
| `send-pending-reminders` | `15 16 * * *` | `private.invoke_edge_function('send-pending-reminders', …)` |
| `send-morning-checkins` | `0 13 * * *` | `private.invoke_edge_function('send-morning-checkins', …)` |
| `matchmaking-retry-stale` | `* * * * *` | `public.matchmaking_retry_stale_searches(5, 30)` |

### Auth and Realtime

- Edge Functions that act on behalf of users expect a **valid Supabase JWT** where applicable; service-role paths are used from DB/`pg_net` for trusted invokes.
- **Realtime (client):** subscribe to `matches`, `match_day_participants`, `match_search_requests` for the current user’s flows (see repositories / view models).

---

## 16. Supabase Local Setup & Backup (Migration-Based Workflow)

### Overview

This workflow establishes a local Supabase development environment aligned with the repo’s **versioned** schema and backend logic. It ensures local reproducibility, safe backups of structure, and a **migration-driven** change process (not dashboard-only edits).

### Setup process

#### 1. Initialize Supabase locally

```bash
supabase init
```

If a `supabase` folder already exists and you want a safe backup before re-initializing:

```bash
mv supabase supabase_old_backup
```

#### 2. Link to remote project

```bash
supabase link --project-ref <PROJECT_REF>
```

#### 3. Repair migration history (if needed)

If Supabase reports mismatched migrations:

```bash
supabase migration repair --status applied <migration_id>
```

Use when local and remote histories diverged or you adopted migrations after dashboard edits. Verify:

```bash
supabase migration list
```

#### 4. Pull database schema (requires Docker)

```bash
supabase db pull
```

Requirements: Docker running (`docker ps`). This generates migration files from the linked remote project.

#### 5. Commit migrations

```bash
git add supabase
git commit -m "Add Supabase migrations"
```

### Edge Functions backup

Download or sync all functions:

```bash
supabase functions download
```

Keep `supabase/functions/` in Git alongside migrations.

### Roles / RLS backup

```bash
supabase db dump --role-only > supabase/roles.sql
```

### Cron jobs backup

Supabase does not automatically export all cron definitions. Maintain **`supabase/cron.sql`** in the repo (copy from dashboard / `cron.job` definitions as needed).

### Git workflow

Use branches for backend changes; review before merge.

### Expected folder structure

```
supabase/
├── migrations/
├── functions/
├── roles.sql      ← optional
├── cron.sql       ← in repo for this project
└── config.toml
```

### Rules going forward

- Prefer **migrations** for schema changes; avoid dashboard-only drift.
- Treat **`/supabase`** as the single source of truth for backend shape.
- Keep functions and SQL in sync with production.

### Command reference (quick)

```bash
supabase init
mv supabase supabase_old_backup   # optional safety
supabase link --project-ref <PROJECT_REF>
supabase migration repair --status applied <migration_id>
supabase migration list
supabase db pull
docker ps
supabase functions download
supabase db dump --role-only > supabase/roles.sql
git add supabase
git commit -m "Add Supabase migrations"
```

---

## 17. Logging System

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

## 18. Paywall and Monetization

| Feature | Free | Premium |
|---|---|---|
| Match slots (searching + pending + active combined) | 1 | Unlimited |
| Dev Mode | Dev builds only | Dev builds only |

**Paywall timing:** Never shown before user has completed at least one match. After winning first match = soft upsell (not hard block).

**Pricing:** $4.99/month · $29.99/year. RevenueCat from day one.

**Dev Mode:** Toggle in Profile / Settings. Only compiled into `#if DEBUG` builds. When on, `SubscriptionService` returns `premium` regardless of actual entitlement. Stored in `UserDefaults`.

---

## 19. Architecture

### Layers

| Layer | Responsibility |
|---|---|
| SwiftUI Views | Render state, handle taps, navigate — no logic |
| ViewModels | Hold UI state, call services, coordinate data |
| Services | Business logic — **`MetricSyncCoordinator`** (HealthKit→Supabase orchestration), **`HealthKitService`**, **`NotificationService`**, **`SubscriptionService`**, **`MatchmakingService`**, **`DirectChallengeService`**, **`ReadinessCalculator`**, etc. |
| Repositories | All Supabase read/write — one repo per domain area |
| Backend | Postgres (RLS, triggers, RPCs) + **Edge Functions** — pairing, activation, finalization, notifications, leaderboard |
| External | HealthKit, APNs, ActivityKit, RevenueCat |

**Third-party wiring:** `AppThirdPartyConfig` in `SupabaseProvider.swift` configures **Supabase** and **RevenueCat** from Info.plist / xcconfig keys. **`AppDelegate`** forwards APNs device token registration to **`NotificationService`**.

### Architecture rules (non-negotiable)

- Views **never** query Supabase directly
- Views **never** call `HKHealthStore` directly
- All Supabase access goes through repository or service layers
- All HealthKit access goes through `HealthKitService` only
- Match state transitions owned by **Postgres (triggers/RPCs) and Edge Functions** — not by ad hoc client writes to `matches.state`
- Day finalization owned by backend — client never writes `finalized_value`
- Series score always derived — never stored, never computed in views
- `ReadinessCalculator` is a pure Swift function — unit testable, not in views
- Leaderboard points computed by backend after each finalization

---

## 20. Cursor Rules

*Save as `<repo root>/.cursor/rules.md`.*

```markdown
# FitUp — Cursor Rules

## Repo and project
- Repo root: FitUp-App/
- Open FitUp-App/ in Cursor (not a subdirectory)
- Xcode project: FitUp-App/FitUp/FitUp.xcodeproj
- Do NOT restructure the Xcode project layout
- Add new Swift files inside FitUp-App/FitUp/FitUp/ using Xcode groups

## Primary references
1. FitUp/docs/fitup-docs-pack.md — architecture, state machine, data model, scoring rules
2. FitUp/docs/mockups/FitUp_Final_Mockup.jsx — single source of truth for ALL UI
   Read the relevant JSX components before implementing any screen.
   Every color, spacing, animation, and layout must match this file as closely as practical.
   Sections marked [MOCK DATA] must be replaced with real HealthKit or backend data.

## Architecture rules (never violate)
- Views never query Supabase directly
- Views never call HKHealthStore directly
- All Supabase access through repository or service layers
- All HealthKit access through HealthKitService only
- Match state transitions owned by Supabase Postgres (triggers/RPCs) and Edge Functions
- Client reads state — never writes transitions or finalizes days
- Series score derived from match_days rows — never stored, never in views
- ReadinessCalculator is a pure function — not in views

## Design rules
- All design values from DesignTokens.swift — no hardcoded hex, sizes, or radii elsewhere
- Glass card styles via .glassCard(variant) ViewModifier
- Bottom nav is a floating card — all 4 corners rounded, safe area aware
- Nav hidden on: Match Details, Live Match, Challenge flow

## Home section order
**As built:** Stats → Searching → Pending → Active → Past matches → Discover (see `HomeView.swift`). Original spec order was Searching → Active → Pending → Discover — preserve that for greenfield mockup parity unless product explicitly changes shipped order.

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
  match.state (DB): 'searching' | 'pending' | 'active' | 'completed' | 'cancelled'
  match_search_requests.status: 'searching' | 'matched' | 'cancelled'
  direct_challenges.status: 'pending' | 'accepted' | 'declined'
  match_days.status: 'pending' | 'provisional' | 'finalized'
  metric_type: 'steps' | 'active_calories'
  start_mode: 'today' | 'tomorrow'
  data_status: 'pending' | 'confirmed'

## Ambiguity rule
If a change could affect match state, scoring, finalization, HealthKit data flow,
or the design system — stop and ask. Do not guess.
```

---

## 21. Decisions Log

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
| Home section order | **As built:** Stats → Searching → Pending → Active → Past → Discover (spec: Searching → Active → Pending → Discover) |
| Challenge flow | 4-step (Sport → Format → Opponent → Review/Send) |
| Bottom nav | **As built:** 4 tabs + center Battle (Home, Health, Ranks, Profile); floating card; mockup showed 6 labels |
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
| Sleep (Health tab) | Last night = **local 18:00 prior day → 12:00 today**; overlap-resolved samples; totals/% from `SleepRatioBreakdown` — **Slice 15** |

### Open items — `[CONFIRM]`

| Question | Affects |
|---|---|
| Stale indicator exact threshold (currently ~2 hours) | Health sync UI copy |
| Leaderboard points formula — use as documented or adjust? | Slice 11 |

### # As-built implementation notes (April 2026)

| # Topic | What shipped |
|---|---|
| # iOS deployment | Minimum **iOS 18.6**; Swift 5; Xcode current stable per `.cursor/rules` |
| # Secrets | `FitUp/FitUp/Config/Secrets.example.xcconfig` → copy to **`Secrets.xcconfig`**; supplies `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `REVENUECAT_API_KEY` |
| # Auth | Supabase Auth: **Sign in with Apple** + **email/password**; `SessionStore` restores session on launch; `ProfileRepository` creates `profiles` row on sign-up; extended session state for onboarding (e.g. HealthKit prompt per profile) — see `SessionStore.swift` |
| # Subscriptions | RevenueCat; entitlement identifier **`pro`** (not only abstract “premium”); products **`fitup_pro_annual`**, **`fitup_pro_monthly`**; paywall gated until after first match completed (`UserDefaults` / `SubscriptionService`) |
| # Push + Live Activities | `AppDelegate` adaptor for APNs; `profiles.apns_token`, `profiles.live_activity_push_token`, `profiles.notifications_enabled`; widget extension target **`FitUpWidgetExtension`**; live activity updates exempt from daily notification cap in `dispatch-notification` |
| # Supabase backend | **Authoritative:** `supabase/migrations/*.sql` + `supabase/functions/` + `supabase/cron.sql`. Runbook: **`FitUp/docs/supabase-setup-guide.md`** (Part 1 overview + Path A manual + Path B CLI). Edge Functions: nine folders as in that guide. |
| # “Portal” | **No in-repo admin web UI.** Configure **Apple Developer Portal** (identifiers, Push, Sign in with Apple, widget App ID) and **Supabase Dashboard** (Auth, SQL, Edge Functions, secrets, Vault for service role / `pg_net` triggers). |
| # Decline behavior | Pending decline for **direct and public matchmaking** uses RPC + triggers (`slice4e-decline-pending-match.sql`); challenger may receive `challenge_declined`-style notification for random match decline |
| # Sleep (Slice 15) | Last night = local **18:00 → 12:00** `sleepAnalysis` window; overlap merge; **Sleep Ratio** UI from `SleepRatioBreakdown` only — **Section 11** + `fitup-build-slices.md` Slice 15 |

---

## 22. # Rebuild-from-scratch checklist (operations)

Use this order to approximate the current production-ready system:

1. **# Apple Developer:** App ID + HealthKit + Push + Sign in with Apple + Widget Extension ID for Live Activities (see tracker for bundle IDs used in your org).
2. **# Supabase project:** Create or link project → apply **`supabase/migrations`** in order (`supabase db push` / linked remote) → apply **`supabase/cron.sql`** where pg_cron is enabled → deploy **`supabase/functions/*`**. Store secrets (APNs, service role for `pg_net`, etc.) per Supabase docs. Use **Section 16** of this file for local/backup workflow.
3. **# Edge Functions:** `supabase functions deploy` for each function (or deploy all); verify JWT and service-role env vars match function code.
4. **# iOS project:** Open `FitUp/FitUp/FitUp.xcodeproj`; configure signing; copy **`Config/Secrets.example.xcconfig`** → **`Secrets.xcconfig`**; enable capabilities matching **`Config/FitUp.entitlements`**.
5. **# RevenueCat & App Store Connect:** Products / entitlement **`pro`** aligned with **`SubscriptionService`** (`fitup_pro_annual`, `fitup_pro_monthly` per tracker).
6. **# Verification:** **`FitUp/docs/slice-tracker.md`** for file-level notes; smoke-test auth, one match flow, sync, notification.

---

*End of fitup-docs-pack.md — update Section 21 (Decisions Log) after material changes.*
