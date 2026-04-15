//
//  MatchDetailsRepository.swift
//  FitUp
//
//  Slice 5 match details reads and live refresh loop.
//

import Combine
import Foundation
import Supabase

enum MatchDetailsRepositoryError: LocalizedError {
    case supabaseNotConfigured
    case matchNotFound

    var errorDescription: String? {
        switch self {
        case .supabaseNotConfigured:
            return "Supabase is not configured."
        case .matchNotFound:
            return "The selected match could not be loaded."
        }
    }
}

enum MatchDetailsState: String, Codable {
    case pending
    case active
    case completed
}

struct MatchDetailsCompetitor: Equatable, Codable {
    let id: UUID
    let displayName: String
    let initials: String
    let colorHex: String
}

struct MatchDetailsDayRow: Identifiable, Equatable, Codable {
    let dayNumber: Int
    let dayLabel: String
    let calendarDate: Date?
    let myValue: Int
    let theirValue: Int
    let isFinalized: Bool
    let isToday: Bool
    /// True when this match day is after the viewer's local calendar today.
    let isFuture: Bool
    /// Opponent's `last_updated_at` on `match_day_participants` for this day (set when `isToday`).
    let opponentLastUpdatedAt: Date?
    let myWon: Bool?
    let isTie: Bool

    var id: Int { dayNumber }

    func withMyValue(_ value: Int) -> MatchDetailsDayRow {
        MatchDetailsDayRow(
            dayNumber: dayNumber,
            dayLabel: dayLabel,
            calendarDate: calendarDate,
            myValue: value,
            theirValue: theirValue,
            isFinalized: isFinalized,
            isToday: isToday,
            isFuture: isFuture,
            opponentLastUpdatedAt: opponentLastUpdatedAt,
            myWon: myWon,
            isTie: isTie
        )
    }
}

struct MatchDetailsSnapshot: Equatable, Codable {
    let matchId: UUID
    let state: MatchDetailsState
    let metricType: String
    let durationDays: Int
    let challengeId: UUID?
    let me: MatchDetailsCompetitor
    let opponent: MatchDetailsCompetitor
    let myAcceptedAt: Date?
    let opponentAcceptedAt: Date?
    let myScore: Int
    let theirScore: Int
    let myToday: Int
    let theirToday: Int
    let isWinning: Bool
    let dayRows: [MatchDetailsDayRow]

    var sportLabel: String {
        metricType == "active_calories" ? "Calories" : "Steps"
    }

    var seriesLabel: String {
        switch durationDays {
        case 1: return "Daily"
        case 3: return "First to 3"
        case 5: return "Best of 5"
        case 7: return "Best of 7"
        default: return "Best of \(durationDays)"
        }
    }

    var canRespondToPending: Bool {
        state == .pending && myAcceptedAt == nil
    }
}

/// Extended load payload for Match Details v2 (meta + opponent sync time).
struct MatchDetailBundle: Equatable {
    let snapshot: MatchDetailsSnapshot
    let opponentTodayLastSyncedAt: Date?
    let startsAt: Date?
    let endsAt: Date?
    let matchTimezone: String
}

final class MatchDetailsRepository {
    private var realtimeChannel: RealtimeChannelV2?
    private var participantUpdateTask: Task<Void, Never>?
    private var participantInsertTask: Task<Void, Never>?
    private var matchStateTask: Task<Void, Never>?

    deinit {
        stopLiveRefresh()
    }

    private var client: SupabaseClient {
        get throws {
            guard let client = SupabaseProvider.client else {
                throw MatchDetailsRepositoryError.supabaseNotConfigured
            }
            return client
        }
    }

    func loadSnapshot(matchId: UUID, currentUser: Profile) async throws -> MatchDetailsSnapshot {
        try await loadMatchDetailBundle(matchId: matchId, currentUser: currentUser).snapshot
    }

