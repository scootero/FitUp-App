//
//  MatchDetailDisplayModel+BattlePhase.swift
//  FitUp
//
//  Pending finalization and match-score copy for Match Details.
//

import SwiftUI

extension MatchDetailDisplayModel {
    var isPendingFinalization: Bool {
        guard snapshot.state == .active else { return false }
        let hasUnfinalized = mergedDayRows.contains { !$0.isFinalized }
        guard hasUnfinalized else { return false }

        let todayKey = BattleDateRangeFormatting.profileTodayKey(timeZoneIdentifier: matchTimezone)
        let endKey = mergedDayRows
            .compactMap { row -> String? in
                guard let date = row.calendarDate else { return nil }
                return BattleDateRangeFormatting.calendarDateKey(from: date, timeZoneIdentifier: matchTimezone)
            }
            .sorted()
            .last

        if let endKey, endKey < todayKey {
            return true
        }
        return false
    }

    var battleDateRangeLabel: String {
        let keys = mergedDayRows
            .compactMap { row -> String? in
                guard let date = row.calendarDate else { return nil }
                return BattleDateRangeFormatting.calendarDateKey(from: date, timeZoneIdentifier: matchTimezone)
            }
            .sorted()
        return BattleDateRangeFormatting.label(
            durationDays: snapshot.durationDays,
            startDateKey: keys.first,
            endDateKey: keys.last,
            timeZone: TimeZone(identifier: matchTimezone)
        )
    }

    var matchScoreText: String {
        BattlePhaseCopy.matchScoreLine(myScore: snapshot.myScore, theirScore: snapshot.theirScore)
    }

    var matchScoreMargin: Int {
        snapshot.myScore - snapshot.theirScore
    }

    var matchStatusLabel: String {
        let margin = matchScoreMargin
        if margin > 0 { return BattlePhaseCopy.matchWinning }
        if margin < 0 { return BattlePhaseCopy.matchLosing }
        return BattlePhaseCopy.matchTied
    }

    var matchStatusColor: Color {
        let margin = matchScoreMargin
        if margin > 0 { return FitUpColors.Neon.green }
        if margin < 0 { return FitUpColors.Neon.orange }
        return FitUpColors.Text.secondary
    }

    /// Label for the step totals row when the battle day has ended but scores are not final yet.
    var stepsPeriodLabel: String {
        isPendingFinalization ? "Yesterday's steps" : "Steps today"
    }
}
