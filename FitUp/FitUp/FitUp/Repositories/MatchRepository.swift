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
    let pastMatchCount: Int?
    let rollingStepsBaseline: Double?
    let rollingCaloriesBaseline: Double?
}

struct MatchRepositoryDirectChallengeResult {
    let matchId: UUID
    let challengeId: UUID
}

final class MatchRepository {
    private enum OpponentDiscoveryLimits {
        /// Profiles fetched for client-side sort when RPC is unavailable.
        static let profilePool = 50
        /// Default opponent rows when search is empty.
        static let defaultDisplay = 15
        /// Max rows when user is searching by name.
        static let searchDisplay = 50
    }

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
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let isSearching = !trimmedQuery.isEmpty
        let displayLimit = isSearching
            ? OpponentDiscoveryLimits.searchDisplay
            : OpponentDiscoveryLimits.defaultDisplay

        if let rpcCandidates = try? await fetchOpponentCandidatesViaRPC(
            query: trimmedQuery,
            metricType: metricType,
            limit: displayLimit
        ) {
            return rpcCandidates
        }

        return try await fetchOpponentCandidatesBatched(
            currentUserId: currentUserId,
            query: trimmedQuery,
            metricType: metricType,
            displayLimit: displayLimit
        )
    }

    private func fetchOpponentCandidatesViaRPC(
        query: String,
        metricType: ChallengeMetricType,
        limit: Int
    ) async throws -> [MatchRepositoryOpponentCandidate] {
        let client = try client
        let localDate = Self.calendarFormatter.string(from: Date())
        let params = ListOpponentCandidatesRPCParams(
            p_query: query,
            p_metric_type: metricType.rawValue,
            p_viewer_local_date: localDate,
            p_limit: limit
        )
        let response: PostgrestResponse<[ListOpponentCandidatesRPCRow]> = try await client
            .rpc("list_opponent_candidates", params: params)
            .execute()
        return response.value.map { row in
            MatchRepositoryOpponentCandidate(
                id: row.id,
                displayName: row.display_name ?? "Player",
                initials: row.initials ?? Self.initials(from: row.display_name ?? "Player"),
                colorHex: colorHex(for: row.id),
                todaySteps: row.today_steps,
                wins: row.wins,
                losses: row.losses,
                pastMatchCount: row.past_match_count,
                rollingStepsBaseline: row.rolling_avg_7d_steps,
                rollingCaloriesBaseline: row.rolling_avg_7d_calories
            )
        }
    }

    private func fetchOpponentCandidatesBatched(
        currentUserId: UUID,
        query: String,
        metricType: ChallengeMetricType,
        displayLimit: Int
    ) async throws -> [MatchRepositoryOpponentCandidate] {
        let rows = try await fetchProfileRows(limit: OpponentDiscoveryLimits.profilePool)
        let myBaselines = try await fetchMyBaselines(userId: currentUserId)
        let myBaseline = metricType == .steps ? myBaselines.steps7 : myBaselines.calories7
        let trimmedQuery = query.lowercased()

        var candidateIds: [UUID] = []
        var profileById: [UUID: [String: Any]] = [:]
        for row in rows {
            guard let id = uuid(from: row["id"]), id != currentUserId else { continue }
            let displayName = string(from: row["display_name"]) ?? "Player"
            if !trimmedQuery.isEmpty, !displayName.lowercased().contains(trimmedQuery) {
                continue
            }
            candidateIds.append(id)
            profileById[id] = row
        }

        let latestStatsByUser = try await fetchLatestLeaderboardStatsBatch(userIds: candidateIds)
        let todayStepsByUser = try await fetchLatestTodayStepsBatch(userIds: candidateIds)
        let pastMatchCounts = try await fetchPastMatchCountsBatch(
            currentUserId: currentUserId,
            opponentIds: candidateIds
        )

        var candidates: [MatchRepositoryOpponentCandidate] = []
        candidates.reserveCapacity(candidateIds.count)
        for id in candidateIds {
            guard let row = profileById[id] else { continue }
            let displayName = string(from: row["display_name"]) ?? "Player"
            let initials = string(from: row["initials"]) ?? Self.initials(from: displayName)
            let baselines = parseBaselines(from: row["user_health_baselines"])
            let latestStats = latestStatsByUser[id]
            candidates.append(
                MatchRepositoryOpponentCandidate(
                    id: id,
                    displayName: displayName,
                    initials: initials,
                    colorHex: colorHex(for: id),
                    todaySteps: todayStepsByUser[id],
                    wins: latestStats?.wins,
                    losses: latestStats?.losses,
                    pastMatchCount: pastMatchCounts[id] ?? 0,
                    rollingStepsBaseline: baselines.steps,
                    rollingCaloriesBaseline: baselines.calories
                )
            )
        }

        let sorted = candidates.sorted { lhs, rhs in
            let lhsCount = lhs.pastMatchCount ?? 0
            let rhsCount = rhs.pastMatchCount ?? 0
            if lhsCount != rhsCount { return lhsCount > rhsCount }
            let lhsDistance = scoreDistance(candidate: lhs, myBaseline: myBaseline, metricType: metricType)
            let rhsDistance = scoreDistance(candidate: rhs, myBaseline: myBaseline, metricType: metricType)
            if lhsDistance != rhsDistance { return lhsDistance < rhsDistance }
            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }
        return Array(sorted.prefix(displayLimit))
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
        startMode: ChallengeStartMode,
        scoringMode: MatchScoringModePreference?,
        difficulty: MatchDifficultyPreference?
    ) async throws -> UUID {
        try await cancelPriorSearchingRequests(creatorId: creatorId)

        let baselines = try await fetchMyBaselines(userId: creatorId)
        let creatorBaseline = metricType == .steps ? baselines.steps7 : baselines.calories7
        let avg30 = metricType == .steps ? baselines.steps30 : nil

        let scoringDb: String?
        let difficultyDb: String?
        switch metricType {
        case .steps:
            let mode = scoringMode ?? .balanced
            scoringDb = mode.rawValue
            difficultyDb = mode == .balanced ? nil : (difficulty ?? .fair).rawValue
        case .activeCalories:
            scoringDb = nil
            difficultyDb = nil
        }

        let payload = MatchSearchInsert(
            creatorId: creatorId,
            metricType: metricType.rawValue,
            durationDays: durationDays,
            startMode: startMode.rawValue,
            status: "searching",
            creatorBaseline: creatorBaseline,
            scoringMode: scoringDb,
            difficulty: difficultyDb,
            creatorAvg30dSteps: avg30
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
        startMode: ChallengeStartMode,
        scoringMode: MatchScoringModePreference?,
        difficulty: MatchDifficultyPreference?
    ) async throws -> MatchRepositoryDirectChallengeResult {
        let client = try client
        let timezone = TimeZone.current.identifier
        let startsAt = Self.isoFormatter.string(from: Date())

        // Server-side RPC (SECURITY DEFINER) so inserts are not subject to client RLS on `matches`.
        // Challenger is derived from the JWT in Postgres only; `challengerId` is unused for writes.
        _ = challengerId

        let scoringParam: String?
        let difficultyParam: String?
        switch metricType {
        case .steps:
            let mode = scoringMode ?? .balanced
            scoringParam = mode.rawValue
            difficultyParam = mode == .balanced ? nil : (difficulty ?? .fair).rawValue
        case .activeCalories:
            scoringParam = nil
            difficultyParam = nil
        }

        let params = CreateDirectChallengeRPCParams(
            p_recipient_id: recipientId,
            p_metric_type: metricType.rawValue,
            p_duration_days: durationDays,
            p_start_mode: startMode.rawValue,
            p_match_timezone: timezone,
            p_starts_at: startsAt,
            p_scoring_mode: scoringParam,
            p_difficulty: difficultyParam
        )

        let response: PostgrestResponse<CreateDirectChallengeRPCResult> = try await client.rpc(
            "create_direct_challenge",
            params: params
        ).execute()

        let row = response.value
        return MatchRepositoryDirectChallengeResult(matchId: row.match_id, challengeId: row.challenge_id)
    }

    /// Fills `baseline_steps` via RPC when HealthKit aggregates were missing at activation (`balanced` steps matches only).
    func syncBalancedBaselineFloorsIfNeeded(userId: UUID, floorSteps: Int) async {
        guard let client = SupabaseProvider.client else { return }
        let floor = max(3000, floorSteps)
        do {
            let partResp = try await client
                .from("match_participants")
                .select("match_id, baseline_steps")
                .eq("user_id", value: userId.uuidString)
                .execute()
            let rows = jsonRows(from: partResp.data)
            var candidateIds: [UUID] = []
            for row in rows {
                guard let mid = uuid(from: row["match_id"]) else { continue }
                guard double(from: row["baseline_steps"]) == nil else { continue }
                candidateIds.append(mid)
            }
            let uniqueIds = Array(Set(candidateIds))
            guard !uniqueIds.isEmpty else { return }

            let matchResp = try await client
                .from("matches")
                .select("id, state, scoring_mode, metric_type")
                .in("id", values: uniqueIds)
                .execute()
            let matchRows = jsonRows(from: matchResp.data)
            for mRow in matchRows {
                guard
                    let id = uuid(from: mRow["id"]),
                    string(from: mRow["state"]) == "active",
                    string(from: mRow["scoring_mode"]) == "balanced",
                    string(from: mRow["metric_type"]) == "steps"
                else { continue }
                let params = SetBaselineRPCParams(p_match_id: id.uuidString, p_baseline_steps: floor)
                try await client.rpc("set_my_match_participant_baseline", params: params).execute()
            }
        } catch {
            AppLogger.log(
                category: "matchmaking",
                level: .warning,
                message: "syncBalancedBaselineFloorsIfNeeded failed",
                userId: userId,
                metadata: ["error": error.localizedDescription]
            )
        }
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

    private func fetchProfileRows(limit: Int) async throws -> [[String: Any]] {
        let response = try await client
            .from("profiles")
            .select("id, display_name, initials, created_at, user_health_baselines(rolling_avg_7d_steps, rolling_avg_7d_calories, rolling_avg_30d_steps)")
            .order("created_at", ascending: false)
            .limit(limit)
            .execute()
        return jsonRows(from: response.data)
    }

    private func fetchLatestLeaderboardStatsBatch(
        userIds: [UUID]
    ) async throws -> [UUID: (wins: Int?, losses: Int?)] {
        guard !userIds.isEmpty else { return [:] }
        let response = try await client
            .from("leaderboard_entries")
            .select("user_id, wins, losses, week_start")
            .in("user_id", values: userIds.map(\.uuidString))
            .order("week_start", ascending: false)
            .execute()

        var latestStatsByUser: [UUID: (wins: Int?, losses: Int?)] = [:]
        for row in jsonRows(from: response.data) {
            guard let userId = uuid(from: row["user_id"]), latestStatsByUser[userId] == nil else { continue }
            latestStatsByUser[userId] = (int(from: row["wins"]), int(from: row["losses"]))
        }
        return latestStatsByUser
    }

    private func fetchPastMatchCountsBatch(
        currentUserId: UUID,
        opponentIds: [UUID]
    ) async throws -> [UUID: Int] {
        guard !opponentIds.isEmpty else { return [:] }
        let opponentSet = Set(opponentIds)

        let participantResponse = try await client
            .from("match_participants")
            .select("match_id")
            .eq("user_id", value: currentUserId.uuidString)
            .execute()

        let matchIds = Set(jsonRows(from: participantResponse.data).compactMap { uuid(from: $0["match_id"]) })
        guard !matchIds.isEmpty else { return [:] }

        let matchesResponse = try await client
            .from("matches")
            .select("id")
            .in("id", values: matchIds.map(\.uuidString))
            .eq("state", value: "completed")
            .execute()

        let completedMatchIds = Set(jsonRows(from: matchesResponse.data).compactMap { uuid(from: $0["id"]) })
        guard !completedMatchIds.isEmpty else { return [:] }

        let allParticipantsResponse = try await client
            .from("match_participants")
            .select("match_id, user_id")
            .in("match_id", values: completedMatchIds.map(\.uuidString))
            .execute()

        var counts: [UUID: Int] = [:]
        for row in jsonRows(from: allParticipantsResponse.data) {
            guard
                let matchId = uuid(from: row["match_id"]),
                completedMatchIds.contains(matchId),
                let userId = uuid(from: row["user_id"]),
                userId != currentUserId,
                opponentSet.contains(userId)
            else { continue }
            counts[userId, default: 0] += 1
        }
        return counts
    }

    private func fetchLatestTodayStepsBatch(userIds: [UUID]) async throws -> [UUID: Int] {
        guard !userIds.isEmpty else { return [:] }
        let today = Self.calendarFormatter.string(from: Date())
        let response = try await client
            .from("metric_snapshots")
            .select("user_id, value, synced_at")
            .in("user_id", values: userIds.map(\.uuidString))
            .eq("metric_type", value: "steps")
            .eq("source_date", value: today)
            .order("synced_at", ascending: false)
            .execute()

        var latestStepsByUser: [UUID: Int] = [:]
        for row in jsonRows(from: response.data) {
            guard let userId = uuid(from: row["user_id"]), latestStepsByUser[userId] == nil else { continue }
            if let steps = int(from: row["value"]) {
                latestStepsByUser[userId] = steps
            }
        }
        return latestStepsByUser
    }

    private func fetchMyBaselines(userId: UUID) async throws -> (steps7: Double?, calories7: Double?, steps30: Double?) {
        let response = try await client
            .from("user_health_baselines")
            .select("rolling_avg_7d_steps, rolling_avg_7d_calories, rolling_avg_30d_steps")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
        let row = jsonRows(from: response.data).first
        return (
            double(from: row?["rolling_avg_7d_steps"]),
            double(from: row?["rolling_avg_7d_calories"]),
            double(from: row?["rolling_avg_30d_steps"])
        )
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
    let p_scoring_mode: String?
    let p_difficulty: String?
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
        try c.encodeIfPresent(p_scoring_mode, forKey: .p_scoring_mode)
        try c.encodeIfPresent(p_difficulty, forKey: .p_difficulty)
    }

    enum CodingKeys: String, CodingKey {
        case p_recipient_id
        case p_metric_type
        case p_duration_days
        case p_start_mode
        case p_match_timezone
        case p_starts_at
        case p_scoring_mode
        case p_difficulty
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

private struct SetBaselineRPCParams: Encodable, Sendable {
    let p_match_id: String
    let p_baseline_steps: Int

    enum CodingKeys: String, CodingKey {
        case p_match_id
        case p_baseline_steps
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_match_id, forKey: .p_match_id)
        try c.encode(p_baseline_steps, forKey: .p_baseline_steps)
    }
}

/// Params for `public.list_opponent_candidates` (see `supabase/manual_sql/list_opponent_candidates.sql`).
private struct ListOpponentCandidatesRPCParams: Sendable {
    let p_query: String
    let p_metric_type: String
    let p_viewer_local_date: String
    let p_limit: Int
}

extension ListOpponentCandidatesRPCParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_query, forKey: .p_query)
        try c.encode(p_metric_type, forKey: .p_metric_type)
        try c.encode(p_viewer_local_date, forKey: .p_viewer_local_date)
        try c.encode(p_limit, forKey: .p_limit)
    }

    enum CodingKeys: String, CodingKey {
        case p_query
        case p_metric_type
        case p_viewer_local_date
        case p_limit
    }
}

