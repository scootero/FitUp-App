//
//  ProductAnalytics.swift
//  FitUp
//
//  Intentional product events to `analytics_events`. Not mirrored from AppLogger.
//  Pre-auth events allowed with `userId == nil` must match `preAuthAllowlistedEventNames`
//  and server RLS on `analytics_events`.
//

import Foundation
import OSLog
import Supabase
import SwiftUI

enum ProductAnalytics {
    private static let osLog = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FitUp", category: "analytics")

    /// One UUID for the entire process (cold start correlation).
    private static let clientSessionId: String = UUID().uuidString

    private static let sessionLock = NSLock()
    private static var foregroundSessionId: UUID?
    private static var foregroundSessionStartedAt: Date?

    private static var didTrackColdStart = false

    /// Must stay in sync with `supabase/migrations/*analytics*` allowlist for `user_id is null`.
    static let preAuthAllowlistedEventNames: Set<String> = [
        "app_cold_start",
        "auth_screen_view",
        "app_opened",
        "app_backgrounded",
        "session_started",
        "session_ended",
    ]

    enum Event {
        static let appColdStart = "app_cold_start"
        static let authScreenView = "auth_screen_view"
        static let appOpened = "app_opened"
        static let appBackgrounded = "app_backgrounded"
        static let sessionStarted = "session_started"
        static let sessionEnded = "session_ended"

        static let authSignIn = "auth_sign_in"
        static let authSignOut = "auth_sign_out"
        static let sessionRestored = "session_restored"

        static let onboardingStarted = "onboarding_started"
        static let onboardingCompleted = "onboarding_completed"
        static let onboardingStepViewed = "onboarding_step_viewed"
        static let onboardingTutorialCompleted = "onboarding_tutorial_completed"
        static let onboardingHealthPromptCompleted = "onboarding_health_prompt_completed"
        static let onboardingNotificationPromptCompleted = "onboarding_notification_prompt_completed"
        static let onboardingFindOpponentSubmitted = "onboarding_find_opponent_submitted"

        static let postAuthDisplayNameCompleted = "post_auth_display_name_completed"

        static let healthPermissionRequested = "health_permission_requested"
        static let healthPermissionGranted = "health_permission_granted"
        static let healthPermissionDenied = "health_permission_denied"

        static let healthSyncStarted = "health_sync_started"
        static let healthSyncSucceeded = "health_sync_succeeded"
        static let healthSyncFailed = "health_sync_failed"

        static let matchmakingStarted = "matchmaking_started"
        static let matchmakingCancelled = "matchmaking_cancelled"
        static let matchCreated = "match_created"
        static let matchViewed = "match_viewed"
        static let matchAccepted = "match_accepted"
        static let matchDeclined = "match_declined"
        static let matchCompleted = "match_completed"

        static let opponentProfileViewed = "opponent_profile_viewed"
        static let leaderboardViewed = "leaderboard_viewed"

        static let subscriptionScreenViewed = "subscription_screen_viewed"
        static let subscriptionPurchaseStarted = "subscription_purchase_started"
        static let subscriptionPurchaseSucceeded = "subscription_purchase_succeeded"
        static let subscriptionPurchaseFailed = "subscription_purchase_failed"
        static let subscriptionRestoreSucceeded = "subscription_restore_succeeded"

        static let feedbackOpened = "feedback_opened"
        static let feedbackSubmitted = "feedback_submitted"

        static let screenViewed = "screen_viewed"
        static let screenExited = "screen_exited"
    }

    /// Call once after session restore finishes (`isLoadingSession` becomes `false`).
    static func trackAppColdStartIfNeeded(userId: UUID?) {
        guard !didTrackColdStart else { return }
        didTrackColdStart = true
        track(
            Event.appColdStart,
            userId: userId,
            properties: ["authenticated": userId != nil ? "true" : "false"]
        )
    }

