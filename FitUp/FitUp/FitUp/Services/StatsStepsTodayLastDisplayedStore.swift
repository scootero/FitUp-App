//
//  StatsStepsTodayLastDisplayedStore.swift
//  FitUp
//
//  Local-only persistence for the last Stats hero steps snapshot the user saw today.
//

import Foundation

enum StatsStepsTodayLastDisplayedStore {
    private static let stepsKeyPrefix = "fitup.statsStepsToday.lastDisplayedSteps."
    private static let nowFractionKeyPrefix = "fitup.statsStepsToday.lastDisplayedNowFraction."
    private static let localDateKeyPrefix = "fitup.statsStepsToday.lastDisplayedLocalDate."

    struct Snapshot: Equatable {
        let steps: Int
        let nowFraction: Double
        let localDate: String
    }

    static func load(profileId: UUID, localDate: String) -> Snapshot? {
        let stepsKey = stepsKey(for: profileId)
        guard UserDefaults.standard.object(forKey: stepsKey) != nil else { return nil }
        let storedDate = UserDefaults.standard.string(forKey: localDateKey(for: profileId))
        guard storedDate == localDate else {
            clear(profileId: profileId)
            return nil
        }
        return Snapshot(
            steps: UserDefaults.standard.integer(forKey: stepsKey),
            nowFraction: UserDefaults.standard.double(forKey: nowFractionKey(for: profileId)),
            localDate: localDate
        )
    }

    static func save(steps: Int, nowFraction: Double, profileId: UUID, localDate: String) {
        UserDefaults.standard.set(steps, forKey: stepsKey(for: profileId))
        UserDefaults.standard.set(nowFraction, forKey: nowFractionKey(for: profileId))
        UserDefaults.standard.set(localDate, forKey: localDateKey(for: profileId))
    }

    static func clear(profileId: UUID) {
        UserDefaults.standard.removeObject(forKey: stepsKey(for: profileId))
        UserDefaults.standard.removeObject(forKey: nowFractionKey(for: profileId))
        UserDefaults.standard.removeObject(forKey: localDateKey(for: profileId))
    }

    private static func stepsKey(for profileId: UUID) -> String {
        stepsKeyPrefix + profileId.uuidString
    }

    private static func nowFractionKey(for profileId: UUID) -> String {
        nowFractionKeyPrefix + profileId.uuidString
    }

    private static func localDateKey(for profileId: UUID) -> String {
        localDateKeyPrefix + profileId.uuidString
    }

    static func localDateString(now: Date = Date(), profileTimeZoneIdentifier: String?) -> String {
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
