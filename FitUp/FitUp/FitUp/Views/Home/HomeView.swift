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

    @EnvironmentObject private var sessionStore: SessionStore
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    statsRow

                    if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(FitUpFont.body(12, weight: .semibold))
                            .foregroundStyle(FitUpColors.Neon.pink)
                            .padding(.horizontal, 2)
                    }

                    // Stats -> Searching -> Pending -> Active Battles -> Past Matches -> Discover
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
                        .transition(
                            .asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.96)),
                                removal: .opacity
                            )
                        )
                    }

                    ActiveSection(
                        matches: viewModel.activeMatches,
                        onOpenMatch: { match in
                            onOpenMatchDetails(match.id, match.opponent.displayName)
                        }
                    )

                    PastMatchesSection(
                        matches: viewModel.completedMatches,
                        onOpenMatch: { match in
                            onOpenMatchDetails(match.id, match.opponentName)
                        }
                    )

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
                .animation(
                    .spring(response: 0.52, dampingFraction: 0.78),
                    value: viewModel.pendingMatches.map(\.id)
                )
            }
            .scrollIndicators(.hidden)

            if let celebration = viewModel.matchFoundCelebration {
                MatchFoundCelebrationOverlay(
                    opponentName: celebration.opponent.displayName,
                    onDismiss: { viewModel.dismissMatchFoundCelebration() }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                .zIndex(1)
            }
        }
        .task(id: profile?.id) {
            viewModel.start(profile: profile, showOnboardingSearching: showOnboardingSearching)
        }
        .onAppear {
            clearSearchingFlagIfHasMatch()
        }
        .onChange(of: viewModel.pendingMatches.count) { _, _ in
            clearSearchingFlagIfHasMatch()
        }
        .onChange(of: viewModel.activeMatches.count) { _, _ in
            clearSearchingFlagIfHasMatch()
        }
        .onDisappear {
            viewModel.stop()
        }
    }

    private func clearSearchingFlagIfHasMatch() {
        if !viewModel.pendingMatches.isEmpty || !viewModel.activeMatches.isEmpty {
            sessionStore.clearSearchingCardOnHomeFlag()
        }
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCell(value: "\(viewModel.stats.matchCount)", label: "Matches")
            statCell(value: "\(viewModel.stats.winCount)", label: "Wins")
            statCell(
                value: viewModel.stats.winRateText,
                label: "Win Rate",
                accentColor: FitUpColors.Neon.cyan,
                variant: .win
            )
        }
    }

    private func statCell(
        value: String,
        label: String,
        accentColor: Color? = nil,
        variant: GlassCardVariant = .base
    ) -> some View {
        VStack(spacing: 5) {
            Text(value)
                .font(FitUpFont.display(28, weight: .black))
                .foregroundStyle(accentColor ?? FitUpColors.Text.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label.uppercased())
                .font(FitUpFont.body(10, weight: .medium))
                .foregroundStyle(FitUpColors.Text.tertiary)
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 8)
        .glassCard(variant)
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

// MARK: - Match found celebration (retro)

private struct MatchFoundCelebrationOverlay: View {
    let opponentName: String
    var onDismiss: () -> Void

    @State private var cardAppeared = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.56)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            scanlineField

            VStack(spacing: 14) {
                Text("YOU'VE BEEN MATCHED!")
                    .font(FitUpFont.mono(17, weight: .heavy))
                    .foregroundStyle(FitUpColors.Neon.green)
                    .shadow(color: FitUpColors.Neon.green.opacity(0.5), radius: 10)
                    .multilineTextAlignment(.center)

                Text("VS \(opponentName.uppercased())")
                    .font(FitUpFont.mono(13, weight: .semibold))
                    .foregroundStyle(FitUpColors.Neon.yellow)
                    .multilineTextAlignment(.center)

                Text("TAP TO CONTINUE")
                    .font(FitUpFont.mono(10, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.tertiary)
                    .padding(.top, 6)
            }
            .padding(28)
            .frame(maxWidth: 320)
            .background(
                RoundedRectangle(cornerRadius: FitUpRadius.lg)
                    .fill(Color(rgb: 0x0A1020).opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: FitUpRadius.lg)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        FitUpColors.Neon.cyan,
                                        FitUpColors.Neon.purple,
                                        FitUpColors.Neon.green,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                    )
            )
            .shadow(color: FitUpColors.Neon.cyan.opacity(0.25), radius: 22)
            .scaleEffect(cardAppeared ? 1 : 0.9)
            .opacity(cardAppeared ? 1 : 0)
            .padding(.horizontal, 24)
            .contentShape(Rectangle())
            .onTapGesture { onDismiss() }
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.72)) {
                cardAppeared = true
            }
        }
    }

    private var scanlineField: some View {
        GeometryReader { geo in
            Canvas { context, size in
                let lineH: CGFloat = 1
                let gap: CGFloat = 6
                var y: CGFloat = 0
                while y < size.height {
                    let rect = CGRect(x: 0, y: y, width: size.width, height: lineH)
                    context.fill(Path(rect), with: .color(Color.white.opacity(0.04)))
                    y += gap + lineH
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
