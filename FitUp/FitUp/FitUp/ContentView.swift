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
                HomePlaceholderView(
                    profile: sessionStore.currentProfile,
                    showSearchingCard: sessionStore.showSearchingCardOnHome,
                    onSignOut: {
                        Task { await sessionStore.signOut() }
                    }
                )
            }
        }
        .screenTransition()
    }
}

private struct HomePlaceholderView: View {
    let profile: Profile?
    let showSearchingCard: Bool
    var onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Home Placeholder")
                    .font(FitUpFont.display(24, weight: .black))
                    .foregroundStyle(FitUpColors.Text.primary)
                Text("Signed in as \(profile?.displayName ?? "Unknown user")")
                    .font(FitUpFont.body(14, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showSearchingCard {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(FitUpColors.Neon.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Finding opponent...")
                            .font(FitUpFont.body(14, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.primary)
                        Text("Steps · 1 day · Start today")
                            .font(FitUpFont.body(12, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.secondary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .glassCard(.pending)
            }

            Button("Sign Out") {
                onSignOut()
            }
            .ghostButton(color: FitUpColors.Neon.pink)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(20)
        .glassCard(.win)
        .padding(.horizontal, 16)
    }
}

#Preview {
    ContentView()
        .environmentObject(SessionStore())
}