    func loadMatchDetailBundle(matchId: UUID, currentUser: Profile) async throws -> MatchDetailBundle {
        guard let matchRow = try await fetchMatchRow(matchId: matchId) else {
            throw MatchDetailsRepositoryError.matchNotFound
        }
        let state = MatchDetailsState(rawValue: string(from: matchRow["state"]) ?? "pending") ?? .pending
        let metricType = string(from: matchRow["metric_type"]) ?? "steps"
        let durationDays = int(from: matchRow["duration_days"]) ?? 1
        let startsAt = date(from: matchRow["starts_at"])
        let endsAt = date(from: matchRow["ends_at"])
        let matchTimezone = string(from: matchRow["match_timezone"]) ?? "America/Chicago"

        let participantRows = try await fetchParticipantRows(matchId: matchId)
        let myAcceptedAt = participantRows
            .first(where: { uuid(from: $0["user_id"]) == currentUser.id })
            .flatMap { date(from: $0["accepted_at"]) }
        let opponentId = participantRows
            .compactMap { uuid(from: $0["user_id"]) }
            .first(where: { $0 != currentUser.id })

        let resolvedOpponentId = opponentId ?? UUID()
        let opponent = try await fetchOpponent(userId: resolvedOpponentId)
        let opponentAcceptedAt = participantRows
            .first(where: { uuid(from: $0["user_id"]) == resolvedOpponentId })
            .flatMap { date(from: $0["accepted_at"]) }

        let me = MatchDetailsCompetitor(
            id: currentUser.id,
            displayName: currentUser.displayName,
            initials: currentUser.initials,
            colorHex: "00FFE0"
        )

        let challengeId = try await fetchChallengeId(matchId: matchId)
        let rawDayRows = try await fetchDayRows(matchId: matchId)
        let derivedDayRows = try await deriveDayRows(
            rawDayRows: rawDayRows,
            currentUserId: currentUser.id,
            opponentId: resolvedOpponentId
        )
        let visibleDayRows = visibleRows(from: derivedDayRows)
        let rowsForScoring = visibleDayRows.isEmpty ? derivedDayRows : visibleDayRows
        let scoreTuple = deriveScore(from: rowsForScoring)
        let todayTotals = deriveTodayTotals(from: rowsForScoring)
        let opponentTodayLastSyncedAt = rowsForScoring.first(where: { $0.isToday })?.opponentLastUpdatedAt

        let snapshot = MatchDetailsSnapshot(
            matchId: matchId,
            state: state,
            metricType: metricType,
            durationDays: durationDays,
            challengeId: challengeId,
            me: me,
            opponent: opponent,
            myAcceptedAt: myAcceptedAt,
            opponentAcceptedAt: opponentAcceptedAt,
            myScore: scoreTuple.myScore,
            theirScore: scoreTuple.theirScore,
            myToday: todayTotals.myToday,
            theirToday: todayTotals.theirToday,
            isWinning: state == .completed ? scoreTuple.myScore >= scoreTuple.theirScore : todayTotals.myToday >= todayTotals.theirToday,
            dayRows: rowsForScoring
        )

        return MatchDetailBundle(
            snapshot: snapshot,
            opponentTodayLastSyncedAt: opponentTodayLastSyncedAt,
            startsAt: startsAt,
            endsAt: endsAt,
            matchTimezone: matchTimezone
        )
    }

