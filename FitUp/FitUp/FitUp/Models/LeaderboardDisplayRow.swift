//
//  LeaderboardDisplayRow.swift
//  FitUp
//
//  Slice 11 — UI model for leaderboard podium and list rows.
//

import Foundation

struct LeaderboardDisplayRow: Identifiable, Equatable {
    let id: UUID
    /// Display order (1-based) returned by the weekly steps leaderboard source.
    let displayRank: Int
    let totalSteps: Int
    let displayName: String
    let initials: String
    /// Hex without `#`, same palette as `ProfileAccentColor`.
    let colorHex: String
    let isCurrentUser: Bool
}
