# FitUp TestFlight — Start Here

This folder has **one workflow** and **specialized sub-docs**. Follow the order below; do not duplicate steps across files.

## Which document to use

| Document | Role | When to open it |
|----------|------|-----------------|
| **[testflight-README.md](testflight-README.md)** (this file) | **Index + order of operations** | First, and when you are unsure what’s next |
| **[testflight-xcode-and-apple-developer.md](testflight-xcode-and-apple-developer.md)** | **Sub:** Xcode signing, archive, Apple Developer portal | Before your first archive; when signing or capabilities fail |
| **[testflight-external-compliance-checklist.md](testflight-external-compliance-checklist.md)** | **Main runbook:** App Store Connect, TestFlight metadata, privacy, reviewer notes | After a build is uploaded; before **external** testers |
| **[testflight-push-verification.md](testflight-push-verification.md)** | **Sub:** Push/APNs verification on a TestFlight build | After install from TestFlight; before you promise push works |
| **[testflight-readiness-changes-done.md](testflight-readiness-changes-done.md)** | **Changelog only** (code already merged) | Once, to see what changed in the app for this pass—not a todo list |

**Source of truth:** Compliance checklist = Connect/TestFlight process. Push doc = push only. Xcode doc = signing/portal only. This README = **order**, not duplicate checklists.

## Known FitUp values (keep consistent everywhere)

| Item | Value |
|------|--------|
| Main bundle ID | `com.ScottOliver.FitUp` |
| Widget extension bundle ID | `com.ScottOliver.FitUp.FitUpWidgetExtension` |
| Xcode team ID | `BLAUCQ8H26` |
| Privacy policy URL | https://scootero.github.io/FitUp-App/privacy/ |
| Support / deletion email | oliverscott14@gmail.com |
| Min iOS (project) | 18.6 |

In-app links: **Profile → Privacy** (policy URL), **Profile → Account Deletion** (manual delete instructions).

Repo config (change only with intent):

| What | Where in repo |
|------|----------------|
| TestFlight dev bypass (paywall, dev UI) | `FitUp/FitUp/Config/BetaFlags.xcconfig` → `FITUP_TESTFLIGHT_BYPASS` (currently `YES`) |
| Entitlements (Push, HealthKit, Sign in with Apple) | `FitUp/FitUp/Config/FitUp.entitlements` |
| Health permission string | `FitUp/FitUp/FitUp.xcodeproj` → FitUp target → `INFOPLIST_KEY_NSHealthShareUsageDescription` |
| Privacy URL in app | `FitUp/FitUp/FitUp/Views/Profile/ProfileView.swift` → `ProfileSupportLinks.privacyPolicyURL` |
| Static policy HTML | `docs/privacy/index.html` (must be published at the GitHub Pages URL above) |

---

## Recommended order (external TestFlight)

Do these in sequence. Check off in the linked doc, not here.

### Phase 0 — Apple & Xcode (before archive)

**Doc:** [testflight-xcode-and-apple-developer.md](testflight-xcode-and-apple-developer.md)

- Confirm App IDs and capabilities in **Apple Developer**
- Confirm **Xcode → FitUp target → Signing & Capabilities** (no errors)
- Bump **build number** if re-uploading the same marketing version
- **Product → Archive** → upload to App Store Connect

### Phase 1 — Build on device (internal TestFlight)

- Install from **TestFlight** app (not Xcode Run) on a **physical iPhone**
- Smoke test: sign-in, Health prompt, onboarding, two-account match (see compliance “What to Test”)
- Skim [testflight-readiness-changes-done.md](testflight-readiness-changes-done.md) so you know what copy/plist changed

### Phase 2 — Push verification

**Doc:** [testflight-push-verification.md](testflight-push-verification.md)

- Run **only** on the build you will give external testers
- Do **not** edit `aps-environment` or Supabase `APNS_USE_SANDBOX` unless step 1 of that doc fails—**stop and decide** first

### Phase 3 — App Store Connect & external testers

**Doc:** [testflight-external-compliance-checklist.md](testflight-external-compliance-checklist.md)

- App Information, App Privacy, TestFlight **Test Information**, external group, Beta App Review
- Paste “What to Test” from that doc
- Open privacy URL on phone Safari before submitting

### Phase 4 — After external approval

- Invite external group; monitor feedback email
- Track issues; new uploads = new build number + repeat Phase 2 if push-related

---

## Stop points (get approval before changing)

| Change | Where |
|--------|--------|
| `FITUP_TESTFLIGHT_BYPASS` YES → NO | `FitUp/FitUp/Config/BetaFlags.xcconfig` then re-archive |
| `aps-environment` in entitlements | `FitUp/FitUp/Config/FitUp.entitlements` |
| Supabase `APNS_USE_SANDBOX` or APNs secrets | Supabase Dashboard → Edge Functions → Secrets |
| Bundle IDs or team | Xcode + Apple Developer Identifiers |
| Privacy URL | `ProfileView.swift`, `docs/privacy/index.html`, App Store Connect |

---

## Before App Store (not this TestFlight pass)

See the table at the bottom of [testflight-external-compliance-checklist.md](testflight-external-compliance-checklist.md) (automated deletion, bypass off, RevenueCat, hide dev tools, etc.).
