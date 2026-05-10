//
//  StatsPageSnapshotCacheStore.swift
//  FitUp
//
//  Cache envelope for Stats page snapshot (stale-while-refresh).
//

import Foundation

struct CachedStatsPageSnapshot: Codable {
    let schemaVersion: Int
    let profileId: UUID
    let localDate: String
    let profileTimeZoneIdentifier: String?
    let rangeKeyRaw: String
    let effectiveRangeKeyRaw: String
    let savedAt: Date
    let dateChipText: String
    let fallbackScopeNote: String?
    let margins: [DailyBattleMargin]
    let previousPeriodPercent: Int?
    let battleStatsScopeLabel: String
    let battleStats: HealthBattleStats
}

final class StatsPageSnapshotCacheStore {
    private let defaults: UserDefaults
    private let keyPrefix = "stats.page.snapshot.v1"
    private let schemaVersion = 1

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(
        profileId: UUID,
        profileTimeZoneIdentifier: String?,
        rangeKeyRaw: String,
        now: Date = Date()
    ) -> CachedStatsPageSnapshot? {
        let localDate = localDateString(now: now, profileTimeZoneIdentifier: profileTimeZoneIdentifier)
        let key = cacheKey(profileId: profileId, localDate: localDate, rangeKeyRaw: rangeKeyRaw)
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let cached = try? JSONDecoder().decode(CachedStatsPageSnapshot.self, from: data) else {
            defaults.removeObject(forKey: key)
            return nil
        }
        guard cached.schemaVersion == schemaVersion,
              cached.profileId == profileId,
              cached.localDate == localDate,
              cached.rangeKeyRaw == rangeKeyRaw
        else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return cached
    }

    func save(_ snapshot: CachedStatsPageSnapshot) {
        let key = cacheKey(
            profileId: snapshot.profileId,
            localDate: snapshot.localDate,
            rangeKeyRaw: snapshot.rangeKeyRaw
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }

    func makeSnapshot(
        profileId: UUID,
        profileTimeZoneIdentifier: String?,
        rangeKeyRaw: String,
        effectiveRangeKeyRaw: String,
        dateChipText: String,
        fallbackScopeNote: String?,
        margins: [DailyBattleMargin],
        previousPeriodPercent: Int?,
        battleStatsScopeLabel: String,
        battleStats: HealthBattleStats,
        savedAt: Date,
        now: Date = Date()
    ) -> CachedStatsPageSnapshot {
        let localDate = localDateString(now: now, profileTimeZoneIdentifier: profileTimeZoneIdentifier)
        return CachedStatsPageSnapshot(
            schemaVersion: schemaVersion,
            profileId: profileId,
            localDate: localDate,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier,
            rangeKeyRaw: rangeKeyRaw,
            effectiveRangeKeyRaw: effectiveRangeKeyRaw,
            savedAt: savedAt,
            dateChipText: dateChipText,
            fallbackScopeNote: fallbackScopeNote,
            margins: margins,
            previousPeriodPercent: previousPeriodPercent,
            battleStatsScopeLabel: battleStatsScopeLabel,
            battleStats: battleStats
        )
    }

    private func cacheKey(profileId: UUID, localDate: String, rangeKeyRaw: String) -> String {
        "\(keyPrefix).\(profileId.uuidString).\(localDate).\(rangeKeyRaw)"
    }

    private func localDateString(now: Date, profileTimeZoneIdentifier: String?) -> String {
        let tz = profileTimeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = tz
        return formatter.string(from: now)
    }
}
