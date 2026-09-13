# FitUp App Store Launch Checklist

Shared checklist for shipping FitUp with free-tier limits and FitUp Pro monthly.  
Fill **Phase E** with the other AI that just shipped (StoreKit / ASC / RevenueCat).

**Full You vs Agent release playbook** (Pondera-style process adapted to FitUp): [fitup-app-store-release-playbook.md](fitup-app-store-release-playbook.md)

---

## Locked product rules (v1)

### Free
- Exactly **1** open battle at a time (searching + pending + active)
- Duration locked to **3 days only**
- After a battle **fully completes**, wait until the **next local calendar day after the completion date** before starting another
- Start paths: **Quick/random match** + **SMS / share invite-a-friend** (App Store link)
- No free Discover / in-app direct challenge to arbitrary FitUp users

### Premium (`pro`)
- Unlimited battles, all durations (1 / 3 / 5 / 7), in-app direct challenges
- **$2.99 / month** with **1-week free trial** (ASC introductory offer + RevenueCat)
- Paywall UI: monthly primary

### Build
- Production archive with `FITUP_TESTFLIGHT_BYPASS = NO` (already set in repo for App Store)

---

## Phase A — Free-tier rules (app code)

Status: **Implemented in repo**

| Item | Where |
|------|--------|
| Slot limit + cooldown gate | [`SubscriptionService.swift`](../FitUp/FitUp/FitUp/Services/SubscriptionService.swift), [`MatchmakingService.evaluateEntryGate`](../FitUp/FitUp/FitUp/Services/MatchmakingService.swift) |
| Last completed end date | [`MatchRepository.fetchLatestCompletedMatchEndDate`](../FitUp/FitUp/FitUp/Repositories/MatchRepository.swift) |
| Free duration lock (3-day) | [`DurationStepView`](../FitUp/FitUp/FitUp/Views/Challenge/Steps/FormatStepView.swift), [`ChallengeFlowView`](../FitUp/FitUp/FitUp/Views/Challenge/ChallengeFlowView.swift) |
| Free opponent paths (Quick + Invite) | [`OpponentStepView`](../FitUp/FitUp/FitUp/Views/Challenge/Steps/OpponentStepView.swift) |
| SMS / share invite | [`ActivityShareSheet`](../FitUp/FitUp/FitUp/Views/Shared/ActivityShareSheet.swift), [`FitUpAppLinks.inviteFriendShareText`](../FitUp/FitUp/FitUp/Utilities/FitUpAppLinks.swift) |
| Onboarding first search = 3 days | [`MatchSearchRepository`](../FitUp/FitUp/FitUp/Repositories/MatchSearchRepository.swift) (`durationDays: 3`) |

- [x] Gate blocks free users on slot limit after first completed match
- [x] Gate blocks free users until day after last completed battle ends
- [x] Free duration forced to 3-day
- [x] Free: Quick Battle + Invite Friend only
- [x] Onboarding search uses 3-day duration

---

## Phase B — Monetization UI (app)

Status: **Implemented in repo** (products still configured in Phase E)

| Item | Where |
|------|--------|
| Monthly paywall + trial copy | [`PaywallView.swift`](../FitUp/FitUp/FitUp/Views/Paywall/PaywallView.swift) |
| Entitlement id `pro` | [`SubscriptionService.swift`](../FitUp/FitUp/FitUp/Services/SubscriptionService.swift) |
| Privacy + Terms on paywall | `FitUpAppLinks` |
| Secrets template | [`Secrets.example.xcconfig`](../FitUp/FitUp/Config/Secrets.example.xcconfig) |

- [x] Monthly primary UI at `$2.99` fallback + 7-day trial CTA
- [x] Restore Purchases
- [ ] Real `REVENUECAT_API_KEY` in local `Secrets.xcconfig` (you / other AI — not committed)

---

## Phase C — Compliance / App Store hygiene

Status: **Mostly implemented in repo**

