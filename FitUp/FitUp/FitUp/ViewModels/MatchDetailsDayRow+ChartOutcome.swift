//
//  MatchDetailsDayRow+ChartOutcome.swift
//  FitUp
//

import Foundation

enum MatchDayChartOutcome: Equatable {
    case won
    case lost
    case tie
}

extension MatchDetailsDayRow {
    /// True when we can show Won/Lost/Tie chrome (finalized or both players have day totals).
    var showsDayOutcomeChrome: Bool {
        if isFuture { return false }
        if isToday && !isFinalized { return false }
        if isFinalized { return true }
        return !isToday && myValue > 0 && theirValue > 0
    }

    var chartOutcome: MatchDayChartOutcome? {
        guard showsDayOutcomeChrome else { return nil }
        if isTie { return .tie }
        if isFinalized {
            if myWon == true { return .won }
            if myWon == false { return .lost }
            if myValue == theirValue { return .tie }
            return nil
        }
        if myValue > theirValue { return .won }
        if myValue < theirValue { return .lost }
        return .tie
    }
}

enum RelativeSyncLabel {
    static func shortAgo(since date: Date?) -> String? {
        guard let date else { return nil }
        let sec = max(0, Int(Date().timeIntervalSince(date)))
        if sec < 60 { return "just now" }
        let min = sec / 60
        if min < 60 { return "\(min)m ago" }
        let hours = min / 60
        if hours < 24 { return "\(hours)h ago" }
        let days = hours / 24
        return "\(days)d ago"
    }
}
