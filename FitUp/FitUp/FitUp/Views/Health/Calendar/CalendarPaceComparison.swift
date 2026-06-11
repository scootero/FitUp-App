//
//  CalendarPaceComparison.swift
//  FitUp
//
//  Pace-adjusted step comparison vs rolling 7D / 30D averages for the activity calendar chip.
//

import SwiftUI

enum CalendarPaceZone: Equatable {
    case ahead
    case behindMild
    case behindSevere
}

struct CalendarPaceDisplay: Equatable {
    let pct7: Int
    let pct30: Int
    let zone: CalendarPaceZone
    let statusLabel: String
    let worstDelta: Int

    func percentGradient(for pct: Int) -> [Color] {
        if pct >= 15 {
            return [FitUpColors.Neon.green, FitUpColors.Neon.cyan]
        }
        if pct >= 0 {
            return [FitUpColors.Neon.cyan, FitUpColors.Neon.blue]
        }
        if pct > -20 {
            return [FitUpColors.Neon.yellow, FitUpColors.Neon.orange]
        }
        return [FitUpColors.Neon.orange, FitUpColors.Neon.pink, FitUpColors.Neon.purple]
    }

    var fillGradientColors: [Color] {
        switch zone {
        case .ahead:
            return [
                FitUpColors.Neon.green.opacity(0.22),
                FitUpColors.Neon.cyan.opacity(0.18),
                FitUpColors.Neon.blue.opacity(0.14),
                FitUpColors.Neon.purple.opacity(0.1),
            ]
        case .behindMild:
            return [
                FitUpColors.Neon.orange.opacity(0.2),
                FitUpColors.Neon.yellow.opacity(0.15),
                FitUpColors.Neon.pink.opacity(0.12),
                FitUpColors.Neon.cyan.opacity(0.08),
            ]
        case .behindSevere:
            return [
                FitUpColors.Neon.orange.opacity(0.22),
                FitUpColors.Neon.pink.opacity(0.16),
                FitUpColors.Neon.purple.opacity(0.14),
                FitUpColors.Neon.blue.opacity(0.1),
            ]
        }
    }

    var borderGradientColors: [Color] {
        switch zone {
        case .ahead:
            return [FitUpColors.Neon.green, FitUpColors.Neon.cyan, FitUpColors.Neon.blue]
        case .behindMild:
            return [FitUpColors.Neon.orange, FitUpColors.Neon.yellow, FitUpColors.Neon.pink]
        case .behindSevere:
            return [FitUpColors.Neon.orange, FitUpColors.Neon.pink, FitUpColors.Neon.purple]
        }
    }

    var statusGradientColors: [Color] {
        switch zone {
        case .ahead:
            return [FitUpColors.Neon.green, FitUpColors.Neon.cyan]
        case .behindMild:
            return [FitUpColors.Neon.yellow, FitUpColors.Neon.orange]
        case .behindSevere:
            return [FitUpColors.Neon.orange, FitUpColors.Neon.pink]
        }
    }

    func statusGradientColors(for pct: Int) -> [Color] {
        if pct >= 15 {
            return [FitUpColors.Neon.green, FitUpColors.Neon.cyan]
        }
        if pct >= 0 {
            return [FitUpColors.Neon.cyan, FitUpColors.Neon.blue]
        }
        if pct > -20 {
            return [FitUpColors.Neon.yellow, FitUpColors.Neon.orange]
        }
        return [FitUpColors.Neon.orange, FitUpColors.Neon.pink]
    }

    var glowColor: Color {
        switch zone {
        case .ahead: return FitUpColors.Neon.cyan
        case .behindMild: return FitUpColors.Neon.orange
        case .behindSevere: return FitUpColors.Neon.pink
        }
    }
}

enum CalendarPaceComparison {
    static func make(
        todaySteps: Int,
        avg7: Double,
        avg30: Double,
        profileTimeZoneIdentifier: String?,
        referenceDate: Date = Date()
    ) -> CalendarPaceDisplay? {
        guard avg7 > 0, avg30 > 0 else { return nil }

        let tz = profileTimeZoneIdentifier.flatMap { TimeZone(identifier: $0) } ?? .current
        let fraction = dayProgressFraction(at: referenceDate, timeZone: tz)
        let expected7 = avg7 * fraction
        let expected30 = avg30 * fraction
        guard expected7 > 0, expected30 > 0 else { return nil }

        let pct7 = percentDelta(actual: todaySteps, expected: expected7)
        let pct30 = percentDelta(actual: todaySteps, expected: expected30)
        let worst = min(pct7, pct30)

        let zone: CalendarPaceZone
        if pct7 >= 0, pct30 >= 0 {
            zone = .ahead
        } else if worst > -20 {
            zone = .behindMild
        } else {
            zone = .behindSevere
        }

        let statusLabel: String
        switch zone {
        case .ahead:
            statusLabel = max(pct7, pct30) >= 15 ? "ON FIRE" : "HEATING UP"
        case .behindMild:
            statusLabel = "OFF PACE"
        case .behindSevere:
            statusLabel = "LAGGING"
        }

        return CalendarPaceDisplay(
            pct7: pct7,
            pct30: pct30,
            zone: zone,
            statusLabel: statusLabel,
            worstDelta: worst
        )
    }

    static func dayProgressFraction(at date: Date, timeZone: TimeZone) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: date)
        let elapsed = date.timeIntervalSince(start)
        let dayLength: TimeInterval = 24 * 60 * 60
        return min(max(elapsed / dayLength, 0.02), 1.0)
    }

    private static func percentDelta(actual: Int, expected: Double) -> Int {
        let delta = (Double(actual) / expected - 1) * 100
        return Int(delta.rounded())
    }

    static func formattedPercent(_ value: Int) -> String {
        if value > 0 { return "+\(value)%" }
        return "\(value)%"
    }

    static func columnStatusLabel(for pct: Int, window: PaceWindow) -> String {
        switch window {
        case .sevenDay:
            if pct >= 15 { return "Your last week self can't keep up!" }
            if pct >= 0 { return "You're beating your last week self!" }
            if pct > -20 { return "Your last week self is kicking your butt!" }
            return "You're literally losing to your average self.. 👎"
        case .thirtyDay:
            if pct >= 15 { return "Your last month self can't keep up!" }
            if pct >= 0 { return "You're beating your last month self!" }
            if pct > -20 { return "Your last month self is kicking your butt!" }
            return "You're literally losing to your average self.. 👎"
        }
    }

    enum PaceWindow {
        case sevenDay
        case thirtyDay

        var columnHeader: String {
            switch self {
            case .sevenDay:
                return "Today's steps VS\nseven day average"
            case .thirtyDay:
                return "Today's steps VS\n30 day average"
            }
        }
    }

    static let infoTitle = "Step pace vs your averages"
    static let infoBody =
        "Compares your steps so far today with where you'd normally be by this time of day, based on your rolling 7- and 30-day averages.\n\n" +
        "To build momentum, stay ahead of your 7-day pace—a positive number is good, and the higher the better. " +
        "Consistent days ahead will gradually lift your 30-day average too."
}

struct CalendarPaceChipInputs: Equatable {
    let todaySteps: Int
    let avg7: Double
    let avg30: Double
    let profileTimeZoneIdentifier: String?
}
