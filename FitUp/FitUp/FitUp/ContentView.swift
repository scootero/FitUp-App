//
//  ContentView.swift
//  FitUp
//
//  Created by Scott on 3/24/26.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var notificationService: NotificationService
    @Environment(\.scenePhase) private var scenePhase
    @State private var showLaunchIntro = true

    var body: some View {
        ZStack {
            BackgroundGradientView()
            if sessionStore.showAccountDeletionCompletion {
                AccountDeletionCompletionView()
            } else if sessionStore.isLoadingSession {
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

            if showLaunchIntro {
                FitOffLaunchIntroView {
                    showLaunchIntro = false
                }
                .zIndex(10)
            }
        }
        .screenTransition()
        .onAppear {
            notificationService.syncApplicationIconBadge()
            TestFlightFeedbackPromptStore.recordSessionStartIfNeeded()
            if !sessionStore.isLoadingSession {
                ProductAnalytics.trackAppColdStartIfNeeded(userId: sessionStore.currentProfile?.id)
            }
        }
        .onChange(of: sessionStore.isLoadingSession) { _, loading in
            if !loading {
                TestFlightFeedbackPromptStore.recordSessionStartIfNeeded()
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

private struct AccountDeletionCompletionView: View {
    @EnvironmentObject private var sessionStore: SessionStore

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(FitUpColors.Neon.green)
            Text("Account Deleted")
                .font(FitUpFont.display(30, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)
            Text("Your FitOff account and associated personal data were deleted.")
                .font(FitUpFont.body(15, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
                .multilineTextAlignment(.center)
            Button("Continue") { sessionStore.dismissAccountDeletionCompletion() }
                .solidButton(color: FitUpColors.Neon.cyan)
        }
        .padding(28)
    }
}

private struct FitOffLaunchIntroView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let onFinished: () -> Void

    @State private var introTask: Task<Void, Never>?
    @State private var isVisible = false
    @State private var hasFinished = false

    var body: some View {
        ZStack {
            BackgroundGradientView()

            VStack(spacing: 18) {
                appIcon
                    .frame(width: 76, height: 76)
                    .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                    .shadow(color: FitUpColors.Neon.cyan.opacity(0.34), radius: 18, x: 0, y: 8)

                FitUpBrandMark(fontSize: 34)
            }
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.96)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear(perform: startIntro)
        .onDisappear {
            introTask?.cancel()
        }
    }

    @ViewBuilder
    private var appIcon: some View {
        if let image = bundledAppIcon {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color(rgb: 0x0A1020))
                Image(systemName: "figure.run")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(FitUpColors.Neon.cyan)
            }
        }
    }

    private var bundledAppIcon: UIImage? {
        let icons = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any]
        let primary = icons?["CFBundlePrimaryIcon"] as? [String: Any]
        let fileNames = primary?["CFBundleIconFiles"] as? [String]
        return fileNames?.last.flatMap(UIImage.init(named:)) ?? UIImage(named: "AppIcon")
    }

    private func startIntro() {
        guard introTask == nil else { return }

        if reduceMotion {
            isVisible = true
            introTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(450))
                guard !Task.isCancelled else { return }
                finish()
            }
            return
        }

        withAnimation(.easeOut(duration: 0.35)) {
            isVisible = true
        }

        introTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.05))
            guard !Task.isCancelled else { return }

            withAnimation(.easeInOut(duration: 0.25)) {
                isVisible = false
            }

            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    private func finish() {
        guard !hasFinished else { return }
        hasFinished = true
        introTask?.cancel()
        onFinished()
    }
}

private enum TestFlightFeedbackPromptHints {
    static let bullets = [
        "What feels interesting or useful about FitOff?",
        "What feels confusing or missing?",
        "What would make this app worth supporting monthly?",
    ]
}

private struct RootShellView: View {
    @EnvironmentObject private var sessionStore: SessionStore
    @EnvironmentObject private var notificationService: NotificationService
    @Environment(\.scenePhase) private var scenePhase

    let profile: Profile?
    let showOnboardingSearching: Bool

