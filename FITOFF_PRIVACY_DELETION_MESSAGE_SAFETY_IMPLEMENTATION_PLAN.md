# FitOff v1 Privacy, Deletion, and Message Safety Implementation Plan

## Purpose

Implement a focused App Store compliance update without redesigning unrelated FitOff behavior or overwriting unrelated worktree changes.

- Implement Sign in with Apple token revocation as a required part of Apple-account deletion.
- Replace email-only deletion with a simple in-app deletion flow.
- Delete user-associated content and health data while preserving only anonymous battle outcomes needed by opponents.
- Add blocking, reporting, and basic message filtering.
- Correct every in-app privacy link to `https://fitoff.pages.dev/privacy/`.

## Worktree and Authority Boundaries

- Work in `/Users/scott/Desktop/FitUp-App----DONE--off-icloud`.
- Inspect `git status` and relevant diffs before editing. The worktree is dirty; preserve every unrelated existing change.
- Do not reset, stash, delete, overwrite, stage, commit, or sweep unrelated work.
- Local source, migrations, Edge Function code, website package files, tests, and documentation may be implemented and verified.
- Do not deploy Supabase migrations or Edge Functions, change Supabase secrets, publish Cloudflare Pages, or edit App Store Connect without Scott's explicit approval.
- Treat local builds and tests as local evidence only, not proof of deployment, device behavior, App Store Connect configuration, or Apple approval.

## Account Deletion

### User experience

Under **Settings → Account**, add:

> **Delete Account**  
> Permanently delete your FitOff account and associated data.

Tapping it presents Apple's standard destructive confirmation:

> **Delete Account?**  
> This permanently deletes your account and associated personal data and cannot be undone.
>
> If you have an active App Store subscription, deleting your account does not automatically cancel your subscription.
>
> **Cancel** | **Delete Account**

- Do not require typing `DELETE`, emailing support, or visiting a website.
- Disable the destructive action and show progress while deletion runs.
- On success, clear local FitOff state, sign out, and show a short completion screen.
- On failure, keep the account signed in, show a retryable error, and include the deletion operation ID for support.

### Backend behavior

Add an authenticated, idempotent `delete-account` Supabase Edge Function backed by a transactional cleanup operation.

- Verify the current Supabase JWT and resolve the authenticated profile on the server.
- For Sign in with Apple accounts:
  - request fresh Apple authorization in the app;
  - transmit the one-use authorization code securely to the Edge Function;
  - exchange it server-side and call Apple's token-revocation endpoint;
  - never log or persist the authorization code, access token, refresh token, identity token, or Apple private key.
- Do not silently skip required Apple revocation. A revocation failure must leave deletion retryable and create only a sanitized stage/error log.
- Delete the Supabase Auth user so the account cannot authenticate again.
- Make every cleanup stage idempotent so the same operation can safely resume after interruption.
- A delayed/manual queue is only a fallback if testing proves synchronous deletion cannot be made reliable. If introduced, state an exact completion time and confirmation method in both UI and policy.

Apple references:

