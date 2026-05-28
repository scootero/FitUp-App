//
//  CalendarMonthLayout.swift
//  FitUp
//
//  Builds a Monday-first grid for the activity calendar (leading prior-month days only; no trailing next-month row).
//

import Foundation

struct CalendarDayItem: Identifiable, Equatable, Sendable {
    let id: String
    let date: Date
    let dayNumber: Int
    let isWithinDisplayedMonth: Bool
    let isToday: Bool
}

enum CalendarMonthLayout {
    private static let daysPerWeek = 7

    static func gridItems(
        for displayedMonth: Date,
        profileTimeZoneIdentifier: String?
    ) -> [CalendarDayItem] {
        let tz = profileTimeZoneIdentifier.flatMap { TimeZone(identifier: $0) } ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        calendar.firstWeekday = 2

        let monthComponents = calendar.dateComponents([.year, .month], from: displayedMonth)
        guard let monthStart = calendar.date(from: monthComponents) else { return [] }
        guard let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else { return [] }

        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday - calendar.firstWeekday + daysPerWeek) % daysPerWeek
        guard let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart) else { return [] }

        let todayKey = HomeRepository.formatProfileCalendarDate(Date(), profileTimeZoneIdentifier: profileTimeZoneIdentifier)
        let displayedMonthKey = monthKey(for: monthStart, calendar: calendar)

        var items: [CalendarDayItem] = []
        var date = gridStart
        while date <= monthEnd {
            let dateKey = HomeRepository.formatProfileCalendarDate(date, profileTimeZoneIdentifier: profileTimeZoneIdentifier)
            let itemMonthKey = monthKey(for: date, calendar: calendar)
            items.append(
                CalendarDayItem(
                    id: dateKey,
                    date: date,
                    dayNumber: calendar.component(.day, from: date),
                    isWithinDisplayedMonth: itemMonthKey == displayedMonthKey,
                    isToday: dateKey == todayKey
                )
            )
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return items
    }

    static func monthTitle(for displayedMonth: Date, profileTimeZoneIdentifier: String?) -> String {
        let tz = profileTimeZoneIdentifier.flatMap { TimeZone(identifier: $0) } ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = tz
        formatter.locale = Locale.current
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: displayedMonth)
    }

    /// Short month name for calendar nav center label (e.g. "May", "April").
    static func monthShortTitle(for displayedMonth: Date, profileTimeZoneIdentifier: String?) -> String {
        let tz = profileTimeZoneIdentifier.flatMap { TimeZone(identifier: $0) } ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = tz
        formatter.locale = Locale.current
        formatter.dateFormat = "MMMM"
        return formatter.string(from: displayedMonth)
    }

    /// Inclusive `yyyy-MM-dd` keys for the visible grid (through last day of `displayedMonth`).
    static func gridDateKeyRange(
        for displayedMonth: Date,
        profileTimeZoneIdentifier: String?
    ) -> (start: String, end: String) {
        let items = gridItems(for: displayedMonth, profileTimeZoneIdentifier: profileTimeZoneIdentifier)
        guard let first = items.first, let last = items.last else {
            let key = HomeRepository.formatProfileCalendarDate(displayedMonth, profileTimeZoneIdentifier: profileTimeZoneIdentifier)
            return (key, key)
        }
        return (first.id, last.id)
    }

    static func startOfMonth(for date: Date, profileTimeZoneIdentifier: String?) -> Date {
        let tz = profileTimeZoneIdentifier.flatMap { TimeZone(identifier: $0) } ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? date
    }

    static func addMonths(_ delta: Int, to month: Date, profileTimeZoneIdentifier: String?) -> Date {
        let tz = profileTimeZoneIdentifier.flatMap { TimeZone(identifier: $0) } ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let start = startOfMonth(for: month, profileTimeZoneIdentifier: profileTimeZoneIdentifier)
        return calendar.date(byAdding: .month, value: delta, to: start) ?? start
    }

    private static func monthKey(for date: Date, calendar: Calendar) -> String {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return String(format: "%04d-%02d", year, month)
    }
}
