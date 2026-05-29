//
//  SessionStore.swift
//  FitUp
//
//  Slice 1: auth/session state, launch restore, and root routing state.
//

import Combine
import Foundation
import Supabase

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var currentProfile: Profile?
    @Published private(set) var isAuthenticated = false
    @Published private(set) var isLoadingSession = true
    @Published var authErrorMessage: String?
    /// In-session prefill for the post-auth name step (set on email sign up / Sign in with Apple). Cleared on completion or sign out.
    @Published private(set) var postAuthNameFieldPrefill: String?
    /// When `true`, the post-auth display name step is done (or not applicable). When `false` and authenticated, show `PostAuthDisplayNameView`.
    @Published private(set) var postAuthDisplayNameStepComplete: Bool = true
    /// Per-profile completion in `UserDefaults` (`fitup.onboardingComplete.<profileId>`). False until a profile is restored.
    @Published private(set) var isOnboardingComplete = false
    /// Per-profile: user finished the onboarding Health authorization step (sheet dismissed).
    @Published private(set) var healthKitPromptCompleted = false
    @Published private(set) var showSearchingCardOnHome = false

    /// Shown once per app launch on Home until the user scrolls or switches tabs.
    @Published private(set) var showHomeIntroTip: Bool = true

    /// Bumped when root UI (e.g. challenge flow) dismisses so Home refetches searching rows without waiting for poll.
    @Published private(set) var homeSnapshotRefreshToken: UInt64 = 0

    /// Set by push handling (`match_found`, `challenge_received`); consumed when Home loads a pending card for this id.
    private var pendingMatchFoundCelebrationMatchId: UUID?

    /// Set by push handling (`match_active`); consumed when Home loads an active card for this id.
    private var pendingMatchActiveCelebrationMatchId: UUID?

    // MARK: - Friend notifications (push + Home UI)

    /// Incoming friend request: requester profile id + display name (from APNs foreground/tap).
    @Published var friendRequestBannerFromPush: (peerId: UUID, fromName: String)?

    /// Original requester sees this when the other user accepts (from APNs).
    @Published var friendAcceptedYourRequestBanner: (peerId: UUID, accepterName: String)?

    /// Deep link / notification: show Friends list on root.
    @Published var presentFriendsListSheet: Bool = false

    /// After accepting a friend request: optional sheet with "Compete?"
    @Published var becameFriendsChallenge: ChallengePrefillOpponent?

    /// Opens Messages inbox; optional peer opens that thread after load.
    @Published var shouldPresentMessages = false
    @Published var pendingMessagesPeerId: UUID?

    private let profileRepository = ProfileRepository()

    /// Legacy global key (pre–per-profile). Migrated only for profiles created before the v2 install anchor.
    private static let legacyOnboardingCompleteKey = "onboardingComplete"
    /// First time this app version registers `SessionStore`; used so new accounts after install do not inherit legacy onboarding.
    private static let onboardingV2InstallAnchorKey = "fitup.onboardingV2InstallAnchor"

    private static func onboardingCompleteKey(profileId: UUID) -> String {
        "fitup.onboardingComplete.\(profileId.uuidString)"
    }

    private static func postAuthDisplayNameKey(profileId: UUID) -> String {
        "fitup.postAuthDisplayNameComplete.\(profileId.uuidString)"
    }

    private static func healthKitPromptKey(profileId: UUID) -> String {
        "fitup.healthKitOnboardingPromptCompleted.\(profileId.uuidString)"
    }

    init() {
        Self.registerOnboardingV2InstallAnchorIfNeeded()
        Task { await restoreSession() }
    }

    private static func registerOnboardingV2InstallAnchorIfNeeded() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: onboardingV2InstallAnchorKey) == nil else { return }
        defaults.set(Date().timeIntervalSince1970, forKey: onboardingV2InstallAnchorKey)
    }

    /// Debug-friendly root routing snapshot (Auth vs name vs onboarding vs tabs).
    func logSessionRoutingDecision(reason: String) {
        let route: String
        if !isAuthenticated {
            route = "auth"
        } else if !postAuthDisplayNameStepComplete {
            route = "post_auth_display_name"
        } else if !isOnboardingComplete {
            route = "onboarding"
        } else {
            route = "main_tabs"
        }
        var metadata: [String: String] = [
            "reason": reason,
            "route": route,
            "authenticated": String(isAuthenticated),
            "post_auth_name_complete": String(postAuthDisplayNameStepComplete),
            "onboarding_complete": String(isOnboardingComplete),
            "health_kit_prompt_complete": String(healthKitPromptCompleted),
        ]
        if let p = currentProfile {
            metadata["profile_id"] = p.id.uuidString
            metadata["auth_user_id"] = p.authUserId.uuidString
        }
        AppLogger.log(category: "session_routing", level: .debug, message: "root_route", metadata: metadata)
    }

    private func migrateLegacyOnboardingIfNeeded(for profile: Profile) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Self.legacyOnboardingCompleteKey) else { return }

        let perKey = Self.onboardingCompleteKey(profileId: profile.id)
        if defaults.object(forKey: perKey) != nil {
            if defaults.bool(forKey: perKey) {
                defaults.removeObject(forKey: Self.legacyOnboardingCompleteKey)
            }
            return
        }

        let anchorTs = defaults.double(forKey: Self.onboardingV2InstallAnchorKey)
        guard anchorTs > 0 else { return }
        let anchor = Date(timeIntervalSince1970: anchorTs)
        guard profile.createdAt < anchor else { return }

        defaults.set(true, forKey: perKey)
        defaults.removeObject(forKey: Self.legacyOnboardingCompleteKey)
        let createdISO = ISO8601DateFormatter().string(from: profile.createdAt)
        AppLogger.log(
            category: "session_routing",
            level: .info,
            message: "onboarding_legacy_migrated_to_per_profile",
            userId: profile.id,
            metadata: [
                "auth_user_id": profile.authUserId.uuidString,
                "profile_created_at": createdISO,
            ]
        )
    }

    private func syncOnboardingCompletionState(for profile: Profile) {
        migrateLegacyOnboardingIfNeeded(for: profile)
        let perKey = Self.onboardingCompleteKey(profileId: profile.id)
        isOnboardingComplete = UserDefaults.standard.bool(forKey: perKey)
    }

    func restoreSession() async {
        isLoadingSession = true
        authErrorMessage = nil

        guard let client = SupabaseProvider.client else {
            isAuthenticated = false
            currentProfile = nil
            postAuthNameFieldPrefill = nil
            postAuthDisplayNameStepComplete = true
            isOnboardingComplete = false
            isLoadingSession = false
            AppLogger.log(category: "auth", level: .warning, message: "session restore skipped: Supabase client missing")
            logSessionRoutingDecision(reason: "supabase_client_missing")
            return
        }

        do {
            let session = try await client.auth.session
            let authUserId = try Self.resolveAuthUserId(from: session.user.id)
            let profile = try await profileRepository.fetchProfile(authUserId: authUserId)
            if let profile {
                currentProfile = profile
                isAuthenticated = true
                showSearchingCardOnHome = false
                syncHealthKitPromptCompletedFromDefaults()
                applyPostAuthDisplayNameStateAfterRestore(profile: profile)
                syncOnboardingCompletionState(for: profile)
                ProductAnalytics.track(
                    ProductAnalytics.Event.sessionRestored,
                    userId: currentProfile?.id
                )
            } else {
                AppLogger.log(
                    category: "auth",
                    level: .info,
                    message: "session present but no profile row; signing out"
                )
                do {
                    try await client.auth.signOut()
                } catch {
                    AppLogger.log(
                        category: "auth",
                        level: .warning,
                        message: "sign-out after missing profile failed",
                        metadata: ["error": error.localizedDescription]
                    )
                }
                isAuthenticated = false
                currentProfile = nil
                showSearchingCardOnHome = false
                pendingMatchFoundCelebrationMatchId = nil
                pendingMatchActiveCelebrationMatchId = nil
                clearFriendNotificationUI()
                healthKitPromptCompleted = false
                postAuthNameFieldPrefill = nil
                postAuthDisplayNameStepComplete = true
                isOnboardingComplete = false
            }
        } catch {
            isAuthenticated = false
            currentProfile = nil
            showSearchingCardOnHome = false
            pendingMatchFoundCelebrationMatchId = nil
            pendingMatchActiveCelebrationMatchId = nil
            clearFriendNotificationUI()
            healthKitPromptCompleted = false
            postAuthNameFieldPrefill = nil
            postAuthDisplayNameStepComplete = true
            isOnboardingComplete = false
            AppLogger.log(category: "auth", level: .debug, message: "no active session on launch")
        }

        isLoadingSession = false
        logSessionRoutingDecision(reason: "restore_session_finished")
    }

    func signInWithEmail(email: String, password: String) async {
        authErrorMessage = nil
        do {
            let client = try requireClient()
            _ = try await client.auth.signIn(email: email, password: password)
            await restoreSession()
            if let id = currentProfile?.id {
                ProductAnalytics.track(
                    ProductAnalytics.Event.authSignIn,
                    userId: id,
                    properties: ["method": "email"]
                )
            }
        } catch {
            authErrorMessage = error.localizedDescription
            AppLogger.log(category: "auth", level: .error, message: "email sign-in failed", metadata: ["error": error.localizedDescription])
        }
    }

    func signUp(email: String, password: String, displayName: String) async {
        authErrorMessage = nil
        do {
            let client = try requireClient()
            _ = try await client.auth.signUp(email: email, password: password)
            let session = try await client.auth.session
            let authUserId = try Self.resolveAuthUserId(from: session.user.id)
            currentProfile = try await profileRepository.createProfileIfNeeded(authUserId: authUserId, displayName: displayName)
            isAuthenticated = true
            syncHealthKitPromptCompletedFromDefaults()
            if let profile = currentProfile {
                syncOnboardingCompletionState(for: profile)
                requirePostAuthDisplayNameConfirmation(
                    for: profile,
                    prefill: displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
            if let id = currentProfile?.id {
                ProductAnalytics.track(
                    ProductAnalytics.Event.authSignIn,
                    userId: id,
                    properties: ["method": "email_sign_up"]
                )
            }
        } catch {
            authErrorMessage = error.localizedDescription
            isAuthenticated = false
            currentProfile = nil
            postAuthNameFieldPrefill = nil
            postAuthDisplayNameStepComplete = true
            isOnboardingComplete = false
            AppLogger.log(category: "auth", level: .error, message: "email sign-up failed", metadata: ["error": error.localizedDescription])
        }
        logSessionRoutingDecision(reason: "sign_up_finished")
    }

    func signInWithApple(idToken: String, preferredDisplayName: String? = nil) async {
        authErrorMessage = nil
        do {
            let client = try requireClient()
            _ = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken)
            )
            let session = try await client.auth.session
            let authUserId = try Self.resolveAuthUserId(from: session.user.id)
            let profileExistedBefore = (try? await profileRepository.fetchProfile(authUserId: authUserId)) != nil
            currentProfile = try await profileRepository.createProfileIfNeeded(
                authUserId: authUserId,
                displayName: preferredDisplayName
            )
            isAuthenticated = true
            syncHealthKitPromptCompletedFromDefaults()
            if let profile = currentProfile {
                syncOnboardingCompletionState(for: profile)
                if profileExistedBefore {
                    applyPostAuthDisplayNameStateAfterRestore(profile: profile)
                } else {
                    let trimmed = preferredDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    requirePostAuthDisplayNameConfirmation(
                        for: profile,
                        prefill: trimmed.isEmpty ? nil : trimmed
                    )
                }
            }
            if let id = currentProfile?.id {
                ProductAnalytics.track(
                    ProductAnalytics.Event.authSignIn,
                    userId: id,
                    properties: ["method": "apple"]
                )
            }
        } catch {
            authErrorMessage = error.localizedDescription
            AppLogger.log(category: "auth", level: .error, message: "apple sign-in failed", metadata: ["error": error.localizedDescription])
        }
        logSessionRoutingDecision(reason: "sign_in_apple_finished")
    }

    func signOut() async {
        authErrorMessage = nil
        do {
            let client = try requireClient()
            try await client.auth.signOut()
            let signedOutUserId = currentProfile?.id
            if let signedOutUserId {
                ProductAnalytics.endForegroundSessionForAuthChange(profileId: signedOutUserId)
            }
            isAuthenticated = false
            currentProfile = nil
            showSearchingCardOnHome = false
            pendingMatchFoundCelebrationMatchId = nil
            pendingMatchActiveCelebrationMatchId = nil
            clearFriendNotificationUI()
            healthKitPromptCompleted = false
            postAuthNameFieldPrefill = nil
            postAuthDisplayNameStepComplete = true
            isOnboardingComplete = false
            if let signedOutUserId {
                ProductAnalytics.track(ProductAnalytics.Event.authSignOut, userId: signedOutUserId)
            }
        } catch {
            authErrorMessage = error.localizedDescription
            AppLogger.log(category: "auth", level: .error, message: "sign-out failed", metadata: ["error": error.localizedDescription])
        }
        logSessionRoutingDecision(reason: "sign_out")
    }

    func markOnboardingComplete() {
        guard let profileId = currentProfile?.id else { return }
        let key = Self.onboardingCompleteKey(profileId: profileId)
        UserDefaults.standard.set(true, forKey: key)
        UserDefaults.standard.removeObject(forKey: Self.legacyOnboardingCompleteKey)
        isOnboardingComplete = true
        if let id = currentProfile?.id {
            ProductAnalytics.track(ProductAnalytics.Event.onboardingCompleted, userId: id)
        }
        logSessionRoutingDecision(reason: "onboarding_marked_complete")
    }

    func resetOnboardingForDebug() {
        if let id = currentProfile?.id {
            UserDefaults.standard.removeObject(forKey: Self.onboardingCompleteKey(profileId: id))
        }
        UserDefaults.standard.removeObject(forKey: Self.legacyOnboardingCompleteKey)
        isOnboardingComplete = false
        showSearchingCardOnHome = false
        if let id = currentProfile?.id {
            UserDefaults.standard.removeObject(forKey: Self.healthKitPromptKey(profileId: id))
        }
        healthKitPromptCompleted = false
        logSessionRoutingDecision(reason: "onboarding_reset_debug")
    }

    func markHealthKitPromptCompleted() {
        guard let profileId = currentProfile?.id else { return }
        UserDefaults.standard.set(true, forKey: Self.healthKitPromptKey(profileId: profileId))
        healthKitPromptCompleted = true
    }

    private func syncHealthKitPromptCompletedFromDefaults() {
        guard let id = currentProfile?.id else {
            healthKitPromptCompleted = false
            return
        }
        healthKitPromptCompleted = UserDefaults.standard.bool(forKey: Self.healthKitPromptKey(profileId: id))
    }

    func markOnboardingSearchVisible() {
        showSearchingCardOnHome = true
    }

    func clearSearchingCardOnHomeFlag() {
        guard showSearchingCardOnHome else { return }
        showSearchingCardOnHome = false
    }

    func requestHomeSnapshotRefresh() {
        homeSnapshotRefreshToken &+= 1
    }

    func dismissHomeIntroTip() {
        guard showHomeIntroTip else { return }
        showHomeIntroTip = false
    }

    func queueMatchFoundCelebration(matchId: UUID) {
        pendingMatchFoundCelebrationMatchId = matchId
    }

    /// Clears and returns the queued id only when it appears in the current pending list (Home has synced).
    func takePendingMatchFoundCelebrationIfPendingContains(_ pendingMatchIds: Set<UUID>) -> UUID? {
        guard let id = pendingMatchFoundCelebrationMatchId, pendingMatchIds.contains(id) else { return nil }
        pendingMatchFoundCelebrationMatchId = nil
        return id
    }

    func queueMatchActiveCelebration(matchId: UUID) {
        pendingMatchActiveCelebrationMatchId = matchId
    }

    /// Clears and returns the queued id only when it appears in the current active list (Home has synced).
    func takePendingMatchActiveCelebrationIfActiveContains(_ activeMatchIds: Set<UUID>) -> UUID? {
        guard let id = pendingMatchActiveCelebrationMatchId, activeMatchIds.contains(id) else { return nil }
        pendingMatchActiveCelebrationMatchId = nil
        return id
    }

    // MARK: - Friends / push

    func queueFriendRequestFromPush(peerId: UUID, fromName: String) {
        friendRequestBannerFromPush = (peerId, fromName)
    }

    func queueFriendAcceptedFromPush(accepterName: String, peerId: UUID) {
        friendAcceptedYourRequestBanner = (peerId, accepterName)
    }

    func dismissFriendRequestFromPush() {
        friendRequestBannerFromPush = nil
    }

    func dismissFriendAcceptedYourRequestBanner() {
        friendAcceptedYourRequestBanner = nil
    }

    func requestOpenFriendsListSheet() {
        presentFriendsListSheet = true
    }

    func dismissFriendsListSheet() {
        presentFriendsListSheet = false
    }

    func requestOpenMessages(peerId: UUID? = nil) {
        pendingMessagesPeerId = peerId
        shouldPresentMessages = true
    }

    func dismissMessagesPresentation() {
        shouldPresentMessages = false
        pendingMessagesPeerId = nil
    }

    func setBecameFriendsChallenge(_ opponent: ChallengePrefillOpponent) {
        becameFriendsChallenge = opponent
    }

    func clearBecameFriendsChallenge() {
        becameFriendsChallenge = nil
    }

    private func clearFriendNotificationUI() {
        friendRequestBannerFromPush = nil
        friendAcceptedYourRequestBanner = nil
        presentFriendsListSheet = false
        becameFriendsChallenge = nil
    }

    func updateDisplayName(_ name: String) async {
        guard let authUserId = currentProfile?.authUserId else { return }
        authErrorMessage = nil
        do {
            currentProfile = try await profileRepository.updateDisplayName(name, authUserId: authUserId)
        } catch {
            authErrorMessage = error.localizedDescription
            AppLogger.log(
                category: "auth",
                level: .warning,
                message: "display name update failed",
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    /// Initial `TextField` value for the post-auth name step (session prefill, then non-placeholder profile name, else empty for placeholders).
    var postAuthNameInitialValue: String {
        if let p = postAuthNameFieldPrefill, !p.isEmpty { return p }
        if let profile = currentProfile, profile.isAutoGeneratedDisplayName { return "" }
        return currentProfile?.displayName ?? ""
    }

    func markPostAuthDisplayNameComplete() {
        guard let profile = currentProfile else { return }
        let key = Self.postAuthDisplayNameKey(profileId: profile.id)
        UserDefaults.standard.set(true, forKey: key)
        postAuthDisplayNameStepComplete = true
        postAuthNameFieldPrefill = nil
        ProductAnalytics.track(
            ProductAnalytics.Event.postAuthDisplayNameCompleted,
            userId: profile.id
        )
        logSessionRoutingDecision(reason: "post_auth_display_name_complete")
    }

    private func applyPostAuthDisplayNameStateAfterRestore(profile: Profile) {
        let key = Self.postAuthDisplayNameKey(profileId: profile.id)
        if UserDefaults.standard.object(forKey: key) == nil {
            // First launch with this key: treat auto-generated "FitUp …" as incomplete; real names as complete (app upgrade / existing users).
            UserDefaults.standard.set(!profile.isAutoGeneratedDisplayName, forKey: key)
        }
        postAuthDisplayNameStepComplete = UserDefaults.standard.bool(forKey: key)
    }

    private func requirePostAuthDisplayNameConfirmation(for profile: Profile, prefill: String?) {
        let key = Self.postAuthDisplayNameKey(profileId: profile.id)
        UserDefaults.standard.set(false, forKey: key)
        postAuthDisplayNameStepComplete = false
        if let p = prefill, !p.isEmpty {
            postAuthNameFieldPrefill = p
        } else {
            postAuthNameFieldPrefill = nil
        }
    }

    private func requireClient() throws -> SupabaseClient {
        guard let client = SupabaseProvider.client else {
            throw ProfileRepositoryError.supabaseNotConfigured
        }
        return client
    }

    private static func resolveAuthUserId(from rawValue: Any) throws -> UUID {
        if let uuid = rawValue as? UUID {
            return uuid
        }
        if let text = rawValue as? String, let uuid = UUID(uuidString: text) {
            return uuid
        }
        throw ProfileRepositoryError.invalidAuthUserId
    }
}
