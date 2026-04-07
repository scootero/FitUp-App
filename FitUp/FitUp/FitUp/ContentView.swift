//
//  ContentView.swift
//  FitUp
//
//  Created by Scott on 3/24/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var notificationService: NotificationService
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            BackgroundGradientView()
            if sessionStore.isLoadingSession {
                ProgressView("Restoring session...")
                    .font(FitUpFont.body(14, weight: .medium))
                    .tint(FitUpColors.Neon.cyan)
            } else if !sessionStore.isAuthenticated {
                AuthView()
            } else if !sessionStore.isOnboardingComplete {
                OnboardingView()
            } else {
                RootShellView(
                    profile: sessionStore.currentProfile,
                    showOnboardingSearching: sessionStore.showSearchingCardOnHome
                )
            }
        }
        .screenTransition()
        .task(id: metricSyncLifecycleIdentity) {
            let eligible = sessionStore.isOnboardingComplete || sessionStore.healthKitPromptCompleted
            guard eligible else {
                await MetricSyncCoordinator.shared.updateProfile(nil)
                return
            }
            await MetricSyncCoordinator.shared.updateProfile(sessionStore.currentProfile)
            if sessionStore.currentProfile != nil {
                await MetricSyncCoordinator.shared.requestSync(trigger: .manual, force: true)
                notificationService.registerForRemoteNotifications()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            guard sessionStore.isOnboardingComplete || sessionStore.healthKitPromptCompleted else { return }
            Task {
                await MetricSyncCoordinator.shared.appDidBecomeActive()
            }
        }
    }

    /// Re-runs metric sync lifecycle when profile, Health onboarding prompt, or full onboarding completion changes.
    private var metricSyncLifecycleIdentity: String {
        let pid = sessionStore.currentProfile?.id.uuidString ?? "nil"
        return "\(pid)-hk:\(sessionStore.healthKitPromptCompleted)-ob:\(sessionStore.isOnboardingComplete)"
    }
}

private struct RootShellView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var notificationService: NotificationService

    let profile: Profile?
    let showOnboardingSearching: Bool

    @State private var selectedTab: MainTab = .home
    @State private var challengeLaunchContext: ChallengeLaunchContext?
    @State private var matchDetailsContext: MatchDetailsContext?
    @State private var showingPaywall = false

    var body: some View {
        ZStack {
            BackgroundGradientView()
            currentTabContent
        }
        .safeAreaInset(edge: .bottom) {
            FloatingTabBar(selected: $selectedTab) {
                challengeLaunchContext = .battleEntry
            }
        }
        .fullScreenCover(item: $challengeLaunchContext) { launchContext in
            ChallengeFlowView(
                profile: profile,
                launchContext: launchContext
            ) {
                challengeLaunchContext = nil
            }
        }
        .fullScreenCover(item: $matchDetailsContext) { context in
            MatchDetailsView(
                matchId: context.matchId,
                profile: profile
            ) {
                matchDetailsContext = nil
            } onRematch: { launchContext in
                matchDetailsContext = nil
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    challengeLaunchContext = launchContext
                }
            }
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView { showingPaywall = false }
        }
        .onChange(of: notificationService.pendingDeepLink) { _, deepLink in
            guard let deepLink else { return }
            _ = notificationService.consumeDeepLink()
            handleDeepLink(deepLink)
        }
    }

    private func handleDeepLink(_ deepLink: NotificationDeepLink) {
        switch deepLink {
        case .home:
            selectedTab = .home
        case .matchDetails(let matchId):
            matchDetailsContext = MatchDetailsContext(matchId: matchId)
        case .activity:
            selectedTab = .home
        }
    }

    @ViewBuilder
    private var currentTabContent: some View {
        switch selectedTab {
        case .home:
            HomeView(
                profile: profile,
                showOnboardingSearching: showOnboardingSearching,
                onOpenChallenge: { prefilledOpponent in
                    if let prefilledOpponent {
                        challengeLaunchContext = .prefilled(opponent: prefilledOpponent)
                    } else {
                        challengeLaunchContext = .battleEntry
                    }
                },
                onOpenMatchDetails: { matchId, _ in
                    matchDetailsContext = MatchDetailsContext(matchId: matchId)
                }
            )
        case .health:
            HealthView(profile: profile)
        case .profile:
            ProfileView(
                profile: profile,
                onSignOut: { Task { await sessionStore.signOut() } },
                onOpenPaywall: { showingPaywall = true }
            )
        case .ranks:
            LeaderboardView(profile: profile) { opponent in
                challengeLaunchContext = .prefilled(opponent: opponent)
            }
        }
    }
}

private struct MatchDetailsContext: Identifiable {
    let matchId: UUID

    var id: UUID { matchId }
}

#Preview {
    ContentView()
        .environmentObject(SessionStore())
        .environmentObject(NotificationService.shared)
}
