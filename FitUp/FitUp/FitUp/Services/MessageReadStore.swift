//
//  MessageReadStore.swift
//  FitUp
//
//  Local last-read watermark per thread (MVP until server read receipts).
//

import Foundation

enum MessageReadStore {
    private static let prefix = "fitup.messaging.lastReadAt."

    private static func key(threadId: UUID, profileId: UUID) -> String {
        "\(prefix)\(profileId.uuidString).\(threadId.uuidString)"
    }

    static func lastReadAt(threadId: UUID, profileId: UUID) -> Date? {
        let raw = UserDefaults.standard.double(forKey: key(threadId: threadId, profileId: profileId))
        guard raw > 0 else { return nil }
        return Date(timeIntervalSince1970: raw)
    }

    static func markThreadRead(threadId: UUID, profileId: UUID, through date: Date = Date()) {
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: key(threadId: threadId, profileId: profileId))
    }

    /// Unread when the latest message is from the peer and is newer than our last-read watermark.
    static func isUnread(
        threadId: UUID,
        profileId: UUID,
        lastMessageAt: Date?,
        lastSenderId: UUID?
    ) -> Bool {
        guard let lastMessageAt, let lastSenderId else { return false }
        guard lastSenderId != profileId else { return false }
        guard let readAt = lastReadAt(threadId: threadId, profileId: profileId) else {
            return true
        }
        return lastMessageAt > readAt
    }

    static func unreadCount(profileId: UUID, items: [InboxThreadItem]) -> Int {
        items.filter(\.hasUnread).count
    }
}
