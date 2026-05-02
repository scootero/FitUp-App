//
//  HomeBattleStatsCacheStore.swift
//  FitUp
//
//  Small local cache for Home battle stats row.
//

import Foundation

struct CachedHomeBattleStats: Codable {
    let schemaVersion: Int
    let profileId: UUID
    let localDate: String
    let profileTimeZoneIdentifier: String?
    let savedAt: Date
    let matchCount: Int
    let winCount: Int
    let winRatePercent: Int
}

final class HomeBattleStatsCacheStore {
    private let defaults: UserDefaults
    private let keyPrefix = "home.battle.stats.v1"
    private let schemaVersion = 1

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadTodayStats(
        profileId: UUID,
        profileTimeZoneIdentifier: String?,
        now: Date = Date()
    ) -> CachedHomeBattleStats? {
        let localDate = localDateString(now: now, profileTimeZoneIdentifier: profileTimeZoneIdentifier)
        let key = cacheKey(profileId: profileId, localDate: localDate)
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let stats = try? JSONDecoder().decode(CachedHomeBattleStats.self, from: data) else {
            defaults.removeObject(forKey: key)
            return nil
        }
        guard stats.schemaVersion == schemaVersion,
              stats.profileId == profileId,
              stats.localDate == localDate else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return stats
    }

    func saveTodayStats(_ stats: CachedHomeBattleStats) {
        guard let data = try? JSONEncoder().encode(stats) else { return }
        let key = cacheKey(profileId: stats.profileId, localDate: stats.localDate)
        defaults.set(data, forKey: key)
    }

    func makeStats(
        profileId: UUID,
        profileTimeZoneIdentifier: String?,
        stats: HomeViewModel.ActivityStats,
        now: Date = Date()
    ) -> CachedHomeBattleStats {
        CachedHomeBattleStats(
            schemaVersion: schemaVersion,
            profileId: profileId,
            localDate: localDateString(now: now, profileTimeZoneIdentifier: profileTimeZoneIdentifier),
            profileTimeZoneIdentifier: profileTimeZoneIdentifier,
            savedAt: now,
            matchCount: stats.matchCount ?? 0,
            winCount: stats.winCount ?? 0,
            winRatePercent: stats.winRatePercent ?? 0
        )
    }

    private func cacheKey(profileId: UUID, localDate: String) -> String {
        "\(keyPrefix).\(profileId.uuidString).\(localDate)"
    }

    private func localDateString(now: Date, profileTimeZoneIdentifier: String?) -> String {
        var calendar = Calendar(identifier: .gregorian)
        if let profileTimeZoneIdentifier,
           let tz = TimeZone(identifier: profileTimeZoneIdentifier) {
            calendar.timeZone = tz
        } else {
            calendar.timeZone = .current
        }
        let parts = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }
}
