//
//  LeaderboardRepository.swift
//  FitUp
//
//  Slice 11 — Weekly leaderboard reads (global + friends filter).
//

import Combine
import Foundation
import Supabase

struct LeaderboardEntryRecord: Equatable {
    let userId: UUID
    let points: Int
    let wins: Int
    let losses: Int
    let streak: Int
    let rank: Int?
}

struct LeaderboardProfileSummary: Equatable {
    let id: UUID
    let displayName: String
    let initials: String
}

final class LeaderboardRepository {
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

    // MARK: - Public

    func fetchGlobalLeaderboard(weekStart: Date) async throws -> [LeaderboardEntryRecord] {
        let c = try client
        let iso = Self.weekStartISOString(from: weekStart)
        let response = try await c
            .from("leaderboard_entries")
            .select("user_id, points, wins, losses, streak, rank")
            .eq("week_start", value: iso)
            .order("points", ascending: false)
            .execute()

        return jsonRows(from: response.data).compactMap { row in
            guard let userId = uuid(from: row["user_id"]) else { return nil }
            return LeaderboardEntryRecord(
                userId: userId,
                points: int(from: row["points"]) ?? 0,
                wins: int(from: row["wins"]) ?? 0,
                losses: int(from: row["losses"]) ?? 0,
                streak: int(from: row["streak"]) ?? 0,
                rank: int(from: row["rank"])
            )
        }
    }

    func fetchProfiles(userIds: [UUID]) async throws -> [UUID: LeaderboardProfileSummary] {
        guard !userIds.isEmpty else { return [:] }
        let c = try client
        let unique = Array(Set(userIds))
        let response = try await c
            .from("profiles")
            .select("id, display_name, initials")
            .in("id", values: unique.map { $0 })
            .execute()

        var map: [UUID: LeaderboardProfileSummary] = [:]
        for row in jsonRows(from: response.data) {
            guard let id = uuid(from: row["id"]) else { continue }
            let name = string(from: row["display_name"])?.trimmingCharacters(in: .whitespacesAndNewlines)
            let initials = string(from: row["initials"])?.trimmingCharacters(in: .whitespacesAndNewlines)
            map[id] = LeaderboardProfileSummary(
                id: id,
                displayName: (name?.isEmpty == false) ? name! : "Player",
                initials: (initials?.isEmpty == false) ? initials!.uppercased() : "PL"
            )
        }
        return map
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

    private func string(from value: Any?) -> String? {
        value as? String
    }

    private func int(from value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue.rounded()) }
        if let text = value as? String, let doubleValue = Double(text) {
            return Int(doubleValue.rounded())
        }
        return nil
    }
}
