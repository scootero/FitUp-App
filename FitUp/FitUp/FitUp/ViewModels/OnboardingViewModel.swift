//
//  OnboardingViewModel.swift
//  FitUp
//
//  Slice 2: onboarding flow state and side effects.
//

import Combine
import Foundation

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step {
        case tutorial
        case healthExplainer
        case notificationExplainer
        case findFirstMatch
    }

    @Published private(set) var step: Step = .tutorial
    @Published private(set) var sevenDayStepAverage: Double?
    @Published private(set) var isLoadingAverage = false
    @Published private(set) var isAuthorizingHealth = false
    @Published private(set) var isAuthorizingNotifications = false
    @Published private(set) var isSubmittingSearch = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let matchSearchRepository = MatchSearchRepository()
    private var didLogStart = false

    /// Profile id for product analytics (set from `OnboardingView` when the flow is shown).
    var analyticsUserId: UUID?

    func logFlowStartIfNeeded() {
        guard !didLogStart else { return }
        didLogStart = true
        ProductAnalytics.track(ProductAnalytics.Event.onboardingStarted, userId: analyticsUserId)
    }

    func completeTutorialStep() {
        ProductAnalytics.track(
            ProductAnalytics.Event.onboardingTutorialCompleted,
            userId: analyticsUserId
        )
        step = .healthExplainer
        errorMessage = nil
    }

    func requestHealthPermission() async {
        isAuthorizingHealth = true
        errorMessage = nil
        defer { isAuthorizingHealth = false }

        ProductAnalytics.track(
            ProductAnalytics.Event.healthPermissionRequested,
            userId: analyticsUserId,
            properties: ["source": "onboarding"]
        )

        do {
            try await HealthKitService.requestAuthorization()
            ProductAnalytics.track(
                ProductAnalytics.Event.healthPermissionGranted,
                userId: analyticsUserId,
                properties: ["source": "onboarding"]
            )
            ProductAnalytics.track(
                ProductAnalytics.Event.onboardingHealthPromptCompleted,
                userId: analyticsUserId
            )
        } catch {
            let denied = (error as? HealthKitError).map {
                if case .authorizationDenied = $0 { return true }
                return false
            } ?? false
            ProductAnalytics.track(
                ProductAnalytics.Event.healthPermissionDenied,
                userId: analyticsUserId,
                properties: [
                    "source": "onboarding",
                    "reason": denied ? "authorization_denied" : "error",
                ]
            )
            AppLogger.log(
                category: "onboarding",
                level: .warning,
                message: "health permission request failed",
                metadata: ["error": error.localizedDescription]
            )
        }

        await refreshSevenDayStepAverage()
        step = .notificationExplainer
    }

    func requestNotificationPermission() async {
        isAuthorizingNotifications = true
        errorMessage = nil
        defer { isAuthorizingNotifications = false }

        do {
            _ = try await NotificationService.requestAuthorization()
            ProductAnalytics.track(
                ProductAnalytics.Event.onboardingNotificationPromptCompleted,
                userId: analyticsUserId
            )
        } catch {
            AppLogger.log(
                category: "onboarding",
                level: .warning,
                message: "notification permission request failed",
                metadata: ["error": error.localizedDescription]
            )
        }

        step = .findFirstMatch
    }

    func refreshSevenDayStepAverage() async {
        isLoadingAverage = true
        errorMessage = nil
        defer { isLoadingAverage = false }

        do {
            let value = try await HealthKitService.fetchSevenDayStepAverage()
            sevenDayStepAverage = value
        } catch {
            sevenDayStepAverage = nil
            errorMessage = "Could not read your step average right now."
            AppLogger.log(
                category: "onboarding",
                level: .warning,
                message: "7-day step average load failed",
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    func submitFindOpponent(profileId: UUID?) async -> Bool {
        guard let profileId else {
            errorMessage = "Missing user profile. Please sign in again."
            AppLogger.log(category: "onboarding", level: .error, message: "find opponent failed: missing profile")
            return false
        }

        isSubmittingSearch = true
        statusMessage = "Finding opponent..."
        errorMessage = nil
        defer { isSubmittingSearch = false }

        do {
            try await matchSearchRepository.createOnboardingSearchRequest(
                creatorId: profileId,
                creatorBaseline: sevenDayStepAverage
            )
            ProductAnalytics.track(
                ProductAnalytics.Event.onboardingFindOpponentSubmitted,
                userId: profileId
            )

            statusMessage = "We'll notify you when your match is found."
            try await Task.sleep(nanoseconds: 3_000_000_000)
            return true
        } catch {
            statusMessage = nil
            errorMessage = "We couldn't start search yet. Please try again."
            AppLogger.log(
                category: "onboarding",
                level: .error,
                message: "match_search_requests insert failed",
                userId: profileId,
                metadata: ["error": error.localizedDescription]
            )
            return false
        }
    }
}
