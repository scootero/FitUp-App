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
                .tracking(2)
                .foregroundStyle(FitUpColors.Text.tertiary)
                .padding(.bottom, 12)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                statCell(title: "MATCHES", value: "\(stats.matchesPlayed)")
                statCell(title: "WINS", value: "\(stats.wins)")
                statCell(title: "LOSSES", value: "\(stats.losses)")
                statCell(title: "WIN RATE", value: "\(stats.winRate)%")
                statCell(title: "STREAK", value: stats.currentStreakLabel)
                statCell(title: "TIES", value: "\(stats.ties)", subdued: stats.ties == 0)
            }
        }
        .padding(18)
        .glassCard(.base)
    }

    private func statCell(title: String, value: String, subdued: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(FitUpFont.body(9, weight: .heavy))
                .tracking(1.2)
                .foregroundStyle(FitUpColors.Text.tertiary)
            Text(value)
                .font(FitUpFont.display(26, weight: .bold))
                .foregroundStyle(subdued ? FitUpColors.Text.secondary : FitUpColors.Neon.cyan)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassCard(.base)
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
