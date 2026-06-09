//
//  NotificationPreferences.swift
//  FitUp
//
//  Local user preferences for Live Activities (device-only).
//

import Foundation

enum NotificationPreferences {
    static let liveActivitiesEnabledKey = "fitup.settings.liveActivitiesEnabled"

    /// Default `true` when the key has never been set.
    static var isLiveActivitiesEnabled: Bool {
        guard UserDefaults.standard.object(forKey: liveActivitiesEnabledKey) != nil else {
            return true
        }
        return UserDefaults.standard.bool(forKey: liveActivitiesEnabledKey)
    }

    static func setLiveActivitiesEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: liveActivitiesEnabledKey)
    }
}
