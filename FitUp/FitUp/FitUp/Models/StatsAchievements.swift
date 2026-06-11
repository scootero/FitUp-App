//
//  StatsAchievements.swift
//  FitUp
//

import Foundation

enum StatsAchievementPlacement: Sendable {
    case featured
    case overflow
}

enum StatsAchievementKind: String, CaseIterable, Sendable {
    case firstBlood
    case fiveWinStreak
    case upsetVictory
    case dominator
    case nightWalker
    case champion
    case morningWalker
    case photoFinish
    case ironVeteran
    case stepCrusher
    case bounceBack
    case perfectWeek
    case marathonMatch
    case rivalSlayer
    case socialButterfly

    var placement: StatsAchievementPlacement {
        switch self {
        case .firstBlood, .fiveWinStreak, .upsetVictory, .dominator, .nightWalker, .champion:
            return .featured
        case .morningWalker, .photoFinish, .ironVeteran, .stepCrusher,
             .bounceBack, .perfectWeek, .marathonMatch, .rivalSlayer, .socialButterfly:
            return .overflow
        }
    }

    var title: String {
        switch self {
        case .firstBlood: return "First Blood"
        case .fiveWinStreak: return "5-Win Streak"
        case .upsetVictory: return "Upset Victory"
        case .dominator: return "Dominator"
        case .nightWalker: return "Night Walker"
        case .champion: return "Champion"
        case .morningWalker: return "Morning Walker"
        case .photoFinish: return "Photo Finish"
        case .ironVeteran: return "Iron Veteran"
        case .stepCrusher: return "Step Crusher"
        case .bounceBack: return "Bounce Back"
        case .perfectWeek: return "Perfect Week"
        case .marathonMatch: return "Marathon Match"
        case .rivalSlayer: return "Rival Slayer"
        case .socialButterfly: return "Social Butterfly"
        }
    }

    var icon: String {
        switch self {
        case .firstBlood: return "⚡"
        case .fiveWinStreak: return "🔥"
        case .upsetVictory: return "😤"
        case .dominator: return "💀"
        case .nightWalker: return "🌙"
        case .champion: return "🏆"
        case .morningWalker: return "🌅"
        case .photoFinish: return "📸"
        case .ironVeteran: return "🛡️"
        case .stepCrusher: return "👟"
        case .bounceBack: return "🩹"
        case .perfectWeek: return "✨"
        case .marathonMatch: return "🏃"
        case .rivalSlayer: return "⚔️"
        case .socialButterfly: return "🦋"
        }
    }
}

struct StatsAchievementItem: Equatable, Sendable, Identifiable {
    let kind: StatsAchievementKind
    let isUnlocked: Bool
    let multiplier: Int?

    var id: String { kind.rawValue }
    var placement: StatsAchievementPlacement { kind.placement }
}

enum StatsAchievementCatalog {
    static let dominatorMarginThreshold = 5_000
    static let championWinThreshold = 10
    static let streakThreshold = 5
    static let nightWalkerStepThreshold = 2_500
    static let morningWalkerStepThreshold = 1_500
    static let photoFinishMarginThreshold = 500
    static let ironVeteranMatchThreshold = 10
    static let stepCrusherStepThreshold = 20_000
    static let hourlyBattleAchievementMaxDaysToScan = 40
    static let rivalSlayerWinThreshold = 3
    static let socialButterflyFriendThreshold = 5
    static let perfectWeekMinBattleDays = 3
    static let marathonMatchMinDays = 7

