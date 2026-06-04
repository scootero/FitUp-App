//
//  StatsAchievements.swift
//  FitUp
//

import Foundation

enum StatsAchievementKind: String, CaseIterable, Sendable {
    case firstBlood
    case fiveWinStreak
    case dominator
    case champion

    var title: String {
        switch self {
        case .firstBlood: return "First Blood"
        case .fiveWinStreak: return "5-Win Streak"
        case .dominator: return "Dominator"
        case .champion: return "Champion"
        }
    }

    var icon: String {
        switch self {
        case .firstBlood: return "⚡"
        case .fiveWinStreak: return "🔥"
        case .dominator: return "💀"
        case .champion: return "🏆"
        }
    }
}

struct StatsAchievementItem: Equatable, Sendable, Identifiable {
    let kind: StatsAchievementKind
    let isUnlocked: Bool
    let multiplier: Int?

    var id: String { kind.rawValue }
}

enum StatsAchievementCatalog {
    static let dominatorMarginThreshold = 5_000
    static let championWinThreshold = 10
    static let streakThreshold = 5

    static func allItems(
        battleStats: HealthBattleStats = .empty,
        longestMatchWinStreak: Int = 0,
        dominatorDayCount: Int = 0
    ) -> [StatsAchievementItem] {
        let currentWinStreak = battleStats.currentStreakType == .win ? battleStats.currentStreakCount : 0
        let effectiveStreak = max(currentWinStreak, longestMatchWinStreak)

        return [
            StatsAchievementItem(
                kind: .firstBlood,
                isUnlocked: battleStats.wins >= 1,
                multiplier: nil
            ),
            StatsAchievementItem(
                kind: .fiveWinStreak,
                isUnlocked: effectiveStreak >= streakThreshold,
                multiplier: effectiveStreak >= streakThreshold ? max(1, effectiveStreak / streakThreshold) : nil
            ),
            StatsAchievementItem(
                kind: .dominator,
                isUnlocked: dominatorDayCount >= 1,
                multiplier: dominatorDayCount > 1 ? dominatorDayCount : nil
            ),
            StatsAchievementItem(
                kind: .champion,
                isUnlocked: battleStats.wins >= championWinThreshold,
                multiplier: nil
            ),
        ]
    }

    /// Grid includes locked slots for deferred achievements (Upset, Night Walker) as disabled placeholders — omitted per plan.
    static func displayGrid(from items: [StatsAchievementItem]) -> [StatsAchievementItem] {
        items
    }

    static func dominatorDayCount(margins: [DailyBattleMargin]) -> Int {
        margins.filter { $0.margin >= dominatorMarginThreshold }.count
    }
}
