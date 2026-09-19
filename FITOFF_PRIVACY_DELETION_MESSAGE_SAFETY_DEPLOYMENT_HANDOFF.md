# FitOff Privacy, Deletion, and Message Safety Deployment Handoff

All actions below are owner-controlled and were intentionally not performed by the local implementation task.

## Required order

1. **Database migration and policies**
   - Review and deploy `supabase/migrations/20260918120000_privacy_deletion_message_safety.sql`.
   - Run `supabase/manual_sql/verify_privacy_deletion_message_safety.sql` as read-only structural verification.
   - Use disposable users A, B, and C to test both block directions and confirm C is unaffected.
   - Verify authenticated clients cannot select, update, or delete `moderation_reports`.

2. **Edge Function and Apple secrets**
   - Configure `APPLE_CLIENT_ID`, `APPLE_TEAM_ID`, `APPLE_KEY_ID`, and `APPLE_PRIVATE_KEY` as Supabase Edge Function secrets. Use the native Sign in with Apple client identifier for this app.
   - Deploy `supabase/functions/delete-account` with normal JWT verification enabled.
   - Do not print or inspect authorization codes, Apple tokens, the private key, user JWTs, or notification tokens.
   - Test email/password deletion and Sign in with Apple deletion with disposable accounts.
   - Confirm the Apple authorization is revoked and the deleted Apple identity does not silently recover its former FitOff data.

3. **iOS build**
   - Archive and upload a new build only after the database and Edge Function are live and verified.
   - The local simulator build does not prove production deletion, Apple revocation, or notification behavior.

4. **Website publication**
   - Publish the updated `FitOff-website-upload` package to the existing Cloudflare Pages project.
   - Verify `https://fitoff.pages.dev/privacy/` and the Support page return HTTP 200 and show the updated deletion and safety language.

5. **Two-account TestFlight validation**
   - Use at least users A and B, plus C for non-interference checks.
   - Cover every acceptance item in the implementation plan: blocks, unblocks, reports, filtering, active-battle communication suppression, anonymous completed outcomes, deletion-stage retries, and removal of all associated data.
   - Also regression-test HealthKit onboarding/sync, battles, notifications, messaging, friends, purchase/restore, email auth, and Sign in with Apple.

6. **App Store Connect metadata**
   - Set the Privacy URL to `https://fitoff.pages.dev/privacy/`.
   - Review and publish App Privacy answers that match the deployed collection, reports, moderation, analytics, HealthKit, and deletion behavior.
   - These portal changes require owner review and are separate from uploading or submitting the build.

