//
//  LiveMatchRepository.swift
//  FitUp
//
//  Slice 6 data source for Live Match bootstrap + realtime opponent updates.
//

import Combine
import Foundation
import Supabase

enum LiveMatchRepositoryError: LocalizedError {
    case supabaseNotConfigured
    case matchNotFound
    case opponentNotFound
    case matchDayNotFound

    var errorDescription: String? {
        switch self {
        case .supabaseNotConfigured:
            return "Supabase is not configured."
        case .matchNotFound:
            return "This match could not be found."
        case .opponentNotFound:
            return "This live match has no opponent."
        case .matchDayNotFound:
            return "No match day is available for this live match."
        }
    }
}

struct LiveMatchCompetitor: Equatable {
    let id: UUID
    let displayName: String
    let initials: String
    let colorHex: String
}

struct LiveMatchBootstrap: Equatable {
    let matchId: UUID
    let matchDayId: UUID
    let metricType: String
    let durationDays: Int
    let myScore: Int
    let theirScore: Int
    let me: LiveMatchCompetitor
    let opponent: LiveMatchCompetitor
    let opponentTodayTotal: Int

    var seriesLabel: String {
        switch durationDays {
        case 1: return "Daily"
        case 3: return "First to 3"
        case 5: return "Best of 5"
        case 7: return "Best of 7"
        default: return "Best of \(durationDays)"
        }
    }
}

final class LiveMatchRepository {
    private var realtimeChannel: RealtimeChannelV2?
    private var realtimeUpdateTask: Task<Void, Never>?
    private var realtimeInsertTask: Task<Void, Never>?

    deinit {
        stopOpponentRealtime()
    }

    private var client: SupabaseClient {
        get throws {
            guard let client = SupabaseProvider.client else {
                throw LiveMatchRepositoryError.supabaseNotConfigured
            }
            return client
        }
    }

    func loadBootstrap(matchId: UUID, currentUser: Profile) async throws -> LiveMatchBootstrap {
        guard let matchRow = try await fetchMatchRow(matchId: matchId) else {
            throw LiveMatchRepositoryError.matchNotFound
        }
        let metricType = string(from: matchRow["metric_type"]) ?? "steps"
        let durationDays = int(from: matchRow["duration_days"]) ?? 1

        let participantRows = try await fetchParticipantRows(matchId: matchId)
        guard
            let opponentId = participantRows
                .compactMap({ uuid(from: $0["user_id"]) })
                .first(where: { $0 != currentUser.id })
        else {
            throw LiveMatchRepositoryError.opponentNotFound
        }

        let me = LiveMatchCompetitor(
            id: currentUser.id,
            displayName: currentUser.displayName,
            initials: currentUser.initials,
            colorHex: "00FFE0"
        )
        let opponent = try await fetchOpponent(userId: opponentId)

        let dayRows = try await fetchDayRows(matchId: matchId)
        guard let currentDay = resolveCurrentDay(from: dayRows) else {
            throw LiveMatchRepositoryError.matchDayNotFound
        }
        let dayId = currentDay.id

        let dayParticipantRows = try await fetchDayParticipantRows(dayId: dayId)
        let opponentTodayTotal = dayParticipantRows
            .first(where: { uuid(from: $0["user_id"]) == opponentId })
            .flatMap { int(from: $0["metric_total"]) } ?? 0

        let score = deriveScore(
            from: dayRows,
            currentUserId: currentUser.id,
            opponentId: opponentId
        )

        return LiveMatchBootstrap(
            matchId: matchId,
            matchDayId: dayId,
            metricType: metricType,
            durationDays: durationDays,
            myScore: score.myScore,
            theirScore: score.theirScore,
            me: me,
            opponent: opponent,
            opponentTodayTotal: opponentTodayTotal
        )
    }

