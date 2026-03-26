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
            viewModel.logFlowStartIfNeeded()
        }
        .screenTransition()
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .tutorial:
            TutorialCardsView {
                viewModel.completeTutorialStep()
            }
        case .healthExplainer:
            PermissionExplainerView(
                title: "Enable Apple Health",
                bodyText: "FitUp needs access to steps, active calories, resting heart rate, and sleep to run fair matches.",
                iconSystemName: "heart.text.square.fill",
                buttonTitle: "Continue",
                isWorking: viewModel.isAuthorizingHealth
            ) {
                Task {
                    await viewModel.requestHealthPermission()
                }
            }
        case .notificationExplainer:
            PermissionExplainerView(
                title: "Enable Notifications",
                bodyText: "Get notified when a match is found, when challenges update, and when each day is finalized.",
                iconSystemName: "bell.badge.fill",
                buttonTitle: "Continue",
                isWorking: viewModel.isAuthorizingNotifications
            ) {
                Task {
                    await viewModel.requestNotificationPermission()
                }
            }
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
