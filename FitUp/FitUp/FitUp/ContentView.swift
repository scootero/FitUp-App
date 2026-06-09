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
                SessionRestoreLoadingView()
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
            notificationService.syncApplicationIconBadge()
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
                await MetricSyncCoordinator.shared.requestSync(trigger: .appLaunch, force: true)
                notificationService.registerForRemoteNotifications()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            Task {
                await MetricSyncCoordinator.shared.updateScenePhase(newPhase)
            }
            ProductAnalytics.handleScenePhaseChange(newPhase, userId: sessionStore.currentProfile?.id)
            guard newPhase == .active else { return }
            notificationService.syncApplicationIconBadge()
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
    @StateObject private var homeViewModel = HomeViewModel()
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
            ZStack {
                mainTabShell

                if let context = matchDetailsContext {
                    MatchDetailsView(
                        matchId: context.matchId,
                        profile: profile,
                        onClose: { matchDetailsContext = nil },
                        onRematch: { launchContext in
                            matchDetailsContext = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                challengeLaunchContext = launchContext
                            }
                        }
                    )
                    .trackProductScreen("match_detail", userId: sessionStore.currentProfile?.id)
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
        .animation(.easeInOut(duration: 0.22), value: matchDetailsContext != nil)
        .environmentObject(sessionStore)
        .environmentObject(notificationService)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(selected: $selectedTab) {
                challengeLaunchContext = .battleEntry
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .onChange(of: selectedTab) { _, _ in
            matchDetailsContext = nil
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
                viewModel: homeViewModel,
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
                },
                onOpenLeaderboard: {
                    selectedTab = .ranks
                }
            )
            .trackProductScreen("home", userId: sessionStore.currentProfile?.id)
        case .health:
            HealthView(
                profile: profile,
                onOpenChallenge: {
                    challengeLaunchContext = .battleEntry
                },
                onRematchRival: { opponent in
                    challengeLaunchContext = .prefilled(opponent: opponent)
                },
                onOpenMatchDetails: { matchId, _ in
                    matchDetailsContext = MatchDetailsContext(matchId: matchId)
                }
            )
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

private struct SessionRestoreLoadingView: View {
    private static let introTipAutoDismissSeconds: Double = 3

    @State private var isShowingIntroTip = false
    @State private var introTipDismissTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            VStack(spacing: 22) {
                HomeIntroTipRevealSection(
                    isShowingTip: $isShowingIntroTip,
                    onTipRevealed: scheduleIntroTipAutoDismiss
                )

                Spacer(minLength: 0)

                ProgressView("Restoring session...")
                    .font(FitUpFont.body(14, weight: .medium))
                    .tint(FitUpColors.Neon.cyan)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            if isShowingIntroTip {
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissIntroTip()
                    }
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("FitUp. Restoring session.")
        .onDisappear {
            introTipDismissTask?.cancel()
            introTipDismissTask = nil
        }
    }

    private func scheduleIntroTipAutoDismiss() {
        introTipDismissTask?.cancel()
        introTipDismissTask = Task {
            try? await Task.sleep(for: .seconds(Self.introTipAutoDismissSeconds))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                dismissIntroTip(animated: true)
            }
        }
    }

    private func dismissIntroTip(animated: Bool = true) {
        introTipDismissTask?.cancel()
        introTipDismissTask = nil
        guard isShowingIntroTip else { return }
        if animated {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                isShowingIntroTip = false
            }
        } else {
            isShowingIntroTip = false
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
