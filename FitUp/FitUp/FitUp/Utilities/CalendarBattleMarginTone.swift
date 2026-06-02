//
//  CalendarBattleMarginTone.swift
//  FitUp
//
//  Margin → neon tone for activity calendar battle day chips (aligned with HomeBattleMarginChart).
//

import SwiftUI

enum CalendarBattleMarginTone {
    private static let defaultCap: Double = 2_000

    /// Solid fill for a calendar day chip from signed step margin (you − closest rival).
    static func fillColor(margin: Int, cap: Double = defaultCap) -> Color {
        let t = normalizedT(margin: margin, cap: cap)
        if t >= 0.65 { return FitUpColors.Neon.green.opacity(0.88) }
        if t >= 0.35 { return FitUpColors.Neon.cyan.opacity(0.82) }
        if t >= 0.12 { return FitUpColors.Neon.blue.opacity(0.78) }
        if t > -0.12 { return FitUpColors.Neon.purple.opacity(0.55) }
        if t > -0.35 { return FitUpColors.Neon.orange.opacity(0.82) }
        if t > -0.65 { return FitUpColors.Neon.red.opacity(0.85) }
        return FitUpColors.Neon.red.opacity(0.92)
    }

    static func glowColor(margin: Int, cap: Double = defaultCap) -> Color {
        let t = normalizedT(margin: margin, cap: cap)
        if t >= 0.5 { return FitUpColors.Neon.green.opacity(0.45) }
        if t >= 0.15 { return FitUpColors.Neon.cyan.opacity(0.4) }
        if t > -0.15 { return FitUpColors.Neon.purple.opacity(0.28) }
        if t > -0.5 { return FitUpColors.Neon.orange.opacity(0.42) }
        return FitUpColors.Neon.red.opacity(0.48)
    }

    /// When margin RPC has no row, approximate from aggregated day outcome.
    static func approximateMargin(for state: CalendarDayBattleState) -> Int? {
        switch state {
        case .none: return nil
        case .voidOnly: return 0
        case .wonAny: return 900
        case .lostAll: return -900
        case .inProgress: return nil
        }
    }

    static func resolvedMargin(state: CalendarDayBattleState, marginByDate: Int?) -> Int? {
        if let marginByDate { return marginByDate }
        return approximateMargin(for: state)
    }

    private static func normalizedT(margin: Int, cap: Double) -> Double {
        let capValue = max(cap, 400)
        return max(-1, min(1, Double(margin) / capValue))
    }
}
