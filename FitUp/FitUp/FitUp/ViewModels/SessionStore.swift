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
    @Published private(set) var showSearchingCardOnHome = false

    private let profileRepository = ProfileRepository()

    private static let onboardingKey = "onboardingComplete"

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
            currentProfile = try await profileRepository.fetchProfile(authUserId: authUserId)
            isAuthenticated = true
            showSearchingCardOnHome = false
            AppLogger.log(
                category: "auth",
                level: .info,
                message: "session restored",
                userId: currentProfile?.id
            )
        } catch {
            isAuthenticated = false
            currentProfile = nil
            showSearchingCardOnHome = false
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

    func signInWithApple(idToken: String) async {
        authErrorMessage = nil
        do {
            let client = try requireClient()
            _ = try await client.auth.signInWithIdToken(
                credentials: .init(provider: .apple, idToken: idToken)
            )
            let session = try await client.auth.session
            let authUserId = try Self.resolveAuthUserId(from: session.user.id)
            currentProfile = try await profileRepository.createProfileIfNeeded(authUserId: authUserId, displayName: nil)
            isAuthenticated = true
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
    }

    func markOnboardingSearchVisible() {
        showSearchingCardOnHome = true
        AppLogger.log(category: "onboarding", level: .info, message: "home searching card flagged visible")
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
