//
//  UserIntradayStepTicksRepository.swift
//  FitUp
//
//  Slice 3 — Supabase RPCs for `user_intraday_step_ticks` (append + fetch opponent series).
//  SQL: `supabase/manual_sql/intraday_step_ticks_slice2_rpcs.sql`
//

import Foundation
import Supabase

/// One sample from `fetch_opponent_intraday_step_ticks` (writer’s cumulative steps that day).
struct OpponentIntradayStepTick: Equatable, Sendable, Identifiable {
    let id: UUID
    let cumulativeSteps: Int
    let recordedAt: Date
    let timezoneIdentifier: String
    let calendarDateISO: String
    let createdAt: Date

    fileprivate init(
        id: UUID,
        cumulativeSteps: Int,
        recordedAt: Date,
        timezoneIdentifier: String,
        calendarDateISO: String,
        createdAt: Date
    ) {
        self.id = id
        self.cumulativeSteps = cumulativeSteps
        self.recordedAt = recordedAt
        self.timezoneIdentifier = timezoneIdentifier
        self.calendarDateISO = calendarDateISO
        self.createdAt = createdAt
    }
}

/// One row from `fetch_latest_opponent_intraday_ticks_for_active_matches` (Slice 8).
struct OpponentLatestIntradayStepTickSummary: Equatable, Sendable {
    let opponentProfileId: UUID
    let cumulativeSteps: Int
    let recordedAt: Date
}

enum UserIntradayStepTicksRepositoryError: LocalizedError {
    case supabaseNotConfigured
    case unexpectedAppendResponse
    case unexpectedPruneResponse

    var errorDescription: String? {
        switch self {
        case .supabaseNotConfigured:
            return "Supabase is not configured."
        case .unexpectedAppendResponse:
            return "Unexpected response from append_user_intraday_step_tick."
        case .unexpectedPruneResponse:
            return "Unexpected response from prune_user_intraday_step_tick_day."
        }
    }
}

final class UserIntradayStepTicksRepository {
    private var client: SupabaseClient {
        get throws {
            guard let client = SupabaseProvider.client else {
                throw UserIntradayStepTicksRepositoryError.supabaseNotConfigured
            }
            return client
        }
    }

    // MARK: - Append (insert + server-side prune to ≤30 / day)

    /// Inserts one tick for the signed-in user and returns the new row id. Server prunes that calendar day to at most 30 rows.
    func appendTick(
        calendarDate: Date,
        profileTimeZoneIdentifier: String?,
        cumulativeSteps: Int,
        recordedAt: Date = Date()
    ) async throws -> UUID {
        let tzId = (profileTimeZoneIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? TimeZone.current.identifier
        let calendarDateStr = HomeRepository.formatProfileCalendarDate(calendarDate, profileTimeZoneIdentifier: tzId)
        let recordedAtStr = Self.iso8601.string(from: recordedAt)

        let params = AppendUserIntradayStepTickRPCParams(
            p_calendar_date: calendarDateStr,
            p_timezone_identifier: tzId,
            p_cumulative_steps: cumulativeSteps,
            p_recorded_at: recordedAtStr
        )

        let c = try client
        let response = try await c.rpc("append_user_intraday_step_tick", params: params).execute()
        return try Self.decodeScalarUUID(from: response.data)
    }

    /// Prune-only repair for the signed-in user for one calendar day (returns rows removed).
    func pruneDay(calendarDate: Date, profileTimeZoneIdentifier: String?) async throws -> Int {
        let tzId = (profileTimeZoneIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? TimeZone.current.identifier
        let calendarDateStr = HomeRepository.formatProfileCalendarDate(calendarDate, profileTimeZoneIdentifier: tzId)

        let params = PruneUserIntradayStepTickDayRPCParams(p_calendar_date: calendarDateStr)
        let c = try client
        let response = try await c.rpc("prune_user_intraday_step_tick_day", params: params).execute()
        return try Self.decodeScalarInt(from: response.data)
    }

    // MARK: - Fetch opponent series

    /// Ticks for an active-match opponent on a writer-local calendar day. Empty if not permitted or no rows.
    func fetchOpponentTicks(
        opponentProfileId: UUID,
        calendarDate: Date,
        opponentTimezoneIdentifier: String,
        sinceRecordedAt: Date? = nil
    ) async throws -> [OpponentIntradayStepTick] {
        let calStr = HomeRepository.formatProfileCalendarDate(
            calendarDate,
            profileTimeZoneIdentifier: opponentTimezoneIdentifier
        )
        let sinceStr = sinceRecordedAt.map { Self.iso8601.string(from: $0) }

        let params = FetchOpponentIntradayStepTicksRPCParams(
            p_opponent_profile_id: opponentProfileId,
            p_calendar_date: calStr,
            p_since: sinceStr
        )

        let c = try client
        let response: PostgrestResponse<[FetchOpponentIntradayStepTicksRPCRow]> = try await c
            .rpc("fetch_opponent_intraday_step_ticks", params: params)
            .execute()

        return response.value.map { $0.toDomain() }
    }

    /// Latest tick per opponent for all active accepted matches (Slice 8). Empty if none or RPC not deployed.
    func fetchLatestOpponentTicksForActiveMatches(
        calendarDate: Date,
        viewerTimezoneIdentifier: String?
    ) async throws -> [OpponentLatestIntradayStepTickSummary] {
        let tzId = (viewerTimezoneIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
            ?? TimeZone.current.identifier
        let calendarDateStr = HomeRepository.formatProfileCalendarDate(calendarDate, profileTimeZoneIdentifier: tzId)

        let params = FetchLatestOpponentIntradayTicksForActiveMatchesRPCParams(p_calendar_date: calendarDateStr)
        let c = try client
        let response: PostgrestResponse<[FetchLatestOpponentIntradayTicksForActiveMatchesRPCRow]> = try await c
            . rpc("fetch_latest_opponent_intraday_ticks_for_active_matches", params: params)
            .execute()

        return response.value.map { $0.toDomain() }
    }

    // MARK: - Decoding

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static func decodeScalarUUID(from data: Data) throws -> UUID {
        do {
            return try JSONDecoder().decode(UUID.self, from: data)
        } catch {
            if let s = String(data: data, encoding: .utf8),
               let u = UUID(uuidString: s.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\""))) {
                return u
            }
            throw UserIntradayStepTicksRepositoryError.unexpectedAppendResponse
        }
    }

    private static func decodeScalarInt(from data: Data) throws -> Int {
        do {
            return try JSONDecoder().decode(Int.self, from: data)
        } catch {
            if let s = String(data: data, encoding: .utf8),
               let i = Int(s.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return i
            }
            throw UserIntradayStepTicksRepositoryError.unexpectedPruneResponse
        }
    }
}

// MARK: - RPC params / rows

private struct AppendUserIntradayStepTickRPCParams: Sendable {
    let p_calendar_date: String
    let p_timezone_identifier: String
    let p_cumulative_steps: Int
    let p_recorded_at: String
}

extension AppendUserIntradayStepTickRPCParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_calendar_date, forKey: .p_calendar_date)
        try c.encode(p_timezone_identifier, forKey: .p_timezone_identifier)
        try c.encode(p_cumulative_steps, forKey: .p_cumulative_steps)
        try c.encode(p_recorded_at, forKey: .p_recorded_at)
    }

    enum CodingKeys: String, CodingKey {
        case p_calendar_date
        case p_timezone_identifier
        case p_cumulative_steps
        case p_recorded_at
    }
}

