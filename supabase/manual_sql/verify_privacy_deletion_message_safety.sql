-- READ-ONLY structural verification after owner deployment.
-- Behavioral A/B/C and deletion tests must use disposable TestFlight/Sandbox accounts.

select table_name
from information_schema.tables
where table_schema = 'public'
  and table_name in (
    'user_blocks', 'moderation_reports', 'message_filter_terms',
    'account_deletion_operations'
  )
order by table_name;

select routine_name
from information_schema.routines
where routine_schema = 'public'
  and routine_name in (
    'block_user', 'unblock_user', 'get_my_blocked_users',
    'report_user', 'report_message', 'fitoff_validate_message',
    'perform_account_deletion_cleanup'
  )
order by routine_name;

select tablename, policyname, cmd, roles
from pg_policies
where schemaname = 'public'
  and tablename in ('user_blocks', 'moderation_reports', 'message_threads', 'messages')
order by tablename, policyname;

select event_object_table, trigger_name, action_timing, event_manipulation
from information_schema.triggers
where trigger_schema = 'public'
  and trigger_name in (
    'fitoff_friendship_block_guard', 'fitoff_direct_challenge_block_guard',
    'fitoff_message_thread_block_guard', 'fitoff_match_participant_block_guard',
    'fitoff_message_safety_guard'
  )
order by event_object_table, trigger_name;

select id, auth_user_id, display_name, initials, avatar_url, apns_token,
       live_activity_push_token, subscription_tier
from public.profiles
where id = '00000000-0000-0000-0000-00000000dead'::uuid;

select grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
  and table_name = 'moderation_reports'
order by grantee, privilege_type;

