//
//  StatsArcadeMetrics.swift
//  FitUp
//
//  Slice 3B: derived metrics for Stats Arcade battle impact cards.
//

import Foundation

struct StatsBattleImpactMetric: Equatable, Sendable {
    let lookbackDays: Int
    let normalDayAverageSteps: Int
    let battleDayAverageSteps: Int
    let deltaSteps: Int
    let boostPercent: Int
    let normalDaySampleCount: Int
    let battleDaySampleCount: Int

    var hasEnoughSample: Bool {
        normalDaySampleCount >= 7 && battleDaySampleCount >= 3
    }
}

struct StatsMonthlyBattleBonusMetric: Equatable, Sendable {
    let monthBattleDayCount: Int
    let monthBattleDayTotalSteps: Int
    let bonusSteps: Int
    let approxMiles: Int

    var hasData: Bool {
        monthBattleDayCount > 0
    }
}

struct StatsOpponentStepsRollups: Equatable, Sendable {
    let lifetimeSteps: Int
    let rolling365dSteps: Int
    let currentMonthSteps: Int
    let computedAt: Date?
}

enum StatsArcadeStreakDot: Equatable, Sendable {
    case win
    case loss
    case today
}

/// Top Stats card: today's live battle steps + all-time cumulative (literal HealthKit steps).
struct StatsBattleStepsDisplay: Equatable, Sendable {
    let todaySteps: Int
    let allTimeSteps: Int
    let isTodayBattleDay: Bool
    let finalizedBattleDayCount: Int
    let averageFinalizedBattleDaySteps: Int?

    static let empty = StatsBattleStepsDisplay(
        todaySteps: 0,
        allTimeSteps: 0,
        isTodayBattleDay: false,
        finalizedBattleDayCount: 0,
        averageFinalizedBattleDaySteps: nil
    )
}