| Item | Where |
|------|--------|
| Bypass off | [`BetaFlags.xcconfig`](../FitUp/FitUp/Config/BetaFlags.xcconfig) → `FITUP_TESTFLIGHT_BYPASS = NO` |
| Terms of Use | [`docs/terms/index.html`](terms/index.html) → publish to `https://scootero.github.io/FitUp-App/terms/` |
| Privacy fix + in-app delete copy | [`docs/privacy/index.html`](privacy/index.html) |
| In-app account deletion | [`AccountDeletionRequestView.swift`](../FitUp/FitUp/FitUp/Views/Profile/AccountDeletionRequestView.swift) + Edge Function [`delete-account`](../supabase/functions/delete-account/index.ts) |
| Messaging hidden for review | `AppLaunchFlags.messagingEnabled = false` in [`FitUpAppLinks.swift`](../FitUp/FitUp/FitUp/Utilities/FitUpAppLinks.swift) |
| Support / Terms / Privacy in Profile | [`ProfileView.swift`](../FitUp/FitUp/FitUp/Views/Profile/ProfileView.swift) |

- [x] Bypass = NO
- [x] Terms HTML added
- [x] Privacy Account Deletion section fixed (duplicate `</p>` removed; in-app delete documented)
- [x] Automated delete UI + `delete-account` function source
- [ ] **Deploy** `supabase functions deploy delete-account` on production project
- [ ] **Publish** `docs/terms/` (and updated privacy) to GitHub Pages
- [x] Messaging UI gated off for App Review (re-enable later with UGC report/block)
- [ ] Push IPA check vs `APNS_USE_SANDBOX` ([testflight-push-verification.md](testflight-push-verification.md)) — do not edit entitlements blindly

---

## Phase D — You / Connect (manual)

- [ ] Archive with bypass off; upload to App Store Connect
- [ ] Internal TestFlight smoke (2 accounts): Health, matchmaking, free cooldown, paywall, sandbox purchase
- [ ] Screenshots, description, keywords, age rating
- [ ] App Privacy questionnaire (HealthKit not for ads)
- [ ] Review notes: how to test 1v1 (two sandbox accounts), Health permissions, subscription
- [ ] Replace placeholder App Store URL in [`FitUpAppLinks.appStoreURL`](../FitUp/FitUp/FitUp/Utilities/FitUpAppLinks.swift) once listing exists
- [ ] Fill **Phase E** with other AI

---

## Phase E — StoreKit / Xcode / payments (BLANK — other AI)

> FitUp code expects RevenueCat entitlement **`pro`** and a **monthly** package. Fill this section with the other AI that just released.

- [ ] App Store Connect → In-App Purchases → Auto-Renewable Subscription
- [ ] Product id: `fitup_pro_monthly`
- [ ] Price: **$2.99 USD / month**
- [ ] Introductory offer: **1 week free**
- [ ] Subscription group + localization + review notes for IAP
- [ ] RevenueCat: app, public API key → `FitUp/FitUp/Config/Secrets.xcconfig` → `REVENUECAT_API_KEY`
- [ ] RevenueCat entitlement: `pro` → attach monthly product
- [ ] RevenueCat current Offering with monthly package
- [ ] Paid Apps Agreement / banking / tax in ASC
- [ ] Sandbox testers; verify trial → paid; Restore
- [ ] Xcode: Signing & Capabilities, Archive, upload
- [ ] (Optional later) Annual product — not required for this launch
- [ ] _Other AI notes:_ _______________________________

---

## Smoke verification (dev / TestFlight)

See [app-store-launch-smoke.md](app-store-launch-smoke.md).

---

## Out of scope (this launch)

- Deep-link auto-start match from SMS invite
- Stats backend TODOs / health history charts deferred work
- Changing push entitlements unless IPA verification fails
- Annual subscription as a launch requirement
- Shipping in-app DMs (gated off until UGC ready)
