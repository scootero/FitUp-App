//
//  ActiveBattlesNeonSection.swift
//  FitUp
//
//  Neon/arcade Active Battles block: stat cards + battle list panel.
//

import SwiftUI

struct ActiveBattlesNeonSection: View {
    let matches: [HomeActiveMatch]
    let summary: HomeViewModel.BattleSummaryStats
    let leaderboardRankDisplay: String
    var onOpenMatch: (HomeActiveMatch) -> Void
    var onOpenWinningMatch: () -> Void
    var onOpenLosingMatch: () -> Void
    var onOpenLeaderboard: () -> Void

    private let gridSpacing: CGFloat = 5

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            statsGrid

            if !matches.isEmpty {
                battlesList
            }
        }
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
                accent: FitUpColors.Neon.cyan
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
                    accent: FitUpColors.Neon.pink
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
                    accent: accent
                )
            }
            .buttonStyle(.plain)
        } else {
            NeonStatCard(
                systemImage: systemImage,
                label: label,
                value: value,
                accent: accent
            )
        }
    }

    private var activeCountText: String {
        if let total = summary.totalActive {
            return String(total)
        }
        return matches.isEmpty ? "--" : String(matches.count)
    }

    private var battlesList: some View {
        VStack(spacing: gridSpacing) {
            ForEach(matches) { match in
                Button {
                    onOpenMatch(match)
                } label: {
                    ActiveBattleRowView(match: match)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