    static func allItems(
        battleStats: HealthBattleStats = .empty,
        longestMatchWinStreak: Int = 0,
        dominatorDayCount: Int = 0,
        hasUpsetVictory: Bool = false,
        hasNightWalker: Bool = false,
        hasMorningWalker: Bool = false,
        hasPhotoFinish: Bool = false,
        hasStepCrusher: Bool = false,
        hasBounceBack: Bool = false,
        hasPerfectWeek: Bool = false,
        hasMarathonMatch: Bool = false,
        hasRivalSlayer: Bool = false,
        hasSocialButterfly: Bool = false
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
                kind: .upsetVictory,
                isUnlocked: hasUpsetVictory,
                multiplier: nil
            ),
            StatsAchievementItem(
                kind: .dominator,
                isUnlocked: dominatorDayCount >= 1,
                multiplier: dominatorDayCount > 1 ? dominatorDayCount : nil
            ),
            StatsAchievementItem(
                kind: .nightWalker,
                isUnlocked: hasNightWalker,
                multiplier: nil
            ),
            StatsAchievementItem(
                kind: .champion,
                isUnlocked: battleStats.wins >= championWinThreshold,
                multiplier: nil
            ),
            StatsAchievementItem(
                kind: .morningWalker,
                isUnlocked: hasMorningWalker,
                multiplier: nil
            ),
            StatsAchievementItem(
                kind: .photoFinish,
                isUnlocked: hasPhotoFinish,
                multiplier: nil
            ),
            StatsAchievementItem(
                kind: .ironVeteran,
                isUnlocked: battleStats.matchesPlayed >= ironVeteranMatchThreshold,
                multiplier: nil
            ),
            StatsAchievementItem(
                kind: .stepCrusher,
                isUnlocked: hasStepCrusher,
                multiplier: nil
            ),
            StatsAchievementItem(
                kind: .bounceBack,
                isUnlocked: hasBounceBack,
                multiplier: nil
            ),
            StatsAchievementItem(
                kind: .perfectWeek,
                isUnlocked: hasPerfectWeek,
                multiplier: nil
            ),
            StatsAchievementItem(
                kind: .marathonMatch,
                isUnlocked: hasMarathonMatch,
                multiplier: nil
            ),
            StatsAchievementItem(
                kind: .rivalSlayer,
                isUnlocked: hasRivalSlayer,
                multiplier: nil
            ),
            StatsAchievementItem(
                kind: .socialButterfly,
                isUnlocked: hasSocialButterfly,
                multiplier: nil
            ),
        ]
    }

    static func featuredItems(from items: [StatsAchievementItem]) -> [StatsAchievementItem] {
        items.filter { $0.placement == .featured }
    }

    static func overflowItems(from items: [StatsAchievementItem]) -> [StatsAchievementItem] {
        items.filter { $0.placement == .overflow }
    }

    static func dominatorDayCount(margins: [DailyBattleMargin]) -> Int {
        margins.filter { $0.margin >= dominatorMarginThreshold }.count
    }

    /// Won a multi-day series by exactly one day (e.g. 4–3, 7–6).
    static func hasUpsetVictory(from matches: [ActivityCompletedMatch]) -> Bool {
        matches.contains { match in
            match.myWon
                && match.durationDays >= 2
                && (match.myScore - match.theirScore) == 1
        }
    }

    static func hasPhotoFinish(margins: [DailyBattleMargin]) -> Bool {
        margins.contains { margin in
            margin.margin > 0 && margin.margin < photoFinishMarginThreshold
        }
    }

    static func hasStepCrusher(
        dailySteps: [String: Int],
        battleDateKeys: Set<String>
    ) -> Bool {
        battleDateKeys.contains { key in
            (dailySteps[key] ?? 0) >= stepCrusherStepThreshold
        }
    }

    /// Won a completed match immediately after a loss.
    static func hasBounceBack(from matches: [ActivityCompletedMatch]) -> Bool {
        let sorted = matches.sorted {
            ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast)
        }
        guard sorted.count >= 2 else { return false }
        for index in 1..<sorted.count {
            if sorted[index].myWon, !sorted[index - 1].myWon {
                return true
            }
        }
        return false
    }

    /// Every battle day in a calendar week was a win (minimum three battle days).
    static func hasPerfectWeek(margins: [DailyBattleMargin], calendar: Calendar) -> Bool {
        struct WeekKey: Hashable {
            let year: Int
            let week: Int
        }

        var formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = calendar.timeZone

        var marginsByWeek: [WeekKey: [DailyBattleMargin]] = [:]
        for margin in margins {
            guard let date = formatter.date(from: margin.calendarDate) else { continue }
            let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            guard let year = components.yearForWeekOfYear, let week = components.weekOfYear else { continue }
            let key = WeekKey(year: year, week: week)
            marginsByWeek[key, default: []].append(margin)
        }

        return marginsByWeek.values.contains { weekMargins in
            weekMargins.count >= perfectWeekMinBattleDays
                && weekMargins.allSatisfy { $0.margin > 0 }
        }
    }

    /// Won a series that lasted at least seven days.
    static func hasMarathonMatch(from matches: [ActivityCompletedMatch]) -> Bool {
        matches.contains { $0.myWon && $0.durationDays >= marathonMatchMinDays }
    }

    /// Beat the same opponent in three or more completed matches.
    static func hasRivalSlayer(from matches: [ActivityCompletedMatch]) -> Bool {
        var winsByOpponent: [UUID: Int] = [:]
        for match in matches where match.myWon {
            let wins = winsByOpponent[match.opponentProfileId, default: 0] + 1
            winsByOpponent[match.opponentProfileId] = wins
            if wins >= rivalSlayerWinThreshold {
                return true
            }
        }
        return false
    }

    /// More than five accepted friends.
    static func hasSocialButterfly(acceptedFriendCount: Int) -> Bool {
        acceptedFriendCount > socialButterflyFriendThreshold
    }

    static func nightSteps(from hourlyBuckets: [HealthIntradayHourlyBucket], calendar: Calendar) -> Int {
        hourlyBuckets.reduce(0) { total, bucket in
            let hour = calendar.component(.hour, from: bucket.hourStart)
            let isNightHour = hour >= 21 || hour < 5
            return total + (isNightHour ? bucket.value : 0)
        }
    }

    /// Steps logged before 9:00 AM local on a battle day.
    static func morningSteps(from hourlyBuckets: [HealthIntradayHourlyBucket], calendar: Calendar) -> Int {
        hourlyBuckets.reduce(0) { total, bucket in
            let hour = calendar.component(.hour, from: bucket.hourStart)
            return total + (hour < 9 ? bucket.value : 0)
        }
    }
}
