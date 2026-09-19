-- FitOff privacy, account deletion, and message-safety controls.
-- Local source only until the owner explicitly deploys this migration.

-- Messaging was originally installed from a reviewed manual SQL file. Promote its
-- core tables here so a clean migration run has the same safety boundary.
create table if not exists public.message_threads (
  id uuid primary key default gen_random_uuid(),
  user_low uuid not null references public.profiles(id) on delete cascade,
  user_high uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  last_message_at timestamptz,
  constraint message_threads_order_check check (user_low < user_high),
  constraint message_threads_pair_unique unique (user_low, user_high)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.message_threads(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null,
  created_at timestamptz not null default now(),
  constraint messages_body_len_check check (
    char_length(trim(both from body)) between 1 and 2000
  )
);

create index if not exists message_threads_user_low_idx on public.message_threads(user_low);
create index if not exists message_threads_user_high_idx on public.message_threads(user_high);
create index if not exists messages_thread_created_idx on public.messages(thread_id, created_at desc);
alter table public.message_threads enable row level security;
alter table public.messages enable row level security;
grant select, insert on public.message_threads to authenticated;
grant select, insert on public.messages to authenticated;
grant all on public.message_threads, public.messages to service_role;

create table if not exists public.user_blocks (
  blocker_id uuid not null references public.profiles(id) on delete cascade,
  blocked_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint user_blocks_pkey primary key (blocker_id, blocked_id),
  constraint user_blocks_distinct_users check (blocker_id <> blocked_id)
);

create index if not exists user_blocks_blocked_idx on public.user_blocks(blocked_id);
alter table public.user_blocks enable row level security;
revoke all on public.user_blocks from public, anon, authenticated;
grant select on public.user_blocks to authenticated;
grant all on public.user_blocks to service_role;

create policy "user_blocks: blocker read"
  on public.user_blocks for select to authenticated
  using (blocker_id = (select id from public.profiles where auth_user_id = auth.uid() limit 1));

create table if not exists public.moderation_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references public.profiles(id) on delete set null,
  reported_user_id uuid references public.profiles(id) on delete set null,
  message_id uuid references public.messages(id) on delete set null,
  reason text not null,
  state text not null default 'open',
  retained_message_excerpt text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint moderation_reports_reason_check check (reason in (
    'harassment_bullying', 'hate_offensive', 'sexual_inappropriate',
    'spam', 'threat_safety', 'other'
  )),
  constraint moderation_reports_state_check check (state in (
    'open', 'reviewing', 'resolved', 'dismissed'
  ))
);

create index if not exists moderation_reports_state_created_idx
  on public.moderation_reports(state, created_at);
alter table public.moderation_reports enable row level security;
revoke all on public.moderation_reports from public, anon, authenticated;
grant all on public.moderation_reports to service_role;

create table if not exists public.message_filter_terms (
  normalized_term text primary key,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  constraint message_filter_terms_normalized check (
    normalized_term = lower(trim(normalized_term)) and char_length(normalized_term) >= 3
  )
);

alter table public.message_filter_terms enable row level security;
revoke all on public.message_filter_terms from public, anon, authenticated;
grant all on public.message_filter_terms to service_role;

-- Deliberately small, high-confidence starter set. Maintain through reviewed migrations.
insert into public.message_filter_terms(normalized_term) values
  ('kill yourself'),
  ('go kill yourself'),
  ('kys'),
  ('i will kill you'),
  ('i am going to kill you')
on conflict (normalized_term) do nothing;

create table if not exists public.account_deletion_operations (
  id uuid primary key,
  auth_user_id uuid,
  profile_id uuid,
  stage text not null default 'created',
  succeeded boolean not null default false,
  sanitized_error_code text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint account_deletion_stage_check check (stage in (
    'created', 'apple_revoked', 'cleanup_complete', 'auth_deleted', 'failed'
  ))
);

create unique index if not exists account_deletion_active_auth_idx
  on public.account_deletion_operations(auth_user_id) where auth_user_id is not null;
alter table public.account_deletion_operations enable row level security;
revoke all on public.account_deletion_operations from public, anon, authenticated;
grant all on public.account_deletion_operations to service_role;

create or replace function public.fitoff_current_profile_id()
returns uuid language sql stable security definer
set search_path = public, pg_temp
as $$
  select id from public.profiles where auth_user_id = auth.uid() limit 1
$$;

revoke all on function public.fitoff_current_profile_id() from public;
grant execute on function public.fitoff_current_profile_id() to authenticated;

create or replace function public.fitoff_users_blocked(p_first uuid, p_second uuid)
returns boolean language sql stable security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.user_blocks b
    where (b.blocker_id = p_first and b.blocked_id = p_second)
       or (b.blocker_id = p_second and b.blocked_id = p_first)
  )
$$;

