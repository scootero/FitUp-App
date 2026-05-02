//
//  HomeDailyBattleMarginsCacheStore.swift
//  FitUp
//
//  Local cache for Home battle margin chart series (stale-while-refresh).
//

import Foundation

struct CachedDailyBattleMarginRow: Codable, Equatable {
    let calendarDate: String
    let margin: Int
}

struct CachedHomeDailyBattleMargins: Codable {
    let schemaVersion: Int
    let profileId: UUID
    let localDate: String
    let profileTimeZoneIdentifier: String?
    let metricKey: String
    let dayCount: Int
    let savedAt: Date
    let rows: [CachedDailyBattleMarginRow]
}

final class HomeDailyBattleMarginsCacheStore {
    private let defaults: UserDefaults
    private let keyPrefix = "home.daily.battle.margins.v1"
    private let schemaVersion = 1

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load(
        profileId: UUID,
        profileTimeZoneIdentifier: String?,
        metricKey: String,
        dayCount: Int,
        now: Date = Date()
    ) -> CachedHomeDailyBattleMargins? {
        let localDate = localDateString(now: now, profileTimeZoneIdentifier: profileTimeZoneIdentifier)
        let key = cacheKey(profileId: profileId, localDate: localDate, metricKey: metricKey, dayCount: dayCount)
        guard let data = defaults.data(forKey: key) else { return nil }
        guard let cached = try? JSONDecoder().decode(CachedHomeDailyBattleMargins.self, from: data) else {
            defaults.removeObject(forKey: key)
            return nil
        }
        guard cached.schemaVersion == schemaVersion,
              cached.profileId == profileId,
              cached.localDate == localDate,
              cached.metricKey == metricKey,
              cached.dayCount == dayCount else {
            defaults.removeObject(forKey: key)
            return nil
        }
        return cached
    }

    func save(_ margins: CachedHomeDailyBattleMargins) {
        let key = cacheKey(
            profileId: margins.profileId,
            localDate: margins.localDate,
            metricKey: margins.metricKey,
            dayCount: margins.dayCount
        )
        guard let data = try? JSONEncoder().encode(margins) else { return }
        defaults.set(data, forKey: key)
    }

    func makeCached(
        profileId: UUID,
        profileTimeZoneIdentifier: String?,
        metricKey: String,
        dayCount: Int,
        rows: [DailyBattleMargin],
        savedAt: Date,
        now: Date = Date()
    ) -> CachedHomeDailyBattleMargins {
        let localDate = localDateString(now: now, profileTimeZoneIdentifier: profileTimeZoneIdentifier)
        return CachedHomeDailyBattleMargins(
            schemaVersion: schemaVersion,
            profileId: profileId,
            localDate: localDate,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier,
            metricKey: metricKey,
            dayCount: dayCount,
            savedAt: savedAt,
            rows: rows.map {
                CachedDailyBattleMarginRow(calendarDate: $0.calendarDate, margin: $0.margin)
            }
        )
    }

    private func cacheKey(profileId: UUID, localDate: String, metricKey: String, dayCount: Int) -> String {
        "\(keyPrefix).\(profileId.uuidString).\(localDate).\(metricKey).\(dayCount)"
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
