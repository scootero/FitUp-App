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
            } else if !sessionStore.postAuthDisplayNameStepComplete {
                PostAuthDisplayNameView()
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
        .onAppear {
            if !sessionStore.isLoadingSession {
                ProductAnalytics.trackAppColdStartIfNeeded(userId: sessionStore.currentProfile?.id)
            }
        }
        .onChange(of: sessionStore.isLoadingSession) { _, loading in
            if !loading {
                ProductAnalytics.trackAppColdStartIfNeeded(userId: sessionStore.currentProfile?.id)
            }
        }
        .onChange(of: sessionStore.currentProfile?.id) { _, _ in
            if scenePhase == .active, let pid = sessionStore.currentProfile?.id {
                ProductAnalytics.syncForegroundSessionWithProfile(profileId: pid)
            }
        }
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
            ProductAnalytics.handleScenePhaseChange(newPhase, userId: sessionStore.currentProfile?.id)
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
        return "\(pid)-name:\(sessionStore.postAuthDisplayNameStepComplete)-hk:\(sessionStore.healthKitPromptCompleted)-ob:\(sessionStore.isOnboardingComplete)"
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
        FitUpAppChromeContainer(
            profile: profile,
            showsGreeting: false,
            onOpenChallenge: { challengeLaunchContext = .battleEntry },
            onOpenMatchDetails: { matchId, _ in
                matchDetailsContext = MatchDetailsContext(matchId: matchId)
            }
        ) {
            mainTabShell
        }
        .environmentObject(sessionStore)
        .environmentObject(notificationService)
        .safeAreaInset(edge: .bottom) {
            FloatingTabBar(selected: $selectedTab) {
                challengeLaunchContext = .battleEntry
            }
        }
        .fullScreenCover(item: $challengeLaunchContext) { launchContext in
            FitUpAppChromeContainer(
                profile: profile,
                showsGreeting: false,
                onOpenChallenge: {
                    challengeLaunchContext = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        challengeLaunchContext = .battleEntry
                    }
                },
                onOpenMatchDetails: { matchId, _ in
                    challengeLaunchContext = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        matchDetailsContext = MatchDetailsContext(matchId: matchId)
                    }
                }
            ) {
                ChallengeFlowView(
                    profile: profile,
                    launchContext: launchContext
                ) {
                    challengeLaunchContext = nil
                    selectedTab = .home
                    sessionStore.requestHomeSnapshotRefresh()
                }
                .environmentObject(sessionStore)
                .trackProductScreen("challenge_flow", userId: sessionStore.currentProfile?.id)
            }
            .environmentObject(sessionStore)
            .environmentObject(notificationService)
        }
        .fullScreenCover(item: $matchDetailsContext) { context in
            FitUpAppChromeContainer(
                profile: profile,
                showsGreeting: false,
                onOpenChallenge: {
                    matchDetailsContext = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        challengeLaunchContext = .battleEntry
                    }
                },
                onOpenMatchDetails: { matchId, _ in
                    matchDetailsContext = MatchDetailsContext(matchId: matchId)
                }
            ) {
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
                .trackProductScreen("match_detail", userId: sessionStore.currentProfile?.id)
            }
            .environmentObject(sessionStore)
            .environmentObject(notificationService)
        }
        .sheet(isPresented: $showingPaywall) {
            PaywallView { showingPaywall = false }
                .environmentObject(sessionStore)
                .trackProductScreen("subscription_paywall", userId: sessionStore.currentProfile?.id)
        }
        .sheet(
            isPresented: Binding(
                get: { sessionStore.presentFriendsListSheet },
                set: { new in
                    if !new { sessionStore.dismissFriendsListSheet() }
                }
            )
        ) {
            NavigationStack {
                FriendsListView(profile: profile)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Done") { sessionStore.dismissFriendsListSheet() }
                        }
                    }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { sessionStore.becameFriendsChallenge != nil },
                set: { if !$0 { sessionStore.clearBecameFriendsChallenge() } }
            )
        ) {
            ZStack {
                if let opponent = sessionStore.becameFriendsChallenge {
                    FriendConnectedCelebrationView(
                        opponent: opponent,
                        onCompete: {
                            let o = opponent
                            sessionStore.clearBecameFriendsChallenge()
                            challengeLaunchContext = .prefilled(opponent: o)
                        },
                        onDismiss: { sessionStore.clearBecameFriendsChallenge() }
                    )
                }
            }
            .presentationDetents([.medium])
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
            notificationService.requestPresentHomeInbox()
        case .matchDetails(let matchId):
            matchDetailsContext = MatchDetailsContext(matchId: matchId)
        case .recapInbox:
            selectedTab = .home
            notificationService.requestPresentHomeInbox()
        case .activity:
            selectedTab = .home
            notificationService.requestPresentHomeInbox()
        case .friends:
            selectedTab = .profile
            sessionStore.requestOpenFriendsListSheet()
        case .messages(let peerId):
            sessionStore.requestOpenMessages(peerId: peerId)
        }
    }

    private var mainTabShell: some View {
        ZStack {
            BackgroundGradientView()
            currentTabContent
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
            .trackProductScreen("home", userId: sessionStore.currentProfile?.id)
        case .health:
            HealthView(profile: profile)
                .trackProductScreen("health", userId: sessionStore.currentProfile?.id)
        case .profile:
            ProfileView(
                profile: profile,
                onSignOut: { Task { await sessionStore.signOut() } },
                onOpenPaywall: { showingPaywall = true }
            )
            .trackProductScreen("profile", userId: sessionStore.currentProfile?.id)
        case .ranks:
            LeaderboardView(profile: profile) { opponent in
                challengeLaunchContext = .prefilled(opponent: opponent)
            }
            .trackProductScreen("leaderboard", userId: sessionStore.currentProfile?.id)
        }
    }
}

private struct MatchDetailsContext: Identifiable, Equatable {
    let matchId: UUID

    var id: UUID { matchId }
}

#Preview {
    ContentView()
        .environmentObject(SessionStore())
        .environmentObject(NotificationService.shared)
}
