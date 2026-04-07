//
//  LeaderboardDisplayRow.swift
//  FitUp
//
//  Slice 11 — UI model for leaderboard podium and list rows.
//

import Foundation

struct LeaderboardDisplayRow: Identifiable, Equatable {
    let id: UUID
    /// Display order (1-based). Friends tab uses client recomputed ranks; global uses server rank when present.
    let displayRank: Int
    let points: Int
    let wins: Int
    let losses: Int
    let streak: Int
    let displayName: String
    let initials: String
    /// Hex without `#`, same palette as `ProfileAccentColor`.
    let colorHex: String
    let isCurrentUser: Bool
}