    func startOpponentRealtime(
        matchDayId: UUID,
        opponentId: UUID,
        onOpponentTotal: @escaping @Sendable (Int) async -> Void
    ) {
        stopOpponentRealtime()
        guard let client = SupabaseProvider.client else { return }

        let channel = client.channel("live-match-\(matchDayId.uuidString)")
        realtimeChannel = channel

        let updateStream = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "match_day_participants",
            filter: .eq("match_day_id", value: matchDayId)
        )
        let insertStream = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "match_day_participants",
            filter: .eq("match_day_id", value: matchDayId)
        )

        Task {
            do {
                try await channel.subscribeWithError()
                AppLogger.log(
                    category: "match_state",
                    level: .debug,
                    message: "live match realtime subscribed",
                    metadata: ["match_day_id": matchDayId.uuidString]
                )
            } catch {
                AppLogger.log(
                    category: "match_state",
                    level: .warning,
                    message: "live match realtime subscribe failed",
                    metadata: ["error": error.localizedDescription]
                )
            }
        }

        realtimeUpdateTask = Task {
            for await action in updateStream {
                guard
                    let rowUserId = uuid(from: action.record["user_id"]),
                    rowUserId == opponentId
                else {
                    continue
                }
                let total = int(from: action.record["metric_total"]) ?? 0
                await onOpponentTotal(total)
            }
        }

        realtimeInsertTask = Task {
            for await action in insertStream {
                guard
                    let rowUserId = uuid(from: action.record["user_id"]),
                    rowUserId == opponentId
                else {
                    continue
                }
                let total = int(from: action.record["metric_total"]) ?? 0
                await onOpponentTotal(total)
            }
        }
    }

    func stopOpponentRealtime() {
        realtimeUpdateTask?.cancel()
        realtimeUpdateTask = nil

        realtimeInsertTask?.cancel()
        realtimeInsertTask = nil

        guard let channel = realtimeChannel else { return }
        realtimeChannel = nil

        guard let client = SupabaseProvider.client else { return }
        Task {
            await client.removeChannel(channel)
            AppLogger.log(category: "match_state", level: .debug, message: "live match realtime unsubscribed")
        }
    }

    private func fetchMatchRow(matchId: UUID) async throws -> [String: Any]? {
        let response = try await client
            .from("matches")
            .select("id, metric_type, duration_days")
            .eq("id", value: matchId.uuidString)
            .limit(1)
            .execute()
        return jsonRows(from: response.data).first
    }

    private func fetchParticipantRows(matchId: UUID) async throws -> [[String: Any]] {
        let response = try await client
            .from("match_participants")
            .select("user_id")
            .eq("match_id", value: matchId.uuidString)
            .execute()
        return jsonRows(from: response.data)
    }

    private func fetchOpponent(userId: UUID) async throws -> LiveMatchCompetitor {
        let response = try await client
            .from("profiles")
            .select("id, display_name, initials")
            .eq("id", value: userId.uuidString)
            .limit(1)
            .execute()
        let row = jsonRows(from: response.data).first
        return LiveMatchCompetitor(
            id: userId,
            displayName: string(from: row?["display_name"]) ?? "Opponent",
            initials: string(from: row?["initials"]) ?? "OP",
            colorHex: colorHex(for: userId)
        )
    }

    private func fetchDayRows(matchId: UUID) async throws -> [[String: Any]] {
        let response = try await client
            .from("match_days")
            .select("id, day_number, winner_user_id, is_void, calendar_date")
            .eq("match_id", value: matchId.uuidString)
            .order("day_number", ascending: true)
            .execute()
        return jsonRows(from: response.data)
    }

    private func fetchDayParticipantRows(dayId: UUID) async throws -> [[String: Any]] {
        let response = try await client
            .from("match_day_participants")
            .select("user_id, metric_total")
            .eq("match_day_id", value: dayId.uuidString)
            .execute()
        return jsonRows(from: response.data)
    }

    private func resolveCurrentDay(from rows: [[String: Any]]) -> (id: UUID, dayNumber: Int)? {
        let normalizedRows = rows.compactMap { row -> (id: UUID, dayNumber: Int, date: Date?)? in
            guard
                let id = uuid(from: row["id"]),
                let dayNumber = int(from: row["day_number"])
            else {
                return nil
            }
            return (id, dayNumber, dateFromCalendarString(row["calendar_date"]))
        }

        if let todayRow = normalizedRows.first(where: { isToday($0.date) }) {
            return (todayRow.id, todayRow.dayNumber)
        }
        guard let latest = normalizedRows.max(by: { $0.dayNumber < $1.dayNumber }) else {
            return nil
        }
        return (latest.id, latest.dayNumber)
    }

    private func deriveScore(
        from rows: [[String: Any]],
        currentUserId: UUID,
        opponentId: UUID
    ) -> (myScore: Int, theirScore: Int) {
        var myScore = 0
        var theirScore = 0

        for row in rows {
            let isVoid = bool(from: row["is_void"]) == true
            if isVoid { continue }

            guard let winnerId = uuid(from: row["winner_user_id"]) else { continue }
            if winnerId == currentUserId {
                myScore += 1
            } else if winnerId == opponentId {
                theirScore += 1
            }
        }
        return (myScore, theirScore)
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
            let rows = object as? [[String: Any]]
        else {
            return []
        }
        return rows
    }

    private func uuid(from value: Any?) -> UUID? {
        if let uuid = value as? UUID { return uuid }
        if let string = value as? String { return UUID(uuidString: string) }
        if let anyJSON = value as? AnyJSON {
            switch anyJSON {
            case let .string(string):
                return UUID(uuidString: string)
            default:
                return nil
            }
        }
        return nil
    }

    private func string(from value: Any?) -> String? {
        if let string = value as? String { return string }
        if let anyJSON = value as? AnyJSON {
            return anyJSON.stringValue
        }
        return nil
    }

    private func int(from value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue.rounded()) }
        if let stringValue = value as? String, let doubleValue = Double(stringValue) {
            return Int(doubleValue.rounded())
        }
        if let anyJSON = value as? AnyJSON {
            switch anyJSON {
            case let .integer(value):
                return value
            case let .double(value):
                return Int(value.rounded())
            case let .string(value):
                if let doubleValue = Double(value) {
                    return Int(doubleValue.rounded())
                }
                return nil
            default:
                return nil
            }
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

    private static let calendarDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
