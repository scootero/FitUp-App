//
//  MatchRepository.swift
//  FitUp
//
//  Slice 4 challenge flow reads/writes for matchmaking and direct challenges.
//

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

    @discardableResult
    func createQuickMatchSearch(
        creatorId: UUID,
        metricType: ChallengeMetricType,
        durationDays: Int,
        startMode: ChallengeStartMode
    ) async throws -> UUID {
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
        let timezone = TimeZone.current.identifier
        let startsAt = Self.isoFormatter.string(from: Date())

        let matchPayload = MatchInsert(
            matchType: "direct_challenge",
            metricType: metricType.rawValue,
            durationDays: durationDays,
            startMode: startMode.rawValue,
            state: "pending",
            matchTimezone: timezone,
            startsAt: startsAt
        )

        let matchResponse = try await client
            .from("matches")
            .insert(matchPayload)
            .select("id")
            .execute()

        guard let matchId = jsonRows(from: matchResponse.data).first.flatMap({ uuid(from: $0["id"]) }) else {
            throw MatchRepositoryError.insertFailed
        }

        let acceptedAt = Self.isoFormatter.string(from: Date())
        let participants: [MatchParticipantInsert] = [
            .init(
                matchId: matchId,
                userId: challengerId,
                acceptedAt: acceptedAt,
                role: "challenger",
                joinedVia: "direct_challenge"
            ),
            .init(
                matchId: matchId,
                userId: recipientId,
                acceptedAt: nil,
                role: "opponent",
                joinedVia: "direct_challenge"
            ),
        ]

        try await client
            .from("match_participants")
            .insert(participants)
            .execute()

        let challengeResponse = try await client
            .from("direct_challenges")
            .insert(
                DirectChallengeInsert(
                    challengerId: challengerId,
                    recipientId: recipientId,
                    matchId: matchId,
                    status: "pending"
                )
            )
            .select("id")
            .execute()

        guard let challengeId = jsonRows(from: challengeResponse.data).first.flatMap({ uuid(from: $0["id"]) }) else {
            throw MatchRepositoryError.insertFailed
        }

        return MatchRepositoryDirectChallengeResult(matchId: matchId, challengeId: challengeId)
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

private struct MatchInsert: Encodable {
    let matchType: String
    let metricType: String
    let durationDays: Int
    let startMode: String
    let state: String
    let matchTimezone: String
    let startsAt: String

    enum CodingKeys: String, CodingKey {
        case matchType = "match_type"
        case metricType = "metric_type"
        case durationDays = "duration_days"
        case startMode = "start_mode"
        case state
        case matchTimezone = "match_timezone"
        case startsAt = "starts_at"
    }
}

private struct MatchParticipantInsert: Encodable {
    let matchId: UUID
    let userId: UUID
    let acceptedAt: String?
    let role: String
    let joinedVia: String

    enum CodingKeys: String, CodingKey {
        case matchId = "match_id"
        case userId = "user_id"
        case acceptedAt = "accepted_at"
        case role
        case joinedVia = "joined_via"
    }
}

private struct DirectChallengeInsert: Encodable {
    let challengerId: UUID
    let recipientId: UUID
    let matchId: UUID
    let status: String

    enum CodingKeys: String, CodingKey {
        case challengerId = "challenger_id"
        case recipientId = "recipient_id"
        case matchId = "match_id"
        case status
    }
}
