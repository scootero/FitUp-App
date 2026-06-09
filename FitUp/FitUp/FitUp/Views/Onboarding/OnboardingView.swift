//
//  OnboardingView.swift
//  FitUp
//
//  Slice 2 onboarding flow container.
//

import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            BackgroundGradientView()
            VStack(spacing: 0) {
                OnboardingTopChrome(
                    showsBack: viewModel.showsBack,
                    onBack: { viewModel.goBack() }
                )
                stepContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .padding(.bottom, 28)
        }
        .onAppear {
            viewModel.analyticsUserId = sessionStore.currentProfile?.id
            viewModel.logFlowStartIfNeeded()
        }
        .onChange(of: sessionStore.currentProfile?.id) { _, _ in
            viewModel.analyticsUserId = sessionStore.currentProfile?.id
            viewModel.logFlowStartIfNeeded()
        }
        .onChange(of: viewModel.step) { _, _ in
            trackStepViewed()
        }
        .onChange(of: viewModel.matchSetupPhase) { _, _ in
            if viewModel.step == .findFirstMatch {
                trackStepViewed()
            }
        }
        .trackProductScreen("onboarding", userId: sessionStore.currentProfile?.id)
        .screenTransition()
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .hero:
            OnboardingHeroView {
                viewModel.completeHeroStep()
            }
        case .howItWorks:
            OnboardingHowItWorksView {
                viewModel.completeHowItWorksStep()
            }
        case .permissions:
            OnboardingPermissionsView(
                isRequestingHealth: viewModel.isAuthorizingHealth,
                isRequestingNotifications: viewModel.isAuthorizingNotifications,
                isLoadingStepAverages: viewModel.isLoadingAverage,
                onContinue: {
                    Task {
                        await viewModel.runOnboardingPermissionsFlow {
                            sessionStore.markHealthKitPromptCompleted()
                        }
                    }
                }
            )
        case .findFirstMatch:
            switch viewModel.matchSetupPhase {
            case .stepGoal:
                OnboardingStepGoalView(
                    sevenDayAverageSteps: viewModel.sevenDayStepAverage,
                    thirtyDayAverageSteps: viewModel.thirtyDayStepAverage,
                    ninetyDayAverageSteps: viewModel.ninetyDayStepAverage,
                    isLoadingAverage: viewModel.isLoadingAverage,
                    errorMessage: viewModel.errorMessage,
                    stepGoalTier: $viewModel.stepGoalTier,
                    dailyStepGoalText: $viewModel.dailyStepGoalText,
                    onSelectTier: { viewModel.selectStepGoalTier($0) },
                    onRetryAverage: {
                        Task { await viewModel.refreshAllStepAverages() }
                    },
                    onNext: { viewModel.advanceToStartMatch() }
                )
            case .startMatch:
                OnboardingStartMatchView(
                    isSubmitting: viewModel.isSubmittingSearch,
                    isLoadingAverage: viewModel.isLoadingAverage,
                    statusMessage: viewModel.statusMessage,
                    errorMessage: viewModel.errorMessage,
                    onFindOpponent: {
                        Task {
                            let success = await viewModel.submitFindOpponent(profileId: sessionStore.currentProfile?.id)
                            guard success else { return }
                            sessionStore.markOnboardingSearchVisible()
                            sessionStore.markOnboardingComplete()
                        }
                    }
                )
            }
        }
    }

    private func trackStepViewed() {
        let stepKey: String
        switch viewModel.step {
        case .hero: stepKey = "hero"
        case .howItWorks: stepKey = "how_it_works"
        case .permissions: stepKey = "permissions"
        case .findFirstMatch: stepKey = "find_first_match"
        }

        var properties: [String: String] = ["step": stepKey]
        if viewModel.step == .findFirstMatch {
            properties["substep"] = viewModel.matchSetupPhase == .stepGoal ? "step_goal" : "start_match"
        }

        ProductAnalytics.track(
            ProductAnalytics.Event.onboardingStepViewed,
            userId: sessionStore.currentProfile?.id,
            properties: properties
        )
    }
}

#Preview {
    OnboardingView()
        .environmentObject(SessionStore())
}
