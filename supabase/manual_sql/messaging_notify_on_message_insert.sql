-- =============================================================================
-- Push notification when a friend sends a direct message (recipient only).
-- Run after messaging_mvp.sql. Idempotent trigger replace.
-- =============================================================================

set check_function_bodies = off;

create or replace function public.notify_message_insert()
  returns trigger
  language plpgsql
  security definer
  set search_path to 'public', 'pg_temp'
as $function$
declare
  v_thread public.message_threads%rowtype;
  v_recipient uuid;
  v_sender_name text;
  v_preview text;
begin
  select * into v_thread from public.message_threads where id = new.thread_id;
  if not found then
    return new;
  end if;

  if new.sender_id = v_thread.user_low then
    v_recipient := v_thread.user_high;
  else
    v_recipient := v_thread.user_low;
  end if;

  if v_recipient = new.sender_id then
    return new;
  end if;

  select coalesce(display_name, 'Player')
  into v_sender_name
  from public.profiles
  where id = new.sender_id
  limit 1;

  v_preview := left(trim(both from new.body), 120);

  perform private.invoke_dispatch_notification(
    array[v_recipient],
    'message_received',
    jsonb_build_object(
      'thread_id', new.thread_id::text,
      'peer_profile_id', new.sender_id::text,
      'sender_display_name', v_sender_name,
      'opponent_display_name', v_sender_name,
      'message_preview', v_preview,
      'deep_link_target', 'messages'
    )
  );

  return new;
end;
$function$;

drop trigger if exists tr_notify_message_insert on public.messages;
create trigger tr_notify_message_insert
  after insert on public.messages
  for each row
  execute function public.notify_message_insert();
