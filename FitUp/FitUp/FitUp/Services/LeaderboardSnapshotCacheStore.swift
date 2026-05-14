//
//  LeaderboardSnapshotCacheStore.swift
//  FitUp
//
//  Stale-while-refresh: last successful Ranks payload per profile, UTC week, and tab.
//

import Foundation

private struct CachedLeaderboardSnapshot: Codable {
    let schemaVersion: Int
    let profileId: UUID
    let weekStartIso: String
    let tabRaw: String
    let savedAt: Date
    let entries: [CachedLeaderboardEntry]
}

private struct CachedLeaderboardEntry: Codable {
    let userId: UUID
    let rank: Int
    let totalSteps: Int
    let displayName: String
    let initials: String
}

final class LeaderboardSnapshotCacheStore {
    private let defaults: UserDefaults
    private let schemaVersion = 1

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(
        profileId: UUID,
        weekStartIso: String,
        tabRaw: String
    ) -> [WeeklyStepsLeaderboardRecord]? {
        let key = Self.cacheKey(profileId: profileId, weekStartIso: weekStartIso, tabRaw: tabRaw)
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let cached = try? JSONDecoder().decode(CachedLeaderboardSnapshot.self, from: data) else {
            defaults.removeObject(forKey: key)
            return nil
        }
        guard cached.schemaVersion == schemaVersion,
              cached.profileId == profileId,
              cached.weekStartIso == weekStartIso,
              cached.tabRaw == tabRaw
        else {
            defaults.removeObject(forKey: key)
            return nil
        }

        guard let weekStart = LeaderboardRepository.dateFromWeekStartISOString(weekStartIso) else { return nil }
        let weekEnd = Self.weekEndUTC(weekStart: weekStart)

        return cached.entries.map { row in
            WeeklyStepsLeaderboardRecord(
                userId: row.userId,
                weekStart: weekStart,
                weekEnd: weekEnd,
                totalSteps: row.totalSteps,
                rank: row.rank,
                displayName: row.displayName,
                initials: row.initials
            )
        }
    }

    func save(
        entries: [WeeklyStepsLeaderboardRecord],
        profileId: UUID,
        weekStartIso: String,
        tabRaw: String
    ) {
        let key = Self.cacheKey(profileId: profileId, weekStartIso: weekStartIso, tabRaw: tabRaw)
        let rows = entries.map { entry in
            CachedLeaderboardEntry(
                userId: entry.userId,
                rank: entry.rank,
                totalSteps: entry.totalSteps,
                displayName: entry.displayName,
                initials: entry.initials
            )
        }
        let snapshot = CachedLeaderboardSnapshot(
            schemaVersion: schemaVersion,
            profileId: profileId,
            weekStartIso: weekStartIso,
            tabRaw: tabRaw,
            savedAt: Date(),
            entries: rows
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    private static func cacheKey(profileId: UUID, weekStartIso: String, tabRaw: String) -> String {
        "leaderboard.snapshot.v1.\(profileId.uuidString).\(weekStartIso).\(tabRaw)"
    }

    private static func weekEndUTC(weekStart: Date) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(secondsFromGMT: 0)!
        return cal.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
    }
}
