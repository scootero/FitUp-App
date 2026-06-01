//
//  ActiveBattlesNeonSection.swift
//  FitUp
//
//  Neon/arcade Active Battles block: stat cards + battle list panel.
//

import SwiftUI

struct ActiveBattlesNeonSection: View {
    let matches: [HomeActiveMatch]
    let userProfile: ActiveBattleRowUserProfile
    let summary: HomeViewModel.BattleSummaryStats
    let summaryLine: String?
    let leaderboardRankDisplay: String
    var onOpenMatch: (HomeActiveMatch) -> Void
    var onOpenWinningMatch: () -> Void
    var onOpenLosingMatch: () -> Void
    var onOpenLeaderboard: () -> Void

    private let gridSpacing: CGFloat = 3
    private let statCardScale: CGFloat = 0.72

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            statsGrid
            sectionHeaderRow

            if !matches.isEmpty {
                battlesList
            }
        }
    }

    private var sectionHeaderRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Active Battles")
                .font(FitUpFont.body(12, weight: .bold))
                .foregroundStyle(HomePageStyle.offWhite)
            Spacer(minLength: 0)
            if let summaryLine, !summaryLine.isEmpty {
                Text(summaryLine)
                    .font(FitUpFont.body(11, weight: .semibold))
                    .foregroundStyle(HomePageStyle.muted)
                    .multilineTextAlignment(.trailing)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, 2)
    }

    private var statsGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: gridSpacing), count: 4),
            spacing: gridSpacing
        ) {
            NeonStatCard(
                systemImage: "flag.2.crossed.fill",
                label: "Active Battles",
                value: activeCountText,
                accent: FitUpColors.Neon.cyan,
                compact: true,
                compactScale: statCardScale
            )
            tappableStatCard(
                systemImage: "trophy.fill",
                label: "Winning",
                value: summary.winningCount.map(String.init) ?? "--",
                accent: FitUpColors.Neon.green,
                isEnabled: (summary.winningCount ?? 0) > 0,
                action: onOpenWinningMatch
            )
            tappableStatCard(
                systemImage: "arrow.down.right.circle.fill",
                label: "Losing",
                value: summary.losingCount.map(String.init) ?? "--",
                accent: FitUpColors.Neon.orange,
                isEnabled: (summary.losingCount ?? 0) > 0,
                action: onOpenLosingMatch
            )
            Button(action: onOpenLeaderboard) {
                NeonStatCard(
                    systemImage: "list.number",
                    label: "Leaderboard",
                    value: leaderboardRankDisplay,
                    accent: FitUpColors.Neon.pink,
                    compact: true,
                    compactScale: statCardScale
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func tappableStatCard(
        systemImage: String,
        label: String,
        value: String,
        accent: Color,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        if isEnabled {
            Button(action: action) {
                NeonStatCard(
                    systemImage: systemImage,
                    label: label,
                    value: value,
                    accent: accent,
                    compact: true,
                    compactScale: statCardScale
                )
            }
            .buttonStyle(.plain)
        } else {
            NeonStatCard(
                systemImage: systemImage,
                label: label,
                value: value,
                accent: accent,
                compact: true,
                compactScale: statCardScale
            )
        }
    }

    private var activeCountText: String {
        matches.isEmpty ? "--" : String(matches.count)
    }

    private var battlesList: some View {
        VStack(spacing: gridSpacing) {
            ForEach(matches) { match in
                Button {
                    onOpenMatch(match)
                } label: {
                    ActiveBattleRowView(match: match, userProfile: userProfile, compact: true)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
