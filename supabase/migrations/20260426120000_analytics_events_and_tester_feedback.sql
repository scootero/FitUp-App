-- Product analytics (sparse, intentional) and tester feedback.
-- `app_logs` remains for technical diagnostics only; do not mirror automatically.

-- ---------------------------------------------------------------------------
-- analytics_events
-- ---------------------------------------------------------------------------

create table public.analytics_events (
  id uuid not null default gen_random_uuid() primary key,
  user_id uuid references public.profiles (id) on delete set null,
  event_name text not null,
  properties jsonb not null default '{}'::jsonb,
  app_version text,
  platform text,
  client_session_id text,
  created_at timestamptz not null default now(),
  constraint analytics_events_event_name_len check (char_length(event_name) <= 128)
);

create index analytics_events_user_created
  on public.analytics_events (user_id, created_at desc);
create index analytics_events_name_created
  on public.analytics_events (event_name, created_at desc);

alter table public.analytics_events enable row level security;

-- Anon, no signed-in user: only allowlisted pre-auth funnel events, user_id null.
-- Authenticated: user_id must match caller's profile.
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
      user_id = (select id from public.profiles where auth_user_id = auth.uid() limit 1)
      and (select id from public.profiles where auth_user_id = auth.uid() limit 1) is not null
    )
  );

-- No SELECT/UPDATE/DELETE for client roles (read via service_role / SQL Editor).

-- ---------------------------------------------------------------------------
-- tester_feedback
-- ---------------------------------------------------------------------------

create table public.tester_feedback (
  id uuid not null default gen_random_uuid() primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  message text not null,
  app_version text,
  context jsonb,
  created_at timestamptz not null default now()
);

create index tester_feedback_user_created
  on public.tester_feedback (user_id, created_at desc);

alter table public.tester_feedback enable row level security;

create policy "tester_feedback: own insert"
  on public.tester_feedback
  as permissive
  for insert
  to public
  with check (
    user_id = (select id from public.profiles where auth_user_id = auth.uid() limit 1)
  );

-- ---------------------------------------------------------------------------
-- grants (insert-only for app clients on analytics; insert-only for feedback)
-- ---------------------------------------------------------------------------

revoke all on public.analytics_events from public;
revoke all on public.tester_feedback from public;

grant insert on public.analytics_events to anon, authenticated, service_role;
grant select on public.analytics_events to service_role;

grant insert on public.tester_feedback to authenticated, service_role;
grant select on public.tester_feedback to service_role;
