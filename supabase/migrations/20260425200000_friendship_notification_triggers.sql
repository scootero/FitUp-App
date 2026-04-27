-- Push notifications: friend request received (recipient) and friend request accepted (original requester).

set check_function_bodies = off;

create or replace function public.notify_friend_request_insert()
  returns trigger
  language plpgsql
  security definer
  set search_path to 'public', 'pg_temp'
as $function$
declare
  v_recipient uuid;
  v_requester_name text;
begin
  if new.status is distinct from 'pending' then
    return new;
  end if;

  v_recipient := case
    when new.requested_by = new.a_id then new.b_id
    else new.a_id
  end;

  select coalesce(display_name, 'Player')
  into v_requester_name
  from public.profiles
  where id = new.requested_by
  limit 1;

  perform private.invoke_dispatch_notification(
    array[v_recipient],
    'friend_request_received',
    jsonb_build_object(
      'peer_profile_id', new.requested_by::text,
      'from_display_name', v_requester_name,
      'opponent_display_name', v_requester_name,
      'deep_link_target', 'friends'
    )
  );

  return new;
end;
$function$;

create or replace function public.notify_friend_request_accepted()
  returns trigger
  language plpgsql
  security definer
  set search_path to 'public', 'pg_temp'
as $function$
declare
  v_requester uuid;
  v_accepter uuid;
  v_accepter_name text;
begin
  if old.status is distinct from 'pending' or new.status is distinct from 'accepted' then
    return new;
  end if;

  v_requester := new.requested_by;
  v_accepter := case
    when new.requested_by = new.a_id then new.b_id
    else new.a_id
  end;

  select coalesce(display_name, 'Player')
  into v_accepter_name
  from public.profiles
  where id = v_accepter
  limit 1;

  perform private.invoke_dispatch_notification(
    array[v_requester],
    'friend_request_accepted',
    jsonb_build_object(
      'peer_profile_id', v_accepter::text,
      'accepter_display_name', v_accepter_name,
      'opponent_display_name', v_accepter_name,
      'deep_link_target', 'home'
    )
  );

  return new;
end;
$function$;

create trigger tr_notify_friend_request_insert
  after insert on public.friendships
  for each row
  execute function public.notify_friend_request_insert();

create trigger tr_notify_friend_request_accepted
  after update on public.friendships
  for each row
  execute function public.notify_friend_request_accepted();
