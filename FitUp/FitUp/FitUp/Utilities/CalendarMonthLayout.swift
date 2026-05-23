//
//  CalendarMonthLayout.swift
//  FitUp
//
//  Builds a 6-week Monday-first grid for the activity calendar.
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
    private static let gridWeekCount = 6
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

        let weekday = calendar.component(.weekday, from: monthStart)
        let leading = (weekday - calendar.firstWeekday + daysPerWeek) % daysPerWeek
        guard let gridStart = calendar.date(byAdding: .day, value: -leading, to: monthStart) else { return [] }

        let todayKey = HomeRepository.formatProfileCalendarDate(Date(), profileTimeZoneIdentifier: profileTimeZoneIdentifier)
        let displayedMonthKey = monthKey(for: monthStart, calendar: calendar)

        var items: [CalendarDayItem] = []
        items.reserveCapacity(gridWeekCount * daysPerWeek)

        for offset in 0..<(gridWeekCount * daysPerWeek) {
            guard let date = calendar.date(byAdding: .day, value: offset, to: gridStart) else { continue }
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

    /// Inclusive `yyyy-MM-dd` keys for the 6-week grid containing `displayedMonth`.
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
