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
    case recapInbox
    case activity
    case friends
    case messages(peerId: UUID?)
}

struct InAppNotificationItem: Identifiable, Equatable, Codable {
    let id: UUID
    let title: String
    let body: String
    let eventType: String
    let deepLinkTarget: String?
    let matchId: UUID?
    let peerProfileId: UUID?
    let createdAt: Date
    var isRead: Bool
}

// MARK: - Service

@MainActor
final class NotificationService: NSObject, ObservableObject {

    static let shared = NotificationService()

    /// Published so `ContentView` / `RootShellView` can react to tapped notifications.
    @Published private(set) var pendingDeepLink: NotificationDeepLink?
    @Published private(set) var pendingRecapCards: [RecapMatchCard] = []
    @Published private(set) var inboxItems: [InAppNotificationItem] = []
    @Published private(set) var shouldPresentHomeInbox: Bool = false

    /// Wired from `FitUpApp` so `match_found` / `challenge_received` / `match_active` pushes can queue Home celebrations.
    weak var sessionStore: SessionStore?

    private let inboxStorageKey = "fitup.notification.inbox.items"

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        loadInboxFromDefaults()
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
        AppLogger.log(category: "notifications", level: .debug, message: "APNs token registered", metadata: ["token_prefix": String(hex.prefix(16))])
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
        guard NotificationPreferences.isLiveActivitiesEnabled else {
            AppLogger.log(
                category: "notifications",
                level: .debug,
                message: "Live Activity push token upload suppressed by user preference"
            )
            return
        }
        let hex = token.map { String(format: "%02x", $0) }.joined()
        AppLogger.log(category: "notifications", level: .debug, message: "Live Activity push token updated")
        Task {
            await ProfileRepository().updatePushTokens(liveActivityPushToken: hex)
        }
    }

    // MARK: - Deep link consumption

    func consumeDeepLink() -> NotificationDeepLink? {
        defer { pendingDeepLink = nil }
        return pendingDeepLink
    }

    func requestPresentHomeInbox() {
        shouldPresentHomeInbox = true
    }

    func consumePresentHomeInbox() -> Bool {
        let shouldPresent = shouldPresentHomeInbox
        shouldPresentHomeInbox = false
        return shouldPresent
    }

    func consumeRecapCards() -> [RecapMatchCard] {
        defer { pendingRecapCards = [] }
        return pendingRecapCards
    }

    func markAllInboxItemsRead() {
        guard inboxItems.contains(where: { !$0.isRead }) else { return }
        inboxItems = inboxItems.map { item in
            var next = item
            next.isRead = true
            return next
        }
        saveInboxToDefaults()
    }

    func markInboxItemRead(_ itemId: UUID) {
        guard let idx = inboxItems.firstIndex(where: { $0.id == itemId }), inboxItems[idx].isRead == false else { return }
        inboxItems[idx].isRead = true
        saveInboxToDefaults()
    }

    var unreadInboxCount: Int {
        inboxItems.reduce(into: 0) { acc, item in
            if !item.isRead { acc += 1 }
        }
    }

    func attachSessionStore(_ store: SessionStore) {
        sessionStore = store
    }

    // MARK: - Private helpers

    /// v1: foreground Home light refresh — excludes `challenge_received` (recipient UX differs; not needed for sender `match_active` goal).
    private static let homeLightRefreshEventTypes: Set<String> = ["match_active", "match_found"]

    private func requestHomeLightRefreshIfMatchLifecycle(userInfo: [AnyHashable: Any]) {
        let eventType = userInfo["event_type"] as? String ?? ""
        guard Self.homeLightRefreshEventTypes.contains(eventType) else { return }
        let matchId = (userInfo["match_id"] as? String).flatMap(UUID.init(uuidString:))
        AppLogger.log(
            category: "notifications",
            level: .debug,
            message: "home_push_notification_received",
            metadata: [
                "event_type": eventType,
                "match_id": matchId?.uuidString ?? "nil",
            ]
        )
        sessionStore?.requestHomeLightSnapshotRefresh(eventType: eventType, matchId: matchId)
    }

    /// Queues Home celebrations when a push arrives; safe for foreground banners (does not set `pendingDeepLink`).
    private func applyCelebrationQueuesFromNotificationPayload(userInfo: [AnyHashable: Any]) {
        let eventType = userInfo["event_type"] as? String ?? ""
        if eventType == "friend_request_received" {
            if let peerStr = userInfo["peer_profile_id"] as? String, let peerId = UUID(uuidString: peerStr) {
                let name = (userInfo["from_display_name"] as? String)
                    ?? (userInfo["opponent_display_name"] as? String) ?? "Player"
                sessionStore?.queueFriendRequestFromPush(peerId: peerId, fromName: name)
            }
            return
        }
        if eventType == "friend_request_accepted" {
            if let peerStr = userInfo["peer_profile_id"] as? String, let peerId = UUID(uuidString: peerStr) {
                let name = (userInfo["accepter_display_name"] as? String)
                    ?? (userInfo["opponent_display_name"] as? String) ?? "Player"
                sessionStore?.queueFriendAcceptedFromPush(accepterName: name, peerId: peerId)
            }
            return
        }

        let matchIdString = userInfo["match_id"] as? String ?? ""
        guard let uuid = UUID(uuidString: matchIdString) else { return }
        switch eventType {
        case "match_found", "challenge_received":
            sessionStore?.queueMatchFoundCelebration(matchId: uuid)
        case "match_active":
            sessionStore?.queueMatchActiveCelebration(matchId: uuid)
        default:
            break
        }
    }

    private func routeNotification(userInfo: [AnyHashable: Any]) {
        recordInboxItem(from: userInfo)
        applyCelebrationQueuesFromNotificationPayload(userInfo: userInfo)

        let eventType = userInfo["event_type"] as? String ?? ""
        if eventType == "friend_request_received" {
            pendingDeepLink = .friends
            return
        }
        if eventType == "friend_request_accepted" {
            pendingDeepLink = .home
            shouldPresentHomeInbox = true
            return
        }
        if eventType == "message_received" {
            let peerId = (userInfo["peer_profile_id"] as? String).flatMap(UUID.init(uuidString:))
            pendingDeepLink = .messages(peerId: peerId)
            return
        }

        let matchIdString = userInfo["match_id"] as? String ?? ""
        let target = userInfo["deep_link_target"] as? String ?? ""

        switch target {
        case "recap_inbox":
            pendingRecapCards = RecapMatchCardParser.parse(from: userInfo)
            pendingDeepLink = .recapInbox
            shouldPresentHomeInbox = true
        case "match_details":
            if let uuid = UUID(uuidString: matchIdString) {
                pendingDeepLink = .matchDetails(matchId: uuid)
            } else {
                pendingDeepLink = .home
            }
        case "activity":
            pendingDeepLink = .activity
        case "friends":
            pendingDeepLink = .friends
        case "messages":
            let peerId = (userInfo["peer_profile_id"] as? String).flatMap(UUID.init(uuidString:))
            pendingDeepLink = .messages(peerId: peerId)
        default:
            pendingDeepLink = .home
            shouldPresentHomeInbox = true
        }
    }

    private func recordInboxItem(from userInfo: [AnyHashable: Any], providedTitle: String? = nil, providedBody: String? = nil) {
        let eventType = userInfo["event_type"] as? String ?? "general"
        let title = providedTitle ?? (userInfo["title"] as? String) ?? defaultTitle(for: eventType)
        let body = providedBody ?? (userInfo["message"] as? String) ?? (userInfo["aps.alert.body"] as? String) ?? defaultBody(for: eventType)
        let deepLinkTarget = userInfo["deep_link_target"] as? String
        let matchId: UUID? = {
            guard let raw = userInfo["match_id"] as? String else { return nil }
            return UUID(uuidString: raw)
        }()
        let peerProfileId: UUID? = {
            guard let raw = userInfo["peer_profile_id"] as? String else { return nil }
            return UUID(uuidString: raw)
        }()
        let item = InAppNotificationItem(
            id: UUID(),
            title: title,
            body: body,
            eventType: eventType,
            deepLinkTarget: deepLinkTarget,
            matchId: matchId,
            peerProfileId: peerProfileId,
            createdAt: Date(),
            isRead: false
        )
        inboxItems.insert(item, at: 0)
        if inboxItems.count > 50 {
            inboxItems = Array(inboxItems.prefix(50))
        }
        saveInboxToDefaults()
    }

    private func defaultTitle(for eventType: String) -> String {
        switch eventType {
        case "match_found", "challenge_received":
            return "New Challenge"
        case "match_active":
            return "Battle Is Live"
        case "friend_request_received":
            return "Friend Request"
        case "friend_request_accepted":
            return "Friend Request Accepted"
        case "yesterday_recap":
            return "Yesterday's Results"
        case "final_day_comeback":
            return "FINAL DAY"
        case "message_received":
            return "New Message"
        default:
            return "FitUp Alert"
        }
    }

    private func defaultBody(for eventType: String) -> String {
        switch eventType {
        case "yesterday_recap":
            return "Open your daily scoreboard."
        case "final_day_comeback":
            return "You still have time to close the gap today."
        case "match_found", "challenge_received":
            return "You have a new matchup waiting."
        case "match_active":
            return "Your battle has started."
        case "friend_request_received":
            return "You received a new friend request."
        case "friend_request_accepted":
            return "You are connected. Time to compete."
        case "message_received":
            return "Tap to read and reply."
        default:
            return "Open FitUp to view details."
        }
    }

    private func saveInboxToDefaults() {
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(inboxItems) else { return }
        UserDefaults.standard.set(data, forKey: inboxStorageKey)
    }

    private func loadInboxFromDefaults() {
        guard let data = UserDefaults.standard.data(forKey: inboxStorageKey) else { return }
        let decoder = JSONDecoder()
        if let items = try? decoder.decode([InAppNotificationItem].self, from: data) {
            inboxItems = items
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
        let userInfo = notification.request.content.userInfo
        Task { @MainActor in
            let eventType = userInfo["event_type"] as? String ?? ""
            if eventType == "yesterday_recap" {
                self.pendingRecapCards = RecapMatchCardParser.parse(from: userInfo)
            }
            self.recordInboxItem(
                from: userInfo,
                providedTitle: notification.request.content.title,
                providedBody: notification.request.content.body
            )
            self.applyCelebrationQueuesFromNotificationPayload(userInfo: userInfo)
            self.requestHomeLightRefreshIfMatchLifecycle(userInfo: userInfo)
        }
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
