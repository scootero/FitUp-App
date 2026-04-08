//
//  MatchRepository.swift
//  FitUp
//
//  Slice 4 challenge flow reads/writes for matchmaking and direct challenges.
//

import Combine
import Foundation
import Supabase

struct MatchRepositoryOpponentCandidate: Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let initials: String
    let colorHex: String
    let todaySteps: Int?
    let wins: Int?
    let losses: Int?
    let rollingStepsBaseline: Double?
    let rollingCaloriesBaseline: Double?
}

struct MatchRepositoryDirectChallengeResult {
    let matchId: UUID
    let challengeId: UUID
}

final class MatchRepository {
    private var client: SupabaseClient {
        get throws {
            guard let client = SupabaseProvider.client else {
                throw ProfileRepositoryError.supabaseNotConfigured
            }
            return client
        }
    }

    // MARK: - Entry gating

    func countOpenSlots(currentUserId: UUID) async throws -> Int {
        let searchingCount = try await fetchSearchingCount(currentUserId: currentUserId)
        let activePendingCount = try await fetchActivePendingMatchCount(currentUserId: currentUserId)
        return searchingCount + activePendingCount
    }

    // MARK: - Opponent discovery

    func fetchOpponentCandidates(
        currentUserId: UUID,
        query: String,
        metricType: ChallengeMetricType
    ) async throws -> [MatchRepositoryOpponentCandidate] {
        let rows = try await fetchProfileRows()
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let myBaselines = try await fetchMyBaselines(userId: currentUserId)
        let myBaseline = metricType == .steps ? myBaselines.steps : myBaselines.calories

        var candidates: [MatchRepositoryOpponentCandidate] = []
        for row in rows {
            guard let id = uuid(from: row["id"]), id != currentUserId else { continue }
            let displayName = string(from: row["display_name"]) ?? "Player"
            if !trimmedQuery.isEmpty, !displayName.lowercased().contains(trimmedQuery) {
                continue
            }

            let initials = string(from: row["initials"]) ?? Self.initials(from: displayName)
            let baselines = parseBaselines(from: row["user_health_baselines"])
            let latestStats = try? await fetchLatestLeaderboardStats(userId: id)
            let todaySteps = try? await fetchLatestTodaySteps(userId: id)

            candidates.append(
                MatchRepositoryOpponentCandidate(
                    id: id,
                    displayName: displayName,
                    initials: initials,
                    colorHex: colorHex(for: id),
                    todaySteps: todaySteps,
                    wins: latestStats?.wins,
                    losses: latestStats?.losses,
                    rollingStepsBaseline: baselines.steps,
                    rollingCaloriesBaseline: baselines.calories
                )
            )
        }

        return candidates.sorted {
            scoreDistance(
                candidate: $0,
                myBaseline: myBaseline,
                metricType: metricType
            ) < scoreDistance(
                candidate: $1,
                myBaseline: myBaseline,
                metricType: metricType
            )
        }
    }

    // MARK: - Writes

    /// Cancels any prior open matchmaking rows for this user so only one `searching` request exists (avoids duplicate queue rows).
    func cancelPriorSearchingRequests(creatorId: UUID) async throws {
        let client = try client
        try await client
            .from("match_search_requests")
            .update(MatchSearchStatusUpdate(status: "cancelled"))
            .eq("creator_id", value: creatorId.uuidString)
            .eq("status", value: "searching")
            .execute()
    }

    /// Authenticated retry: same pairing logic as the DB trigger (useful if pg_net delivery failed).
    /// Passes the session access token explicitly so the Edge Function always receives a user JWT
    /// (avoids 401 if `FunctionsClient` auth was not yet synced from auth state).
    func retryMatchmakingSearch(requestId: UUID) async throws {
        let client = try client
        let session = try await client.auth.session
        try await client.functions.invoke(
            "retry-matchmaking-search",
            options: FunctionInvokeOptions(
                headers: ["Authorization": "Bearer \(session.accessToken)"],
                body: RetryMatchmakingBody(match_search_request_id: requestId.uuidString)
            )
        )
    }

    @discardableResult
    func createQuickMatchSearch(
        creatorId: UUID,
        metricType: ChallengeMetricType,
        durationDays: Int,
        startMode: ChallengeStartMode
    ) async throws -> UUID {
        try await cancelPriorSearchingRequests(creatorId: creatorId)

        let creatorBaseline = try await fetchCreatorBaseline(userId: creatorId, metricType: metricType)
        let payload = MatchSearchInsert(
            creatorId: creatorId,
            metricType: metricType.rawValue,
            durationDays: durationDays,
            startMode: startMode.rawValue,
            status: "searching",
            creatorBaseline: creatorBaseline
        )

        let response = try await client
            .from("match_search_requests")
            .insert(payload)
            .select("id")
            .execute()

        guard let createdId = jsonRows(from: response.data).first.flatMap({ uuid(from: $0["id"]) }) else {
            throw MatchRepositoryError.insertFailed
        }
        return createdId
    }

