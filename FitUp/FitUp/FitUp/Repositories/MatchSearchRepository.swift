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
        creatorBaseline: Double?
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
            creatorBaseline: creatorBaseline
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

    enum CodingKeys: String, CodingKey {
        case creatorId = "creator_id"
        case metricType = "metric_type"
        case durationDays = "duration_days"
        case startMode = "start_mode"
        case creatorBaseline = "creator_baseline"
    }
}
