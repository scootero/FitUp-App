# FitUp App Store Release Playbook

FitUp-specific release guide. Combines:

- The general subscription App Store playbook (Pondera-style process and state discipline)
- FitUp’s real product rules, stack, and launch checklist already in this repo

This is a **considerations + ownership map**, not a mandate to rewrite FitUp to match Pondera (e.g. native StoreKit 2–only or Cloudflare Workers). Where Pondera patterns differ from FitUp, both are noted so you can choose.

Related docs:

- [app-store-launch-checklist.md](app-store-launch-checklist.md) — product rules + Phases A–E (implementation status)
- [app-store-launch-smoke.md](app-store-launch-smoke.md) — device / TestFlight smoke
- [testflight-README.md](testflight-README.md) — TestFlight order of operations

---

## The rule that prevents most release mistakes

Keep these states separate. Never treat one as proof of a later one:

1. Source code is changed  
2. The app compiles or archives locally  
3. A build is uploaded to App Store Connect  
4. Apple finishes processing the build  
5. The processed build is selected for an App Store version  
6. The build is installed and tested through TestFlight  
7. App Store Connect metadata and compliance are complete  
8. The app, subscription group, and subscription product are in the same submission when required  
9. Apple approves the submission  
10. The app is actually released and visible on the App Store  

---

## High-level steps (all workstreams)

1. **Inventory** — confirm what FitUp actually does, IDs, versions, secrets, flags  
2. **Product / free–Pro rules** — lock and verify free (1× 3-day + cooldown) vs Pro  
3. **Subscriptions / payments** — ASC product + RevenueCat (or native StoreKit if you ever migrate)  
4. **Backend / Supabase** — Edge Functions, secrets, account deletion, APNs  
5. **Privacy, permissions, legal pages** — HealthKit, privacy labels, Terms, Support  
6. **App Store Connect account** — agreements, tax, banking, app record  
7. **Version, archive, upload** — marketing version vs build number vs processed build  
8. **Screenshots & listing copy** — real UI, correct sizes, no invented features  
9. **App Privacy questionnaire** — publish in Connect (repo pages are not enough)  
10. **TestFlight / Sandbox** — real product price, trial, restore, free limits, 2-account battles  
11. **Draft submission** — iOS version + build + subscription group + product together  
12. **After approval** — release vs Ready for Sale; verify public page and production install  

---

## FitUp identity (fill / verify before portal work)

| Field | FitUp value (verify in Xcode / Connect) |
|-------|----------------------------------------|
| App name | FitUp |
| Bundle ID | `com.ScottOliver.FitUp` |
| Widget extension | `com.ScottOliver.FitUp.FitUpWidgetExtension` |
| Xcode team | `BLAUCQ8H26` |
| Scheme / project | `FitUp` / `FitUp/FitUp/FitUp.xcodeproj` |
| Min iOS | 18.6 |
| Marketing version (repo) | `1.0` |
| Build number (app target, repo) | `2` (bump before each new upload) |
| Monetization | Free + auto-renewable Pro subscription |
| Entitlement id (RevenueCat) | `pro` |
| Planned product id | `fitup_pro_monthly` |
| Price / trial target | **$2.99/month**, **1-week free trial** |
| Privacy URL | https://scootero.github.io/FitUp-App/privacy/ |
| Terms URL | https://scootero.github.io/FitUp-App/terms/ |
| Support | `oliverscott14@gmail.com` (`mailto:`) |
| App Store invite URL (placeholder) | update `FitUpAppLinks.appStoreURL` when live |
| Backend | Supabase (Auth, DB, Edge Functions, Realtime) |
| Payments SDK in app | **RevenueCat** (wraps StoreKit; not a second truth source) |
| Health | HealthKit read (steps, activity, etc.) |
| Push / Live Activities | APNs + widget extension |
| UGC / DMs | Messaging **gated off** for launch (`AppLaunchFlags.messagingEnabled = false`) |
| AI provider in app binary | **None** (Pondera-style Worker not required unless you add AI later) |

---

## Locked FitUp product rules (v1)

**Free**

- 1 open battle (searching + pending + active)
- 3-day duration only
- After complete → wait until **next local calendar day** after end before starting another
- Paths: Quick/random + SMS/share invite friend only

**Pro (`pro`)**

- Unlimited battles, all durations, in-app direct challenges
- $2.99/mo + 1-week intro trial (configured in ASC + RevenueCat)

---

# 1. Inventory & evidence audit

### You (Scott)

- [ ] Confirm Apple Developer + App Store Connect access (Account Holder / Admin / App Manager)
- [ ] Confirm which Supabase project is “production”
- [ ] Confirm whether FitUp app record already exists in Connect
- [ ] Decide final app name, subtitle, category, keywords direction
- [ ] Note any dirty local secrets / TestFlight history already uploaded

