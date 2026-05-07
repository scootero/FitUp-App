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
            content
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
        .onChange(of: viewModel.step) { _, step in
            let stepKey: String
            switch step {
            case .hero: stepKey = "hero"
            case .howItWorks: stepKey = "how_it_works"
            case .permissions: stepKey = "permissions"
            case .findFirstMatch: stepKey = "find_first_match"
            }
            ProductAnalytics.track(
                ProductAnalytics.Event.onboardingStepViewed,
                userId: sessionStore.currentProfile?.id,
                properties: ["step": stepKey]
            )
        }
        .trackProductScreen("onboarding", userId: sessionStore.currentProfile?.id)
        .screenTransition()
    }

    @ViewBuilder
    private var content: some View {
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
                onContinue: {
                    Task {
                        await viewModel.runOnboardingPermissionsFlow {
                            sessionStore.markHealthKitPromptCompleted()
                        }
                    }
                }
            )
        case .findFirstMatch:
            FindFirstMatchView(
                sevenDayAverageSteps: viewModel.sevenDayStepAverage,
                isLoadingAverage: viewModel.isLoadingAverage,
                isSubmitting: viewModel.isSubmittingSearch,
                statusMessage: viewModel.statusMessage,
                errorMessage: viewModel.errorMessage,
                onRetryAverage: {
                    Task { await viewModel.refreshSevenDayStepAverage() }
                },
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

#Preview {
    OnboardingView()
        .environmentObject(SessionStore())
}
