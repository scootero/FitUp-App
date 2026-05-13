//
//  MatchSearchRepository.swift
//  FitUp
//
//  Slice 2: onboarding quick-match search writes.
//

import Combine
import Foundation
import Supabase

struct MatchSearchRepository {
    private var client: SupabaseClient {
        get throws {
            guard let client = SupabaseProvider.client else {
                throw ProfileRepositoryError.supabaseNotConfigured
            }
            return client
        }
    }

    func createOnboardingSearchRequest(
        creatorId: UUID,
        creatorBaseline: Double?,
        creatorAvg30dSteps: Double?
    ) async throws {
        let client = try client
        try await client
            .from("match_search_requests")
            .update(MatchSearchStatusUpdate(status: "cancelled"))
            .eq("creator_id", value: creatorId.uuidString)
            .eq("status", value: "searching")
            .execute()

        let row = MatchSearchRequestInsert(
            creatorId: creatorId,
            metricType: "steps",
            durationDays: 1,
            startMode: "today",
            creatorBaseline: creatorBaseline,
            scoringMode: "balanced",
            difficulty: nil,
            creatorAvg30dSteps: creatorAvg30dSteps
        )
        try await client.from("match_search_requests").insert(row).execute()
    }
}

private struct MatchSearchStatusUpdate: Encodable {
    let status: String
}

private struct MatchSearchRequestInsert: Encodable {
    let creatorId: UUID
    let metricType: String
    let durationDays: Int
    let startMode: String
    let creatorBaseline: Double?
    let scoringMode: String
    let difficulty: String?
    let creatorAvg30dSteps: Double?

    enum CodingKeys: String, CodingKey {
        case creatorId = "creator_id"
        case metricType = "metric_type"
        case durationDays = "duration_days"
        case startMode = "start_mode"
        case creatorBaseline = "creator_baseline"
        case scoringMode = "scoring_mode"
        case difficulty
        case creatorAvg30dSteps = "creator_avg_30d_steps"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(creatorId, forKey: .creatorId)
        try c.encode(metricType, forKey: .metricType)
        try c.encode(durationDays, forKey: .durationDays)
        try c.encode(startMode, forKey: .startMode)
        try c.encodeIfPresent(creatorBaseline, forKey: .creatorBaseline)
        try c.encode(scoringMode, forKey: .scoringMode)
        try c.encodeIfPresent(difficulty, forKey: .difficulty)
        try c.encodeIfPresent(creatorAvg30dSteps, forKey: .creatorAvg30dSteps)
    }
}
