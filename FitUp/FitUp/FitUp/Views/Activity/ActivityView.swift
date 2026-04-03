//
//  ActivityView.swift
//  FitUp
//
//  Slice 10 full Activity screen.
//

import SwiftUI

struct ActivityView: View {
    let profile: Profile?
    var onOpenMatchDetails: (UUID, String) -> Void

    @StateObject private var viewModel = ActivityViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                statsRow

                if viewModel.isLoading && viewModel.completedMatches.isEmpty && viewModel.activeMatches.isEmpty {
                    ProgressView("Loading completed matches...")
                        .font(FitUpFont.body(13, weight: .medium))
                        .tint(FitUpColors.Neon.cyan)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 22)
                } else {
                    activeSection
                    pastMatchesSection

                    if viewModel.activeMatches.isEmpty && viewModel.completedMatches.isEmpty {
                        emptyState
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
        }
        .scrollIndicators(.hidden)
        .task(id: profile?.id) {
            viewModel.start(profile: profile)
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Activity")
                .font(FitUpFont.display(22, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)

            Spacer(minLength: 0)

            Button {} label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .frame(width: 36, height: 36)
                    .glassCard(.base)
            }
            .buttonStyle(.plain)
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

    private var activeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Active Battles", actionTitle: "\(viewModel.activeMatches.count) live", onAction: {})

            if viewModel.activeMatches.isEmpty {
                Text("No active battles right now.")
                    .font(FitUpFont.body(13, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .glassCard(.base)
            } else {
                ForEach(viewModel.activeMatches) { match in
                    ActiveMatchRow(match: match) {
                        onOpenMatchDetails(match.id, match.opponent.displayName)
                    }
                }
            }
        }
    }

    private var pastMatchesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Past Matches", actionTitle: "Filter →", onAction: {})

            if viewModel.completedMatches.isEmpty {
                Text("Completed matches appear here after day finalization.")
                    .font(FitUpFont.body(13, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .glassCard(.base)
            } else {
                ForEach(viewModel.completedMatches) { match in
                    PastMatchRow(match: match) {
                        onOpenMatchDetails(match.id, match.opponentName)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("No matches yet")
                .font(FitUpFont.display(18, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)
            Text("Create or accept a challenge from Home, then come back to see your full history.")
                .font(FitUpFont.body(13, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
        }
        .padding(14)
        .glassCard(.base)
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
}
