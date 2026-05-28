# TestFlight External Compliance Checklist

**Main runbook** for [testflight-README.md](testflight-README.md) **Phase 3** (after archive + on-device smoke + [push verification](testflight-push-verification.md)).

**Not in this file:** Xcode signing, archive, Apple Developer App IDs → [testflight-xcode-and-apple-developer.md](testflight-xcode-and-apple-developer.md).  
**Not in this file:** Push/IPA/APNs → [testflight-push-verification.md](testflight-push-verification.md).  
**Not a todo list:** code already changed → [testflight-readiness-changes-done.md](testflight-readiness-changes-done.md).

---

## Known values (use consistently)

| Item | Value |
|------|--------|
| Privacy Policy URL | https://scootero.github.io/FitUp-App/privacy/ |
| Support / deletion email | oliverscott14@gmail.com |
| Account deletion (this phase) | Manual via **Profile → Account Deletion** (in-app instructions + email) |

---

## Before you start Phase 3

- [ ] Phase 0 complete: [Xcode & Apple Developer](testflight-xcode-and-apple-developer.md)
- [ ] TestFlight build installed on a physical iPhone
- [ ] [Push verification](testflight-push-verification.md) passed (if match alerts matter for this beta)

---

## App Store Connect — create or open the app

**Where:** [appstoreconnect.apple.com](https://appstoreconnect.apple.com) → **Apps**.

| If… | Do this |
|-----|---------|
| No FitUp app yet | **+** → **New App** → iOS → name **FitUp** → language → bundle ID **`com.ScottOliver.FitUp`** → SKU (any unique string, permanent) |
| App exists | Open **FitUp** → use left sidebar sections below |

**What changes:** A new app record in Connect only; does not change Xcode or git.

---

## App Information (privacy URL, category, support)

**Where:** **Apps** → **FitUp** → **App Information** (under “General” in sidebar).

| Field | What to enter | What it affects |
|-------|---------------|-----------------|
| **Privacy Policy URL** | `https://scootero.github.io/FitUp-App/privacy/` | Required for App Store / review; must match in-app **Profile → Privacy** (`ProfileView.swift`) |
| **Category** | **Health & Fitness** | Store listing; matches `LSApplicationCategoryType` in Xcode |
| **Support URL** or contact | Support page or `mailto:oliverscott14@gmail.com` | Reviewer/tester contact |

- [ ] Privacy URL opens on **iPhone Safari** (not just desktop)
- [ ] Policy content matches [`docs/privacy/index.html`](privacy/index.html) (publish via GitHub Pages for repo `scootero/FitUp-App` or your hosting path)

**Website fix (repo, if needed):** edit `docs/privacy/index.html` → push to GitHub → wait for Pages deploy. Duplicate `</p>` in Account Deletion section—fix before external invite.

---

## App Privacy (nutrition labels)

**Where:** **Apps** → **FitUp** → **App Privacy** → **Get Started** or **Edit**.

**What you are doing:** Declaring data types Apple shows on the store page—not changing app code.

Suggested alignment with FitUp today:

| Data type | Typical declaration | Linked to |
|-----------|---------------------|-----------|
| Contact info / account | Email, name (auth) | Supabase Auth, `profiles` |
| Health & Fitness | Steps, activity, heart rate (read via HealthKit) | `HealthKitService`, not used for ads (matches plist string) |
| Identifiers | User ID | `profiles.id` |
| Diagnostics / usage | If you collect analytics | `analytics_events`, `app_logs` (see policy) |

- [ ] **HealthKit** purpose: app functionality; **not** used for tracking/third-party advertising
- [ ] Answers consistent with [`docs/privacy/index.html`](privacy/index.html)

**What changes:** Connect metadata only.

---

## Age Rating

**Where:** **Apps** → **FitUp** → **App Information** or **Age Rating** questionnaire.

- [ ] Complete questionnaire (fitness/social features; no mature content)

---

## TestFlight — select build

**Where:** **Apps** → **FitUp** → **TestFlight** tab → **iOS** builds.

- [ ] Build status **Ready to Test** (not stuck in Processing)
- [ ] **Export Compliance:** answer encryption questions when prompted (usually standard HTTPS only → “No” for proprietary non-exempt encryption, if accurate for your app)

---

## TestFlight — Test Information (Beta App Review)

**Where:** **TestFlight** → **Test Information** (left sidebar under TestFlight) or build-level **Test Details**.

| Field | What to put |
|-------|-------------|
| **Beta App Description** | Short: 1v1 fitness battles, HealthKit steps/calories, requires two players |
| **Feedback Email** | `oliverscott14@gmail.com` |
| **Privacy Policy URL** | Same as App Information |
| **What to Test** | Paste block below (edit if needed) |

### What to Test (paste or adapt)

```
FitUp is a 1v1 fitness battle app. You need TWO test accounts (two Apple IDs or email sign-ups) to complete a match.

1. Sign in (Sign in with Apple recommended).
2. Complete onboarding; allow Apple Health read access for steps/calories.
3. Allow notifications when prompted (match alerts).
4. Account A: finish onboarding → Start My First Match (search).
5. Account B: same, or use New Battle → pick Account A as opponent (direct challenge).
6. Accept challenge / wait for match → verify active battle on Home.

Support: oliverscott14@gmail.com
Privacy: https://scootero.github.io/FitUp-App/privacy/
Account deletion: Profile → Account Deletion (email request; automated delete coming later).

Beta note: This build may show Developer tools and bypass the paywall (TestFlight internal beta).
```

**What changes:** Text shown to Beta App Review and external testers only.

---

## TestFlight — External testing group

**Where:** **TestFlight** → **External Testing** → **+** (create group, e.g. “External Beta”).

1. Add the build to the group.
2. **Submit for Review** (Beta App Review)—required before public external links work.
3. When status is **Approved**, add testers by email or public link.

**What changes:** Testers can install via TestFlight app; no code change.

---

## Authentication (verify on device, document for review)

**Where to test:** TestFlight build on iPhone—not Connect.

| Check | How |
|-------|-----|
| Sign in with Apple | Auth screen → white Apple button → completes sign-in |
| Email/password | Same screen → email fields → Sign In / Create Account |
| Reviewer note | If Apple ID restricted, use email sign-up and say so in **What to Test** |

**Repo:** `AuthView.swift`, entitlement `com.apple.developer.applesignin` in `FitUp.entitlements`.  
**Portal:** Sign in with Apple enabled on App ID ([Xcode doc](testflight-xcode-and-apple-developer.md)).

---

## HealthKit (verify on device)

| Check | How |
|-------|-----|
| Permission prompt | Onboarding or Health tab → system dialog shows **read** explanation |
| Wording | Matches updated share string (Slice A in [changes done](testflight-readiness-changes-done.md)) |
| Denied path | Settings → Health → FitUp → enable reads; app recovers |

**Repo (if copy must change):** `project.pbxproj` → `INFOPLIST_KEY_NSHealthShareUsageDescription`; do not add clinical/update keys unless you use those APIs.

---

## Account deletion (TestFlight-acceptable)

| Surface | Where | What user sees |
|---------|--------|----------------|
| In-app | **Profile → Account Deletion** | Email instructions, copy user ID (`AccountDeletionRequestView.swift`) |
| Policy | `docs/privacy/index.html` → Account Deletion | Must match process |
| Connect | What to Test + App Review notes | Point to Profile path + support email |

- [ ] You can receive and act on deletion emails at `oliverscott14@gmail.com`

**Future App Store:** automated in-app deletion required long-term (see table below).

---

## Push (if match alerts are core)

**Do not duplicate steps here.**

- [ ] Complete [testflight-push-verification.md](testflight-push-verification.md) on the **same build** you ship externally
- [ ] Only claim push works in Test Information after sign-off table in that doc

---

## In-app vs Connect (quick reference)

| Requirement | In-app | App Store Connect |
|-------------|--------|-------------------|
| Privacy policy | **Profile → Privacy** | App Information → Privacy Policy URL |
| Account deletion | **Profile → Account Deletion** | What to Test + policy |
| Health explanation | Onboarding + system prompt | App Privacy questionnaire |
| 1v1 / two players | Onboarding/Home copy (Slice C) | What to Test |
| Notifications toggle | **Profile → Notifications** | (optional mention in What to Test) |

---

## Before App Store submission (not this TestFlight pass)

| Item | Where to change when ready |
|------|----------------------------|
| In-app automated account deletion | New feature + policy update |
| `FITUP_TESTFLIGHT_BYPASS = NO` | `FitUp/FitUp/Config/BetaFlags.xcconfig` → re-archive |
| RevenueCat / IAP | `Secrets.xcconfig` + App Store Connect → In-App Purchases |
| Hide dev tools | Bypass off + no `DevMode` UI in Release |
| Push entitlements | Only if [push doc](testflight-push-verification.md) failed—approve first |
| Screenshots, description | Connect → **App Store** version page |

---

**Back to workflow:** [testflight-README.md](testflight-README.md)
