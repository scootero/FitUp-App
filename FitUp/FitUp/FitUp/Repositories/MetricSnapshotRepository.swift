//
//  MetricSnapshotRepository.swift
//  FitUp
//
//  Slice 7 writes for metric snapshots and rolling baselines.
//

import Combine
import Foundation
import Supabase

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

    func insertSnapshots(
        matchIds: [UUID],
        userId: UUID,
        metricType: HealthMetricType,
        value: Int,
        sourceDate: String,
        metadata: [String: String]? = nil
    ) async throws {
        guard !matchIds.isEmpty else { return }

        let flagged = shouldFlag(metricType: metricType, value: value)
        let syncedAt = Self.isoFormatter.string(from: Date())
        let rows = matchIds.map { matchId in
            MetricSnapshotInsert(
                matchId: matchId,
                userId: userId,
                metricType: metricType.rawValue,
                value: value,
                sourceDate: sourceDate,
                syncedAt: syncedAt,
                flagged: flagged,
                metadata: metadata
            )
        }

        try await client
            .from("metric_snapshots")
            .insert(rows)
            .execute()

        guard flagged else { return }
        for matchId in matchIds {
            AppLogger.log(
                category: "healthkit_sync",
                level: .warning,
                message: "anomaly value flagged in metric snapshot",
                userId: userId,
                metadata: [
                    "match_id": matchId.uuidString,
                    "metric_type": metricType.rawValue,
                    "value": String(value),
                ]
            )
        }
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

private struct MetricSnapshotInsert: Encodable {
    let matchId: UUID
    let userId: UUID
    let metricType: String
    let value: Int
    let sourceDate: String
    let syncedAt: String
    let flagged: Bool
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case matchId = "match_id"
        case userId = "user_id"
        case metricType = "metric_type"
        case value
        case sourceDate = "source_date"
        case syncedAt = "synced_at"
        case flagged
        case metadata
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
