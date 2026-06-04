//
//  StatsPersonalRecords.swift
//  FitUp
//

import Foundation

struct StatsPersonalRecordRow: Equatable, Sendable, Identifiable {
    let id: String
    let icon: String
    let label: String
    let value: String
    let subtitle: String?
}

struct StatsPersonalRecords: Equatable, Sendable {
    let rows: [StatsPersonalRecordRow]

    var isEmpty: Bool { rows.isEmpty }

    static let empty = StatsPersonalRecords(rows: [])
}

enum StatsPersonalRecordsBuilder {
    static let recordsLookbackDays = 365

    static func longestMatchWinStreakCount(from matches: [ActivityCompletedMatch]) -> Int {
        longestMatchWinStreak(from: matches)?.count ?? 0
    }

    static func build(
        margins: [DailyBattleMargin],
        dailySteps: [String: Int],
        battleDateKeys: Set<String>,
        completedMatches: [ActivityCompletedMatch],
        profileTimeZoneIdentifier: String?
    ) -> StatsPersonalRecords {
        var rows: [StatsPersonalRecordRow] = []

        if let bestDay = bestBattleDay(dailySteps: dailySteps, battleDateKeys: battleDateKeys, timeZoneId: profileTimeZoneIdentifier) {
            rows.append(
                StatsPersonalRecordRow(
                    id: "best_day",
                    icon: "👑",
                    label: "Best Battle Day",
                    value: "\(bestDay.steps.formatted()) steps",
                    subtitle: bestDay.dateLabel
                )
            )
        }

        if let biggest = margins.filter({ $0.margin > 0 }).max(by: { $0.margin < $1.margin }) {
            rows.append(
                StatsPersonalRecordRow(
                    id: "biggest_win",
                    icon: "💥",
                    label: "Biggest Win Margin",
                    value: "+\(biggest.margin.formatted()) steps",
                    subtitle: formatDateKey(biggest.calendarDate, timeZoneId: profileTimeZoneIdentifier)
                )
            )
        }

        if let closest = margins.filter({ $0.margin > 0 }).min(by: { $0.margin < $1.margin }) {
            rows.append(
                StatsPersonalRecordRow(
                    id: "closest",
                    icon: "😬",
                    label: "Closest Battle",
                    value: "+\(closest.margin.formatted()) steps",
                    subtitle: formatDateKey(closest.calendarDate, timeZoneId: profileTimeZoneIdentifier)
                )
            )
        }

        if let streak = longestMatchWinStreak(from: completedMatches) {
            rows.append(
                StatsPersonalRecordRow(
                    id: "longest_streak",
                    icon: "🔥",
                    label: "Longest Win Streak",
                    value: "\(streak.count) wins",
                    subtitle: streak.rangeLabel
                )
            )
        }

        return StatsPersonalRecords(rows: rows)
    }

    private struct BestBattleDay {
        let steps: Int
        let dateLabel: String?
    }

    private static func bestBattleDay(
        dailySteps: [String: Int],
        battleDateKeys: Set<String>,
        timeZoneId: String?
    ) -> BestBattleDay? {
        let battleDays = dailySteps.filter { battleDateKeys.contains($0.key) }
        guard let best = battleDays.max(by: { $0.value < $1.value }), best.value > 0 else {
            return nil
        }
        return BestBattleDay(
            steps: best.value,
            dateLabel: formatDateKey(best.key, timeZoneId: timeZoneId)
        )
    }

    private struct WinStreakResult {
        let count: Int
        let rangeLabel: String?
    }

    private static func longestMatchWinStreak(from matches: [ActivityCompletedMatch]) -> WinStreakResult? {
        let sorted = matches.sorted {
            ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast)
        }
        guard !sorted.isEmpty else { return nil }

        var bestCount = 0
        var bestStart: Date?
        var bestEnd: Date?
        var currentCount = 0
        var currentStart: Date?

        for match in sorted {
            if match.myWon {
                if currentCount == 0 { currentStart = match.completedAt }
                currentCount += 1
                if currentCount > bestCount {
                    bestCount = currentCount
                    bestStart = currentStart
                    bestEnd = match.completedAt
                }
            } else {
                currentCount = 0
                currentStart = nil
            }
        }

        guard bestCount > 0 else { return nil }
        let rangeLabel = formatStreakRange(start: bestStart, end: bestEnd, timeZoneId: nil)
        return WinStreakResult(count: bestCount, rangeLabel: rangeLabel)
    }

    private static func formatDateKey(_ key: String, timeZoneId: String?) -> String? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2])
        else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        if let tzId = timeZoneId, let tz = TimeZone(identifier: tzId) {
            calendar.timeZone = tz
        }
        guard let date = calendar.date(from: DateComponents(year: y, month: m, day: d)) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "MMM d, yyyy"
        if let tzId = timeZoneId, let tz = TimeZone(identifier: tzId) {
            formatter.timeZone = tz
        }
        return formatter.string(from: date)
    }

    private static func formatStreakRange(start: Date?, end: Date?, timeZoneId: String?) -> String? {
        guard let start, let end else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "MMM yyyy"
        if let tzId = timeZoneId, let tz = TimeZone(identifier: tzId) {
            formatter.timeZone = tz
        }
        let startText = formatter.string(from: start)
        let endText = formatter.string(from: end)
        if startText == endText { return startText }
        return "\(startText) – \(endText)"
    }
}
