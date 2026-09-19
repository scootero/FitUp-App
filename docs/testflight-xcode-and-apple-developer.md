# TestFlight — Xcode & Apple Developer Setup

**Sub-doc** for [testflight-README.md](testflight-README.md) **Phase 0**.  
App Store Connect steps live in [testflight-external-compliance-checklist.md](testflight-external-compliance-checklist.md). Push testing lives in [testflight-push-verification.md](testflight-push-verification.md).

---

## 1. Apple Developer — Identifiers

**Where:** [developer.apple.com](https://developer.apple.com) → **Account** → **Certificates, Identifiers & Profiles** → **Identifiers**.

### Main app: `com.ScottOliver.FitUp`

1. Open the identifier (or **+** → App IDs → App → register with this bundle ID).
2. **Capabilities** — enable and **Save**:
   - [ ] **Push Notifications**
   - [ ] **Sign in with Apple** (Configure if prompted; use as primary App ID)
   - [ ] **HealthKit** (enable **HealthKit Background Delivery** if shown as part of HealthKit)
3. **What this affects:** Xcode can sync capabilities; provisioning profiles include these entitlements. Does **not** change Supabase.

### Widget extension: `com.ScottOliver.FitUp.FitUpWidgetExtension`

1. Separate App ID for the extension (required for Live Activity / WidgetKit target).
2. Same team; bundle ID must match Xcode **FitUpWidgetExtension** target.
3. **What this affects:** Archive embeds the extension; upload fails if the extension ID is missing.

**Do not** enable unrelated capabilities (iCloud, Associated Domains, etc.) unless you add matching code and entitlements.

---

## 2. Apple Developer — Keys (push server)

**Where:** **Certificates, Identifiers & Profiles** → **Keys**.

- [ ] You have an **Apple Push Notifications service (APNs)** key (`.p8`) for team `BLAUCQ8H26`
- [ ] Key ID matches what Supabase Edge uses (`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`, `APNS_BUNDLE_ID` = `com.ScottOliver.FitUp`)

**What this changes:** Only server-side push delivery (Supabase secrets). **Not** changed in this doc—verify in Dashboard when push fails ([push verification](testflight-push-verification.md)).

---

## 3. Xcode — Open project

**Where:** `FitUp/FitUp/FitUp.xcodeproj`  
**Scheme:** **FitUp**  
**Destination for archive:** **Any iOS Device (arm64)** (not a simulator)

---

## 4. Xcode — FitUp target → Signing & Capabilities

**Where:** Project navigator → **FitUp** project → **TARGETS** → **FitUp** → **Signing & Capabilities**.

| Setting | Expected |
|---------|----------|
| **Team** | Your team (`BLAUCQ8H26`) |
| **Bundle Identifier** | `com.ScottOliver.FitUp` |
| **Automatically manage signing** | On |
| Errors | None (fix App ID in portal first if capability mismatch) |

**Capabilities tab** should align with `FitUp/FitUp/Config/FitUp.entitlements`:

- [ ] Push Notifications  
- [ ] Sign in with Apple  
- [ ] HealthKit (+ background delivery if listed)  
- Live Activities supported via Info.plist keys (`NSSupportsLiveActivities`)

**What changes if you toggle here:** Xcode updates the entitlements file and regenerates profiles. **Do not** remove Push/HealthKit/Apple Sign In for FitUp.

**Repo entitlements file** (`FitUp/FitUp/Config/FitUp.entitlements`) may show `aps-environment` = `development`. **TestFlight builds often embed `production` in the signed app anyway**—confirm on the IPA ([push doc](testflight-push-verification.md)), don’t edit the file preemptively.

---

## 5. Xcode — FitUpWidgetExtension target

**Where:** **TARGETS** → **FitUpWidgetExtension** → **Signing & Capabilities**.

| Setting | Expected |
|---------|----------|
| **Bundle Identifier** | `com.ScottOliver.FitUp.FitUpWidgetExtension` |
| **Team** | Same as main app |
| **Automatically manage signing** | On |

No separate `.entitlements` file in repo; extension uses `Config/FitUpWidgetExtension-Info.plist`.

---

## 6. Xcode — Version & build number

**Where:** **FitUp** target → **General** (or **Build Settings** → `CURRENT_PROJECT_VERSION` / `MARKETING_VERSION`).

| Field | Repo default | What to do |
|-------|--------------|------------|
| **Version** (`MARKETING_VERSION`) | e.g. `1.0` | User-visible; change when you ship a new marketing release |
| **Build** (`CURRENT_PROJECT_VERSION`) | e.g. `1` | **Increment for every upload** to App Store Connect with the same version |

**What changes:** App Store Connect rejects duplicate version+build pairs.

---

## 7. Xcode — Archive & upload

1. Select **Any iOS Device (arm64)**.
2. **Product → Archive** (uses **Release** configuration; both Debug/Release use `Debug.xcconfig` including `BetaFlags.xcconfig`).
3. **Organizer** opens → select archive → **Distribute App**.
4. **App Store Connect** → **Upload** → follow prompts (symbols, etc.).
5. Wait for build **Processing** in [App Store Connect](https://appstoreconnect.apple.com) → **TestFlight** tab.

**What changes:** New build on Connect only; no git change unless you bumped build number in Xcode.

---

## 8. Optional — Paywall logging before archive

**Where:** `FitUp/FitUp/Config/BetaFlags.xcconfig`

| Flag | Typical | Effect if `YES` |
|------|---------|-----------------|
| `FITUP_PAYWALL_LOGGING` | `NO` | Verbose StoreKit / paywall AppLogger lines |

Subscription Free/Pro/System overrides and the Profile Developer section exist only in `#if DEBUG` and are absent from Release / TestFlight / App Store archives. StoreKit always runs in Release.

Change logging → **clean archive** (new build number).

---

## 9. Sign-off (Phase 0)

| Check | Done |
|-------|------|
| Both App IDs exist with correct capabilities | |
| FitUp + extension signing green in Xcode | |
| Build number incremented for this upload | |
| Archive uploaded; build visible in TestFlight (processing OK) | |

**Next:** [testflight-README.md](testflight-README.md) → Phase 1 (install TestFlight) → Phase 2 [push](testflight-push-verification.md) → Phase 3 [compliance](testflight-external-compliance-checklist.md).
