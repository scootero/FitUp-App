//
//  CalendarDayDetailModels.swift
//  FitUp
//
//  Detail payloads for activity calendar day taps.
//

import Foundation

struct CalendarOpponentSummary: Equatable, Sendable, Identifiable {
    let id: UUID
    let displayName: String
    let initials: String
    let colorHex: String
}

/// One completed (or active) match in the rivalry strip vs a single opponent.
struct CalendarRivalryEmblem: Equatable, Sendable, Identifiable {
    let id: UUID
    let viewerWon: Bool
    let completedAt: Date?
}

struct CalendarDayBattleMatchDetail: Equatable, Sendable, Identifiable {
    let id: UUID
    let matchId: UUID
    let opponent: CalendarOpponentSummary
    let mySteps: Int
    let theirSteps: Int
    let myWon: Bool?
    let isVoid: Bool
    let isFinalized: Bool
    let headToHead: HeadToHeadStats?
    let rivalryEmblems: [CalendarRivalryEmblem]
}

struct CalendarDayBattleDetail: Equatable, Sendable {
    let dateKey: String
    let displayTitle: String
    let summaryLine: String
    let aggregateState: CalendarDayBattleState
    let matches: [CalendarDayBattleMatchDetail]
}

struct CalendarDayStepsDetail: Equatable, Sendable {
    let dateKey: String
    let displayTitle: String
    let steps: Int
    let stepsGoal: Int
    let sparklineValues: [CGFloat]
    let pointTimestamps: [Date]
}
