//
//  StatsSummaryPillRow.swift
//  FitUp
//

import SwiftUI

struct StatsSummaryPillRow: View {
    let battleStats: HealthBattleStats
    let rivalCount: Int
    var hasResolvedBattleStats: Bool = true

    private var recordText: String {
        guard hasResolvedBattleStats, battleStats.matchesPlayed > 0 else {
            return BattleStatsTheme.unresolvedPlaceholder
        }
        if battleStats.ties > 0 {
            return "\(battleStats.wins)-\(battleStats.losses)-\(battleStats.ties)"
        }
        return "\(battleStats.wins)-\(battleStats.losses)"
    }

    private var winRateText: String {
        guard hasResolvedBattleStats, (battleStats.wins + battleStats.losses) > 0 else {
            return BattleStatsTheme.unresolvedPlaceholder
        }
        return "\(battleStats.winRate)%"
    }

    private var streakText: String? {
        guard hasResolvedBattleStats,
              battleStats.currentStreakType == .win,
              battleStats.currentStreakCount > 0
        else { return nil }
        return "\(battleStats.currentStreakCount)W 🔥"
    }

    private var rivalsText: String {
        guard hasResolvedBattleStats else { return BattleStatsTheme.unresolvedPlaceholder }
        return "\(rivalCount)"
    }

    var body: some View {
        HStack(spacing: 6) {
            pill(label: "RECORD", value: recordText, color: BattleStatsTheme.green)
            pill(label: "WIN RATE", value: winRateText, color: BattleStatsTheme.gold)
            if let streakText {
                pill(label: "STREAK", value: streakText, color: BattleStatsTheme.orange)
            } else {
                pill(label: "STREAK", value: BattleStatsTheme.unresolvedPlaceholder, color: BattleStatsTheme.textLabel)
            }
            pill(label: "RIVALS", value: rivalsText, color: BattleStatsTheme.blue)
        }
        .accessibilityElement(children: .contain)
    }

    private func pill(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(label)
                .font(.system(size: 8, weight: .medium, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(BattleStatsTheme.textLabel)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(BattleStatsTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(BattleStatsTheme.cardBorder, lineWidth: 1)
        }
        .accessibilityLabel("\(label), \(value)")
    }
}