### Claude / agent

- [ ] Audit repo: bundle IDs, versions, RevenueCat usage, paywall, free-tier gates, entitlements, Info/Health strings, legal URLs, feature flags
- [ ] Report in columns: verified in source / local build / device / TestFlight / Connect / backend / unknown
- [ ] Do **not** claim uploaded, approved, or live without evidence
- [ ] Point to [app-store-launch-checklist.md](app-store-launch-checklist.md) for what is already implemented

### Considerations from the general playbook

- Search for hard-coded secrets, `PrivacyInfo.xcprivacy` (FitUp may still need one), analytics SDKs, release flags
- FitUp uses **RevenueCat**, not a standalone StoreKit 2 manager — audit RC + ASC product ID alignment instead of inventing a second purchase stack
- Migrating fully to native StoreKit 2 is a **possibility**, not a requirement for this launch

---

# 2. Free / Pro product behavior (app)

### You

- [ ] Agree final free rules stay as locked above (or explicitly change them before archive)
- [ ] Test with a real free account after bypass is off (no Dev Mode “fake Pro”)

### Claude / agent

- [ ] Keep / fix gates: slot limit, 3-day lock, day-after cooldown, Quick + invite only ([SubscriptionService](../FitUp/FitUp/FitUp/Services/SubscriptionService.swift), [ChallengeFlowView](../FitUp/FitUp/FitUp/Views/Challenge/ChallengeFlowView.swift))
- [ ] Keep paywall copy aligned with free limits + trial + $2.99
- [ ] Ensure `FITUP_TESTFLIGHT_BYPASS = NO` for App Store archives
- [ ] Document smoke steps ([app-store-launch-smoke.md](app-store-launch-smoke.md))

### Considerations

- Paywall after first completed match (existing FitUp rule) vs always enforcing slots — know which behavior reviewers will see
- Invite share uses placeholder App Store URL until listing is live
- Rematch / Discover as free should hit Pro paywall

---

# 3. Subscriptions & payments (App Store Connect + RevenueCat)

FitUp’s app already purchases via **RevenueCat** entitlement `pro` and monthly package type. ASC still owns the real product.

### You

- [ ] Paid Apps Agreement active; banking + tax complete
- [ ] Create subscription **group** (e.g. “FitUp Pro”)
- [ ] Create auto-renewable product id exactly: `fitup_pro_monthly`
- [ ] Duration: 1 Month (cannot change after submission — choose carefully)
- [ ] Price: $2.99 (or chosen Apple tier); intro offer: **1 week free**
- [ ] Localization, availability, tax category, Family Sharing decision
- [ ] Subscription review screenshot + notes (how to reach paywall, purchase, restore)
- [ ] Create / configure **RevenueCat** app; paste public SDK key into local gitignored `Secrets.xcconfig`
- [ ] RevenueCat: entitlement `pro` → attach `fitup_pro_monthly`; set current Offering with monthly package
- [ ] Sandbox Apple ID testers ready
- [ ] First subscription: include **group + product with the same app version submission** when Apple requires it

### Claude / agent

- [ ] Verify code requests monthly package / entitlement `pro` consistently
- [ ] Verify paywall uses StoreKit/RC localized price when packages load; avoid lying about price if product missing (fallback copy is not proof of ASC)
- [ ] Checklist for Manage Subscription (Settings deep link / Apple subscription URL) if missing
- [ ] Optional: add local `.storekit` config **only** for Xcode simulation — never treat it as ASC proof
- [ ] Do **not** invent a second StoreKit manager that fights RevenueCat unless you explicitly choose a migration

### Considerations (Pondera vs FitUp)

| Pondera-style | FitUp today |
|---------------|-------------|
| Native StoreKit 2 product load by ID | RevenueCat offerings + entitlement `pro` |
| `AppStore.sync()` restore | `Purchases.restorePurchases()` |
| Local `.storekit` for Xcode | Optional; RC sandbox/TestFlight is the real proof |
| Cloudflare AI Worker | Not applicable unless you add AI |

Possibility: later migrate off RevenueCat to pure StoreKit 2 — only if you want that; not required to ship.

---

# 4. Backend / Supabase (not Cloudflare for FitUp)

### You

- [ ] Deploy Edge Function `delete-account` to production Supabase  
  `supabase functions deploy delete-account`
- [ ] Confirm APNs secrets (`APNS_*`, `APNS_USE_SANDBOX`) match the **signed IPA** `aps-environment` ([testflight-push-verification.md](testflight-push-verification.md))
- [ ] Confirm matchmaking / finalize / notification functions are the production set
- [ ] Rotate any keys that were ever committed or shared carelessly

