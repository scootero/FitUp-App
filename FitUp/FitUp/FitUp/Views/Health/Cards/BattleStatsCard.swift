//
//  BattleStatsCard.swift
//  FitUp
//
//  Lightweight competitive stats summary.
//

import SwiftUI

struct BattleStatsCard: View {
    let stats: HealthBattleStats

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("BATTLE STATS")
                .font(FitUpFont.body(10, weight: .heavy))
                .fitUpHealthSectionTitleStyle(weight: .heavy, tracking: 2)
                .padding(.bottom, 12)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statCell(title: "MATCHES", value: "\(stats.matchesPlayed)", index: 0)
                statCell(title: "WINS", value: "\(stats.wins)", index: 1)
                statCell(title: "LOSSES", value: "\(stats.losses)", index: 2)
                statCell(title: "WIN RATE", value: "\(stats.winRate)%", index: 3)
                statCell(title: "STREAK", value: stats.currentStreakLabel, index: 4)
                statCell(title: "TIES", value: "\(stats.ties)", subdued: stats.ties == 0, index: 5)
            }
        }
        .padding(18)
        .healthGamifiedCard(.battleStats)
    }

    private func statCell(title: String, value: String, subdued: Bool = false, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FitUpFont.body(9, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(FitUpColors.HealthOnLight.tertiary)
            Text(value)
                .font(FitUpFont.display(26, weight: .bold))
                .foregroundStyle(subdued ? FitUpColors.HealthOnLight.secondary : FitUpColors.Neon.cyan)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .healthGamifiedCard(.miniAccent(index))
    }
}

#Preview {
    BattleStatsCard(
        stats: HealthBattleStats(
            matchesPlayed: 12,
            wins: 8,
            losses: 3,
            ties: 1,
            winRate: 73,
            currentStreakType: .win,
            currentStreakCount: 3
        )
    )
    .padding()
    .background { BackgroundGradientView() }
}