- [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
- [Handling account deletions and revoking tokens for Sign in with Apple](https://developer.apple.com/documentation/technotes/tn3194-handling-account-deletions-and-revoking-tokens-for-sign-in-with-apple)

### Data removal and battles

Delete or remove the account's association with:

- Authentication credentials and identifying profile fields
- APNs and Live Activity tokens
- Friendships, blocks, pending challenges, and matchmaking requests
- Messages authored by the deleted user and other user-associated content
- Raw and derived HealthKit records, detailed step/calorie history, baselines, and intraday data
- Product analytics, feedback, and ordinary diagnostic logs
- FitOff-stored subscription entitlement state

Battle behavior:

- An active battle ends immediately as a forfeit to the remaining player.
- Pending battles and direct challenges are cancelled.
- Completed battles retain only the minimum anonymous outcome required for the other player's history.
- Replace the deleted participant with an unlinked `Deleted Player` representation containing no auth ID, display name, email, avatar, tokens, health values, or identifying fields.
- Historical UI may show the win/loss outcome but must not expose deleted-user charts, messages, health totals, profile navigation, friend controls, or rematch controls.
- A moderation report row may remain for workflow integrity, but remove its identifying fields and retained message excerpt when the associated account is deleted.

## Message Safety

- Add directional blocks enforced through Supabase RLS and server-side functions.
- A block must prevent messages, friend requests, direct challenges, opponent suggestions, and random matchmaking in either direction.
- Blocking removes the current friendship and hides the conversation.
- Blocking does not cancel an existing active battle; it suppresses communication and prevents future rematches.
- Add **Block User** and **Report User** to the conversation menu.
- Add **Report Message** to actions for incoming messages.
- Add **Blocked Users** under Settings so users can review and unblock people.
- Store reports in a restricted Supabase moderation queue with fixed reasons and `open`, `reviewing`, `resolved`, and `dismissed` states.
- Use these fixed user-facing reasons: harassment/bullying, hate/offensive content, sexual/inappropriate content, spam, threat/safety, and other.
- App clients may submit reports but may not list, update, or delete moderation-queue rows.
- Add conservative server-side filtering using a maintained set of high-confidence abusive terms.
- Never place rejected message content in logs.
- Enforce blocking and message validation at the backend so an older client cannot bypass them.

## Privacy, Interfaces, and Logging

- Centralize legal URLs and update the Profile and paywall Privacy links to `https://fitoff.pages.dev/privacy/`.
- Keep the Apple Standard EULA link unchanged.
- Update the public Privacy and Support source pages to describe real deletion, anonymous battle retention, blocking, reports, and moderation.
- Provide typed Swift interfaces for account deletion, block, unblock, blocked-user loading, user reporting, and message reporting.
- Keep diagnostics deliberately small:
  - `account_deletion`: operation ID, stage, success/failure, and sanitized error code;
  - `moderation`: failed block/report/filter operations only.
- Successful block and report records are already their audit trail and do not need duplicate diagnostic events.
- Never log email, display name, message/report text, HealthKit values, Apple credentials, authorization codes, user tokens, or notification tokens.
- Retain diagnostic logs under the existing 14-day policy.
- App Store Connect must ultimately use the same Privacy URL and disclose the data FitOff actually collects, but those portal changes are owner-controlled and outside local implementation.

## Tests and Acceptance Criteria

### Account deletion

- Test both email/password and Sign in with Apple accounts.
- Verify Apple authorization is revoked and the deleted Apple user cannot silently recover the old FitOff account.
- Verify the Supabase Auth user and all identifying, message, HealthKit, notification, analytics, feedback, and entitlement data are removed.
- Verify deletion during an active battle produces the correct forfeit.
- Verify opponents retain only an anonymous completed outcome and no deleted-user metrics or navigation.
- Interrupt or fail each deletion stage and verify retrying the same operation completes safely.
- Verify failure UI keeps the account signed in and presents a non-sensitive operation ID.

### Message safety

- With users A, B, and C, verify a block initiated by either side prevents every specified future interaction between that pair without affecting C.
- Verify unblocking does not automatically recreate a friendship or conversation.
- Verify an existing active battle continues without messaging and cannot be rematched afterward.
- Verify RLS prevents clients from reading, changing, or deleting moderation reports.
- Verify report content is server-derived where applicable and deletion scrubs identifying/report-excerpt fields.
- Verify message filtering rejects configured abusive terms without logging message text.

### Regression and release boundaries

- Regression-test HealthKit onboarding and synchronization, battles, notifications, messaging, friend flows, subscription purchase/restore, email sign-in, and Sign in with Apple.
- Run targeted unit tests plus an iOS simulator build without altering unrelated source.
- Prepare deployment instructions in this order: database migration and policies → Edge Function and Apple secrets → iOS build → website publication → two-account TestFlight validation → App Store Connect metadata.
- Clearly mark every unperformed external action as owner-required; do not claim local verification proves deployment or App Store readiness.