revoke all on function public.fitoff_users_blocked(uuid, uuid) from public;
grant execute on function public.fitoff_users_blocked(uuid, uuid) to authenticated, service_role;

create or replace function public.block_user(p_target_id uuid)
returns void language plpgsql security definer
set search_path = public, pg_temp
as $$
declare v_me uuid := public.fitoff_current_profile_id();
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if p_target_id = v_me then raise exception 'cannot_block_self' using errcode = 'P0001'; end if;
  if not exists (select 1 from public.profiles where id = p_target_id and auth_user_id is not null) then
    raise exception 'user_not_found' using errcode = 'P0001';
  end if;

  insert into public.user_blocks(blocker_id, blocked_id)
  values (v_me, p_target_id) on conflict do nothing;

  delete from public.friendships
  where (a_id = least(v_me, p_target_id) and b_id = greatest(v_me, p_target_id));

  delete from public.message_threads
  where user_low = least(v_me, p_target_id) and user_high = greatest(v_me, p_target_id);

  update public.matches set state = 'cancelled', completed_at = now()
  where id in (
    select match_id from public.direct_challenges
    where status = 'pending'
      and ((challenger_id = v_me and recipient_id = p_target_id)
        or (challenger_id = p_target_id and recipient_id = v_me))
  );

  update public.direct_challenges set status = 'declined'
  where status = 'pending'
    and ((challenger_id = v_me and recipient_id = p_target_id)
      or (challenger_id = p_target_id and recipient_id = v_me));
end;
$$;

create or replace function public.unblock_user(p_target_id uuid)
returns void language plpgsql security definer
set search_path = public, pg_temp
as $$
declare v_me uuid := public.fitoff_current_profile_id();
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  delete from public.user_blocks where blocker_id = v_me and blocked_id = p_target_id;
end;
$$;

create or replace function public.get_my_blocked_users()
returns table(id uuid, display_name text, initials text, blocked_at timestamptz)
language sql stable security definer
set search_path = public, pg_temp
as $$
  select p.id, p.display_name, p.initials, b.created_at
  from public.user_blocks b
  join public.profiles p on p.id = b.blocked_id
  where b.blocker_id = public.fitoff_current_profile_id()
  order by b.created_at desc
$$;

create or replace function public.report_user(p_target_id uuid, p_reason text)
returns uuid language plpgsql security definer
set search_path = public, pg_temp
as $$
declare v_me uuid := public.fitoff_current_profile_id(); v_id uuid;
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  if p_target_id = v_me then raise exception 'cannot_report_self' using errcode = 'P0001'; end if;
  insert into public.moderation_reports(reporter_id, reported_user_id, reason)
  values (v_me, p_target_id, p_reason) returning id into v_id;
  return v_id;
end;
$$;

create or replace function public.report_message(p_message_id uuid, p_reason text)
returns uuid language plpgsql security definer
set search_path = public, pg_temp
as $$
declare
  v_me uuid := public.fitoff_current_profile_id();
  v_sender uuid;
  v_body text;
  v_id uuid;
begin
  if v_me is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  select m.sender_id, m.body into v_sender, v_body
  from public.messages m
  join public.message_threads t on t.id = m.thread_id
  where m.id = p_message_id
    and v_me in (t.user_low, t.user_high)
    and m.sender_id <> v_me;
  if v_sender is null then raise exception 'message_not_reportable' using errcode = 'P0001'; end if;

  insert into public.moderation_reports(
    reporter_id, reported_user_id, message_id, reason, retained_message_excerpt
  ) values (v_me, v_sender, p_message_id, p_reason, left(v_body, 500))
  returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.block_user(uuid) from public;
revoke all on function public.unblock_user(uuid) from public;
revoke all on function public.get_my_blocked_users() from public;
revoke all on function public.report_user(uuid, text) from public;
revoke all on function public.report_message(uuid, text) from public;
grant execute on function public.block_user(uuid) to authenticated;
grant execute on function public.unblock_user(uuid) to authenticated;
grant execute on function public.get_my_blocked_users() to authenticated;
grant execute on function public.report_user(uuid, text) to authenticated;
grant execute on function public.report_message(uuid, text) to authenticated;

create or replace function public.fitoff_enforce_safe_pair()
returns trigger language plpgsql security definer
set search_path = public, pg_temp
as $$
declare v_first uuid; v_second uuid;
begin
  if tg_table_name = 'friendships' then v_first := new.a_id; v_second := new.b_id;
  elsif tg_table_name = 'direct_challenges' then v_first := new.challenger_id; v_second := new.recipient_id;
  elsif tg_table_name = 'message_threads' then v_first := new.user_low; v_second := new.user_high;
  else raise exception 'unsupported_pair_table' using errcode = 'P0001';
  end if;
  if public.fitoff_users_blocked(v_first, v_second) then
    raise exception 'interaction_blocked' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists fitoff_friendship_block_guard on public.friendships;
