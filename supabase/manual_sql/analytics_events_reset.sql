-- =============================================================================
-- analytics_events_reset.sql
-- =============================================================================
-- Pre–TestFlight manual reset: rebuilds public.analytics_events with a clean
-- schema, indexes, RLS, and grants. Run once in Supabase SQL Editor on the
-- target project (dev/staging/prod as appropriate).
--
-- WARNING: DROP TABLE removes all existing analytics_events rows.
-- Safe when only internal/test data exists. Does NOT touch app_logs or
-- tester_feedback.
--
-- Client contract (iOS): user_id must be profiles.id, never auth.users.id.
-- Anonymous inserts: user_id NULL only for app_cold_start and auth_screen_view.
-- =============================================================================

drop table if exists public.analytics_events cascade;

create table public.analytics_events (
  id uuid not null default gen_random_uuid() primary key,
  user_id uuid references public.profiles (id) on delete set null,
  event_name text not null,
  screen_name text,
  session_id uuid,
  client_session_id text,
  properties jsonb not null default '{}'::jsonb,
  app_version text,
  build_number text,
  platform text not null default 'ios',
  source text not null default 'ios_client',
  event_schema_version integer not null default 1,
  created_at timestamptz not null default now(),
  constraint analytics_events_event_name_len check (char_length(event_name) <= 128)
);

comment on table public.analytics_events is
  'Product/user behavior only. Technical diagnostics belong in app_logs.';

-- Indexes (dashboard-friendly time ordering)
create index analytics_events_created_at_desc
  on public.analytics_events (created_at desc);

create index analytics_events_user_created
  on public.analytics_events (user_id, created_at desc);

create index analytics_events_name_created
  on public.analytics_events (event_name, created_at desc);

create index analytics_events_session_created
  on public.analytics_events (session_id, created_at desc);

create index analytics_events_user_session_created
  on public.analytics_events (user_id, session_id, created_at desc);

alter table public.analytics_events enable row level security;

-- Inserts only. Anonymous: tiny allowlist + user_id must be null + no JWT.
-- Authenticated: user_id must be the caller's profile row (profiles.auth_user_id = auth.uid()).
create policy "analytics_events: insert"
  on public.analytics_events
  as permissive
  for insert
  to public
  with check (
    (
      user_id is null
      and auth.uid() is null
      and event_name in (
        'app_cold_start',
        'auth_screen_view'
      )
    )
    or
    (
      user_id is not null
      and user_id = (select id from public.profiles where auth_user_id = auth.uid() limit 1)
      and (select id from public.profiles where auth_user_id = auth.uid() limit 1) is not null
    )
  );

-- No client reads/updates/deletes; use service_role or SQL Editor for analysis.
revoke all on public.analytics_events from public;

grant insert on public.analytics_events to anon, authenticated, service_role;
grant select on public.analytics_events to service_role;

-- =============================================================================
-- Manual RLS / insert tests (run in SQL Editor with appropriate role/session)
-- =============================================================================
--
-- 1) Anon key, no Authorization header (or invalid session):
--    INSERT INTO public.analytics_events (event_name) VALUES ('app_cold_start');
--    Expect: SUCCESS (user_id omitted or null).
--
-- 2) Anon, non-allowlisted event:
--    INSERT INTO public.analytics_events (event_name) VALUES ('session_started');
--    Expect: FAIL (policy violation).
--
-- 3) Authenticated user JWT, correct profile id:
--    INSERT INTO public.analytics_events (user_id, event_name)
--    VALUES ('<your profiles.id for this auth user>', 'session_started');
--    Expect: SUCCESS.
--
-- 4) Authenticated JWT, wrong profile id (another user's profiles.id):
--    Expect: FAIL.
--
-- 5) Authenticated JWT, user_id NULL, event not in anon allowlist:
--    INSERT INTO public.analytics_events (user_id, event_name) VALUES (null, 'match_viewed');
--    Expect: FAIL.
--
-- =============================================================================
