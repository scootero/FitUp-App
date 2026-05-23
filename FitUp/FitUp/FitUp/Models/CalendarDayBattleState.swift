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

/// Raw match day row used when aggregating calendar battle states.
struct CalendarMatchDayRow: Equatable, Sendable {
    let calendarDate: String
    let status: String
    let isVoid: Bool
    let winnerUserId: UUID?
}
