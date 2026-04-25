//
//  MatchDurationCopy.swift
//  FitUp
//
//  User-facing strings for match calendar length and “days to win” progress.
//

import Foundation

enum MatchDurationCopy {

    /// Short label for badges and pills (e.g. home card, pending row).
    static func competitionLengthBadge(days: Int) -> String {
        let d = max(days, 1)
        return "\(d)-day match"
    }

    /// Hero / Live Activity progress (e.g. "Day 2 of 3").
    static func dayProgress(current: Int, total: Int) -> String {
        let t = max(total, 1)
        let c = min(max(current, 1), t)
        return "Day \(c) of \(t)"
    }

    /// Under the series progress bar on match details.
    static func daysRemainingToWin(finalizedCount: Int, totalDays: Int) -> String {
        let total = max(totalDays, 1)
        let left = max(0, total - finalizedCount)
        if left == 0 { return "All days played" }
        if left == 1 { return "1 day left to win" }
        return "\(left) days left to win"
    }

    /// Stats row: days won vs competition length.
    static func daysWonFraction(won: Int, totalDays: Int) -> String {
        let t = max(totalDays, 1)
        let w = max(0, won)
        if w == 1 { return "1 of \(t) days won" }
        return "\(w) of \(t) days won"
    }
}