private struct ListOpponentCandidatesRPCRow: Sendable {
    let id: UUID
    let display_name: String?
    let initials: String?
    let wins: Int?
    let losses: Int?
    let today_steps: Int?
    let rolling_avg_7d_steps: Double?
    let rolling_avg_7d_calories: Double?
    let past_match_count: Int?
}

extension ListOpponentCandidatesRPCRow: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        display_name = try c.decodeIfPresent(String.self, forKey: .display_name)
        initials = try c.decodeIfPresent(String.self, forKey: .initials)
        wins = try c.decodeIfPresent(Int.self, forKey: .wins)
        losses = try c.decodeIfPresent(Int.self, forKey: .losses)
        today_steps = try c.decodeIfPresent(Int.self, forKey: .today_steps)
        rolling_avg_7d_steps = try c.decodeIfPresent(Double.self, forKey: .rolling_avg_7d_steps)
        rolling_avg_7d_calories = try c.decodeIfPresent(Double.self, forKey: .rolling_avg_7d_calories)
        past_match_count = try c.decodeIfPresent(Int.self, forKey: .past_match_count)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case display_name
        case initials
        case wins
        case losses
        case today_steps
        case rolling_avg_7d_steps
        case rolling_avg_7d_calories
        case past_match_count
    }
}

private struct MatchSearchInsert: Encodable {
    let creatorId: UUID
    let metricType: String
    let durationDays: Int
    let startMode: String
    let status: String
    let creatorBaseline: Double?
    let scoringMode: String?
    let difficulty: String?
    let creatorAvg30dSteps: Double?

    enum CodingKeys: String, CodingKey {
        case creatorId = "creator_id"
        case metricType = "metric_type"
        case durationDays = "duration_days"
        case startMode = "start_mode"
        case status
        case creatorBaseline = "creator_baseline"
        case scoringMode = "scoring_mode"
        case difficulty
        case creatorAvg30dSteps = "creator_avg_30d_steps"
    }
}

