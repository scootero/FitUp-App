//
//  ContentView.swift
//  FitUp
//
//  Created by Scott on 3/24/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessionStore: SessionStore

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
    }
}

private struct RootShellView: View {
    @EnvironmentObject private var sessionStore: SessionStore

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
            TabPlaceholderView(
                title: "Activity",
                subtitle: "Slice 10 will replace this placeholder."
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
}
