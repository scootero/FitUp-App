//
//  BattleStatsRepository.swift
//  FitUp
//
//  Health stats battle-summary RPC reader.
//

import Foundation
import Supabase

struct HealthBattleStats: Equatable {
    enum StreakType: String, Equatable {
        case win
        case loss
        case none
    }

    let matchesPlayed: Int
    let wins: Int
    let losses: Int
    let ties: Int
    let winRate: Int
    let currentStreakType: StreakType
    let currentStreakCount: Int

    static let empty = HealthBattleStats(
        matchesPlayed: 0,
        wins: 0,
        losses: 0,
        ties: 0,
        winRate: 0,
        currentStreakType: .none,
        currentStreakCount: 0
    )

    var currentStreakLabel: String {
        guard currentStreakCount > 0 else { return "No streak" }
        let noun = currentStreakType == .loss ? "L" : "W"
        return "\(currentStreakCount) \(noun)"
    }
}

final class BattleStatsRepository {
    func fetchHealthBattleStats() async -> HealthBattleStats {
        guard let client = SupabaseProvider.client else { return .empty }
        do {
            let response: PostgrestResponse<HealthBattleStatsRPCResult> = try await client
                .rpc("health_battle_stats")
                .execute()
            return response.value.toDomain()
        } catch {
            AppLogger.log(
                category: "network",
                level: .warning,
                message: "health_battle_stats rpc failed",
                metadata: ["error": error.localizedDescription]
            )
            return .empty
        }
    }
}

private struct HealthBattleStatsRPCResult: Decodable {
    let matches_played: Int
    let wins: Int
    let losses: Int
    let ties: Int
    let win_rate: Int
    let current_streak_type: String
    let current_streak_count: Int

    func toDomain() -> HealthBattleStats {
        HealthBattleStats(
            matchesPlayed: max(0, matches_played),
            wins: max(0, wins),
            losses: max(0, losses),
            ties: max(0, ties),
            winRate: max(0, min(100, win_rate)),
            currentStreakType: HealthBattleStats.StreakType(rawValue: current_streak_type) ?? .none,
            currentStreakCount: max(0, current_streak_count)
        )
    }
}
