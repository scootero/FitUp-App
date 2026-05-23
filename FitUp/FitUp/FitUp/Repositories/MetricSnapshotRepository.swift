//
//  MetricSnapshotRepository.swift
//  FitUp
//
//  Slice 7 writes for metric snapshots and rolling baselines.
//  SQL: `supabase/manual_sql/metric_snapshots_record_rpc.sql`
//

import Combine
import Foundation
import Supabase

struct MetricSnapshotRecordResult: Sendable {
    let snapshotId: UUID
    let wasUpdated: Bool
}

enum MetricSnapshotRepositoryError: Error {
    case supabaseNotConfigured
    case unexpectedRecordResponse
}

final class MetricSnapshotRepository {
    // "Calorie equivalent" is not explicitly defined in docs.
    // v1 uses 3,500 active calories as the anomaly threshold.
    private let flaggedStepsThreshold = 50_000
    private let flaggedCaloriesThreshold = 3_500

    private var client: SupabaseClient {
        get throws {
            guard let client = SupabaseProvider.client else {
                throw ProfileRepositoryError.supabaseNotConfigured
            }
            return client
        }
    }

    func recordSnapshot(
        matchId: UUID,
        userId: UUID,
        metricType: HealthMetricType,
        value: Int,
        sourceDate: String,
        metadata: [String: String]? = nil
    ) async throws -> MetricSnapshotRecordResult {
        let flagged = shouldFlag(metricType: metricType, value: value)
        let syncedAt = Self.isoFormatter.string(from: Date())

        let params = RecordMetricSnapshotRPCParams(
            p_match_id: matchId,
            p_metric_type: metricType.rawValue,
            p_value: value,
            p_source_date: sourceDate,
            p_flagged: flagged,
            p_metadata: metadata,
            p_synced_at: syncedAt
        )

        let response = try await client
            .rpc("record_metric_snapshot", params: params)
            .execute()

        let decoded = try Self.decodeRecordResponse(from: response.data)

        guard flagged == false else {
            AppLogger.log(
                category: "healthkit_sync",
                level: .warning,
                message: "anomaly value flagged in metric snapshot",
                userId: userId,
                metadata: [
                    "match_id": matchId.uuidString,
                    "metric_type": metricType.rawValue,
                    "value": String(value),
                    "snapshot_id": decoded.snapshotId.uuidString,
                ]
            )
            return decoded
        }

        return decoded
    }

    /// Records one snapshot per match via `record_metric_snapshot` RPC (insert or update synced_at).
    func insertSnapshots(
        matchIds: [UUID],
        userId: UUID,
        metricType: HealthMetricType,
        value: Int,
        sourceDate: String,
        metadata: [String: String]? = nil
    ) async throws -> [MetricSnapshotRecordResult] {
        guard !matchIds.isEmpty else { return [] }

        var results: [MetricSnapshotRecordResult] = []
        for matchId in matchIds {
            let result = try await recordSnapshot(
                matchId: matchId,
                userId: userId,
                metricType: metricType,
                value: value,
                sourceDate: sourceDate,
                metadata: metadata
            )
            results.append(result)
        }
        return results
    }

    func upsertRollingBaselines(
        userId: UUID,
        stepsAverage7d: Double?,
        stepsAverage30d: Double?,
        stepsAverage90d: Double?,
        caloriesAverage: Double?
    ) async throws {
        let existsResponse = try await client
            .from("user_health_baselines")
            .select("user_id")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()

        let payload = BaselineWrite(
            userId: userId,
            rollingAvg7dSteps: stepsAverage7d,
            rollingAvg30dSteps: stepsAverage30d,
            rollingAvg90dSteps: stepsAverage90d,
            rollingAvg7dCalories: caloriesAverage,
            updatedAt: Self.isoFormatter.string(from: Date())
        )

        if jsonRows(from: existsResponse.data).isEmpty {
            try await client
                .from("user_health_baselines")
                .insert(payload)
                .execute()
        } else {
            try await client
                .from("user_health_baselines")
                .update(
                    BaselineUpdate(
                        rollingAvg7dSteps: stepsAverage7d,
                        rollingAvg30dSteps: stepsAverage30d,
                        rollingAvg90dSteps: stepsAverage90d,
                        rollingAvg7dCalories: caloriesAverage,
                        updatedAt: payload.updatedAt
                    )
                )
                .eq("user_id", value: userId.uuidString)
                .execute()
        }
    }

