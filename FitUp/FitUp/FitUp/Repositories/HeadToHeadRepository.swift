//
//  HeadToHeadRepository.swift
//  FitUp
//
//  Calls Supabase RPC `head_to_head_stats` for all-time record vs one opponent.
//

import Foundation
import Supabase

struct HeadToHeadStats: Equatable, Sendable {
    let totalCompleted: Int
    let viewerWins: Int
    let opponentWins: Int
    let seriesTies: Int
}

enum HeadToHeadRepositoryError: LocalizedError {
    case supabaseNotConfigured

    var errorDescription: String? {
        switch self {
        case .supabaseNotConfigured:
            return "Supabase is not configured."
        }
    }
}

final class HeadToHeadRepository {
    private var client: SupabaseClient {
        get throws {
            guard let client = SupabaseProvider.client else {
                throw HeadToHeadRepositoryError.supabaseNotConfigured
            }
            return client
        }
    }

    func fetchStats(opponentId: UUID, viewerId: UUID) async throws -> HeadToHeadStats {
        _ = viewerId
        let c = try client
        let params = HeadToHeadStatsRPCParams(p_opponent_id: opponentId)
        let response: PostgrestResponse<HeadToHeadStatsRPCResult> = try await c.rpc(
            "head_to_head_stats",
            params: params
        ).execute()

        let row = response.value
        return HeadToHeadStats(
            totalCompleted: row.total_completed,
            viewerWins: row.viewer_wins,
            opponentWins: row.opponent_wins,
            seriesTies: row.series_ties
        )
    }

    func clearMemoryCache() {
        // Reserved for future in-memory caching; RPC is cheap and called once per screen.
    }
}

private struct HeadToHeadStatsRPCParams: Sendable {
    let p_opponent_id: UUID
}

extension HeadToHeadStatsRPCParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_opponent_id, forKey: .p_opponent_id)
    }

    enum CodingKeys: String, CodingKey {
        case p_opponent_id
    }
}

private struct HeadToHeadStatsRPCResult: Decodable, Sendable {
    let total_completed: Int
    let viewer_wins: Int
    let opponent_wins: Int
    let series_ties: Int
}
