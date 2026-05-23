//
//  ProductAnalytics.swift
//  FitUp
//
//  Intentional product events to `analytics_events`. Not mirrored from AppLogger.
//  Pre-auth events allowed with `userId == nil` must match `preAuthAllowlistedEventNames`
//  and server RLS on `analytics_events` (see `supabase/manual_sql/analytics_events_reset.sql`).
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
    /// Profile id that owns the current foreground session (`session_started`); used for `session_ended` after sign-out or background.
    private static var foregroundSessionOwnerProfileId: UUID?

    private static var didTrackColdStart = false

    /// Must stay in sync with `supabase/manual_sql/analytics_events_reset.sql` anonymous allowlist.
    static let preAuthAllowlistedEventNames: Set<String> = [
        "app_cold_start",
        "auth_screen_view",
    ]

    enum Event {
        static let appColdStart = "app_cold_start"
        static let authScreenView = "auth_screen_view"
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

        static let healthSyncFailed = "health_sync_failed"

        static let matchmakingStarted = "matchmaking_started"
        static let matchmakingCancelled = "matchmaking_cancelled"
        static let matchCreated = "match_created"
        static let matchViewed = "match_viewed"
        static let matchAccepted = "match_accepted"
        static let matchDeclined = "match_declined"
        static let completedMatchViewed = "completed_match_viewed"

        static let opponentProfileViewed = "opponent_profile_viewed"

        static let subscriptionScreenViewed = "subscription_screen_viewed"
        static let subscriptionPurchaseStarted = "subscription_purchase_started"
        static let subscriptionPurchaseSucceeded = "subscription_purchase_succeeded"
        static let subscriptionPurchaseFailed = "subscription_purchase_failed"
        static let subscriptionRestoreSucceeded = "subscription_restore_succeeded"

        static let feedbackOpened = "feedback_opened"
        static let feedbackSubmitted = "feedback_submitted"
        static let messagesOpened = "messages_opened"

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

    /// Foreground session: start only when `profileId` is available (see `syncForegroundSessionWithProfile`).
    static func handleScenePhaseChange(_ phase: ScenePhase, userId: UUID?) {
        switch phase {
        case .active:
            if let uid = userId {
                syncForegroundSessionWithProfile(profileId: uid)
            }

        case .background:
            emitSessionEndedAndClear()

        default:
            break
        }
    }

    /// When `currentProfile.id` becomes available while the app is active, start session analytics once per foreground stint.
    static func syncForegroundSessionWithProfile(profileId: UUID?) {
        guard let profileId else { return }
        sessionLock.lock()
        let alreadyOpen = foregroundSessionId != nil
        sessionLock.unlock()
        guard !alreadyOpen else { return }

        sessionLock.lock()
        let sid = UUID()
        foregroundSessionId = sid
        foregroundSessionStartedAt = Date()
        foregroundSessionOwnerProfileId = profileId
        sessionLock.unlock()

        track(Event.sessionStarted, userId: profileId, properties: [:], sessionOverride: sid)
    }

    /// End tracked foreground session on sign-out (app may stay active; background may not fire).
    static func endForegroundSessionForAuthChange(profileId: UUID) {
        sessionLock.lock()
        let owner = foregroundSessionOwnerProfileId
        let sid = foregroundSessionId
        let startedAt = foregroundSessionStartedAt
        guard owner == profileId, sid != nil else {
            sessionLock.unlock()
            return
        }
        foregroundSessionId = nil
        foregroundSessionStartedAt = nil
        foregroundSessionOwnerProfileId = nil
        sessionLock.unlock()

        var props: [String: String] = [:]
        if let startedAt {
            props["duration_ms"] = String(Int(Date().timeIntervalSince(startedAt) * 1000))
        }
        track(Event.sessionEnded, userId: profileId, properties: props, sessionOverride: sid)
    }

    private static func emitSessionEndedAndClear() {
        sessionLock.lock()
        let sid = foregroundSessionId
        let startedAt = foregroundSessionStartedAt
        let owner = foregroundSessionOwnerProfileId
        foregroundSessionId = nil
        foregroundSessionStartedAt = nil
        foregroundSessionOwnerProfileId = nil
        sessionLock.unlock()

        guard let sid, let owner else { return }

        var props: [String: String] = [:]
        if let startedAt {
            props["duration_ms"] = String(Int(Date().timeIntervalSince(startedAt) * 1000))
        }
        track(Event.sessionEnded, userId: owner, properties: props, sessionOverride: sid)
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

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

        let row = AnalyticsEventInsert(
            userId: userId,
            eventName: name,
            properties: properties,
            appVersion: version,
            buildNumber: build,
            platform: "ios",
            source: "ios_client",
            eventSchemaVersion: 1,
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

    // MARK: - Dev analytics buffer (Debug + TestFlight bypass)

    private static let debugBufferLock = NSLock()
    private static var debugRecent: [(Date, String)] = []
    private static var debugLastError: String?
    private static let debugMax = 40

    private static func recordDebugBuffer(name: String, error: String?) {
        guard DevMode.isAvailable else { return }
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
        guard DevMode.isAvailable else { return [] }
        debugBufferLock.lock()
        defer { debugBufferLock.unlock() }
        return debugRecent
    }

    static func debugLastInsertError() -> String? {
        guard DevMode.isAvailable else { return nil }
        debugBufferLock.lock()
        defer { debugBufferLock.unlock() }
        return debugLastError
    }
}

private struct AnalyticsEventInsert: Encodable {
    let userId: UUID?
    let eventName: String
    let properties: [String: String]
    let appVersion: String?
    let buildNumber: String?
    let platform: String?
    let source: String?
    let eventSchemaVersion: Int?
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
        case source
        case eventSchemaVersion = "event_schema_version"
        case clientSessionId = "client_session_id"
        case sessionId = "session_id"
        case screenName = "screen_name"
    }
}
