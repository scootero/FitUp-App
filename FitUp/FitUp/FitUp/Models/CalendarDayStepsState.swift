//
//  CalendarDayStepsState.swift
//  FitUp
//
//  Per-calendar-date step progress for the activity calendar (Steps mode).
//

import Foundation

struct CalendarDayStepsState: Equatable, Sendable {
    let steps: Int
    let stepsGoal: Int

    var progress: Double {
        guard stepsGoal > 0 else { return 0 }
        return min(Double(steps) / Double(stepsGoal), 1)
    }

    var goalMet: Bool {
        stepsGoal > 0 && steps >= stepsGoal
    }

    /// Compact label for the ring center (`8.2k`, `12k`, or raw count).
    var abbreviatedStepsLabel: String {
        Self.abbreviate(steps: steps)
    }

    /// Tighter abbreviation for small calendar day rings (k from 1,000+).
    var calendarRingStepsLabel: String {
        Self.abbreviateForCalendarRing(steps: steps)
    }

    static func abbreviate(steps: Int) -> String {
        if steps < 10_000 {
            return "\(steps)"
        }
        let thousands = Double(steps) / 1000
        if steps >= 100_000 {
            return String(format: "%.0fk", thousands)
        }
        let formatted = String(format: "%.1fk", thousands)
        if formatted.hasSuffix(".0k") {
            return String(format: "%.0fk", thousands)
        }
        return formatted
    }

    static func abbreviateForCalendarRing(steps: Int) -> String {
        if steps < 1_000 {
            return "\(steps)"
        }
        let thousands = Double(steps) / 1000
        if steps >= 100_000 {
            return String(format: "%.0fk", thousands)
        }
        let formatted = String(format: "%.1fk", thousands)
        if formatted.hasSuffix(".0k") {
            return String(format: "%.0fk", thousands)
        }
        return formatted
    }
}