    /// Foreground session: new UUID each time the app returns from `background` to `active`, or first launch.
    static func handleScenePhaseChange(_ phase: ScenePhase, userId: UUID?) {
        switch phase {
        case .active:
            sessionLock.lock()
            let needStart = foregroundSessionId == nil
            let sid = needStart ? UUID() : (foregroundSessionId ?? UUID())
            if needStart {
                foregroundSessionId = sid
                foregroundSessionStartedAt = Date()
            }
            sessionLock.unlock()

            if needStart {
                var props: [String: String] = ["debug": isDebugBuild ? "true" : "false"]
                props["foreground_session_id"] = sid.uuidString
                track(Event.sessionStarted, userId: userId, properties: props, sessionOverride: sid)
                track(Event.appOpened, userId: userId, properties: props, sessionOverride: sid)
            }

        case .background:
            sessionLock.lock()
            let sid = foregroundSessionId
            let startedAt = foregroundSessionStartedAt
            foregroundSessionId = nil
            foregroundSessionStartedAt = nil
            sessionLock.unlock()

            guard let sid else { return }

            var props: [String: String] = [:]
            if let startedAt {
                props["duration_ms"] = String(Int(Date().timeIntervalSince(startedAt) * 1000))
            }
            props["debug"] = isDebugBuild ? "true" : "false"
            track(Event.sessionEnded, userId: userId, properties: props, sessionOverride: sid)
            track(Event.appBackgrounded, userId: userId, properties: props, sessionOverride: sid)

        default:
            break
        }
    }

    private static var isDebugBuild: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    static func currentForegroundSessionIdForDebug() -> UUID? {
        sessionLock.lock()
        defer { sessionLock.unlock() }
        return foregroundSessionId
    }

    static func track(
        _ name: String,
        userId: UUID?,
        screenName: String? = nil,
        properties: [String: String] = [:],
        sessionOverride: UUID? = nil
    ) {
        if userId == nil, !preAuthAllowlistedEventNames.contains(name) {
#if DEBUG
            osLog.warning("analytics: event \(name, privacy: .public) skipped pre-auth (not allowlisted)")
#endif
            return
        }

        guard let client = SupabaseProvider.client else { return }

        sessionLock.lock()
        let sessionId = sessionOverride ?? foregroundSessionId
        sessionLock.unlock()

        var merged = properties
        if merged["debug"] == nil {
            merged["debug"] = isDebugBuild ? "true" : "false"
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

        let row = AnalyticsEventInsert(
            userId: userId,
            eventName: name,
            properties: merged,
            appVersion: version,
            buildNumber: build,
            platform: "ios",
            clientSessionId: clientSessionId,
            sessionId: sessionId,
            screenName: screenName
        )

        recordDebugBuffer(name: name, error: nil)

        Task {
            do {
                try await client.from("analytics_events").insert(row).execute()
            } catch {
                osLog.error("analytics_events insert failed: \(error.localizedDescription, privacy: .public)")
                recordDebugBuffer(name: name, error: error.localizedDescription)
            }
        }
    }

    // MARK: - DEBUG buffer

#if DEBUG
    private static let debugBufferLock = NSLock()
    private static var debugRecent: [(Date, String)] = []
    private static var debugLastError: String?
    private static let debugMax = 40

    private static func recordDebugBuffer(name: String, error: String?) {
        debugBufferLock.lock()
        defer { debugBufferLock.unlock() }
        debugRecent.append((Date(), name))
        if debugRecent.count > debugMax {
            debugRecent.removeFirst(debugRecent.count - debugMax)
        }
        if let error {
            debugLastError = error
        }
    }

    static func debugRecentEvents() -> [(Date, String)] {
        debugBufferLock.lock()
        defer { debugBufferLock.unlock() }
        return debugRecent
    }

    static func debugLastInsertError() -> String? {
        debugBufferLock.lock()
        defer { debugBufferLock.unlock() }
        return debugLastError
    }
#else
    private static func recordDebugBuffer(name: String, error: String?) {}
    static func debugRecentEvents() -> [(Date, String)] { [] }
    static func debugLastInsertError() -> String? { nil }
#endif
}

private struct AnalyticsEventInsert: Encodable {
    let userId: UUID?
    let eventName: String
    let properties: [String: String]
    let appVersion: String?
    let buildNumber: String?
    let platform: String?
    let clientSessionId: String?
    let sessionId: UUID?
    let screenName: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case eventName = "event_name"
        case properties
        case appVersion = "app_version"
        case buildNumber = "build_number"
        case platform
        case clientSessionId = "client_session_id"
        case sessionId = "session_id"
        case screenName = "screen_name"
    }
}