private struct PruneUserIntradayStepTickDayRPCParams: Sendable {
    let p_calendar_date: String
}

extension PruneUserIntradayStepTickDayRPCParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_calendar_date, forKey: .p_calendar_date)
    }

    enum CodingKeys: String, CodingKey {
        case p_calendar_date
    }
}

private struct FetchOpponentIntradayStepTicksRPCParams: Sendable {
    let p_opponent_profile_id: UUID
    let p_calendar_date: String
    let p_since: String?
}

extension FetchOpponentIntradayStepTicksRPCParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_opponent_profile_id, forKey: .p_opponent_profile_id)
        try c.encode(p_calendar_date, forKey: .p_calendar_date)
        try c.encodeIfPresent(p_since, forKey: .p_since)
    }

    enum CodingKeys: String, CodingKey {
        case p_opponent_profile_id
        case p_calendar_date
        case p_since
    }
}

private struct FetchOpponentIntradayStepTicksRPCRow: Decodable, Sendable {
    let tick_id: UUID
    let cumulative_steps: Int
    let recorded_at: Date
    let timezone_identifier: String
    let calendar_date: String
    let created_at: Date

    func toDomain() -> OpponentIntradayStepTick {
        OpponentIntradayStepTick(
            id: tick_id,
            cumulativeSteps: cumulative_steps,
            recordedAt: recorded_at,
            timezoneIdentifier: timezone_identifier,
            calendarDateISO: calendar_date,
            createdAt: created_at
        )
    }
}

private struct FetchLatestOpponentIntradayTicksForActiveMatchesRPCParams: Sendable {
    let p_calendar_date: String
}

extension FetchLatestOpponentIntradayTicksForActiveMatchesRPCParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_calendar_date, forKey: .p_calendar_date)
    }

    enum CodingKeys: String, CodingKey {
        case p_calendar_date
    }
}

private struct FetchLatestOpponentIntradayTicksForActiveMatchesRPCRow: Decodable, Sendable {
    let opponent_profile_id: UUID
    let cumulative_steps: Int
    let recorded_at: Date

    func toDomain() -> OpponentLatestIntradayStepTickSummary {
        OpponentLatestIntradayStepTickSummary(
            opponentProfileId: opponent_profile_id,
            cumulativeSteps: cumulative_steps,
            recordedAt: recorded_at
        )
    }
}