### Claude / agent

- [ ] Document deploy order; keep `delete-account` source correct
- [ ] Audit that no provider AI keys live in the iOS binary (FitUp should have none)
- [ ] Keep Supabase anon key treatment correct (public-by-design) vs service role (server only)
- [ ] Messaging: keep gated off until SQL + UGC report/block are ready

### Considerations

- Pondera’s Worker playbook applies **if** you add server-side AI later: never put provider keys in the app; use Edge Function / Worker secrets
- An app proxy token ≠ proof of paid subscription; FitUp Pro is device entitlement via Apple/RC
- Account deletion must work in the **uploaded** build against **production** functions

---

# 5. Privacy, permissions, legal pages

### You

- [ ] Publish GitHub Pages (or host) so these return **200** on a real phone Safari session:
  - Privacy: https://scootero.github.io/FitUp-App/privacy/
  - Terms: https://scootero.github.io/FitUp-App/terms/
- [ ] Decide Support URL (mailto is OK if Connect accepts; a simple support page is nicer)
- [ ] Answer and **publish** App Privacy questionnaire in Connect (HealthKit, account, identifiers, diagnostics as applicable)
- [ ] Export compliance / encryption answers

### Claude / agent

- [ ] Keep in-app links: Privacy, Terms, Support, Account Deletion ([FitUpAppLinks](../FitUp/FitUp/FitUp/Utilities/FitUpAppLinks.swift), Profile, Paywall)
- [ ] Keep HealthKit usage strings accurate (read-only scoring; not for ads)
- [ ] Consider adding `PrivacyInfo.xcprivacy` if required APIs / SDKs need it (audit SPM: Supabase, RevenueCat)
- [ ] Hide Dev Mode / TestFlight bypass / verbose paywall logs in Release
- [ ] Fix legal HTML in repo when needed; you still must publish

### Considerations

- Repo HTML ≠ live URL until Pages (or host) is updated
- Permission timing: ask Health / notifications in onboarding when the feature needs them (already partly true)
- Messaging off reduces UGC compliance burden for v1

---

# 6. App Store Connect — app record & account

### You

- [ ] Membership active; correct role
- [ ] Agreements / tax / banking
- [ ] App record: iOS, bundle `com.ScottOliver.FitUp`
- [ ] App Information: Privacy URL, category (Health & Fitness), support contact
- [ ] Age rating questionnaire

### Claude / agent

- [ ] Provide field-by-field checklist from FitUp identity table
- [ ] Do not log into Connect or submit unless you explicitly authorize that action

---

# 7. Version, archive, upload, TestFlight

### You

- [ ] Bump **build number** before every new upload (marketing version `1.0` can stay until you choose otherwise)
- [ ] Archive Release with bypass **NO** and real RC key in local Secrets
- [ ] Upload via Organizer / Transporter
- [ ] Wait until build is **Processed**
- [ ] Select that build on the App Store version
- [ ] Internal then external TestFlight as needed
- [ ] Two physical devices / accounts: matchmaking, Health, push, paywall, sandbox purchase, restore, free cooldown

### Claude / agent

- [ ] Tell you exact files/flags to check before archive
- [ ] Update smoke checklist results documentation when you report outcomes
- [ ] Cannot prove TestFlight purchase from a simulator-only build

### Considerations

- Changing build in Xcode without archive/upload ≠ new Connect build
- TestFlight IAP uses Sandbox — not a production charge
- Widget extension bundle ID must stay consistent in signing

---

# 8. Screenshots, listing, review notes

### You

- [ ] Capture real FitUp UI (Home battle, challenge flow, match, paywall, Health/stats if claimed)
- [ ] Export non-transparent JPEG at accepted sizes (e.g. `1242×2688`, `1284×2778` — recheck Apple’s current table)
- [ ] Write description, keywords, subtitle; no features messaging-off builds don’t ship
- [ ] Review notes: how to create two accounts, enable Health, start a battle, open paywall, restore; sandbox account if needed

### Claude / agent

- [ ] Suggest screenshot order / storyboard of screens
- [ ] Draft review notes and description from actual capabilities
- [ ] Optionally resize/export assets if you provide source captures (verify pixel dimensions with a tool)

### Considerations

- Screenshots ≠ app preview videos
- Do not imply unlimited free battles or DMs if gated off

---

# 9. Assemble draft & submit

### You

- [ ] Draft contains: iOS app version + processed build + subscription group + `fitup_pro_monthly` (when Apple requires co-submission)
- [ ] App Privacy published
- [ ] Public URLs work
- [ ] No blocking Connect warnings
- [ ] Click **Submit for Review** only when the gate list is clear

