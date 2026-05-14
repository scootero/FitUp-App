//
//  LeaderboardRepository.swift
//  FitUp
//
//  Slice 11 — Weekly leaderboard reads (global + friends) via
//  `weekly_steps_leaderboard_from_daily_totals` (`user_daily_step_totals`).
//

import Combine
import Foundation
import Supabase

struct WeeklyStepsLeaderboardRecord: Equatable {
    let userId: UUID
    let weekStart: Date?
    let weekEnd: Date?
    let totalSteps: Int
    let rank: Int
    let displayName: String
    let initials: String
}

final class LeaderboardRepository {
    enum LeaderboardScope: String {
        case global
        case friends
    }

    private var client: SupabaseClient {
        get throws {
            guard let client = SupabaseProvider.client else {
                throw ProfileRepositoryError.supabaseNotConfigured
            }
            return client
        }
    }

    /// Matches `weekStartIsoDate` in `supabase/functions/update-leaderboard` (UTC Monday).
    static func weekStartUTC(containing date: Date = Date()) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        guard let utcDay = cal.date(from: comps) else { return date }
        let weekday = cal.component(.weekday, from: utcDay)
        let jsWeekday = weekday == 1 ? 0 : weekday - 1
        let offsetFromMonday = (jsWeekday + 6) % 7
        return cal.date(byAdding: .day, value: -offsetFromMonday, to: utcDay) ?? utcDay
    }

    /// `yyyy-MM-dd` in UTC for Supabase `date` column (matches Edge Function `weekStartIsoDate`).
    static func weekStartISOString(from weekStart: Date) -> String {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        let comps = cal.dateComponents([.year, .month, .day], from: weekStart)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    /// Parses `yyyy-MM-dd` used for `p_week_start` / cache keys (UTC Monday).
    static func dateFromWeekStartISOString(_ value: String) -> Date? {
        isoDayFormatter.date(from: value)
    }

    // MARK: - Public

    func fetchWeeklyStepsLeaderboard(
        weekStart: Date,
        scope: LeaderboardScope,
        limit: Int = 100
    ) async throws -> [WeeklyStepsLeaderboardRecord] {
        let c = try client
        let params = WeeklyStepsLeaderboardRPCParams(
            p_week_start: Self.weekStartISOString(from: weekStart),
            p_limit: max(1, limit),
            p_scope: scope.rawValue
        )
        let response: PostgrestResponse<[WeeklyStepsLeaderboardRPCRow]> = try await c
            .rpc("weekly_steps_leaderboard_from_daily_totals", params: params)
            .execute()
        return response.value.map { row in
            let safeName = row.display_name.trimmingCharacters(in: .whitespacesAndNewlines)
            let safeInitials = row.initials.trimmingCharacters(in: .whitespacesAndNewlines)
            return WeeklyStepsLeaderboardRecord(
                userId: row.user_id,
                weekStart: Self.dateFromISODate(row.week_start),
                weekEnd: Self.dateFromISODate(row.week_end),
                totalSteps: Int(clamping: row.total_steps),
                rank: row.rank,
                displayName: safeName.isEmpty ? "Player" : safeName,
                initials: safeInitials.isEmpty ? "PL" : safeInitials.uppercased()
            )
        }
    }

    /// Opponents = distinct other `user_id` on any `match_participants` row sharing a match with the current user.
    func fetchOpponentProfileIds(currentUserId: UUID) async throws -> Set<UUID> {
        let c = try client
        let mine = try await c
            .from("match_participants")
            .select("match_id")
            .eq("user_id", value: currentUserId.uuidString)
            .execute()

        let matchIds = Set(jsonRows(from: mine.data).compactMap { uuid(from: $0["match_id"]) })
        guard !matchIds.isEmpty else { return Set() }

        let response = try await c
            .from("match_participants")
            .select("user_id")
            .in("match_id", values: Array(matchIds))
            .execute()

        var opponents = Set<UUID>()
        for row in jsonRows(from: response.data) {
            guard let uid = uuid(from: row["user_id"]), uid != currentUserId else { continue }
            opponents.insert(uid)
        }
        return opponents
    }

    /// Accepted app friends: the other profile id in each `friendships` row for the current user with `status = 'accepted'`.
    func fetchAcceptedFriendProfileIds(currentProfileId: UUID) async throws -> Set<UUID> {
        let c = try client
        let response = try await c
            .from("friendships")
            .select("a_id, b_id")
            .eq("status", value: "accepted")
            .or("a_id.eq.\(currentProfileId.uuidString),b_id.eq.\(currentProfileId.uuidString)")
            .execute()

        var peers = Set<UUID>()
        for row in jsonRows(from: response.data) {
            guard let a = uuid(from: row["a_id"]), let b = uuid(from: row["b_id"]) else { continue }
            let peer = a == currentProfileId ? b : a
            peers.insert(peer)
        }
        return peers
    }

    private static func dateFromISODate(_ value: String?) -> Date? {
        guard let value else { return nil }
        return isoDayFormatter.date(from: value)
    }

    // MARK: - JSON helpers

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
        if let text = value as? String { return UUID(uuidString: text) }
        return nil
    }

    private static let isoDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct WeeklyStepsLeaderboardRPCParams: Sendable {
    let p_week_start: String
    let p_limit: Int
    let p_scope: String
}

extension WeeklyStepsLeaderboardRPCParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_week_start, forKey: .p_week_start)
        try c.encode(p_limit, forKey: .p_limit)
        try c.encode(p_scope, forKey: .p_scope)
    }

    enum CodingKeys: String, CodingKey {
        case p_week_start
        case p_limit
        case p_scope
    }
}

private struct WeeklyStepsLeaderboardRPCRow: Decodable, Sendable {
    let user_id: UUID
    let display_name: String
    let initials: String
    let week_start: String?
    let week_end: String?
    let total_steps: Int64
    let rank: Int
}
