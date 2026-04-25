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
    @Published private(set) var isOnboardingComplete = UserDefaults.standard.bool(forKey: "onboardingComplete")
    /// Per-profile: user finished the onboarding Health authorization step (sheet dismissed).
    @Published private(set) var healthKitPromptCompleted = false
    @Published private(set) var showSearchingCardOnHome = false

    /// Set by push handling (`match_found`, `challenge_received`); consumed when Home loads a pending card for this id.
    private var pendingMatchFoundCelebrationMatchId: UUID?

    /// Set by push handling (`match_active`); consumed when Home loads an active card for this id.
    private var pendingMatchActiveCelebrationMatchId: UUID?

    private let profileRepository = ProfileRepository()

    private static let onboardingKey = "onboardingComplete"

    private static func healthKitPromptKey(profileId: UUID) -> String {
        "fitup.healthKitOnboardingPromptCompleted.\(profileId.uuidString)"
    }

    init() {
        Task { await restoreSession() }
    }

    func restoreSession() async {
        isLoadingSession = true
        authErrorMessage = nil

        guard let client = SupabaseProvider.client else {
            isAuthenticated = false
            currentProfile = nil
            isLoadingSession = false
            AppLogger.log(category: "auth", level: .warning, message: "session restore skipped: Supabase client missing")
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
                AppLogger.log(
                    category: "auth",
                    level: .info,
                    message: "session restored",
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
                healthKitPromptCompleted = false
            }
        } catch {
            isAuthenticated = false
            currentProfile = nil
            showSearchingCardOnHome = false
            pendingMatchFoundCelebrationMatchId = nil
            pendingMatchActiveCelebrationMatchId = nil
            healthKitPromptCompleted = false
            AppLogger.log(category: "auth", level: .info, message: "no active session on launch")
        }

        isLoadingSession = false
    }

    func signInWithEmail(email: String, password: String) async {
        authErrorMessage = nil
        do {
            let client = try requireClient()
            _ = try await client.auth.signIn(email: email, password: password)
            await restoreSession()
            AppLogger.log(
                category: "auth",
                level: .info,
                message: "email sign-in success",
                userId: currentProfile?.id
            )
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
            AppLogger.log(
                category: "auth",
                level: .info,
                message: "email sign-up success",
                userId: currentProfile?.id
            )
        } catch {
            authErrorMessage = error.localizedDescription
            isAuthenticated = false
            AppLogger.log(category: "auth", level: .error, message: "email sign-up failed", metadata: ["error": error.localizedDescription])
        }
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
            currentProfile = try await profileRepository.createProfileIfNeeded(
                authUserId: authUserId,
                displayName: preferredDisplayName
            )
            isAuthenticated = true
            syncHealthKitPromptCompletedFromDefaults()
            AppLogger.log(
                category: "auth",
                level: .info,
                message: "apple sign-in success",
                userId: currentProfile?.id
            )
        } catch {
            authErrorMessage = error.localizedDescription
            AppLogger.log(category: "auth", level: .error, message: "apple sign-in failed", metadata: ["error": error.localizedDescription])
        }
    }

    func signOut() async {
        authErrorMessage = nil
        do {
            let client = try requireClient()
            try await client.auth.signOut()
            let signedOutUserId = currentProfile?.id
            isAuthenticated = false
            currentProfile = nil
            showSearchingCardOnHome = false
            pendingMatchFoundCelebrationMatchId = nil
            pendingMatchActiveCelebrationMatchId = nil
            healthKitPromptCompleted = false
            AppLogger.log(
                category: "auth",
                level: .info,
                message: "sign-out success",
                userId: signedOutUserId
            )
        } catch {
            authErrorMessage = error.localizedDescription
            AppLogger.log(category: "auth", level: .error, message: "sign-out failed", metadata: ["error": error.localizedDescription])
        }
    }

    func markOnboardingComplete() {
        UserDefaults.standard.set(true, forKey: Self.onboardingKey)
        isOnboardingComplete = true
        AppLogger.log(category: "auth", level: .info, message: "onboarding flag set complete")
    }

    func resetOnboardingForDebug() {
        UserDefaults.standard.set(false, forKey: Self.onboardingKey)
        isOnboardingComplete = false
        showSearchingCardOnHome = false
        if let id = currentProfile?.id {
            UserDefaults.standard.removeObject(forKey: Self.healthKitPromptKey(profileId: id))
        }
        healthKitPromptCompleted = false
    }

    func markHealthKitPromptCompleted() {
        guard let profileId = currentProfile?.id else { return }
        UserDefaults.standard.set(true, forKey: Self.healthKitPromptKey(profileId: profileId))
        healthKitPromptCompleted = true
        AppLogger.log(category: "onboarding", level: .info, message: "health onboarding prompt completed (metric sync may start)")
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
        AppLogger.log(category: "onboarding", level: .info, message: "home searching card flagged visible")
    }

    func clearSearchingCardOnHomeFlag() {
        guard showSearchingCardOnHome else { return }
        showSearchingCardOnHome = false
        AppLogger.log(category: "onboarding", level: .info, message: "home searching card flag cleared")
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

    func updateDisplayName(_ name: String) async {
        guard let authUserId = currentProfile?.authUserId else { return }
        authErrorMessage = nil
        do {
            currentProfile = try await profileRepository.updateDisplayName(name, authUserId: authUserId)
            AppLogger.log(
                category: "auth",
                level: .info,
                message: "display name updated",
                userId: currentProfile?.id
            )
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
