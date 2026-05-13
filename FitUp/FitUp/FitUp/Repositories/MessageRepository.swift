//
//  MessageRepository.swift
//  FitUp
//
//  Friend-gated 1:1 threads and messages (MVP). Requires manual SQL: messaging_mvp.sql
//

import Foundation
import Supabase

// MARK: - Models

struct MessageThreadRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let userLow: UUID
    let userHigh: UUID
    let createdAt: Date?
    let lastMessageAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case userLow = "user_low"
        case userHigh = "user_high"
        case createdAt = "created_at"
        case lastMessageAt = "last_message_at"
    }
}

struct MessageRowRecord: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let threadId: UUID
    let senderId: UUID
    let body: String
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case threadId = "thread_id"
        case senderId = "sender_id"
        case body
        case createdAt = "created_at"
    }
}

struct InboxThreadItem: Equatable, Identifiable, Sendable {
    var id: UUID { thread.id }
    let thread: MessageThreadRecord
    let peerProfileId: UUID
    /// Last message body for preview; nil if none loaded.
    let lastMessagePreview: String?
}

enum MessageRepositoryError: LocalizedError {
    case supabaseNotConfigured
    case notReady
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .supabaseNotConfigured:
            return "Not signed in."
        case .notReady:
            return "Messaging is not ready yet. Please try again later."
        case .unexpectedResponse:
            return "Could not load messages right now."
        }
    }
}

// MARK: - Repository

final class MessageRepository {
    private var client: SupabaseClient {
        get throws {
            guard let client = SupabaseProvider.client else {
                throw MessageRepositoryError.supabaseNotConfigured
            }
            return client
        }
    }

    private static let jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = isoFormatter.date(from: value) { return date }
            let alt = ISO8601DateFormatter()
            alt.formatOptions = [.withInternetDateTime]
            if let date = alt.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(value)")
        }
        return d
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    /// Creates row if missing; handles unique race by re-selecting.
    func ensureThread(peerProfileId: UUID, currentProfileId: UUID) async throws -> UUID {
        let (low, high) = FriendshipRepository.orderedPair(currentProfileId, peerProfileId)
        if let existing = try await fetchThreadId(userLow: low, userHigh: high) {
            return existing
        }

        let c = try client
        let body = MessageThreadInsert(userLow: low, userHigh: high)
        do {
            try await c
                .from("message_threads")
                .insert(body)
                .execute()
        } catch {
            if let retry = try await fetchThreadId(userLow: low, userHigh: high) {
                return retry
            }
            throw mapError(error)
        }

        if let id = try await fetchThreadId(userLow: low, userHigh: high) {
            return id
        }
        throw MessageRepositoryError.unexpectedResponse
    }

    func fetchThreads(currentProfileId: UUID) async throws -> [MessageThreadRecord] {
        let c = try client
        let response = try await c
            .from("message_threads")
            .select("id, user_low, user_high, created_at, last_message_at")
            .or("user_low.eq.\(currentProfileId.uuidString),user_high.eq.\(currentProfileId.uuidString)")
            .order("last_message_at", ascending: false)
            .execute()
        return try decodeThreads(from: response.data)
    }

    /// Ordered ascending for chat (oldest first).
    func fetchMessages(threadId: UUID, limit: Int = 200) async throws -> [MessageRowRecord] {
        let c = try client
        let response = try await c
            .from("messages")
            .select("id, thread_id, sender_id, body, created_at")
            .eq("thread_id", value: threadId.uuidString)
            .order("created_at", ascending: true)
            .limit(limit)
            .execute()
        return try decodeMessages(from: response.data)
    }

    func sendMessage(threadId: UUID, body: String, senderId: UUID) async throws {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let c = try client
        let payload = MessageInsert(threadId: threadId, senderId: senderId, body: trimmed)
        do {
            try await c
                .from("messages")
                .insert(payload)
                .execute()
        } catch {
            throw mapError(error)
        }
    }

    /// Threads plus peer id and optional last message text.
    func fetchInbox(currentProfileId: UUID) async throws -> [InboxThreadItem] {
        let threads = try await fetchThreads(currentProfileId: currentProfileId)
        var items: [InboxThreadItem] = []
        for t in threads {
            let peer = t.userLow == currentProfileId ? t.userHigh : t.userLow
            let preview = try? await fetchLatestMessageBody(threadId: t.id)
            items.append(
                InboxThreadItem(
                    thread: t,
                    peerProfileId: peer,
                    lastMessagePreview: preview
                )
            )
        }
        return items
    }

    // MARK: - Private

    private func fetchThreadId(userLow: UUID, userHigh: UUID) async throws -> UUID? {
        let c = try client
        let response = try await c
            .from("message_threads")
            .select("id")
            .eq("user_low", value: userLow.uuidString)
            .eq("user_high", value: userHigh.uuidString)
            .limit(1)
            .execute()
        return try decodeThreads(from: response.data).first?.id
    }

    private func fetchLatestMessageBody(threadId: UUID) async throws -> String? {
        let c = try client
        let response = try await c
            .from("messages")
            .select("body")
            .eq("thread_id", value: threadId.uuidString)
            .order("created_at", ascending: false)
            .limit(1)
            .execute()
        guard
            let obj = try? JSONSerialization.jsonObject(with: response.data) as? [[String: Any]],
            let row = obj.first,
            let s = row["body"] as? String
        else {
            return nil
        }
        return s
    }

    private func decodeThreads(from data: Data) throws -> [MessageThreadRecord] {
        do {
            return try Self.jsonDecoder.decode([MessageThreadRecord].self, from: data)
        } catch {
            throw MessageRepositoryError.unexpectedResponse
        }
    }

    private func decodeMessages(from data: Data) throws -> [MessageRowRecord] {
        do {
            return try Self.jsonDecoder.decode([MessageRowRecord].self, from: data)
        } catch {
            throw MessageRepositoryError.unexpectedResponse
        }
    }

    private func mapError(_ error: Error) -> Error {
        if error is MessageRepositoryError { return error }
        let description = error.localizedDescription.lowercased()
        if description.contains("does not exist")
            || description.contains("schema cache")
            || description.contains("\"message_threads\"")
            || description.contains("\"messages\"")
            || description.contains("message_threads")
            || (description.contains("relation") && description.contains("public"))
        {
            return MessageRepositoryError.notReady
        }
        return error
    }
}

private struct MessageThreadInsert: Encodable, Sendable {
    let userLow: UUID
    let userHigh: UUID

    enum CodingKeys: String, CodingKey {
        case userLow = "user_low"
        case userHigh = "user_high"
    }
}

private struct MessageInsert: Encodable, Sendable {
    let threadId: UUID
    let senderId: UUID
    let body: String

    enum CodingKeys: String, CodingKey {
        case threadId = "thread_id"
        case senderId = "sender_id"
        case body
    }
}