    func createDirectChallenge(
        challengerId: UUID,
        recipientId: UUID,
        metricType: ChallengeMetricType,
        durationDays: Int,
        startMode: ChallengeStartMode
    ) async throws -> MatchRepositoryDirectChallengeResult {
        let client = try client
        let timezone = TimeZone.current.identifier
        let startsAt = Self.isoFormatter.string(from: Date())

        // Server-side RPC (SECURITY DEFINER) so inserts are not subject to client RLS on `matches`.
        // Challenger is derived from the JWT in Postgres only; `challengerId` is unused for writes.
        _ = challengerId

        let params = CreateDirectChallengeRPCParams(
            p_recipient_id: recipientId,
            p_metric_type: metricType.rawValue,
            p_duration_days: durationDays,
            p_start_mode: startMode.rawValue,
            p_match_timezone: timezone,
            p_starts_at: startsAt
        )

        let response: PostgrestResponse<CreateDirectChallengeRPCResult> = try await client.rpc(
            "create_direct_challenge",
            params: params
        ).execute()

        let row = response.value
        return MatchRepositoryDirectChallengeResult(matchId: row.match_id, challengeId: row.challenge_id)
    }

    // MARK: - Internal reads

    private func fetchSearchingCount(currentUserId: UUID) async throws -> Int {
        let response = try await client
            .from("match_search_requests")
            .select("id")
            .eq("creator_id", value: currentUserId.uuidString)
            .eq("status", value: "searching")
            .execute()
        return jsonRows(from: response.data).count
    }

    private func fetchActivePendingMatchCount(currentUserId: UUID) async throws -> Int {
        let participantResponse = try await client
            .from("match_participants")
            .select("match_id")
            .eq("user_id", value: currentUserId.uuidString)
            .execute()
        let matchIds = Set(jsonRows(from: participantResponse.data).compactMap { uuid(from: $0["match_id"]) })
        guard !matchIds.isEmpty else { return 0 }

        var count = 0
        for matchId in matchIds {
            let response = try await client
                .from("matches")
                .select("state")
                .eq("id", value: matchId.uuidString)
                .limit(1)
                .execute()
            let state = jsonRows(from: response.data).first.flatMap { string(from: $0["state"]) }
            if state == "pending" || state == "active" {
                count += 1
            }
        }
        return count
    }

    private func fetchProfileRows() async throws -> [[String: Any]] {
        let response = try await client
            .from("profiles")
            .select("id, display_name, initials, created_at, user_health_baselines(rolling_avg_7d_steps, rolling_avg_7d_calories)")
            .order("created_at", ascending: false)
            .limit(50)
            .execute()
        return jsonRows(from: response.data)
    }

    private func fetchLatestLeaderboardStats(userId: UUID) async throws -> (wins: Int?, losses: Int?) {
        let response = try await client
            .from("leaderboard_entries")
            .select("wins, losses, week_start")
            .eq("user_id", value: userId.uuidString)
            .order("week_start", ascending: false)
            .limit(1)
            .execute()
        let row = jsonRows(from: response.data).first
        return (int(from: row?["wins"]), int(from: row?["losses"]))
    }

    private func fetchLatestTodaySteps(userId: UUID) async throws -> Int? {
        let response = try await client
            .from("metric_snapshots")
            .select("value, synced_at")
            .eq("user_id", value: userId.uuidString)
            .eq("metric_type", value: "steps")
            .eq("source_date", value: Self.calendarFormatter.string(from: Date()))
            .order("synced_at", ascending: false)
            .limit(1)
            .execute()
        let row = jsonRows(from: response.data).first
        return int(from: row?["value"])
    }

    private func fetchMyBaselines(userId: UUID) async throws -> (steps: Double?, calories: Double?) {
        let response = try await client
            .from("user_health_baselines")
            .select("rolling_avg_7d_steps, rolling_avg_7d_calories")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
        let row = jsonRows(from: response.data).first
        return (
            double(from: row?["rolling_avg_7d_steps"]),
            double(from: row?["rolling_avg_7d_calories"])
        )
    }

    private func fetchCreatorBaseline(userId: UUID, metricType: ChallengeMetricType) async throws -> Double? {
        let baselines = try await fetchMyBaselines(userId: userId)
        return metricType == .steps ? baselines.steps : baselines.calories
    }

    // MARK: - Mapping