    /// Debug read of aggregates stored for matchmaking (no HealthKit samples).
    func fetchRollingStepBaselines(userId: UUID) async throws -> (d7: Double?, d30: Double?, d90: Double?, updatedAt: String?) {
        let client = try client
        let response = try await client
            .from("user_health_baselines")
            .select("rolling_avg_7d_steps, rolling_avg_30d_steps, rolling_avg_90d_steps, updated_at")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
        let row = jsonRows(from: response.data).first
        let d7 = row.flatMap { double(from: $0["rolling_avg_7d_steps"]) }
        let d30 = row.flatMap { double(from: $0["rolling_avg_30d_steps"]) }
        let d90 = row.flatMap { double(from: $0["rolling_avg_90d_steps"]) }
        let updated = row.flatMap { $0["updated_at"] as? String }
        return (d7, d30, d90, updated)
    }

    private static func decodeRecordResponse(from data: Data) throws -> MetricSnapshotRecordResult {
        struct Payload: Decodable {
            let snapshot_id: UUID
            let was_updated: Bool
        }

        if let payload = try? JSONDecoder().decode(Payload.self, from: data) {
            return MetricSnapshotRecordResult(snapshotId: payload.snapshot_id, wasUpdated: payload.was_updated)
        }

        if let scalar = try? JSONDecoder().decode(UUID.self, from: data) {
            return MetricSnapshotRecordResult(snapshotId: scalar, wasUpdated: false)
        }

        throw MetricSnapshotRepositoryError.unexpectedRecordResponse
    }

    private func double(from value: Any?) -> Double? {
        if let doubleValue = value as? Double { return doubleValue }
        if let intValue = value as? Int { return Double(intValue) }
        if let stringValue = value as? String { return Double(stringValue) }
        return nil
    }

    private func shouldFlag(metricType: HealthMetricType, value: Int) -> Bool {
        switch metricType {
        case .steps:
            return value > flaggedStepsThreshold
        case .activeCalories:
            return value > flaggedCaloriesThreshold
        }
    }

    private func jsonRows(from data: Data) -> [[String: Any]] {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let rows = object as? [[String: Any]]
        else {
            return []
        }
        return rows
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct RecordMetricSnapshotRPCParams: Sendable {
    let p_match_id: UUID
    let p_metric_type: String
    let p_value: Int
    let p_source_date: String
    let p_flagged: Bool
    let p_metadata: [String: String]?
    let p_synced_at: String
}

extension RecordMetricSnapshotRPCParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(p_match_id, forKey: .p_match_id)
        try container.encode(p_metric_type, forKey: .p_metric_type)
        try container.encode(p_value, forKey: .p_value)
        try container.encode(p_source_date, forKey: .p_source_date)
        try container.encode(p_flagged, forKey: .p_flagged)
        try container.encodeIfPresent(p_metadata, forKey: .p_metadata)
        try container.encode(p_synced_at, forKey: .p_synced_at)
    }

    enum CodingKeys: String, CodingKey {
        case p_match_id
        case p_metric_type
        case p_value
        case p_source_date
        case p_flagged
        case p_metadata
        case p_synced_at
    }
}

private struct BaselineWrite: Encodable {
    let userId: UUID
    let rollingAvg7dSteps: Double?
    let rollingAvg30dSteps: Double?
    let rollingAvg90dSteps: Double?
    let rollingAvg7dCalories: Double?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case rollingAvg7dSteps = "rolling_avg_7d_steps"
        case rollingAvg30dSteps = "rolling_avg_30d_steps"
        case rollingAvg90dSteps = "rolling_avg_90d_steps"
        case rollingAvg7dCalories = "rolling_avg_7d_calories"
        case updatedAt = "updated_at"
    }
}

private struct BaselineUpdate: Encodable {
    let rollingAvg7dSteps: Double?
    let rollingAvg30dSteps: Double?
    let rollingAvg90dSteps: Double?
    let rollingAvg7dCalories: Double?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case rollingAvg7dSteps = "rolling_avg_7d_steps"
        case rollingAvg30dSteps = "rolling_avg_30d_steps"
        case rollingAvg90dSteps = "rolling_avg_90d_steps"
        case rollingAvg7dCalories = "rolling_avg_7d_calories"
        case updatedAt = "updated_at"
    }
}
