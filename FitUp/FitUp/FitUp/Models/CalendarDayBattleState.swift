//
//  CalendarDayBattleState.swift
//  FitUp
//
//  Per-calendar-date battle outcome for the activity calendar (Battles mode).
//

import Foundation

/// Aggregated match-day outcome for one profile calendar date (`yyyy-MM-dd`).
///
/// Multi-match rule: **wonAny** if the user won at least one finalized non-void match day;
/// **lostAll** only when they had competitive finalized days and won none.
enum CalendarDayBattleState: Equatable, Sendable {
    /// No `match_days` rows for this user on this date.
    case none
    /// At least one match day on this date is not yet finalized.
    case inProgress
    /// Won at least one finalized non-void match day on this date.
    case wonAny
    /// Had finalized non-void losses and no wins on this date.
    case lostAll
    /// Only void/tie finalized days (or finalized with no winner).
    case voidOnly

    /// Merges multiple match-day rows for the same calendar date.
    static func aggregate(dayRows: [CalendarMatchDayRow], userId: UUID) -> CalendarDayBattleState {
        guard !dayRows.isEmpty else { return .none }

        var hasInProgress = false
        var hasWon = false
        var hasLost = false
        var hadMatchDay = false

        for row in dayRows {
            hadMatchDay = true
            if row.status != "finalized" {
                hasInProgress = true
                continue
            }
            if row.isVoid {
                continue
            }
            guard let winnerId = row.winnerUserId else { continue }
            if winnerId == userId {
                hasWon = true
            } else {
                hasLost = true
            }
        }

        guard hadMatchDay else { return .none }
        if hasInProgress { return .inProgress }
        if hasWon { return .wonAny }
        if hasLost { return .lostAll }
        return .voidOnly
    }
}

/// Per-date win/loss breakdown for Battles calendar ring indicators.
struct CalendarDayBattleSummary: Equatable, Sendable {
    let state: CalendarDayBattleState
    let matchCount: Int
    let wins: Int
    let losses: Int
    let voids: Int

    var netScore: Int { wins - losses }

    static let empty = CalendarDayBattleSummary(
        state: .none,
        matchCount: 0,
        wins: 0,
        losses: 0,
        voids: 0
    )

    /// Merges multiple match-day rows for the same calendar date with W/L/V counts.
    static func aggregateSummary(dayRows: [CalendarMatchDayRow], userId: UUID) -> CalendarDayBattleSummary {
        guard !dayRows.isEmpty else { return .empty }

        var hasInProgress = false
        var wins = 0
        var losses = 0
        var voids = 0

        for row in dayRows {
            if row.status != "finalized" {
                hasInProgress = true
                continue
            }
            if row.isVoid {
                voids += 1
                continue
            }
            guard let winnerId = row.winnerUserId else {
                voids += 1
                continue
            }
            if winnerId == userId {
                wins += 1
            } else {
                losses += 1
            }
        }

        let state = CalendarDayBattleState.aggregate(dayRows: dayRows, userId: userId)
        return CalendarDayBattleSummary(
            state: state,
            matchCount: dayRows.count,
            wins: wins,
            losses: losses,
            voids: voids
        )
    }
}

struct CalendarBattleStatesResult: Equatable, Sendable {
    let states: [String: CalendarDayBattleState]
    let summaries: [String: CalendarDayBattleSummary]
}

/// Raw match day row used when aggregating calendar battle states.
struct CalendarMatchDayRow: Equatable, Sendable {
    let calendarDate: String
    let status: String
    let isVoid: Bool
    let winnerUserId: UUID?
}
