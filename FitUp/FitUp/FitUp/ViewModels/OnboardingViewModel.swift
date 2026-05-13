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
        case hero
        case howItWorks
        case permissions
        case findFirstMatch
    }

    enum StepGoalTier: String, CaseIterable, Identifiable {
        case easy
        case moderate
        case aggressive

        var id: String { rawValue }

        var label: String {
            switch self {
            case .easy: return "Easy"
            case .moderate: return "Moderate"
            case .aggressive: return "Aggressive"
            }
        }
    }

    @Published private(set) var step: Step = .hero
    @Published private(set) var sevenDayStepAverage: Double?
    @Published private(set) var thirtyDayStepAverage: Double?
    @Published private(set) var ninetyDayStepAverage: Double?
    @Published private(set) var isLoadingAverage = false
    @Published private(set) var isAuthorizingHealth = false
    @Published private(set) var isAuthorizingNotifications = false
    @Published private(set) var isSubmittingSearch = false
    @Published var stepGoalTier: StepGoalTier = .moderate
    @Published var dailyStepGoalText: String = ""
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let matchSearchRepository = MatchSearchRepository()
    private var didLogStart = false

    /// Profile id for product analytics (set from `OnboardingView` when the flow is shown).
    var analyticsUserId: UUID?

    func logFlowStartIfNeeded() {
        guard let uid = analyticsUserId else { return }
        guard !didLogStart else { return }
        didLogStart = true
        ProductAnalytics.track(ProductAnalytics.Event.onboardingStarted, userId: uid)
    }

    func completeHeroStep() {
        ProductAnalytics.track(
            ProductAnalytics.Event.onboardingTutorialCompleted,
            userId: analyticsUserId
        )
        step = .howItWorks
        errorMessage = nil
    }

    func completeHowItWorksStep() {
        step = .permissions
        errorMessage = nil
    }

    /// Requests Health, then notifications, on one conceptual step. Calls `onHealthPromptFinished` after the Health flow returns (for per-profile Health onboarding flag).
    func runOnboardingPermissionsFlow(onHealthPromptFinished: @escaping () -> Void) async {
        errorMessage = nil

        isAuthorizingHealth = true
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

        onHealthPromptFinished()
        await refreshAllStepAverages()

        isAuthorizingNotifications = true
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

    /// Rounds to nearest 50; floors at 500 for a sensible minimum display target.
    private static func roundStepGoalSuggestion(_ raw: Double) -> Int {
        max(500, Int((raw / 50.0).rounded() * 50))
    }

    /// 30d average when available, else 7d, else a neutral default for suggestion math only.
    private var suggestionBaselineSteps: Double {
        if let t = thirtyDayStepAverage, t > 0 { return t }
        if let s = sevenDayStepAverage, s > 0 { return s }
        return 10_000
    }

    func suggestedGoal(for tier: StepGoalTier) -> Int {
        let base = suggestionBaselineSteps
        let mult: Double
        switch tier {
        case .easy: mult = 1.05
        case .moderate: mult = 1.15
        case .aggressive: mult = 1.30
        }
        return Self.roundStepGoalSuggestion(base * mult)
    }

    func selectStepGoalTier(_ tier: StepGoalTier) {
        stepGoalTier = tier
        dailyStepGoalText = "\(suggestedGoal(for: tier))"
        AppLogger.log(
            category: "onboarding",
            level: .info,
            message: "step goal tier selected",
            userId: analyticsUserId,
            metadata: [
                "tier": tier.rawValue,
                "suggested_goal": "\(suggestedGoal(for: tier))",
            ]
        )
    }

    private func applyDefaultGoalFromTier() {
        dailyStepGoalText = "\(suggestedGoal(for: stepGoalTier))"
    }

    func refreshAllStepAverages() async {
        isLoadingAverage = true
        errorMessage = nil
        defer { isLoadingAverage = false }

        async let v7 = HealthKitService.fetchSevenDayStepAverage()
        async let v30 = HealthKitService.fetchNDayStepAverage(days: 30)
        async let v90 = HealthKitService.fetchNDayStepAverage(days: 90)

        var anyOk = false

        do {
            sevenDayStepAverage = try await v7
            if let sevenDayStepAverage, sevenDayStepAverage > 0 { anyOk = true }
        } catch {
            sevenDayStepAverage = nil
            AppLogger.log(
                category: "onboarding",
                level: .warning,
                message: "7-day step average load failed",
                metadata: ["error": error.localizedDescription]
            )
        }

        do {
            thirtyDayStepAverage = try await v30
            if let thirtyDayStepAverage, thirtyDayStepAverage > 0 { anyOk = true }
        } catch {
            thirtyDayStepAverage = nil
            AppLogger.log(
                category: "onboarding",
                level: .warning,
                message: "30-day step average load failed",
                metadata: ["error": error.localizedDescription]
            )
        }

        do {
            ninetyDayStepAverage = try await v90
            if let ninetyDayStepAverage, ninetyDayStepAverage > 0 { anyOk = true }
        } catch {
            ninetyDayStepAverage = nil
            AppLogger.log(
                category: "onboarding",
                level: .warning,
                message: "90-day step average load failed",
                metadata: ["error": error.localizedDescription]
            )
        }

        if !anyOk {
            errorMessage = "Could not read your step averages right now."
        }

        let d7 = sevenDayStepAverage.map { String(Int($0.rounded())) } ?? "nil"
        let d30 = thirtyDayStepAverage.map { String(Int($0.rounded())) } ?? "nil"
        let d90 = ninetyDayStepAverage.map { String(Int($0.rounded())) } ?? "nil"
        AppLogger.log(
            category: "onboarding",
            level: .info,
            message: "step averages load finished",
            userId: analyticsUserId,
            metadata: [
                "d7": d7,
                "d30": d30,
                "d90": d90,
                "any_ok": anyOk ? "true" : "false",
            ]
        )

        applyDefaultGoalFromTier()
    }

    func submitFindOpponent(profileId: UUID?) async -> Bool {
        guard let profileId else {
            errorMessage = "Missing user profile. Please sign in again."
            AppLogger.log(category: "onboarding", level: .error, message: "find opponent failed: missing profile")
            return false
        }

        let normalized = dailyStepGoalText
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let goal = Int(normalized), goal >= 1_000, goal <= 200_000 else {
            errorMessage = "Enter a realistic daily step goal (1,000 – 200,000)."
            return false
        }
        ReadinessGoals.saveStepsGoal(goal)
        AppLogger.log(
            category: "onboarding",
            level: .info,
            message: "daily step goal saved locally",
            userId: profileId,
            metadata: ["readiness_steps_goal": "\(goal)", "tier": stepGoalTier.rawValue]
        )

        isSubmittingSearch = true
        statusMessage = "Finding opponent..."
        errorMessage = nil
        defer { isSubmittingSearch = false }

        do {
            let avg30: Double?
            if let cached = thirtyDayStepAverage, cached > 0 {
                avg30 = cached
            } else {
                avg30 = try? await HealthKitService.fetchNDayStepAverage(days: 30)
            }
            try await matchSearchRepository.createOnboardingSearchRequest(
                creatorId: profileId,
                creatorBaseline: sevenDayStepAverage,
                creatorAvg30dSteps: avg30
            )
            AppLogger.log(
                category: "onboarding",
                level: .info,
                message: "onboarding match search created",
                userId: profileId,
                metadata: [
                    "scoring_mode": "balanced",
                    "difficulty": "nil",
                    "has_avg30": (avg30 != nil) ? "true" : "false",
                ]
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
