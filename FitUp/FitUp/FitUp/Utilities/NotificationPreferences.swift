//
//  NotificationPreferences.swift
//  FitUp
//
//  Local user preferences for Live Activities (device-only).
//

import Foundation

enum NotificationPreferences {
    static let liveActivitiesEnabledKey = "fitup.settings.liveActivitiesEnabled"

    /// Temporary release switch. Set to `true` when Live Activities are ready
    /// to be enabled again; the extension and the user's saved preference remain intact.
    static let isLiveActivitiesFeatureAvailable = false

    /// Default `true` when the key has never been set.
    static var isLiveActivitiesEnabled: Bool {
        guard isLiveActivitiesFeatureAvailable else { return false }
        guard UserDefaults.standard.object(forKey: liveActivitiesEnabledKey) != nil else {
            return true
        }
        return UserDefaults.standard.bool(forKey: liveActivitiesEnabledKey)
    }

    static func setLiveActivitiesEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: liveActivitiesEnabledKey)
    }
}
