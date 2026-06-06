//
//  CalendarBattleDayIndicator.swift
//  FitUp
//
//  Maps calendar battle summaries to ring indicator style (ghost, live, W/L/T, mixed).
//

import SwiftUI

enum CalendarBattleDayIndicatorStyle: Equatable, Sendable {
    case ghost
    case live(trimProgress: Double, label: String)
    case filled(label: String, fillColor: Color, glowColor: Color)
}

enum CalendarBattleDayIndicator {
    private static let marginCap: Double = 2_000

    static func resolve(summary: CalendarDayBattleSummary, margin: Int?) -> CalendarBattleDayIndicatorStyle {
        if summary.matchCount == 0 || summary.state == .none {
            return .ghost
        }

        if summary.state == .inProgress {
            return .live(trimProgress: 0.55, label: "LIVE")
        }

        let label = completedLabel(for: summary)
        let colors = completedColors(for: summary)
        return .filled(label: label, fillColor: colors.fill, glowColor: colors.glow)
    }

    static func liveLabel(margin: Int?) -> String {
        guard let margin else { return "LIVE" }
        if margin > 0 { return "+\(margin)" }
        if margin < 0 { return "\(margin)" }
        return "LIVE"
    }

    static func liveTrimProgress(margin: Int?) -> Double {
        guard let margin else { return 0.55 }
        let cap = max(marginCap, 400)
        let normalized = max(-1, min(1, Double(margin) / cap))
        return 0.35 + abs(normalized) * 0.45
    }

    private static func completedLabel(for summary: CalendarDayBattleSummary) -> String {
        if summary.matchCount == 1 {
            if summary.wins == 1 { return "W" }
            if summary.losses == 1 { return "L" }
            return "T"
        }

        if summary.losses == 0, summary.wins > 0 { return "W" }
        if summary.wins == 0, summary.losses > 0 { return "L" }
        if summary.wins == 0, summary.losses == 0 { return "T" }

        let net = summary.netScore
        if net > 0 { return "+\(net)" }
        if net < 0 { return "\(net)" }
        return "T"
    }

    private static func completedColors(for summary: CalendarDayBattleSummary) -> (fill: Color, glow: Color) {
        if summary.matchCount == 1 {
            if summary.wins == 1 {
                return (FitUpColors.Neon.green.opacity(0.88), FitUpColors.Neon.green.opacity(0.45))
            }
            if summary.losses == 1 {
                return (FitUpColors.Neon.red.opacity(0.88), FitUpColors.Neon.red.opacity(0.45))
            }
            return (Color.white.opacity(0.28), Color.white.opacity(0.12))
        }

        if summary.losses == 0, summary.wins > 0 {
            return (FitUpColors.Neon.green.opacity(0.88), FitUpColors.Neon.green.opacity(0.45))
        }
        if summary.wins == 0, summary.losses > 0 {
            return (FitUpColors.Neon.red.opacity(0.88), FitUpColors.Neon.red.opacity(0.45))
        }
        if summary.wins == 0, summary.losses == 0 {
            return (Color.white.opacity(0.28), Color.white.opacity(0.12))
        }

        let net = summary.netScore
        if net > 0 {
            return (FitUpColors.Neon.cyan.opacity(0.82), FitUpColors.Neon.cyan.opacity(0.4))
        }
        if net < 0 {
            return (FitUpColors.Neon.orange.opacity(0.82), FitUpColors.Neon.orange.opacity(0.42))
        }
        return (Color.white.opacity(0.28), Color.white.opacity(0.12))
    }
}
