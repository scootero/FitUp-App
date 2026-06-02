//
//  FitUpNotifications.swift
//  FitUp
//

import Foundation

extension Notification.Name {
    /// Posted when `MetricSyncCoordinator` finishes a successful HealthKit → Supabase sync.
    static let fitupMetricSyncDidComplete = Notification.Name("fitup.metricSyncDidComplete")
}