    @State private var selectedTab: MainTab = .home
    @StateObject private var homeViewModel = HomeViewModel()
    @State private var challengeLaunchContext: ChallengeLaunchContext?
    @State private var matchDetailsContext: MatchDetailsContext?
    @State private var showingPaywall = false
    @State private var showTestFlightFeedbackPrompt = false
    @State private var showTestFlightFeedbackForm = false

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
        .task(id: profile?.id) {
            homeViewModel.start(
                profile: profile,
                showOnboardingSearching: showOnboardingSearching,
                sessionStore: sessionStore
            )
        }
        .onChange(of: sessionStore.homeSnapshotRefreshToken) { _, _ in
            Task { await homeViewModel.reload(force: true) }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            FloatingTabBar(
                selected: $selectedTab,
                hasActiveBattle: homeViewModel.activeBattleCount > 0
            ) {
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
        .sheet(isPresented: $showTestFlightFeedbackPrompt) {
            TestFlightFeedbackPromptSheet(
                onGiveFeedback: {
                    TestFlightFeedbackPromptStore.markPromptPresentedForCurrentPeriod()
                    showTestFlightFeedbackPrompt = false
                    showTestFlightFeedbackForm = true
                },
                onNotNow: {
                    TestFlightFeedbackPromptStore.markPromptPresentedForCurrentPeriod()
                    showTestFlightFeedbackPrompt = false
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showTestFlightFeedbackForm) {
            if let userId = profile?.id {
                TesterFeedbackSheet(
                    userId: userId,
                    screenName: "testflight_feedback_prompt",
                    promptHints: TestFlightFeedbackPromptHints.bullets,
                    feedbackSource: "testflight_timed_prompt",
                    onSuccess: {
                        TestFlightFeedbackPromptStore.markFeedbackSubmitted()
                    }
                )
            }
        }
        .task(id: testFlightFeedbackPromptTaskIdentity) {
            await scheduleTestFlightFeedbackPromptIfEligible()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task { await scheduleTestFlightFeedbackPromptIfEligible() }
        }
        .onChange(of: notificationService.pendingDeepLink) { _, deepLink in
            guard let deepLink else { return }
            _ = notificationService.consumeDeepLink()
            handleDeepLink(deepLink)
        }
    }

    private var testFlightFeedbackPromptTaskIdentity: String {
        [
            profile?.id.uuidString ?? "nil",
            String(matchDetailsContext != nil),
            String(challengeLaunchContext != nil),
            String(showingPaywall),
            String(sessionStore.presentFriendsListSheet),
            String(sessionStore.becameFriendsChallenge != nil),
            String(showTestFlightFeedbackPrompt),
            String(showTestFlightFeedbackForm),
        ].joined(separator: "|")
    }

    @MainActor
    private func scheduleTestFlightFeedbackPromptIfEligible() async {
        guard scenePhase == .active else { return }
        guard !showTestFlightFeedbackPrompt, !showTestFlightFeedbackForm else { return }
        guard isTestFlightFeedbackPromptPresentationClear else { return }
        guard isTestFlightFeedbackPromptEligible else { return }

        let delay = TestFlightFeedbackPromptStore.presentationDelay
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return }
        guard scenePhase == .active else { return }
        guard !showTestFlightFeedbackPrompt, !showTestFlightFeedbackForm else { return }
        guard isTestFlightFeedbackPromptPresentationClear else { return }
        guard isTestFlightFeedbackPromptEligible else { return }

        showTestFlightFeedbackPrompt = true
        TestFlightFeedbackPromptStore.markPromptPresentedForCurrentPeriod()
    }

    private var isTestFlightFeedbackPromptEligible: Bool {
        TestFlightFeedbackPromptStore.shouldPresent()
    }

    private var isTestFlightFeedbackPromptPresentationClear: Bool {
        matchDetailsContext == nil
            && challengeLaunchContext == nil
            && !showingPaywall
            && !sessionStore.presentFriendsListSheet
            && sessionStore.becameFriendsChallenge == nil
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
            LeaderboardView(profile: profile)
            .trackProductScreen("leaderboard", userId: sessionStore.currentProfile?.id)
        }
    }
}

private struct SessionRestoreLoadingView: View {
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 22) {
                FitUpBrandMark(fontSize: 50)
                    .frame(maxWidth: .infinity, alignment: .center)

                HomeIntroTipView()

                ProgressView("Restoring session...")
                    .font(FitUpFont.body(14, weight: .medium))
                    .tint(FitUpColors.Neon.cyan)
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
            .frame(maxWidth: .infinity, maxHeight: geo.size.height * 0.75, alignment: .top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("FitOff. Restoring session.")
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
