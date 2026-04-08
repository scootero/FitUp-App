# FitUp — Supabase Setup Guide
*Complete reference. Run steps in order. All SQL is copy-pasteable into the Supabase SQL Editor.*
*Last updated: March 2026*

---

## Before You Start

**Resolved conflicts — these are the canonical decisions:**

- `direct_challenges` uses `challenger_id` / `recipient_id` (not `sender_id`) — matches Cursor's Swift code
- `user_health_baselines` has two separate columns (`rolling_avg_7d_steps`, `rolling_avg_7d_calories`) with `user_id` as primary key — matches Cursor's Swift code
- `start_mode` defaults silently to `'today'` in v1 — not shown in UI, Cursor hardcodes it
- iOS deployment target: **18.0**
- All tables below are the canonical versions — supersede anything in docs-pack Section 7 or slice0-schema.sql where they conflict

---

## Step 1 — Create a Supabase Project

1. Go to [supabase.com](https://supabase.com) and sign in
2. Click **New project**
3. Name it `fitup` (or `fitup-dev` for a dev-only project)
4. Set a strong database password — save it somewhere safe
5. Choose the region closest to your users
6. Wait for the project to finish provisioning (~2 minutes)

---

## Step 2 — Copy Your API Keys

1. Go to **Project Settings → API**
2. Copy:
   - **Project URL** — looks like `https://abcdefghijkl.supabase.co`
   - **anon public** key — long JWT string starting with `eyJ...`
3. You will paste these into the app config in Step 4

---

## Step 3 — Run All SQL (in order)

Go to **SQL Editor** in your Supabase dashboard. Create a new query. Paste and run each block below **in the order shown**. Order matters because of foreign key dependencies.

---

### Block 1 — Core user table

```sql
CREATE TABLE IF NOT EXISTS profiles (
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

CREATE INDEX IF NOT EXISTS profiles_auth_user ON profiles (auth_user_id);
```

---

### Block 2 — Health baselines (for matchmaking fairness)

```sql
CREATE TABLE IF NOT EXISTS user_health_baselines (
  user_id                  uuid PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  rolling_avg_7d_steps     numeric,
  rolling_avg_7d_calories  numeric,
  updated_at               timestamptz NOT NULL DEFAULT now()
);
```

---

### Block 3 — Matchmaking queue

```sql
CREATE TABLE IF NOT EXISTS match_search_requests (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  creator_id       uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  metric_type      text NOT NULL CHECK (metric_type IN ('steps', 'active_calories')),
  duration_days    int  NOT NULL CHECK (duration_days IN (1, 3, 5, 7)),
  start_mode       text NOT NULL DEFAULT 'today' CHECK (start_mode IN ('today', 'tomorrow')),
  status           text NOT NULL DEFAULT 'searching' CHECK (status IN ('searching', 'matched', 'cancelled')),
  creator_baseline numeric,
  matched_match_id uuid,
  created_at       timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS msq_creator_status ON match_search_requests (creator_id, status);
CREATE INDEX IF NOT EXISTS msq_status_metric ON match_search_requests (status, metric_type, duration_days, start_mode);
```

---

### Block 4 — Matches (core competition container)

```sql
CREATE TABLE IF NOT EXISTS matches (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_type     text NOT NULL CHECK (match_type IN ('public_matchmaking', 'direct_challenge')),
  metric_type    text NOT NULL CHECK (metric_type IN ('steps', 'active_calories')),
  duration_days  int  NOT NULL CHECK (duration_days IN (1, 3, 5, 7)),
  start_mode     text NOT NULL DEFAULT 'today' CHECK (start_mode IN ('today', 'tomorrow')),
  state          text NOT NULL DEFAULT 'pending' CHECK (state IN ('searching', 'pending', 'active', 'completed', 'cancelled')),
  match_timezone text NOT NULL DEFAULT 'America/New_York',
  starts_at      timestamptz,
  ends_at        timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now(),
  completed_at   timestamptz
);

CREATE INDEX IF NOT EXISTS matches_state ON matches (state);
```

---

### Block 5 — Add FK from match_search_requests to matches (deferred because of creation order)

```sql
ALTER TABLE match_search_requests
  ADD CONSTRAINT fk_msq_matched_match
  FOREIGN KEY (matched_match_id) REFERENCES matches(id) ON DELETE SET NULL;
```

---

### Block 6 — Match participants

```sql
CREATE TABLE IF NOT EXISTS match_participants (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id    uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  role        text NOT NULL CHECK (role IN ('challenger', 'opponent')),
  joined_via  text NOT NULL CHECK (joined_via IN ('matchmaking', 'direct_challenge')),
  accepted_at timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (match_id, user_id)
);

CREATE INDEX IF NOT EXISTS mp_user_match ON match_participants (user_id, match_id);
CREATE INDEX IF NOT EXISTS mp_match ON match_participants (match_id);
```

---

### Block 7 — Direct challenges

```sql
CREATE TABLE IF NOT EXISTS direct_challenges (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenger_id  uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  recipient_id   uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  match_id       uuid REFERENCES matches(id) ON DELETE SET NULL,
  status         text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined')),
  created_at     timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS dc_recipient ON direct_challenges (recipient_id, status);
CREATE INDEX IF NOT EXISTS dc_challenger ON direct_challenges (challenger_id);
```

---

### Block 8 — Match days

```sql
CREATE TABLE IF NOT EXISTS match_days (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id       uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  day_number     int  NOT NULL CHECK (day_number >= 1),
  calendar_date  date NOT NULL,
  status         text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'provisional', 'finalized')),
  winner_user_id uuid REFERENCES profiles(id) ON DELETE SET NULL,
  is_void        boolean NOT NULL DEFAULT false,
  finalized_at   timestamptz,
  created_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (match_id, day_number)
);

CREATE INDEX IF NOT EXISTS md_match ON match_days (match_id);
CREATE INDEX IF NOT EXISTS md_status ON match_days (status);
```

---

### Block 9 — Match day participants (live + finalized per-user-per-day data)

```sql
CREATE TABLE IF NOT EXISTS match_day_participants (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_day_id    uuid NOT NULL REFERENCES match_days(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  metric_total    numeric NOT NULL DEFAULT 0,
  finalized_value numeric,
  data_status     text NOT NULL DEFAULT 'pending' CHECK (data_status IN ('pending', 'confirmed')),
  last_updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (match_day_id, user_id)
);

CREATE INDEX IF NOT EXISTS mdp_match_day ON match_day_participants (match_day_id);
CREATE INDEX IF NOT EXISTS mdp_user ON match_day_participants (user_id);
```

---

### Block 10 — Metric snapshots (raw HealthKit audit log)

```sql
CREATE TABLE IF NOT EXISTS metric_snapshots (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  match_id     uuid NOT NULL REFERENCES matches(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  metric_type  text NOT NULL CHECK (metric_type IN ('steps', 'active_calories')),
  value        numeric NOT NULL,
  source_date  date NOT NULL,
  synced_at    timestamptz NOT NULL DEFAULT now(),
  flagged      boolean NOT NULL DEFAULT false,
  metadata     jsonb
);

CREATE INDEX IF NOT EXISTS ms_user_date ON metric_snapshots (user_id, source_date DESC);
CREATE INDEX IF NOT EXISTS ms_match ON metric_snapshots (match_id);
```

---

### Block 11 — Leaderboard entries

```sql
CREATE TABLE IF NOT EXISTS leaderboard_entries (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  week_start date NOT NULL,
  points     int  NOT NULL DEFAULT 0,
  wins       int  NOT NULL DEFAULT 0,
  losses     int  NOT NULL DEFAULT 0,
  streak     int  NOT NULL DEFAULT 0,
  rank       int,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, week_start)
);

CREATE INDEX IF NOT EXISTS le_week ON leaderboard_entries (week_start, points DESC);
```

---

### Block 12 — All-time personal bests

```sql
CREATE TABLE IF NOT EXISTS all_time_bests (
  user_id                  uuid PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  steps_best_day           numeric,
  steps_best_week          numeric,
  cals_best_day            numeric,
  cals_best_week           numeric,
  best_win_streak_days     int,
  updated_at               timestamptz NOT NULL DEFAULT now()
);
```

---

### Block 13 — Notification events

```sql
CREATE TABLE IF NOT EXISTS notification_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  event_type  text NOT NULL,
  status      text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'failed')),
  payload     jsonb,
  sent_at     timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ne_user_created ON notification_events (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS ne_status ON notification_events (status);
```

---

### Block 14 — App logs (Dev Tools log viewer)

```sql
CREATE TABLE IF NOT EXISTS app_logs (
  id         uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    uuid REFERENCES profiles(id) ON DELETE SET NULL,
  category   text NOT NULL,
  level      text NOT NULL DEFAULT 'info' CHECK (level IN ('debug', 'info', 'warning', 'error')),
  message    text NOT NULL,
  metadata   jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS al_user_created ON app_logs (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS al_level ON app_logs (level);
```

---

### Block 15 — Verify all tables exist

Run this after all blocks above to confirm everything was created:

```sql
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;
```

You should see all 13 tables:
`all_time_bests`, `app_logs`, `direct_challenges`, `leaderboard_entries`, `match_day_participants`, `match_days`, `match_participants`, `match_search_requests`, `matches`, `metric_snapshots`, `notification_events`, `profiles`, `user_health_baselines`

---

## Step 4 — Enable Row Level Security and Add Policies

Go to **Authentication → Policies** or run this SQL. RLS must be enabled before the app can talk to Supabase from the client safely.

**Existing projects:** If you previously applied the recursive `match_participants` policies (subquerying `match_participants` inside `match_participants` policies), run `supabase/sql/fix-match-participants-rls-recursion.sql` from the repository root in the SQL Editor to replace them with `public.current_user_match_ids()` (see that file for details).

### Enable RLS on all tables

```sql
ALTER TABLE profiles                ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_health_baselines   ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_search_requests   ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches                 ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_participants      ENABLE ROW LEVEL SECURITY;
ALTER TABLE direct_challenges       ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_days              ENABLE ROW LEVEL SECURITY;
ALTER TABLE match_day_participants  ENABLE ROW LEVEL SECURITY;
ALTER TABLE metric_snapshots        ENABLE ROW LEVEL SECURITY;
ALTER TABLE leaderboard_entries     ENABLE ROW LEVEL SECURITY;
ALTER TABLE all_time_bests          ENABLE ROW LEVEL SECURITY;
ALTER TABLE notification_events     ENABLE ROW LEVEL SECURITY;
ALTER TABLE app_logs                ENABLE ROW LEVEL SECURITY;
```

### Policies — profiles

```sql
-- Users can read their own profile
CREATE POLICY "profiles: own read"
  ON profiles FOR SELECT
  USING (auth.uid() = auth_user_id);

-- Users can read other profiles (needed for discover list, match opponents)
CREATE POLICY "profiles: read others"
  ON profiles FOR SELECT
  USING (true);

-- Users can insert their own profile (on signup)
CREATE POLICY "profiles: own insert"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = auth_user_id);

-- Users can update their own profile
CREATE POLICY "profiles: own update"
  ON profiles FOR UPDATE
  USING (auth.uid() = auth_user_id);
```

### Policies — app_logs

```sql
-- Users can insert their own logs
CREATE POLICY "app_logs: own insert"
  ON app_logs FOR INSERT
  WITH CHECK (
    user_id IS NULL OR
    user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );

-- Users can read their own logs
CREATE POLICY "app_logs: own read"
  ON app_logs FOR SELECT
  USING (
    user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );
```

### Policies — match_search_requests

```sql
-- Users can insert their own search requests
CREATE POLICY "msr: own insert"
  ON match_search_requests FOR INSERT
  WITH CHECK (
    creator_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );

-- Users can read their own search requests
CREATE POLICY "msr: own read"
  ON match_search_requests FOR SELECT
  USING (
    creator_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );

-- Users can update their own search requests (cancel)
CREATE POLICY "msr: own update"
  ON match_search_requests FOR UPDATE
  USING (
    creator_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );
```

### Policies — matches and match_participants

Run the helper function once (avoids infinite RLS recursion when policies on `match_participants` would otherwise subquery `match_participants`):

```sql
CREATE OR REPLACE FUNCTION public.current_user_match_ids()
RETURNS SETOF uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT mp.match_id
  FROM match_participants mp
  WHERE mp.user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid());
$$;

REVOKE ALL ON FUNCTION public.current_user_match_ids() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.current_user_match_ids() TO authenticated;
GRANT EXECUTE ON FUNCTION public.current_user_match_ids() TO service_role;
```

```sql
-- Users can read matches they are participating in
CREATE POLICY "matches: participant read"
  ON matches FOR SELECT
  USING (id IN (SELECT public.current_user_match_ids()));

-- Users can read their own row and co-participants (same match)
CREATE POLICY "mp: participant read"
  ON match_participants FOR SELECT
  USING (match_id IN (SELECT public.current_user_match_ids()));

-- Users can update their own accepted_at
CREATE POLICY "mp: own update"
  ON match_participants FOR UPDATE
  USING (
    user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );
```

**Direct challenge client inserts (required for Discover → challenge):** the iOS app inserts into `matches` and `match_participants` using the user session. After applying the policies above, run the idempotent script **`supabase/sql/slice4c-direct-challenge-rls.sql`** in the SQL Editor so `INSERT` is allowed for `match_type = 'direct_challenge'` (challenger row first, then opponent row). Public matchmaking still uses the service-role RPC path only.

### Policies — direct_challenges

```sql
-- Challengers can insert a challenge
CREATE POLICY "dc: own insert"
  ON direct_challenges FOR INSERT
  WITH CHECK (
    challenger_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );

-- Both parties can read the challenge
CREATE POLICY "dc: party read"
  ON direct_challenges FOR SELECT
  USING (
    challenger_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid()) OR
    recipient_id  = (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );

-- Recipient can update status (accept / decline)
CREATE POLICY "dc: recipient update"
  ON direct_challenges FOR UPDATE
  USING (
    recipient_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );
```

### Policies — match days and day participants

```sql
-- Participants can read match_days for their matches
CREATE POLICY "md: participant read"
  ON match_days FOR SELECT
  USING (match_id IN (SELECT public.current_user_match_ids()));

-- Participants can read match_day_participants for their matches
CREATE POLICY "mdp: participant read"
  ON match_day_participants FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM match_days md
      WHERE md.id = match_day_participants.match_day_id
        AND md.match_id IN (SELECT public.current_user_match_ids())
    )
  );

-- Users can update their own match_day_participants row (metric_total sync)
CREATE POLICY "mdp: own update"
  ON match_day_participants FOR UPDATE
  USING (
    user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );

-- Users can insert their own metric_snapshots
CREATE POLICY "ms: own insert"
  ON metric_snapshots FOR INSERT
  WITH CHECK (
    user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );

-- Participants can read metric_snapshots for their matches
CREATE POLICY "ms: participant read"
  ON metric_snapshots FOR SELECT
  USING (match_id IN (SELECT public.current_user_match_ids()));
```

### Policies — leaderboard and bests (public read)

```sql
-- Leaderboard is public readable
CREATE POLICY "le: public read"
  ON leaderboard_entries FOR SELECT
  USING (true);

-- All-time bests are public readable
CREATE POLICY "atb: public read"
  ON all_time_bests FOR SELECT
  USING (true);

-- Users can read their own health baselines
CREATE POLICY "uhb: own read"
  ON user_health_baselines FOR SELECT
  USING (
    user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );

-- Users can upsert their own health baselines
CREATE POLICY "uhb: own upsert"
  ON user_health_baselines FOR INSERT
  WITH CHECK (
    user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );

CREATE POLICY "uhb: own update"
  ON user_health_baselines FOR UPDATE
  USING (
    user_id = (SELECT id FROM profiles WHERE auth_user_id = auth.uid())
  );
```

---

## Step 5 — Enable Realtime

The Swift app subscribes to live updates on matches and match_day_participants. Enable Realtime for those tables:

1. Go to **Database → Replication**
2. Find the **Supabase Realtime** section
3. Enable replication for:
   - `matches`
   - `match_participants`
   - `match_day_participants`
   - `match_search_requests`

---

## Step 6 — Wire Keys into the Xcode Project

Cursor already created `FitUp/FitUp/Config/Secrets.example.xcconfig`. Do this:

1. In Finder, go to `FitUp-App/FitUp/FitUp/Config/`
2. Duplicate `Secrets.example.xcconfig` → name it `Secrets.xcconfig`
3. Open `Secrets.xcconfig` and fill in:

```
SUPABASE_URL = https://YOUR_PROJECT_REF.supabase.co
SUPABASE_ANON_KEY = YOUR_ANON_KEY_HERE
```

4. `Secrets.xcconfig` is already in `.gitignore` — do not commit it
5. The `Debug.xcconfig` already includes it, so keys flow into `Info.plist` automatically

---

## Step 7 — Configure Auth Providers

In your Supabase dashboard:

1. Go to **Authentication → Providers**
2. Enable **Email** provider — leave defaults (confirm email: optional for dev)
3. Enable **Apple** provider if you are testing Sign in with Apple:
   - You need: **Service ID**, **Team ID**, **Key ID**, **Private Key** from Apple Developer
   - Paste these into the Apple provider settings in Supabase

### Authentication URLs

1. Go to **Authentication → URL Configuration**
2. Set **Site URL** to your app's URL (for dev, can be `http://localhost:3000` or your app scheme)
3. Add any **Redirect URLs** needed for your auth flow

---

## Step 8 — Sign in with Apple Setup (Apple Developer Portal)

You only need this if testing Sign in with Apple. Skip for email-only testing.

1. In, create an App ID for FitUp with Sign in with Apple enabled
2. Create a **Services ID** (used as the OAuth client ID)
3. Go to **Keys** → create a new key with Sign in with Apple enabled
4. Download the `.p8` private key — you can only download it once
5. Note your **Team ID**, **Key ID**
6. In Supabase Apple provider settings, paste:
   - `client_id` = your Services ID (e.g. `com.yourname.fitup.siwa`)
   - `team_id` = your 10-character team ID
   - `key_id` = your key ID
   - `private_key` = contents of the `.p8` file

---

## Step 9 — Verify Everything Works

Run the app on simulator or device. Verify in Supabase:

```
1. Sign up with email
   → auth.users should have a new row
   → profiles should have a row with auth_user_id, initials, timezone

2. Trigger an app_log write (any action that logs)
   → app_logs should have a row with user_id and category

3. Check RLS is not blocking reads
   → If the app shows no data when data exists, check policies
```

---

## Step 10 — Answer Cursor's Open Questions

Before sending Slice 4 to Cursor, confirm these two things so Cursor doesn't have to guess:

### start_mode

**Answer:** Default silently to `'today'` in v1. Do not add a today/tomorrow control to the Challenge flow UI. The Review step (Step 3) does not need to show start mode. Both `match_search_requests` and `matches` should be created with `start_mode = 'today'` hardcoded until a UI control is added in a later slice.

Add this to your Slice 4 prompt to Cursor:
> `start_mode` should default to `'today'` in all writes for Slice 4. Do not add a UI control for it. Hardcode `'today'` in `MatchmakingService` and `DirectChallengeService` for now.

### iOS deployment target

**Answer:** Use **18.0** throughout. If the current project is set to 18.6, leave it — 18.0 is the minimum floor but 18.6 is fine as the current SDK target.

Add this to your Slice 4 prompt:
> iOS deployment target is 18.0 minimum. If the project is already set to 18.6, leave it as-is.

---

## What Comes Later (Not Needed Yet)

These are backend features for later slices. Do not set them up until you reach that slice:

| Feature | When needed |
|---|---|
| `matchmaking-pairing` / `on-all-accepted` + `slice4-matchmaking.sql` | Slice 4 — [Matchmaking backend](#slice-4--matchmaking-edge-functions--database) (run after Slice 8 Vault secrets exist) |
| APNs push notification sending (beyond queue rows) | Slice 9 |
| Realtime ActivityKit push | Slice 9 |
| RevenueCat product/entitlement setup | Slice 13 |

**Slice 8** (day finalization) uses Edge Functions + SQL in-repo — see the next section when you deploy Slice 8.

---

## Slice 8 — Day finalization (Edge Functions + database)

Source files live at repo root: `supabase/functions/` and `supabase/sql/slice8-finalization.sql`.

### 1. Deploy Edge Functions

From the repo root (`FitUp-App/`), with [Supabase CLI](https://supabase.com/docs/guides/cli) logged in and linked to your project:

```bash
supabase functions deploy finalize-match-day
supabase functions deploy complete-match
supabase functions deploy update-leaderboard
supabase functions deploy dispatch-notification
```

Supabase injects `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` into the Edge runtime; the shared module `supabase/functions/_shared/supabase.ts` requires both.

**Behavior (summary):**

| Function | Role |
|---|---|
| `finalize-match-day` | Input: `{ "match_day_id": "<uuid>" }`. Copies `metric_total` → `finalized_value`, sets `match_days` winner/void/finalized, invokes `update-leaderboard`, may invoke `complete-match`, queues notifications via `dispatch-notification`. |
| `complete-match` | Sets `matches.state = 'completed'` and `completed_at` when all days are finalized. |
| `update-leaderboard` | Adds weekly points per docs (day win, match win, streak cap, steps bonus cap) into `leaderboard_entries`. |
| `dispatch-notification` | Inserts `notification_events` rows (`status = pending`) for Slice 8; APNs delivery is Slice 9. |

### 2. Vault secrets for SQL → HTTP (pg_net)

The trigger and cron job call `finalize-match-day` over HTTPS. Create two secrets in **Supabase Dashboard → Project Settings → Vault** (names must match):

| Secret name | Value |
|---|---|
| `fitup_project_url` | `https://<project-ref>.supabase.co` (no trailing slash) |
| `fitup_service_role_key` | Service role JWT (Dashboard → Project Settings → API) |

### 3. Run SQL migration

In the **SQL Editor**, run the full script:

`supabase/sql/slice8-finalization.sql`

This enables `pg_net` and `pg_cron`, defines `private.invoke_finalize_match_day`, the trigger `tr_finalize_when_all_confirmed` on `match_day_participants`, and schedules `day-cutoff-check` hourly (cron expression `5 * * * *`).

**Requirements:** `profiles.timezone` should be set for each user (Slice 1 onboarding already writes it) so the 10:00 cutoff logic aligns with local time.

### 4. Verify

- With two participants, after both have `data_status = 'confirmed'` for a `match_day`, the trigger should enqueue a finalize call; `match_days.status` becomes `finalized`.
- After the last day finalizes, `matches.state` should become `completed` and completed matches appear in the app **Activity** tab.

---

## Slice 4 — Matchmaking (Edge Functions + database)

Source files: `supabase/functions/matchmaking-pairing/`, `supabase/functions/on-all-accepted/`, and `supabase/sql/slice4-matchmaking.sql`.

**Prerequisites:** Same Vault secrets as Slice 8 (`fitup_project_url`, `fitup_service_role_key`). Run this **after** `slice8-finalization.sql` so `pg_net` and the `private` schema are already in place.

### 1. Deploy Edge Functions

From the repo root (`FitUp-App/`):

```bash
supabase functions deploy matchmaking-pairing
supabase functions deploy retry-matchmaking-search
supabase functions deploy on-all-accepted
```

### 2. Run SQL migration

In the **SQL Editor**, run the full script:

`supabase/sql/slice4-matchmaking.sql`

This defines `public.matchmaking_pair_atomic` and `public.activate_match_with_days`, adds `pg_net` triggers that call the Edge Functions over HTTPS, and **drops** the Slice 9 notification triggers `tr_notify_match_found_on_pairing` and `tr_activate_match_when_all_accepted` if they exist (those paths are superseded so `match_found` / activation + `match_days` creation stay consistent).

If you apply `supabase/sql/slice9-notifications.sql` **after** this script, run `slice4-matchmaking.sql` again so those two older triggers stay dropped.

### 3. Verify

- Two users submit Quick Match with the same metric, duration, and start mode → one `matches` row (`public_matchmaking`), both `match_search_requests` rows `matched`, two `match_participants` with `joined_via = matchmaking`.
- When both have accepted (`accepted_at` set) → `matches.state = active`, `match_days` row count equals `duration_days`, each day has two `match_day_participants`.

### 4. Stale search retries (recommended)

Pairing runs on **INSERT** via `pg_net`. If that HTTP call fails, rows can stay `searching` until something retries. After Slice 8 (`pg_cron` enabled), run:

`supabase/sql/slice4b-matchmaking-stale-retry.sql`

This adds `public.matchmaking_retry_stale_searches` and schedules `matchmaking-retry-stale` every minute (re-invokes `matchmaking-pairing` for up to 30 queue rows older than 5 seconds).

### 5. Deploy authenticated retry function (used by the iOS app)

The app calls `retry-matchmaking-search` with the user’s session JWT (verifies `creator_id` before pairing).

From the repo root (`FitUp-App/`):

```bash
supabase functions deploy retry-matchmaking-search
```

### 6. Operational checks

- Read-only SQL checks: `supabase/sql/verify-matchmaking.sql`
- Manual pairing test (service role, **never** embed in the app): `scripts/matchmaking-pair-test.sh`
- One-time duplicate queue cleanup: `supabase/sql/cleanup-duplicate-match-search-requests.sql`

---

## Slice 9 — Notifications and Live Activities

Source files: `supabase/functions/dispatch-notification/`, `supabase/functions/send-pending-reminders/`, `supabase/functions/send-morning-checkins/`, `supabase/functions/_shared/apns.ts`, and `supabase/sql/slice9-notifications.sql`.

**Prerequisites:** Slice 8 Vault secrets (`fitup_project_url`, `fitup_service_role_key`) must already exist. `pg_net` and `pg_cron` must already be enabled (done by `slice8-finalization.sql`).

### 1. Set Edge Function secrets (APNs)

In **Supabase Dashboard → Project Settings → Edge Functions → Secrets**, add:

| Secret | Value |
|---|---|
| `APNS_TEAM_ID` | Your 10-character Apple Developer Team ID (e.g. `BLAUCQ8H26`) |
| `APNS_KEY_ID` | Key ID shown in Apple Developer portal → Keys (10 chars) |
| `APNS_PRIVATE_KEY` | Full contents of the downloaded `.p8` file (including `-----BEGIN PRIVATE KEY-----` lines; use `\n` for line breaks if the dashboard requires a single-line value) |
| `APNS_BUNDLE_ID` | `com.ScottOliver.FitUp` |
| `APNS_USE_SANDBOX` | `true` (development / TestFlight); change to `false` for App Store production |

### 2. Enable Push Notifications on the App ID

In **Apple Developer portal → Identifiers**, find `com.ScottOliver.FitUp` and enable the **Push Notifications** capability. Xcode automatic signing will regenerate the provisioning profile on the next build.

Also register the Widget Extension App ID: `com.ScottOliver.FitUp.FitUpWidgetExtension`.

### 3. Deploy Edge Functions

From the repo root (`FitUp-App/`):

```bash
supabase functions deploy dispatch-notification
supabase functions deploy send-pending-reminders
supabase functions deploy send-morning-checkins
```

`dispatch-notification` now enriches `live_activity_update` events with per-user totals, display names, and series scores before sending to APNs (token-based JWT auth via the `apns.ts` shared module).

### 4. Run SQL migration

In the **SQL Editor**, run the full script:

`supabase/sql/slice9-notifications.sql`

This script:
- Adds `profiles.notifications_enabled` (boolean, default `true`) and `profiles.live_activity_push_token` (text)
- Creates schema `private` and helper functions: `private.invoke_edge_function`, `private.invoke_dispatch_notification`, `private.notification_sent_today`, `private.resolve_leader_user`
- Creates notification triggers:
  - `tr_notify_match_found_on_pairing` — fires on `match_participants` INSERT (public matchmaking pairs)
  - `tr_notify_challenge_received` — fires on `direct_challenges` INSERT
  - `tr_notify_challenge_declined` — fires on `direct_challenges.status` UPDATE → `'declined'`
  - `tr_activate_match_when_all_accepted` — fires on `match_participants.accepted_at` set; activates match and fires `match_active` push
  - `tr_notify_lead_changed` — fires on `match_day_participants.metric_total` UPDATE when leader changes
  - `tr_push_live_activity_updates` — fires on `match_day_participants.metric_total` INSERT/UPDATE; sends Live Activity push to both participants
- Schedules pg_cron jobs:
  - `send-pending-reminders`: daily at 16:15 UTC
  - `send-morning-checkins`: daily at 13:00 UTC

**Note:** If you run `supabase/sql/slice4-matchmaking.sql` after this, `tr_notify_match_found_on_pairing` and `tr_activate_match_when_all_accepted` are superseded by the Slice 4 matchmaking triggers and will be dropped by that script.

### 5. Verify

- Send a direct challenge → `notification_events` row inserted for recipient with `event_type = 'challenge_received'`; APNs push fires if `APNS_*` secrets are set and token is registered
- Accept challenge → both participants get `match_active` push
- Metric sync while match is active → `lead_changed` push fires on the trailing user when the leader flips
- Live Activity appears on lock screen once a match goes active; updates when opponent syncs
- `notification_events` count for any user stays ≤ 10 `status = 'sent'` rows per UTC day

---

## Schema Summary (Canonical — use this, not any earlier version)

| Table | Primary purpose | FK dependencies |
|---|---|---|
| `profiles` | Users | `auth.users` (via auth_user_id) |
| `user_health_baselines` | 7-day step/cal averages | `profiles` |
| `match_search_requests` | Matchmaking queue | `profiles`, `matches` (deferred FK) |
| `matches` | Competition containers | none |
| `match_participants` | Who's in which match | `profiles`, `matches` |
| `direct_challenges` | Direct invites | `profiles`, `matches` |
| `match_days` | One day per match | `matches`, `profiles` |
| `match_day_participants` | Per-user-per-day data | `match_days`, `profiles` |
| `metric_snapshots` | Raw HealthKit audit | `matches`, `profiles` |
| `leaderboard_entries` | Weekly rankings | `profiles` |
| `all_time_bests` | Personal records | `profiles` |
| `notification_events` | Push audit log | `profiles` |
| `app_logs` | Dev Tools log stream | `profiles` (nullable) |

---

*Save this file at `FitUp-App/FitUp/docs/supabase-setup-guide.md`*
*Reference it for all future Supabase work — do not use the old supabase-slice0-schema.sql for new table creation.*
