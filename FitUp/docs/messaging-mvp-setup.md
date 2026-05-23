# Messaging MVP — setup and debug

Friend-gated 1:1 threads and text messages. Schema is applied **manually** (not via `supabase/migrations`).

## Deploy schema (once per project)

1. Open Supabase SQL Editor for the target project.
2. Run [`supabase/manual_sql/messaging_mvp.sql`](../supabase/manual_sql/messaging_mvp.sql) (idempotent).
3. Run [`supabase/manual_sql/messaging_notify_on_message_insert.sql`](../supabase/manual_sql/messaging_notify_on_message_insert.sql) (push on new DM).
4. Deploy updated `dispatch-notification` edge function (adds `message_received` copy).
5. Run readonly checks: [`supabase/manual_sql/messaging_mvp_00_readonly_checks.sql`](../supabase/manual_sql/messaging_mvp_00_readonly_checks.sql).
6. Paste results into [`supabase/manual_sql/messaging_mvp_00_readonly_results.md`](../supabase/manual_sql/messaging_mvp_00_readonly_results.md).

### Readonly pass criteria

| Check | Expected |
|-------|----------|
| Tables | `message_threads`, `messages` exist |
| RLS | 4 policies (2 per table) |
| Grants | `authenticated` has SELECT + INSERT |
| Trigger | `tr_messages_touch_thread_last` on `messages` |

## Rules (RLS)

- **Read:** Thread participants can SELECT threads and messages (even if friendship later ends).
- **Write:** INSERT thread or message requires `friendships.status = 'accepted'` for the canonical pair (`user_low` / `user_high` = `a_id` / `b_id`).

## iOS surfaces

| Surface | Path |
|---------|------|
| Inbox | Profile → Messages, or top bar Messages icon |
| Chat | `ChatThreadView` via inbox `NavigationLink` |
| Match / peer | Match Details or Peer Profile (friend-gated before new thread) |

## Common failure: “Could not load messages right now”

**Fixed (May 2026):** `fetchThreadId` selected only `id` but decoded full `MessageThreadRecord`, causing decode failure when opening an existing thread from the inbox.

If issues persist:

1. Confirm `messaging_mvp.sql` ran on the project the app points at.
2. Run section 6 of readonly checks with your `profiles.id` and peer id.
3. In Xcode, filter logs for `messaging` / `chat_load_failed` — PostgREST `pg_code` / `pg_message` are logged via `AppLogger`.

## Related files

- [`MessageRepository.swift`](../FitUp/FitUp/Repositories/MessageRepository.swift) — client API
- [`ChatThreadView.swift`](../FitUp/FitUp/Views/Messages/ChatThreadView.swift) — chat UI
- [`MessagesInboxView.swift`](../FitUp/FitUp/Views/Messages/MessagesInboxView.swift) — inbox list