create trigger fitoff_friendship_block_guard before insert or update on public.friendships
for each row execute function public.fitoff_enforce_safe_pair();
drop trigger if exists fitoff_direct_challenge_block_guard on public.direct_challenges;
create trigger fitoff_direct_challenge_block_guard before insert or update on public.direct_challenges
for each row execute function public.fitoff_enforce_safe_pair();
drop trigger if exists fitoff_message_thread_block_guard on public.message_threads;
create trigger fitoff_message_thread_block_guard before insert or update on public.message_threads
for each row execute function public.fitoff_enforce_safe_pair();

create or replace function public.fitoff_enforce_match_participant_block()
returns trigger language plpgsql security definer
set search_path = public, pg_temp
as $$
begin
  if exists (
    select 1 from public.match_participants mp
    where mp.match_id = new.match_id
      and public.fitoff_users_blocked(mp.user_id, new.user_id)
  ) then
    raise exception 'interaction_blocked' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists fitoff_match_participant_block_guard on public.match_participants;
create trigger fitoff_match_participant_block_guard before insert or update on public.match_participants
for each row execute function public.fitoff_enforce_match_participant_block();

create or replace function public.fitoff_validate_message()
returns trigger language plpgsql security definer
set search_path = public, pg_temp
as $$
declare v_low uuid; v_high uuid; v_normalized text;
begin
  select user_low, user_high into v_low, v_high
  from public.message_threads where id = new.thread_id;
  if v_low is null or new.sender_id not in (v_low, v_high) then
    raise exception 'invalid_message_sender' using errcode = 'P0001';
  end if;
  if public.fitoff_users_blocked(v_low, v_high) then
    raise exception 'interaction_blocked' using errcode = 'P0001';
  end if;
  v_normalized := lower(regexp_replace(trim(new.body), '\\s+', ' ', 'g'));
  if exists (
    select 1 from public.message_filter_terms t
    where t.enabled and (
      (position(' ' in t.normalized_term) > 0 and v_normalized like '%' || t.normalized_term || '%')
      or (position(' ' in t.normalized_term) = 0 and v_normalized ~ ('(^|[^a-z0-9])' || t.normalized_term || '([^a-z0-9]|$)'))
    )
  ) then
    raise exception 'message_rejected' using errcode = 'P0001';
  end if;
  return new;
end;
$$;

drop trigger if exists fitoff_message_safety_guard on public.messages;
create trigger fitoff_message_safety_guard before insert or update on public.messages
for each row execute function public.fitoff_validate_message();

-- Replace broad profile discovery with a block-aware policy. Own-profile policy remains.
drop policy if exists "profiles: read others" on public.profiles;
create policy "profiles: read unblocked others"
  on public.profiles for select to public
  using (
    auth_user_id is not null
    and not public.fitoff_users_blocked(id, public.fitoff_current_profile_id())
  );

-- Existing clients remain constrained by RLS as well as the triggers above.
drop policy if exists "message_threads: participant select" on public.message_threads;
create policy "message_threads: participant select"
  on public.message_threads for select to public
  using (
    public.fitoff_current_profile_id() in (user_low, user_high)
    and not public.fitoff_users_blocked(user_low, user_high)
  );

drop policy if exists "message_threads: friend pair insert" on public.message_threads;
create policy "message_threads: friend pair insert"
  on public.message_threads for insert to authenticated
  with check (
    public.fitoff_current_profile_id() in (user_low, user_high)
    and not public.fitoff_users_blocked(user_low, user_high)
    and exists (
      select 1 from public.friendships f
      where f.a_id = user_low and f.b_id = user_high and f.status = 'accepted'
    )
  );

drop policy if exists "messages: participant select" on public.messages;
create policy "messages: participant select"
  on public.messages for select to public
  using (exists (
    select 1 from public.message_threads t
    where t.id = thread_id
      and public.fitoff_current_profile_id() in (t.user_low, t.user_high)
      and not public.fitoff_users_blocked(t.user_low, t.user_high)
  ));

drop policy if exists "messages: friend send insert" on public.messages;
create policy "messages: friend send insert"
  on public.messages for insert to authenticated
  with check (
    sender_id = public.fitoff_current_profile_id()
    and exists (
      select 1 from public.message_threads t
      join public.friendships f on f.a_id = t.user_low and f.b_id = t.user_high
      where t.id = thread_id and f.status = 'accepted'
        and public.fitoff_current_profile_id() in (t.user_low, t.user_high)
        and not public.fitoff_users_blocked(t.user_low, t.user_high)
    )
  );