### Claude / agent

- [ ] Final evidence audit: Verified / Still manual / Blocking
- [ ] Do not submit on your behalf unless authorized

---

# 10. After Apple approval

### You

- [ ] If **Pending Developer Release** → manually release
- [ ] Confirm **Ready for Sale** / public page
- [ ] Install production build; confirm product loads and purchase path
- [ ] Replace placeholder `FitUpAppLinks.appStoreURL` and ship a follow-up build if invite text still points at a stub

### Claude / agent

- [ ] Help update invite URL + any post-release notes
- [ ] Do not treat approval email alone as “live on the Store”

---

## Evidence columns (use on every status update)

| Column | Meaning |
|--------|---------|
| Verified in source | File/flag/product id seen in repo |
| Verified by local build | `xcodebuild` / Archive succeeded |
| Requires physical device | HealthKit, haptics, real push, share sheet |
| Requires TestFlight/Sandbox | Real ASC product, trial, restore |
| Requires App Store Connect | Agreements, metadata, privacy questionnaire, submit |
| Requires Supabase deploy | Edge Functions, secrets, cron |
| Unknown | Needs evidence — do not invent |

---

## Compact final checklist

### Code and build

- [ ] Free/Pro rules match intended launch behavior  
- [ ] Bypass off; Dev tools not in Release  
- [ ] RevenueCat entitlement `pro`; product id matches ASC  
- [ ] Purchase, restore, missing-product, offline-safe paths  
- [ ] Build number incremented; archived; uploaded; **processed**  
- [ ] Correct build selected on version  

### Backend

- [ ] `delete-account` deployed and tested from the uploaded build  
- [ ] APNs sandbox flag matches IPA  
- [ ] No secrets in binary that shouldn’t be there  

### Portal

- [ ] Agreements / tax / banking  
- [ ] Subscription group + `fitup_pro_monthly` + $2.99 + 1-week trial  
- [ ] App Privacy published  
- [ ] Screenshots accepted  
- [ ] Draft includes version + group + product when required  

### Validation

- [ ] Two-account battle smoke  
- [ ] Free slot / 3-day / cooldown verified  
- [ ] Sandbox trial → Pro unlock; restore; free limits after loss of entitlement  
- [ ] Privacy / Terms / Support URLs live  
- [ ] After approval, actually released and visible  

---

## Copy-paste prompts (FitUp-tuned)

### Release audit

```text
Audit FitUp for App Store release readiness.

Repo: FitUp iOS + Supabase. Bundle ID com.ScottOliver.FitUp. Payments: RevenueCat entitlement "pro", planned product fitup_pro_monthly @ $2.99 with 1-week trial. Free: 1 open 3-day battle + day-after-end cooldown; Quick + invite only.

Inspect: git status, versions, BetaFlags, Secrets.example (not real secrets), SubscriptionService, PaywallView, free-tier gates, FitUpAppLinks, HealthKit plist strings, PrivacyInfo if any, messaging flag, delete-account function.

Report columns: Verified in source | Local build | Device | TestFlight/Sandbox | App Store Connect | Supabase | Unknown.
Do not edit. Do not claim uploaded/approved/live without evidence.
```

### Payments / RevenueCat (not a forced StoreKit rewrite)

```text
Audit FitUp subscription wiring for App Store.

Do not replace RevenueCat with a new StoreKit-only stack unless I explicitly ask.

Verify: entitlement id "pro", monthly offering, restore, paywall localized price vs fallback, FITUP_TESTFLIGHT_BYPASS=NO, Secrets.xcconfig expectations for REVENUECAT_API_KEY.
List exact ASC + RevenueCat steps still required. Do not claim portal setup is done.
```

### Final submit gate

```text
Before I click Submit for Review for FitUp, evidence audit only.

Columns: Verified now | Still portal/device/manual | Blocking if missing.

Check: archive of current source, build bumped, processed build selected, product id match, subscription in draft, screenshots, App Privacy published, agreements, live privacy/terms URLs, TestFlight sandbox purchase + free limits, delete-account deployed.
Do not submit. Tell me only the next unresolved action.
```

---

## Official references

- [Submit an In-App Purchase or subscription](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase)
- [Manage App Privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications)
- [App Store Connect workflow](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-workflow)
- RevenueCat: App Store / offerings docs (use current dashboard docs)

Apple’s portal labels change — recheck live Connect before each release.

---

*This playbook is the high-level FitUp map. Day-to-day implementation status for free-tier and compliance code lives in [app-store-launch-checklist.md](app-store-launch-checklist.md).*
