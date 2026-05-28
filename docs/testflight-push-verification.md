# TestFlight Push Notification Verification

**Sub-doc** for [testflight-README.md](testflight-README.md) **Phase 2**.  
App Store Connect metadata: [testflight-external-compliance-checklist.md](testflight-external-compliance-checklist.md).  
Xcode archive & App IDs: [testflight-xcode-and-apple-developer.md](testflight-xcode-and-apple-developer.md).

**Rule:** Do **not** change entitlements, signing, provisioning, Supabase `APNS_*` secrets, or app code unless a step below fails—and **stop for approval** before any fix.

---

## Prerequisites

- [ ] Build installed from **TestFlight** (not Xcode **Run** on device)
- [ ] Physical iPhone (Simulator does not receive APNs)
- [ ] Two FitUp accounts (match search or direct challenge to trigger server push)
- [ ] Phase 0 archive completed ([Xcode doc](testflight-xcode-and-apple-developer.md))

---

## 1. Inspect signed app entitlements (trust the IPA, not the repo file)

**Why:** `FitUp/FitUp/Config/FitUp.entitlements` may list `aps-environment` = `development`, but **distribution/TestFlight IPAs often embed `production`**. Server sandbox flag must match the **signed** value.

### Get an IPA

| Source | Where to click |
|--------|----------------|
| From archive | Xcode → **Window → Organizer** → select archive → **Distribute App** → **Custom** → **App Store Connect** or export → save `.ipa` |
| From Connect | **TestFlight** → build → **Build Metadata** → download if available |

### Inspect entitlements

```bash
unzip -q FitUp.ipa -d /tmp/fitup_ipa
codesign -d --entitlements :- /tmp/fitup_ipa/Payload/FitUp.app/FitUp 2>/dev/null | plutil -p -
```

**Look for:** `"aps-environment" => "production"` (expected for TestFlight).

| Result | Action |
|--------|--------|
| `production` | Continue to §2 |
| `development` on TestFlight IPA | **Stop.** Do not edit entitlements yet—note build number and ask (signing/profile issue) |
| Missing `aps-environment` | **Stop.** Enable Push on App ID → regenerate profiles → re-archive ([Xcode doc §1](testflight-xcode-and-apple-developer.md)) |

**What would change if wrong (approval required):** `FitUp.entitlements`, Xcode capabilities, or provisioning—not Supabase until IPA is correct.

---

## 2. Apple Developer Portal (capability exists)

**Where:** [developer.apple.com](https://developer.apple.com) → **Certificates, Identifiers & Profiles** → **Identifiers** → **`com.ScottOliver.FitUp`**.

- [ ] **Push Notifications** capability enabled (checkbox on App ID)
- [ ] If you just enabled it: Xcode → **Signing & Capabilities** → toggle signing off/on or **Download Manual Profiles** so archive uses a fresh profile

**Widget extension** `com.ScottOliver.FitUp.FitUpWidgetExtension`: required for embedded extension; Live Activity **push tokens** stored in `profiles.live_activity_push_token` (separate from alert `apns_token`).

**What changes:** Portal + automatic profiles only—no repo edit in this step.

---

## 3. Backend environment (verify only — do not change blindly)

**Where:** Supabase Dashboard → **Project** → **Edge Functions** → **Secrets** (or your deployment env).

| Secret | Purpose |
|--------|---------|
| `APNS_BUNDLE_ID` | Should be `com.ScottOliver.FitUp` |
| `APNS_TEAM_ID`, `APNS_KEY_ID`, `APNS_PRIVATE_KEY` | APNs auth key (.p8) |
| `APNS_USE_SANDBOX` | `true` → `api.sandbox.push.apple.com`; `false` → production API |

**Expected pairing (verify after §1):**

| IPA `aps-environment` | `APNS_USE_SANDBOX` should be |
|----------------------|------------------------------|
| `production` | `false` |
| `development` | `true` |

Repo default in `supabase/functions/_shared/apns.ts`: sandbox unless env is `"false"`. Docs once said sandbox for TestFlight—**trust the IPA from §1**, not the doc alone.

**STOP:** Changing `APNS_USE_SANDBOX` or keys requires explicit approval and retest.

---

## 4. On-device registration

**Where:** iPhone with TestFlight build.

| Step | What to do | What should happen |
|------|------------|-------------------|
| Install | TestFlight app → install FitUp build | App opens |
| Sign in | Complete auth | Session in Supabase |
| Onboarding | Allow **Notifications** when prompted | System dialog |
| After profile | App calls `registerForRemoteNotifications` when sync eligible (`ContentView.swift`) | No crash |

**Optional verify token in DB**

**Where:** Supabase Dashboard → **Table Editor** → `profiles` → row for test user.

- [ ] Column **`apns_token`** has a long hex string after notifications allowed and app foregrounded

**In-app toggle:** **Profile → Notifications** → `notifications_enabled` on profile (if off, server may skip sends).

**If no token:** iOS **Settings → FitUp → Notifications** → Allow → kill and reopen app.

---

## 5. End-to-end delivery

Trigger a real server push (Edge `dispatch-notification` path):

| Flow | Device A | Device B | Expected push |
|------|----------|----------|----------------|
| Matchmaking | Start **first match** search / queue | Same metric, also searching | **match_found** (when paired) |
| Direct challenge | **New Battle** → pick opponent | Opponent device | **challenge_received** on B |

- [ ] Banner or lock-screen notification appears
- [ ] Tap notification → app opens **Home** or match/pending UI (deep link via `NotificationService`)

**Optional:** Active match → Live Activity on lock screen (uses `live_activity_push_token`; separate from alert push).

**If token present but no push:** Supabase → **Edge Functions** → **Logs** for `dispatch-notification`; check `notification_events` table for failures—document only, no auto-fix.

---

## 6. Failure triage (document only)

| Symptom | Likely cause | Where to look |
|---------|--------------|---------------|
| No token in DB | Permission denied; register before profile | Settings → FitUp → Notifications; re-login |
| Token, no push | `APNS_USE_SANDBOX` vs IPA mismatch; bad .p8; Edge error | §1 + §3 + function logs |
| Works Xcode Run, not TF | Debug vs distribution APNs env | §1 on **TestFlight IPA** only |
| Push delayed | iOS throttling | Retry during active test |

---

## 7. Sign-off

| Check | Pass | Date | Notes |
|-------|------|------|-------|
| IPA `aps-environment` | | | |
| `APNS_USE_SANDBOX` matches IPA | | | read-only verify |
| Device `apns_token` saved | | | |
| At least one push received | | | |
| Tap opens app correctly | | | |

**Verified by:** _______________  
**Build number:** _______________

---

**Next:** [testflight-external-compliance-checklist.md](testflight-external-compliance-checklist.md) (Phase 3).

**Back:** [testflight-README.md](testflight-README.md)
