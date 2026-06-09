//
//  StatsSummaryScope.swift
//  FitUp
//
//  Top summary pill values for All Time vs This Month.
//

import Foundation

enum StatsSummaryPeriod: String, CaseIterable, Sendable {
    case thisMonth
    case allTime

    var pillLabel: String {
        switch self {
        case .thisMonth: return "This Month"
        case .allTime: return "All Time"
        }
    }
}

struct StatsSummaryPillDisplay: Equatable, Sendable {
    private static let unresolvedPlaceholder = "—"

    let record: String
    let winRate: String
    let streak: String
    let rivals: String

    var hasAnyResolvedMetric: Bool {
        record != Self.unresolvedPlaceholder
            || winRate != Self.unresolvedPlaceholder
            || streak != Self.unresolvedPlaceholder
    }
}

enum StatsSummaryPillBuilder {
    private static let unresolvedPlaceholder = "—"

    static func build(
        period: StatsSummaryPeriod,
        battleStats: HealthBattleStats,
        rivalStats: [HomeRivalStat],
        completedMatches: [ActivityCompletedMatch],
        profileTimeZoneIdentifier: String?,
        hasResolvedBattleStats: Bool
    ) -> StatsSummaryPillDisplay {
        switch period {
        case .allTime:
            return allTimeDisplay(
                battleStats: battleStats,
                rivalCount: rivalStats.count,
                hasResolvedBattleStats: hasResolvedBattleStats
            )
        case .thisMonth:
            return thisMonthDisplay(
                completedMatches: completedMatches,
                profileTimeZoneIdentifier: profileTimeZoneIdentifier
            )
        }
    }

    private static func allTimeDisplay(
        battleStats: HealthBattleStats,
        rivalCount: Int,
        hasResolvedBattleStats: Bool
    ) -> StatsSummaryPillDisplay {
        guard hasResolvedBattleStats, battleStats.matchesPlayed > 0 else {
            return unresolved()
        }

        let record: String = {
            if battleStats.ties > 0 {
                return "\(battleStats.wins)-\(battleStats.losses)-\(battleStats.ties)"
            }
            return "\(battleStats.wins)-\(battleStats.losses)"
        }()

        let winRate: String = {
            guard battleStats.wins + battleStats.losses > 0 else {
                return unresolvedPlaceholder
            }
            return "\(battleStats.winRate)%"
        }()

        let streak: String = {
            guard battleStats.currentStreakType == .win, battleStats.currentStreakCount > 0 else {
                return unresolvedPlaceholder
            }
            return "\(battleStats.currentStreakCount)W 🔥"
        }()

        return StatsSummaryPillDisplay(
            record: record,
            winRate: winRate,
            streak: streak,
            rivals: "\(rivalCount)"
        )
    }

    private static func thisMonthDisplay(
        completedMatches: [ActivityCompletedMatch],
        profileTimeZoneIdentifier: String?
    ) -> StatsSummaryPillDisplay {
        let tz = profileTimeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz

        let monthMatches = completedMatches.filter { match in
            guard let completedAt = match.completedAt else { return false }
            return calendar.isDate(completedAt, equalTo: Date(), toGranularity: .month)
        }

        guard !monthMatches.isEmpty else {
            return unresolved()
        }

        var wins = 0
        var losses = 0
        var ties = 0
        for match in monthMatches {
            switch matchOutcome(match) {
            case .win: wins += 1
            case .loss: losses += 1
            case .tie: ties += 1
            }
        }

        let record: String = {
            if ties > 0 { return "\(wins)-\(losses)-\(ties)" }
            return "\(wins)-\(losses)"
        }()

        let winRate: String = {
            guard wins + losses > 0 else { return unresolvedPlaceholder }
            let rate = Int((Double(wins) / Double(wins + losses) * 100).rounded())
            return "\(rate)%"
        }()

        let streak = "\(longestWinStreak(in: monthMatches))W"

        let rivals = Set(monthMatches.map(\.opponentProfileId)).count

        return StatsSummaryPillDisplay(
            record: record,
            winRate: winRate,
            streak: streak,
            rivals: "\(rivals)"
        )
    }

    private static func unresolved() -> StatsSummaryPillDisplay {
        StatsSummaryPillDisplay(
            record: unresolvedPlaceholder,
            winRate: unresolvedPlaceholder,
            streak: unresolvedPlaceholder,
            rivals: unresolvedPlaceholder
        )
    }

    private enum MatchOutcome {
        case win
        case loss
        case tie
    }

    private static func matchOutcome(_ match: ActivityCompletedMatch) -> MatchOutcome {
        if match.myScore > match.theirScore { return .win }
        if match.myScore < match.theirScore { return .loss }
        return .tie
    }

    /// Longest consecutive wins within the given matches (chronological).
    private static func longestWinStreak(in matches: [ActivityCompletedMatch]) -> Int {
        let sorted = matches.sorted {
            ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast)
        }
        var best = 0
        var current = 0
        for match in sorted {
            if matchOutcome(match) == .win {
                current += 1
                best = max(best, current)
            } else {
                current = 0
            }
        }
        return best
    }
}
