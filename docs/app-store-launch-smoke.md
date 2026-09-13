# FitUp App Store — Smoke Verification

Run on a **physical device** build with `FITUP_TESTFLIGHT_BYPASS = NO` and a real RevenueCat key once Phase E is filled.

## 1. Build / config

- [ ] Confirm [`BetaFlags.xcconfig`](../FitUp/FitUp/Config/BetaFlags.xcconfig): `FITUP_TESTFLIGHT_BYPASS = NO`
- [ ] Confirm local `Secrets.xcconfig` has real `REVENUECAT_API_KEY` (not the example placeholder)
- [ ] Profile does **not** show TestFlight Dev Mode / paywall bypass in Release
- [ ] Messages icon hidden in top bar / Profile (`AppLaunchFlags.messagingEnabled = false`)

## 2. Free-tier gating

Use a **non-premium** sandbox / fresh account.

- [ ] Onboarding find-opponent creates a **3-day** search (not 1-day)
- [ ] New Battle → free user sees **Quick Battle** + **Invite a Friend** only (no Discover list)
- [ ] Invite share sheet shows download text + App Store URL
- [ ] Duration step only offers **3-day** (or auto-locks to it)
- [ ] Opening New Battle while searching/pending/active → blocked + paywall (after first completed match)
- [ ] After a completed free battle, same calendar day → cooldown block + paywall
- [ ] Next local calendar day after completion → can start another free 3-day Quick Battle
- [ ] Prefill / rematch / Discover challenge as free → paywall (Pro required)

## 3. Premium / paywall

- [ ] Paywall shows monthly **$2.99** (or StoreKit localized price) and **7-day free trial** CTA when intro offer is configured
- [ ] Privacy Policy + Terms of Use links open
- [ ] Sandbox purchase / Start Free Trial → `pro` entitlement → unlimited battles + all durations + direct challenge
- [ ] Restore Purchases works
- [ ] Profile → Account Deletion → confirm → account deleted and signed out  
  (requires `delete-account` Edge Function deployed)

## 4. Core product smoke (2 accounts)

- [ ] Sign in with Apple / email
- [ ] HealthKit permission + steps sync
- [ ] Quick Battle pairs two accounts (or direct challenge as Pro)
- [ ] Match Details / Home hero update
- [ ] Push notification arrives on TestFlight / production IPA (verify `aps-environment` vs Supabase `APNS_USE_SANDBOX`)

## 5. Legal URLs (device Safari)

- [ ] https://scootero.github.io/FitUp-App/privacy/
- [ ] https://scootero.github.io/FitUp-App/terms/  
  (publish `docs/terms/` to GitHub Pages before submission)

---

**Checklist index:** [app-store-launch-checklist.md](app-store-launch-checklist.md)
