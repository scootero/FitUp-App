-- ============================================================================
-- FitUp — friend-gated 1:1 messaging (MVP)
-- ============================================================================
-- Run manually in Supabase SQL Editor after review. Idempotent-safe sections
-- use IF NOT EXISTS where practical (Postgres 15+).
--
-- What this adds:
--   - message_threads: canonical pair (user_low < user_high), unique per pair
--   - messages: text body, FK to thread and sender (profiles.id)
--   - Trigger: bumps message_threads.last_message_at on new message (SECURITY DEFINER)
--   - RLS: participants read threads/messages; insert thread only if accepted friendship;
--          insert message only if participant, sender = self, accepted friendship
--
-- MVP read policy: participants may SELECT even if friendship later ends (history).
-- INSERT always requires status = 'accepted' on friendships for the pair.
--
-- Requires existing public.profiles and public.friendships (canonical a_id < b_id).
-- ============================================================================

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.message_threads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_low uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  user_high uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_message_at timestamptz,
  CONSTRAINT message_threads_order_check CHECK (user_low < user_high),
  CONSTRAINT message_threads_pair_unique UNIQUE (user_low, user_high)
);

CREATE TABLE IF NOT EXISTS public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id uuid NOT NULL REFERENCES public.message_threads (id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES public.profiles (id) ON DELETE CASCADE,
  body text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT messages_body_len_check CHECK (
    char_length(trim(both from body)) >= 1
    AND char_length(body) <= 2000
  )
);

COMMENT ON TABLE public.message_threads IS 'One row per 1:1 pair; user_low < user_high matches friendships(a_id,b_id) order.';
COMMENT ON TABLE public.messages IS 'Friend-gated chat messages; RLS enforces sender + friendship.';

-- ---------------------------------------------------------------------------
-- Indexes
-- ---------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS message_threads_user_low_idx
  ON public.message_threads (user_low);

CREATE INDEX IF NOT EXISTS message_threads_user_high_idx
  ON public.message_threads (user_high);

CREATE INDEX IF NOT EXISTS message_threads_last_message_at_idx
  ON public.message_threads (last_message_at DESC NULLS LAST);

CREATE INDEX IF NOT EXISTS messages_thread_created_idx
  ON public.messages (thread_id, created_at DESC);

CREATE INDEX IF NOT EXISTS messages_sender_created_idx
  ON public.messages (sender_id, created_at DESC);

-- ---------------------------------------------------------------------------
-- last_message_at: trigger (bypasses RLS via SECURITY DEFINER)
-- ---------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_messages_touch_thread_last()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
SET row_security = off
AS $$
BEGIN
  UPDATE public.message_threads
  SET last_message_at = NEW.created_at
  WHERE id = NEW.thread_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS tr_messages_touch_thread_last ON public.messages;
CREATE TRIGGER tr_messages_touch_thread_last
  AFTER INSERT ON public.messages
  FOR EACH ROW
  EXECUTE FUNCTION public.fn_messages_touch_thread_last();

COMMENT ON FUNCTION public.fn_messages_touch_thread_last() IS
  'Sets message_threads.last_message_at when a message is inserted (MVP).';

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------

ALTER TABLE public.message_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- Idempotent policy drops (names stable for re-runs)
DROP POLICY IF EXISTS "message_threads: participant select" ON public.message_threads;
DROP POLICY IF EXISTS "message_threads: friend pair insert" ON public.message_threads;
DROP POLICY IF EXISTS "messages: participant select" ON public.messages;
DROP POLICY IF EXISTS "messages: friend send insert" ON public.messages;

-- Threads: read if you are a participant
CREATE POLICY "message_threads: participant select"
  ON public.message_threads
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (
    user_low = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1)
    OR user_high = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1)
  );

-- Threads: create only for self + peer with accepted friendship (canonical pair = thread pair)
CREATE POLICY "message_threads: friend pair insert"
  ON public.message_threads
  AS PERMISSIVE
  FOR INSERT
  TO public
  WITH CHECK (
    user_low < user_high
    AND (
      user_low = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1)
      OR user_high = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1)
    )
    AND EXISTS (
      SELECT 1
      FROM public.friendships f
      WHERE f.status = 'accepted'
        AND f.a_id = user_low
        AND f.b_id = user_high
    )
    AND (
      (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1)
      IN (user_low, user_high)
    )
  );

-- Messages: read if thread participant
CREATE POLICY "messages: participant select"
  ON public.messages
  AS PERMISSIVE
  FOR SELECT
  TO public
  USING (
    EXISTS (
      SELECT 1 FROM public.message_threads t
      WHERE t.id = thread_id
        AND (
          t.user_low = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1)
          OR t.user_high = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1)
        )
    )
  );

-- Messages: insert only as self, in thread, friendship accepted between thread pair
CREATE POLICY "messages: friend send insert"
  ON public.messages
  AS PERMISSIVE
  FOR INSERT
  TO public
  WITH CHECK (
    sender_id = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1)
    AND EXISTS (
      SELECT 1
      FROM public.message_threads t
      WHERE t.id = thread_id
        AND (
          t.user_low = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1)
          OR t.user_high = (SELECT id FROM public.profiles WHERE auth_user_id = auth.uid() LIMIT 1)
        )
        AND EXISTS (
          SELECT 1 FROM public.friendships f
          WHERE f.status = 'accepted'
            AND f.a_id = t.user_low
            AND f.b_id = t.user_high
        )
    )
  );

-- No client UPDATE/DELETE policies on MVP (service_role bypasses RLS)

-- ---------------------------------------------------------------------------
-- Grants (mirror friendships: app uses authenticated + RLS)
-- ---------------------------------------------------------------------------

GRANT SELECT, INSERT ON public.message_threads TO anon;
GRANT SELECT, INSERT ON public.message_threads TO authenticated;

GRANT SELECT, INSERT ON public.messages TO anon;
GRANT SELECT, INSERT ON public.messages TO authenticated;

GRANT ALL ON public.message_threads TO service_role;
GRANT ALL ON public.messages TO service_role;
