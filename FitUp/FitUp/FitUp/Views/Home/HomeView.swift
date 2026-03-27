//
//  HomeView.swift
//  FitUp
//
//  Slice 3 Home shell and ordered sections.
//

import SwiftUI

struct HomeView: View {
    let profile: Profile?
    let showOnboardingSearching: Bool
    var onOpenChallenge: (ChallengePrefillOpponent?) -> Void
    var onOpenMatchDetails: (UUID, String) -> Void

    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(FitUpFont.body(12, weight: .semibold))
                        .foregroundStyle(FitUpColors.Neon.pink)
                        .padding(.horizontal, 2)
                }

                // Locked order: Searching -> Active -> Pending -> Discover Players
                if !viewModel.searchingRequests.isEmpty {
                    SearchingSection(
                        requests: viewModel.searchingRequests,
                        isCancellingSearchId: viewModel.activeActionSearchID,
                        waitTimeText: { viewModel.waitTimeLabel(for: $0) },
                        onCancel: { searchId in
                            Task { await viewModel.cancelSearch(searchId) }
                        }
                    )
                }

                if !viewModel.activeMatches.isEmpty {
                    ActiveSection(
                        matches: viewModel.activeMatches,
                        onOpenMatch: { match in
                            onOpenMatchDetails(match.id, match.opponent.displayName)
                        }
                    )
                }

                if !viewModel.pendingMatches.isEmpty {
                    PendingSection(
                        matches: viewModel.pendingMatches,
                        activeActionMatchID: viewModel.activeActionPendingMatchID,
                        onOpenMatch: { pendingMatch in
                            onOpenMatchDetails(pendingMatch.id, pendingMatch.opponent.displayName)
                        },
                        onAccept: { pendingMatch in
                            Task { await viewModel.acceptPendingMatch(pendingMatch) }
                        },
                        onDecline: { pendingMatch in
                            Task { await viewModel.declinePendingMatch(pendingMatch) }
                        }
                    )
                }

                if !viewModel.discoverUsers.isEmpty {
                    DiscoverSection(
                        users: viewModel.discoverUsers,
                        onChallenge: { user in
                            onOpenChallenge(prefillOpponent(from: user))
                        }
                    )
                }

                if !viewModel.hasAnyContent, !viewModel.isLoading {
                    zeroState
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
        .scrollIndicators(.hidden)
        .task(id: profile?.id) {
            viewModel.start(profile: profile, showOnboardingSearching: showOnboardingSearching)
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text("FIT")
                        .font(FitUpFont.display(27, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.blue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    Text("UP")
                        .font(FitUpFont.display(27, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FitUpColors.Neon.orange, FitUpColors.Neon.yellow],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                Text("Let's go, \(firstName)")
                    .font(FitUpFont.body(12, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Button {} label: {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .frame(width: 36, height: 36)
                        .glassCard(.base)
                }
                .buttonStyle(.plain)

                Button {
                    onOpenChallenge(nil)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(FitUpColors.Neon.cyan)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(FitUpColors.Neon.cyan.opacity(0.14))
                                .overlay(Circle().strokeBorder(FitUpColors.Neon.cyan.opacity(0.28), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var zeroState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ready for your first battle?")
                .font(FitUpFont.display(24, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)
            Text("Your Searching, Active, Pending, and Discover sections are empty. Start by creating a challenge.")
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
            Button("Find Your First Match") {
                onOpenChallenge(nil)
            }
            .solidButton(color: FitUpColors.Neon.cyan)
        }
        .padding(20)
        .glassCard(.base)
    }

    private var firstName: String {
        let full = profile?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Athlete"
        return full.split(separator: " ").first.map(String.init) ?? full
    }

    private func prefillOpponent(from user: HomeDiscoverUser) -> ChallengePrefillOpponent {
        ChallengePrefillOpponent(
            id: user.id,
            displayName: user.displayName,
            initials: user.initials,
            colorHex: user.colorHex
        )
    }
}
