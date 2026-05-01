//
//  CompetitionEdgeTodaySection.swift
//  FitUp
//
//  “Competition Edge Today” — per-active-match delta vs opponent (Health + Home).
//

import SwiftUI

struct CompetitionEdgeTodaySection: View {
    let matches: [HomeActiveMatch]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("COMPETITION EDGE TODAY")
                    .font(FitUpFont.body(11, weight: .heavy))
                    .fitUpGlobalTitleStyle(weight: .heavy, tracking: 2)
                Spacer()
            }
            .padding(.top, 4)
            .padding(.bottom, 10)

            VStack(spacing: 0) {
                if matches.isEmpty {
                    Text("No active battles right now.")
                        .font(FitUpFont.body(12))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                } else {
                    ForEach(Array(matches.enumerated()), id: \.element.id) { index, match in
                        CompetitionEdgeTodayRow(match: match)
                        if index < matches.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.06))
                        }
                    }
                }
            }
            .padding(14)
            .glassCard(.base)
        }
    }
}

private struct CompetitionEdgeTodayRow: View {
    let match: HomeActiveMatch

    var body: some View {
        let delta = match.myToday - match.theirToday
        let up = delta >= 0
        let label = match.metricType == "steps"
            ? "\(abs(delta)) steps"
            : "\(abs(delta)) cal"

        HStack {
            Text("vs \(match.opponent.displayName)")
                .font(FitUpFont.body(12))
                .foregroundStyle(FitUpColors.Text.secondary)
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: up ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(up ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange)
                Text("\(up ? "+" : "-")\(label)")
                    .font(FitUpFont.display(13, weight: .bold))
                    .foregroundStyle(up ? FitUpColors.Neon.cyan : FitUpColors.Neon.orange)
            }
        }
        .padding(.vertical, 8)
    }
}

#Preview {
    CompetitionEdgeTodaySection(
        matches: [
            HomeActiveMatch(
                id: UUID(),
                metricType: "steps",
                durationDays: 7,
                sportLabel: "Steps",
                seriesLabel: "Series",
                daysLeft: 3,
                finalDayCutoffAt: nil,
                finalDayScoreEndsAt: nil,
                myToday: 8200,
                theirToday: 7500,
                myScore: 1,
                theirScore: 0,
                isWinning: true,
                opponent: HomeOpponent(id: UUID(), displayName: "Alex", initials: "A", colorHex: "#00FFFF"),
                dayPips: []
            ),
        ]
    )
    .padding()
    .background { BackgroundGradientView() }
}
