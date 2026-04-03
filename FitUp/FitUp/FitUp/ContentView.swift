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
        .task(id: sessionStore.currentProfile?.id) {
            await MetricSyncCoordinator.shared.updateProfile(sessionStore.currentProfile)
            if sessionStore.currentProfile != nil {
                await MetricSyncCoordinator.shared.requestSync(trigger: .manual, force: true)
                // Register for APNs now that we have a valid session + profile.
                notificationService.registerForRemoteNotifications()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await MetricSyncCoordinator.shared.appDidBecomeActive()
            }
        }
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
            selectedTab = .activity
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
        case .activity:
            ActivityView(
                profile: profile,
                onOpenMatchDetails: { matchId, _ in
                    matchDetailsContext = MatchDetailsContext(matchId: matchId)
                }
            )
        case .health:
            TabPlaceholderView(
                title: "Health",
                subtitle: "Slice 12 will replace this placeholder."
            )
        case .profile:
            ProfilePlaceholderView(
                profile: profile,
                onSignOut: {
                    Task { await sessionStore.signOut() }
                }
            )
        case .ranks:
            TabPlaceholderView(
                title: "Ranks",
                subtitle: "Slice 11 will replace this placeholder."
            )
        }
    }
}

private struct TabPlaceholderView: View {
    let title: String
    let subtitle: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(title)
                    .font(FitUpFont.display(28, weight: .black))
                    .foregroundStyle(FitUpColors.Text.primary)
                Text(subtitle)
                    .font(FitUpFont.body(14, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .glassCard(.base)
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
    }
}

private struct ProfilePlaceholderView: View {
    let profile: Profile?
    var onSignOut: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("Profile")
                    .font(FitUpFont.display(28, weight: .black))
                    .foregroundStyle(FitUpColors.Text.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("Signed in as \(profile?.displayName ?? "Unknown user")")
                    .font(FitUpFont.body(14, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("Sign Out") {
                    onSignOut()
                }
                .ghostButton(color: FitUpColors.Neon.pink)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
            .glassCard(.base)
            .padding(.horizontal, 16)
            .padding(.top, 20)
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
