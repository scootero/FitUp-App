//
//  BattlePhaseCopy.swift
//  FitUp
//
//  Shared user-facing strings for live / pending-finalization / match vs step score.
//

import Foundation

enum BattlePhaseCopy {
    static let pendingTitle = "Battle Complete"
    static let pendingSubtitle = "Finalizing Results"
    static let matchScoreCaption = "Match Score"
    static let stepScoreCaption = "Step Score"
    static let matchWinning = "YOU'RE WINNING"
    static let matchLosing = "YOU'RE LOSING"
    static let matchTied = "TIED"

    static func matchScoreLine(myScore: Int, theirScore: Int) -> String {
        "\(myScore) - \(theirScore)"
    }

    static func matchScorePrefixed(myScore: Int, theirScore: Int) -> String {
        "Match Score: \(matchScoreLine(myScore: myScore, theirScore: theirScore))"
    }
}

enum BattleDateRangeFormatting {
    /// `Duration: 1 Day (5/28)` or `Duration: 3 Days (5/25 - 5/28)` in profile TZ.
    static func label(
        durationDays: Int,
        startDateKey: String?,
        endDateKey: String?,
        timeZone: TimeZone?
    ) -> String {
        let days = max(durationDays, 1)
        let tz = timeZone ?? .current
        guard let endKey = endDateKey, let endDate = parseDateKey(endKey, timeZone: tz) else {
            return "Duration: \(days) Day\(days == 1 ? "" : "s")"
        }
        let endFormatted = shortMonthDay(endDate, timeZone: tz)
        if days <= 1 {
            return "Duration: 1 Day (\(endFormatted))"
        }
        if let startKey = startDateKey, let startDate = parseDateKey(startKey, timeZone: tz) {
            let startFormatted = shortMonthDay(startDate, timeZone: tz)
            return "Duration: \(days) Days (\(startFormatted) - \(endFormatted))"
        }
        return "Duration: \(days) Days (\(endFormatted))"
    }

    private static func parseDateKey(_ key: String, timeZone: TimeZone) -> Date? {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        return formatter.date(from: key)
    }

    private static func shortMonthDay(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    static func profileTodayKey(timeZoneIdentifier: String?, now: Date = Date()) -> String {
        var calendar = Calendar(identifier: .gregorian)
        if let timeZoneIdentifier, let tz = TimeZone(identifier: timeZoneIdentifier) {
            calendar.timeZone = tz
        } else {
            calendar.timeZone = .current
        }
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func calendarDateKey(from date: Date, timeZoneIdentifier: String?) -> String {
        let tz = timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// 10:00 local on the calendar day after `calendar_date` (matches server `day_cutoff_check`).
    static func finalizationCutoff(calendarDateKey: String, timeZoneIdentifier: String?) -> Date? {
        let tz = timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = tz
        guard let dayStart = formatter.date(from: calendarDateKey) else { return nil }
        guard let nextDayStart = cal.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        return cal.date(bySettingHour: 10, minute: 0, second: 0, of: nextDayStart)
    }
}
