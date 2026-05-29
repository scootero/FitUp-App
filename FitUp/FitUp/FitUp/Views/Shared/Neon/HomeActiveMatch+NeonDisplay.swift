//
//  HomeActiveMatch+NeonDisplay.swift
//  FitUp
//
//  Display-only copy for neon Active Battles rows (real HomeActiveMatch fields only).
//

import SwiftUI

extension HomeActiveMatch {
    var neonCardAccentColor: Color {
        if isPendingFinalization {
            return FitUpColors.Neon.yellow.opacity(0.85)
        }
        return matchStatusColor
    }

    var neonLiveCardAccentColor: Color {
        let m = comparableMargin
        if m > 0 { return FitUpColors.Neon.green }
        if m < 0 { return FitUpColors.Neon.red }
        return FitUpColors.Text.secondary
    }

    var neonDayScoreText: String {
        comparableMyScore.formatted()
    }

    var neonCurrentCompetitionDay: Int {
        if let todayPip = dayPips.first(where: { $0.state == .today }) {
            return todayPip.dayNumber
        }
        let finalized = dayPips.filter { $0.state == .won || $0.state == .lost }.count
        return min(max(finalized + 1, 1), max(durationDays, 1))
    }

    var neonDayProgressText: String {
        MatchDurationCopy.dayProgressWithWinsTarget(
            current: neonCurrentCompetitionDay,
            totalDays: durationDays
        )
    }

    var neonComparableMarginText: String {
        let m = comparableMargin
        let sign = m >= 0 ? "+" : "−"
        return "\(sign)\(abs(m).formatted())"
    }

    var neonStepDifferenceNowText: String {
        "Step Difference Now: \(neonComparableMarginText)"
    }

    var neonComparableMarginColor: Color {
        neonCardAccentColor
    }

    /// Centered hero progress (e.g. "Day 3 of 3") for the energy beam card header.
    var neonHeroDayProgressLabel: String {
        MatchDurationCopy.dayProgress(current: neonCurrentCompetitionDay, total: durationDays)
    }

    func neonHeroMatchHeaderContent(userDisplayName: String) -> NeonHeroMatchHeaderContent {
        let trimmedUser = userDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOpponent = opponent.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return NeonHeroMatchHeaderContent(
            userDisplayName: trimmedUser.isEmpty ? "You" : trimmedUser,
            opponentDisplayName: trimmedOpponent.isEmpty ? opponent.initials : trimmedOpponent,
            pills: [],
            dayProgressLabel: neonHeroDayProgressLabel,
            battleDateRangeLabel: battleDateRangeLabel,
            matchStatusLabel: matchStatusLabel,
            matchScoreText: matchScoreText,
            matchStatusColor: matchStatusColor
        )
    }
}

enum ActiveBattleRowFormatting {
    static func avatarAccent(for index: Int) -> Color {
        let palette: [Color] = [
            FitUpColors.Neon.pink,
            FitUpColors.Neon.purple,
            FitUpColors.Neon.cyan,
            FitUpColors.Neon.blue,
        ]
        return palette[index % palette.count]
    }
}
