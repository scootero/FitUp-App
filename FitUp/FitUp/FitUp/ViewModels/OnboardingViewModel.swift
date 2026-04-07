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

    func logFlowStartIfNeeded() {
        guard !didLogStart else { return }
        didLogStart = true
        AppLogger.log(category: "onboarding", level: .info, message: "onboarding started")
    }

    func completeTutorialStep() {
        AppLogger.log(category: "onboarding", level: .info, message: "tutorial completed")
        step = .healthExplainer
        errorMessage = nil
    }

    func requestHealthPermission() async {
        isAuthorizingHealth = true
        errorMessage = nil
        AppLogger.log(category: "onboarding", level: .info, message: "health permission explainer shown")
        defer { isAuthorizingHealth = false }

        do {
            try await HealthKitService.requestAuthorization()
            AppLogger.log(category: "onboarding", level: .info, message: "health authorization request completed")
        } catch {
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
        AppLogger.log(category: "onboarding", level: .info, message: "notification permission explainer shown")
        defer { isAuthorizingNotifications = false }

        do {
            let granted = try await NotificationService.requestAuthorization()
            AppLogger.log(
                category: "onboarding",
                level: .info,
                message: granted ? "notification permission granted" : "notification permission denied"
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
            AppLogger.log(
                category: "onboarding",
                level: .info,
                message: "7-day step average loaded",
                metadata: ["value": String(Int(value.rounded()))]
            )
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
        AppLogger.log(category: "onboarding", level: .info, message: "find opponent tapped", userId: profileId)
        defer { isSubmittingSearch = false }

        do {
            try await matchSearchRepository.createOnboardingSearchRequest(
                creatorId: profileId,
                creatorBaseline: sevenDayStepAverage
            )
            AppLogger.log(category: "onboarding", level: .info, message: "match_search_requests row created", userId: profileId)

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