-- A single anonymous profile preserves only completed/forfeit outcomes for opponents.
alter table public.profiles alter column auth_user_id drop not null;
insert into public.profiles(
  id, auth_user_id, display_name, initials, avatar_url, subscription_tier,
  apns_token, timezone, notifications_enabled, live_activity_push_token
) values (
  '00000000-0000-0000-0000-00000000dead', null, 'Deleted Player', 'DP', null, 'free',
  null, null, false, null
) on conflict (id) do update set
  auth_user_id = null, display_name = 'Deleted Player', initials = 'DP', avatar_url = null,
  subscription_tier = 'free', apns_token = null, timezone = null,
  notifications_enabled = false, live_activity_push_token = null;

alter table public.matches add column if not exists completion_reason text;
alter table public.matches add column if not exists forfeit_winner_id uuid references public.profiles(id) on delete set null;

create or replace function public.perform_account_deletion_cleanup(p_operation_id uuid)
returns void language plpgsql security definer
set search_path = public, auth, pg_temp
as $$
declare
  v_auth_user uuid := auth.uid();
  v_profile uuid;
  v_deleted constant uuid := '00000000-0000-0000-0000-00000000dead';
begin
  if v_auth_user is null then raise exception 'not_authenticated' using errcode = 'P0001'; end if;
  select id into v_profile from public.profiles where auth_user_id = v_auth_user for update;

  -- Idempotent completion: the Edge Function may retry after the profile cleanup stage.
  if v_profile is null then
    if exists (
      select 1 from public.account_deletion_operations
      where id = p_operation_id and auth_user_id = v_auth_user and stage in ('cleanup_complete', 'auth_deleted')
    ) then return; end if;
    raise exception 'profile_not_found' using errcode = 'P0001';
  end if;

  if not exists (
    select 1 from public.account_deletion_operations
    where id = p_operation_id and auth_user_id = v_auth_user and profile_id = v_profile
  ) then raise exception 'operation_mismatch' using errcode = 'P0001'; end if;

  -- Pending/searching matches and challenges have no history to retain.
  delete from public.matches m
  where m.state in ('searching', 'pending')
    and exists (select 1 from public.match_participants mp where mp.match_id = m.id and mp.user_id = v_profile);

  update public.matches m set
    state = 'completed', completed_at = coalesce(completed_at, now()),
    completion_reason = 'account_deletion_forfeit',
    forfeit_winner_id = (
      select mp.user_id from public.match_participants mp
      where mp.match_id = m.id and mp.user_id <> v_profile limit 1
    )
  where m.state = 'active'
    and exists (select 1 from public.match_participants mp where mp.match_id = m.id and mp.user_id = v_profile);

  update public.match_days md set
    status = case when status = 'finalized' then status else 'finalized' end,
    is_void = case when status = 'finalized' then is_void else true end,
    finalized_at = coalesce(finalized_at, now()),
    winner_user_id = case when winner_user_id = v_profile then v_deleted else winner_user_id end
  where exists (
    select 1 from public.match_participants mp where mp.match_id = md.match_id and mp.user_id = v_profile
  );

  -- Remove every retained health value before replacing the historical participant.
  delete from public.metric_snapshots where user_id = v_profile;
  delete from public.match_day_participants where user_id = v_profile;

  -- If the other participant was already deleted, nobody needs this anonymous match history.
  delete from public.matches m
  where exists (select 1 from public.match_participants x where x.match_id = m.id and x.user_id = v_profile)
    and exists (select 1 from public.match_participants x where x.match_id = m.id and x.user_id = v_deleted);

  update public.match_participants set user_id = v_deleted
  where user_id = v_profile and match_id in (select id from public.matches where state = 'completed');

  update public.match_days set winner_user_id = v_deleted where winner_user_id = v_profile;

  -- Reports may remain for workflow integrity, but no identifying link or excerpt remains.
  update public.moderation_reports set
    reporter_id = case when reporter_id = v_profile then null else reporter_id end,
    reported_user_id = case when reported_user_id = v_profile then null else reported_user_id end,
    retained_message_excerpt = case
      when reporter_id = v_profile or reported_user_id = v_profile then null
      else retained_message_excerpt
    end,
    message_id = case
      when reporter_id = v_profile or reported_user_id = v_profile then null
      else message_id
    end,
    updated_at = now()
  where reporter_id = v_profile or reported_user_id = v_profile;

  delete from public.app_logs where user_id = v_profile;
  delete from public.analytics_events where user_id = v_profile;
  delete from public.tester_feedback where user_id = v_profile;
  delete from public.profiles where id = v_profile;

  update public.account_deletion_operations
  set stage = 'cleanup_complete', updated_at = now(), sanitized_error_code = null
  where id = p_operation_id;
end;
$$;

revoke all on function public.perform_account_deletion_cleanup(uuid) from public;
grant execute on function public.perform_account_deletion_cleanup(uuid) to authenticated;
