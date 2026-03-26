//
//  NotificationService.swift
//  FitUp
//
//  Slice 2: notification authorization for onboarding.
//

import Foundation
import UserNotifications

enum NotificationService {
    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }
}
