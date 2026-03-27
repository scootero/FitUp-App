//
//  MatchDetailsView.swift
//  FitUp
//
//  Slice 5 Match Details screen.
//

import SwiftUI

struct MatchDetailsView: View {
    var onClose: () -> Void
    var onRematch: (ChallengeLaunchContext) -> Void

    @StateObject private var viewModel: MatchDetailsViewModel
    @State private var showingLiveMatch = false
    private let profile: Profile?

    init(
        matchId: UUID,
        profile: Profile?,
        onClose: @escaping () -> Void,
        onRematch: @escaping (ChallengeLaunchContext) -> Void
    ) {
        self.onClose = onClose
        self.onRematch = onRematch
        self.profile = profile
        _viewModel = StateObject(
            wrappedValue: MatchDetailsViewModel(
                matchId: matchId,
                profile: profile,
                detailsRepository: MatchDetailsRepository(),
                homeRepository: HomeRepository()
            )
        )
    }

    var body: some View {
        ZStack {
            BackgroundGradientView()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(FitUpFont.body(12, weight: .semibold))
                            .foregroundStyle(FitUpColors.Neon.pink)
                            .padding(.horizontal, 2)
                    }

                    if let snapshot = viewModel.snapshot {
                        heroCard(snapshot: snapshot)

                        if snapshot.state != .pending, !snapshot.dayRows.isEmpty {
                            DayBarChartView(
                                dayRows: snapshot.dayRows,
                                opponentName: snapshot.opponent.displayName,
                                opponentColor: color(from: snapshot.opponent.colorHex)
                            )

                            DayResultsListView(
                                dayRows: snapshot.dayRows,
                                opponentColor: color(from: snapshot.opponent.colorHex)
                            )
                        }
                    } else if viewModel.isLoading {
                        ProgressView("Loading match...")
                            .font(FitUpFont.body(14, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .tint(FitUpColors.Neon.cyan)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard(.base)
                    } else {
                        Text("Match unavailable.")
                            .font(FitUpFont.body(14, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassCard(.base)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollIndicators(.hidden)
        }
        .task {
            viewModel.start()
        }
        .onDisappear {
            viewModel.stop()
        }
        .fullScreenCover(isPresented: $showingLiveMatch) {
            LiveMatchView(
                matchId: viewModel.matchId,
                profile: profile
            ) {
                showingLiveMatch = false
            }
        }
        .screenTransition()
    }

    private var header: some View {
        Button {
            onClose()
        } label: {
            Label("Back", systemImage: "chevron.left")
                .font(FitUpFont.body(14, weight: .semibold))
                .foregroundStyle(FitUpColors.Neon.cyan)
        }
        .buttonStyle(.plain)
    }

    private func heroCard(snapshot: MatchDetailsSnapshot) -> some View {
        let accent = accentColor(for: snapshot)
        let heroVariant = glassVariant(for: snapshot)
        let isPending = snapshot.state == .pending
        let isActive = snapshot.state == .active
        let isCompleted = snapshot.state == .completed

        return VStack(spacing: 0) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.55), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 2)

            VStack(spacing: 12) {
                NeonBadge(
                    label: badgeLabel(for: snapshot),
                    color: isPending ? FitUpColors.Neon.blue : accent
                )

                HStack(alignment: .center, spacing: 8) {
                    VStack(spacing: 6) {
                        AvatarView(
                            initials: snapshot.me.initials,
                            color: FitUpColors.Neon.cyan,
                            size: 52,
                            glow: !isPending && snapshot.isWinning
                        )
                        Text("You")
                            .font(FitUpFont.display(14, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.primary)

                        if !isPending {
                            Text("\(snapshot.myScore)")
                                .font(FitUpFont.display(24, weight: .black))
                                .foregroundStyle(snapshot.isWinning ? FitUpColors.Neon.cyan : FitUpColors.Text.secondary)
                        }

                        if isCompleted && snapshot.isWinning {
                            NeonBadge(label: "🏆 WINNER", color: FitUpColors.Neon.cyan)
                        }

                        if isActive {
                            Text("\(snapshot.myToday.formatted()) today")
                                .font(FitUpFont.body(10, weight: .medium))
                                .foregroundStyle(FitUpColors.Text.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    VStack(spacing: 5) {
                        Text("VS")
                            .font(FitUpFont.display(20, weight: .black))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [accent, accent.opacity(0.55)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }

                    VStack(spacing: 6) {
                        AvatarView(
                            initials: snapshot.opponent.initials,
                            color: color(from: snapshot.opponent.colorHex),
                            size: 52,
                            glow: isCompleted && !snapshot.isWinning
                        )
                        Text(snapshot.opponent.displayName)
                            .font(FitUpFont.display(14, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.primary)
                            .lineLimit(1)

                        if !isPending {
                            Text("\(snapshot.theirScore)")
                                .font(FitUpFont.display(24, weight: .black))
                                .foregroundStyle(!snapshot.isWinning ? FitUpColors.Neon.orange : FitUpColors.Text.secondary)
                        }

                        if isCompleted && !snapshot.isWinning {
                            NeonBadge(label: "🏆 WINNER", color: FitUpColors.Neon.cyan)
                        }

                        if isActive {
                            Text("\(snapshot.theirToday.formatted()) today")
                                .font(FitUpFont.body(10, weight: .medium))
                                .foregroundStyle(FitUpColors.Text.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                if isPending {
                    pendingActions(snapshot: snapshot)
                }

                if isCompleted {
                    Button {
                        if let context = viewModel.makeRematchLaunchContext() {
                            onRematch(context)
                        }
                    } label: {
                        Label("Rematch", systemImage: "arrow.uturn.forward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .solidButton(color: FitUpColors.Neon.orange)
                }

                if isActive {
                    Button {
                        showingLiveMatch = true
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(FitUpColors.Neon.green)
                                .frame(width: 8, height: 8)
                                .shadow(color: FitUpColors.Neon.green.opacity(0.8), radius: 6, x: 0, y: 0)
                            Text("Watch Live ⚡")
                                .font(FitUpFont.body(14, weight: .heavy))
                        }
                        .foregroundStyle(FitUpColors.Neon.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                                .fill(FitUpColors.Neon.green.opacity(0.10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                                        .strokeBorder(FitUpColors.Neon.green.opacity(0.28), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .glassCard(heroVariant)
    }

    @ViewBuilder
    private func pendingActions(snapshot: MatchDetailsSnapshot) -> some View {
        if snapshot.canRespondToPending {
            HStack(spacing: 10) {
                Button {
                    Task {
                        let shouldClose = await viewModel.declinePendingChallenge()
                        if shouldClose {
                            onClose()
                        }
                    }
                } label: {
                    Text("Decline")
                        .font(FitUpFont.body(14, weight: .bold))
                        .foregroundStyle(FitUpColors.Neon.pink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                                .fill(FitUpColors.Neon.pink.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                                        .strokeBorder(FitUpColors.Neon.pink.opacity(0.3), lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)

                Button {
                    Task { await viewModel.acceptPendingChallenge() }
                } label: {
                    Label("Accept Challenge", systemImage: "bolt.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .solidButton(color: FitUpColors.Neon.cyan)
                .frame(maxWidth: .infinity)
            }
            .disabled(viewModel.isSubmittingAction)
            .opacity(viewModel.isSubmittingAction ? 0.65 : 1)
        } else {
            Text("Waiting for both players to accept.")
                .font(FitUpFont.body(12, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }

    private func badgeLabel(for snapshot: MatchDetailsSnapshot) -> String {
        let core = "\(snapshot.sportLabel.uppercased()) · \(snapshot.seriesLabel.uppercased())"
        if snapshot.state == .pending {
            return "INCOMING · \(core)"
        }
        return core
    }

    private func accentColor(for snapshot: MatchDetailsSnapshot) -> Color {
        if snapshot.state == .pending { return FitUpColors.Neon.blue }
        return snapshot.isWinning ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange
    }

    private func glassVariant(for snapshot: MatchDetailsSnapshot) -> GlassCardVariant {
        if snapshot.state == .pending { return .base }
        return snapshot.isWinning ? .win : .lose
    }

    private func color(from hex: String) -> Color {
        guard let value = UInt32(hex, radix: 16) else {
            return FitUpColors.Neon.orange
        }
        return Color(rgb: value)
    }
}
