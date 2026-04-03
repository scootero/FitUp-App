//
//  NotificationService.swift
//  FitUp
//
//  Slice 2: notification authorization for onboarding.
//  Slice 9: full APNs registration, token persistence, foreground presentation,
//           deep-link routing on notification tap.
//

import Combine
import Foundation
import UIKit
import UserNotifications

// MARK: - Deep-link target

enum NotificationDeepLink: Equatable {
    case home
    case matchDetails(matchId: UUID)
    case activity
}

// MARK: - Service

@MainActor
final class NotificationService: NSObject, ObservableObject {

    static let shared = NotificationService()

    /// Published so `ContentView` / `RootShellView` can react to tapped notifications.
    @Published private(set) var pendingDeepLink: NotificationDeepLink?

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // MARK: - Permission

    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])
    }

    // MARK: - APNs registration

    /// Call after a valid session + profile exist (and after permission is granted).
    func registerForRemoteNotifications() {
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Called by `AppDelegate` when registration succeeds.
    func didRegister(deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        AppLogger.log(category: "notifications", level: .info, message: "APNs token registered", metadata: ["token_prefix": String(hex.prefix(16))])
        Task {
            await ProfileRepository().updatePushTokens(apnsToken: hex)
        }
    }

    /// Called by `AppDelegate` when registration fails.
    func didFailToRegister(error: Error) {
        AppLogger.log(category: "notifications", level: .warning, message: "APNs registration failed: \(error.localizedDescription)")
    }

    // MARK: - Live Activity token

    /// Store the Live Activity push token on the profile.
    func storeLiveActivityToken(_ token: Data) {
        let hex = token.map { String(format: "%02x", $0) }.joined()
        AppLogger.log(category: "notifications", level: .info, message: "Live Activity push token updated")
        Task {
            await ProfileRepository().updatePushTokens(liveActivityPushToken: hex)
        }
    }

    // MARK: - Deep link consumption

    func consumeDeepLink() -> NotificationDeepLink? {
        defer { pendingDeepLink = nil }
        return pendingDeepLink
    }

    // MARK: - Private helpers

    private func routeNotification(userInfo: [AnyHashable: Any]) {
        let target = userInfo["deep_link_target"] as? String ?? ""
        let matchIdString = userInfo["match_id"] as? String ?? ""

        switch target {
        case "match_details":
            if let uuid = UUID(uuidString: matchIdString) {
                pendingDeepLink = .matchDetails(matchId: uuid)
            } else {
                pendingDeepLink = .home
            }
        case "activity":
            pendingDeepLink = .activity
        default:
            pendingDeepLink = .home
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {

    /// Deliver notifications while the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
    }

    /// Handle notification tap (foreground or background).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            self.routeNotification(userInfo: userInfo)
        }
        completionHandler()
    }
}