    private func parseBaselines(from rawValue: Any?) -> (steps: Double?, calories: Double?) {
        if let object = rawValue as? [String: Any] {
            return (
                double(from: object["rolling_avg_7d_steps"]),
                double(from: object["rolling_avg_7d_calories"])
            )
        }
        if let array = rawValue as? [[String: Any]], let first = array.first {
            return (
                double(from: first["rolling_avg_7d_steps"]),
                double(from: first["rolling_avg_7d_calories"])
            )
        }
        return (nil, nil)
    }

    private func scoreDistance(
        candidate: MatchRepositoryOpponentCandidate,
        myBaseline: Double?,
        metricType: ChallengeMetricType
    ) -> Double {
        let candidateBaseline = metricType == .steps
            ? candidate.rollingStepsBaseline
            : candidate.rollingCaloriesBaseline
        switch (candidateBaseline, myBaseline) {
        case let (.some(candidateValue), .some(myValue)):
            return abs(candidateValue - myValue)
        case (.some, .none):
            return 10_000_000
        case (.none, .some):
            return 10_000_001
        case (.none, .none):
            return 10_000_002
        }
    }

    private func colorHex(for userId: UUID) -> String {
        let palette = ["00AAFF", "FF6200", "BF5FFF", "FFE000", "39FF14", "FF2D9B"]
        let index = abs(userId.hashValue) % palette.count
        return palette[index]
    }

    // MARK: - JSON helpers

    private func jsonRows(from data: Data) -> [[String: Any]] {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let array = object as? [[String: Any]]
        else {
            return []
        }
        return array
    }

    private func uuid(from value: Any?) -> UUID? {
        if let uuid = value as? UUID { return uuid }
        if let string = value as? String { return UUID(uuidString: string) }
        return nil
    }

    private func string(from value: Any?) -> String? {
        value as? String
    }

    private func int(from value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue.rounded()) }
        if let stringValue = value as? String, let doubleValue = Double(stringValue) {
            return Int(doubleValue.rounded())
        }
        return nil
    }

    private func double(from value: Any?) -> Double? {
        if let doubleValue = value as? Double { return doubleValue }
        if let intValue = value as? Int { return Double(intValue) }
        if let stringValue = value as? String { return Double(stringValue) }
        return nil
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let calendarFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func initials(from displayName: String) -> String {
        let words = displayName.split(separator: " ").map(String.init)
        if words.count >= 2, let first = words.first?.first, let second = words.dropFirst().first?.first {
            return "\(first)\(second)".uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}

enum MatchRepositoryError: LocalizedError {
    case insertFailed

    var errorDescription: String? {
        switch self {
        case .insertFailed:
            return "Could not save challenge data."
        }
    }
}

private struct MatchSearchStatusUpdate: Encodable {
    let status: String
}

/// Params for `public.create_direct_challenge` (see `supabase/sql/slice4d-create-direct-challenge-rpc.sql`).
/// Explicit `nonisolated` Codable: Swift 6 otherwise treats synthesized `Encodable` as main-actor-isolated,
/// which breaks `SupabaseClient.rpc(..., params:)` (`Encodable & Sendable`).
private struct CreateDirectChallengeRPCParams: Sendable {
    let p_recipient_id: UUID
    let p_metric_type: String
    let p_duration_days: Int
    let p_start_mode: String
    let p_match_timezone: String
    let p_starts_at: String
}

extension CreateDirectChallengeRPCParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_recipient_id, forKey: .p_recipient_id)
        try c.encode(p_metric_type, forKey: .p_metric_type)
        try c.encode(p_duration_days, forKey: .p_duration_days)
        try c.encode(p_start_mode, forKey: .p_start_mode)
        try c.encode(p_match_timezone, forKey: .p_match_timezone)
        try c.encode(p_starts_at, forKey: .p_starts_at)
    }

    enum CodingKeys: String, CodingKey {
        case p_recipient_id
        case p_metric_type
        case p_duration_days
        case p_start_mode
        case p_match_timezone
        case p_starts_at
    }
}

private struct CreateDirectChallengeRPCResult: Sendable {
    let match_id: UUID
    let challenge_id: UUID
}

extension CreateDirectChallengeRPCResult: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        match_id = try c.decode(UUID.self, forKey: .match_id)
        challenge_id = try c.decode(UUID.self, forKey: .challenge_id)
    }

    enum CodingKeys: String, CodingKey {
        case match_id
        case challenge_id
    }
}

private struct RetryMatchmakingBody: Encodable {
    let match_search_request_id: String
}

private struct MatchSearchInsert: Encodable {
    let creatorId: UUID
    let metricType: String
    let durationDays: Int
    let startMode: String
    let status: String
    let creatorBaseline: Double?

    enum CodingKeys: String, CodingKey {
        case creatorId = "creator_id"
        case metricType = "metric_type"
        case durationDays = "duration_days"
        case startMode = "start_mode"
        case status
        case creatorBaseline = "creator_baseline"
    }
}

