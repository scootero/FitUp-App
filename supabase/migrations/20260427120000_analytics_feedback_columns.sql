-- Additive columns for TestFlight analytics + tester feedback (v2 payload).

alter table public.analytics_events
  add column if not exists build_number text,
  add column if not exists screen_name text,
  add column if not exists session_id uuid;

alter table public.tester_feedback
  add column if not exists category text not null default 'other',
  add column if not exists screen_name text,
  add column if not exists build_number text;

-- Lifecycle events may fire before sign-in; extend anonymous insert allowlist.
drop policy if exists "analytics_events: insert" on public.analytics_events;

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
        'auth_screen_view',
        'app_opened',
        'app_backgrounded',
        'session_started',
        'session_ended'
      )
    )
    or
    (
      user_id = (select id from public.profiles where auth_user_id = auth.uid() limit 1)
      and (select id from public.profiles where auth_user_id = auth.uid() limit 1) is not null
    )
  );
