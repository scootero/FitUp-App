-- FitUp Slice 0 — supplemental DDL for tables not fully spelled out in fitup-docs-pack.md Section 7.
-- Run in Supabase SQL editor after the Section 7 snippets (profiles, matches, etc.).

-- app_logs: in-app / client logging (see AppLogger.swift)
CREATE TABLE IF NOT EXISTS app_logs (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid REFERENCES profiles(id) ON DELETE SET NULL,
  category     text NOT NULL,
  level        text NOT NULL DEFAULT 'info',
  message      text NOT NULL,
  metadata     jsonb,
  created_at   timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS app_logs_user_created ON app_logs (user_id, created_at DESC);

-- Optional: remaining v1 tables (minimal shapes; tighten with RLS policies in dashboard)

CREATE TABLE IF NOT EXISTS user_health_baselines (
  user_id         uuid PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  rolling_avg_7d_steps    numeric,
  rolling_avg_7d_calories numeric,
  updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS direct_challenges (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  challenger_id   uuid NOT NULL REFERENCES profiles(id),
  recipient_id    uuid NOT NULL REFERENCES profiles(id),
  match_id        uuid REFERENCES matches(id),
  status          text NOT NULL DEFAULT 'pending',
  created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS notification_events (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid REFERENCES profiles(id) ON DELETE CASCADE,
  event_type  text NOT NULL,
  status      text NOT NULL DEFAULT 'pending',
  payload     jsonb,
  sent_at     timestamptz,
  created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS all_time_bests (
  user_id     uuid PRIMARY KEY REFERENCES profiles(id) ON DELETE CASCADE,
  steps_best_day   numeric,
  steps_best_week numeric,
  cals_best_day    numeric,
  cals_best_week   numeric,
  best_win_streak_days int,
  updated_at  timestamptz NOT NULL DEFAULT now()
);