    func startLiveRefresh(matchId: UUID, onChange: @escaping @Sendable () async -> Void) {
        stopLiveRefresh()
        guard let client = SupabaseProvider.client else { return }

        let channel = client.channel("match-details-\(matchId.uuidString)")
        realtimeChannel = channel

        let participantUpdateStream = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "match_day_participants"
        )
        let participantInsertStream = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "match_day_participants"
        )
        let matchUpdateStream = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "matches",
            filter: .eq("id", value: matchId)
        )

        Task {
            do {
                try await channel.subscribeWithError()
                AppLogger.log(
                    category: "match_state",
                    level: .debug,
                    message: "match details realtime subscribed",
                    metadata: ["match_id": matchId.uuidString]
                )
            } catch {
                AppLogger.log(
                    category: "match_state",
                    level: .warning,
                    message: "match details realtime subscribe failed",
                    metadata: ["error": error.localizedDescription]
                )
            }
        }

        participantUpdateTask = Task {
            for await _ in participantUpdateStream {
                await onChange()
            }
        }
        participantInsertTask = Task {
            for await _ in participantInsertStream {
                await onChange()
            }
        }
        matchStateTask = Task {
            for await _ in matchUpdateStream {
                await onChange()
            }
        }
    }

    func stopLiveRefresh() {
        participantUpdateTask?.cancel()
        participantUpdateTask = nil
        participantInsertTask?.cancel()
        participantInsertTask = nil
        matchStateTask?.cancel()
        matchStateTask = nil

        guard let channel = realtimeChannel else { return }
        realtimeChannel = nil

        guard let client = SupabaseProvider.client else { return }
        Task {
            await client.removeChannel(channel)
            AppLogger.log(category: "match_state", level: .debug, message: "match details realtime unsubscribed")
        }
    }

    private func fetchMatchRow(matchId: UUID) async throws -> [String: Any]? {
        let response = try await client
            .from("matches")
            .select("id, state, metric_type, duration_days, starts_at, ends_at, match_timezone")
            .eq("id", value: matchId.uuidString)
            .limit(1)
            .execute()
        return jsonRows(from: response.data).first
    }

    private func fetchParticipantRows(matchId: UUID) async throws -> [[String: Any]] {
        let response = try await client
            .from("match_participants")
            .select("user_id, accepted_at")
            .eq("match_id", value: matchId.uuidString)
            .execute()
        return jsonRows(from: response.data)
    }

    private func fetchChallengeId(matchId: UUID) async throws -> UUID? {
        let response = try await client
            .from("direct_challenges")
            .select("id")
            .eq("match_id", value: matchId.uuidString)
            .limit(1)
            .execute()
        return jsonRows(from: response.data).first.flatMap { uuid(from: $0["id"]) }
    }

    private func fetchDayRows(matchId: UUID) async throws -> [[String: Any]] {
        let response = try await client
            .from("match_days")
            .select("id, day_number, status, winner_user_id, is_void, calendar_date")
            .eq("match_id", value: matchId.uuidString)
            .order("day_number", ascending: true)
            .execute()
        return jsonRows(from: response.data)
    }

    private func fetchOpponent(userId: UUID) async throws -> MatchDetailsCompetitor {
        let response = try await client
            .from("profiles")
            .select("id, display_name, initials")
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
        let row = jsonRows(from: response.data).first
        return MatchDetailsCompetitor(
            id: userId,
            displayName: string(from: row?["display_name"]) ?? "Opponent",
            initials: string(from: row?["initials"]) ?? "OP",
            colorHex: colorHex(for: userId)
        )
    }

    private func deriveDayRows(
        rawDayRows: [[String: Any]],
        currentUserId: UUID,
        opponentId: UUID
    ) async throws -> [MatchDetailsDayRow] {
        var rows: [MatchDetailsDayRow] = []
        for rawDayRow in rawDayRows {
            guard
                let dayId = uuid(from: rawDayRow["id"]),
                let dayNumber = int(from: rawDayRow["day_number"])
            else {
                continue
            }

            let participantRows = try await fetchDayParticipantRows(dayId: dayId)
            let isFinalized = string(from: rawDayRow["status"]) == "finalized"
            let winnerUserId = uuid(from: rawDayRow["winner_user_id"])
            let isVoid = bool(from: rawDayRow["is_void"]) == true
            let calendarDate = dateFromCalendarString(rawDayRow["calendar_date"])

            let myParticipant = participantRows.first(where: { uuid(from: $0["user_id"]) == currentUserId })
            let theirParticipant = participantRows.first(where: { uuid(from: $0["user_id"]) == opponentId })

            let myLive = int(from: myParticipant?["metric_total"]) ?? 0
            let theirLive = int(from: theirParticipant?["metric_total"]) ?? 0
            let myFinalized = int(from: myParticipant?["finalized_value"])
            let theirFinalized = int(from: theirParticipant?["finalized_value"])
            let theirLastUpdated = date(from: theirParticipant?["last_updated_at"])

            let myValue = isFinalized ? (myFinalized ?? myLive) : myLive
            let theirValue = isFinalized ? (theirFinalized ?? theirLive) : theirLive

            let todayStart = Calendar.current.startOfDay(for: Date())
            let isFutureDay: Bool = {
                guard let calendarDate else { return false }
                return Calendar.current.startOfDay(for: calendarDate) > todayStart
            }()

            let myWon: Bool?
            if isVoid {
                myWon = nil
            } else if winnerUserId == currentUserId {
                myWon = true
            } else if winnerUserId == opponentId {
                myWon = false
            } else {
                myWon = nil
            }

            let isTodayRow = isToday(calendarDate)
            rows.append(
                MatchDetailsDayRow(
                    dayNumber: dayNumber,
                    dayLabel: dayLabel(for: calendarDate, fallback: dayNumber),
                    calendarDate: calendarDate,
                    myValue: myValue,
                    theirValue: theirValue,
                    isFinalized: isFinalized,
                    isToday: isTodayRow,
                    isFuture: isFutureDay,
                    opponentLastUpdatedAt: isTodayRow ? theirLastUpdated : nil,
                    myWon: myWon,
                    isTie: isVoid || (isFinalized && winnerUserId == nil)
                )
            )
        }

        return rows.sorted(by: { $0.dayNumber < $1.dayNumber })
    }

    private func fetchDayParticipantRows(dayId: UUID) async throws -> [[String: Any]] {
        let response = try await client
            .from("match_day_participants")
            .select("user_id, metric_total, finalized_value, last_updated_at")
            .eq("match_day_id", value: dayId.uuidString)
            .execute()
        return jsonRows(from: response.data)
    }

    private func visibleRows(from rows: [MatchDetailsDayRow]) -> [MatchDetailsDayRow] {
        guard !rows.isEmpty else { return [] }
        let today = Calendar.current.startOfDay(for: Date())
        let filtered = rows.filter { row in
            if row.isFinalized || row.isToday { return true }
            guard let rowDate = row.calendarDate else { return false }
            return Calendar.current.startOfDay(for: rowDate) <= today
        }
        return filtered.isEmpty ? rows : filtered
    }

    private func deriveScore(from rows: [MatchDetailsDayRow]) -> (myScore: Int, theirScore: Int) {
        var myScore = 0
        var theirScore = 0
        for row in rows where row.isFinalized && !row.isTie {
            if row.myWon == true {
                myScore += 1
            } else if row.myWon == false {
                theirScore += 1
            }
        }
        return (myScore, theirScore)
    }

    private func deriveTodayTotals(from rows: [MatchDetailsDayRow]) -> (myToday: Int, theirToday: Int) {
        if let today = rows.first(where: { $0.isToday }) {
            return (today.myValue, today.theirValue)
        }
        guard let latest = rows.last else { return (0, 0) }
        return (latest.myValue, latest.theirValue)
    }

    private func dayLabel(for date: Date?, fallback dayNumber: Int) -> String {
        guard let date else { return "D\(dayNumber)" }
        let symbol = Self.weekdayFormatter.string(from: date)
        return symbol.prefix(1).uppercased()
    }

    private func isToday(_ date: Date?) -> Bool {
        guard let date else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private func dateFromCalendarString(_ value: Any?) -> Date? {
        guard let value = value as? String else { return nil }
        return Self.calendarDateFormatter.date(from: value)
    }

    private func colorHex(for userId: UUID) -> String {
        let palette = ["00AAFF", "FF6200", "BF5FFF", "FFE000", "39FF14", "FF2D9B"]
        let index = abs(userId.hashValue) % palette.count
        return palette[index]
    }

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

    private func bool(from value: Any?) -> Bool? {
        if let boolValue = value as? Bool { return boolValue }
        if let intValue = value as? Int { return intValue != 0 }
        if let stringValue = value as? String {
            return (stringValue as NSString).boolValue
        }
        return nil
    }

    private func date(from value: Any?) -> Date? {
        if let dateValue = value as? Date { return dateValue }
        if let stringValue = value as? String {
            if let parsed = Self.isoFormatter.date(from: stringValue) {
                return parsed
            }
            return ISO8601DateFormatter().date(from: stringValue)
        }
        return nil
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let calendarDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE"
        return formatter
    }()
}
