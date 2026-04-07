//
//  ProfileRepository.swift
//  FitUp
//
//  Slice 1: all profile table reads/writes for auth flow.
//  Slice 14: notifications toggle + app_logs fetch.
//

import Combine
import Foundation
import Supabase

enum ProfileRepositoryError: LocalizedError {
    case supabaseNotConfigured
    case invalidAuthUserId
    case createFailed

    var errorDescription: String? {
        switch self {
        case .supabaseNotConfigured:
            return "Supabase is not configured. Add SUPABASE_URL and SUPABASE_ANON_KEY."
        case .invalidAuthUserId:
            return "Unable to read the authenticated user id."
        case .createFailed:
            return "Profile could not be created."
        }
    }
}

struct ProfileRepository {
    private var client: SupabaseClient {
        get throws {
            guard let client = SupabaseProvider.client else {
                throw ProfileRepositoryError.supabaseNotConfigured
            }
            return client
        }
    }

    // MARK: - Profile reads / writes

    func fetchProfile(authUserId: UUID) async throws -> Profile? {
        let response = try await client
            .from("profiles")
            .select()
            .eq("auth_user_id", value: authUserId.uuidString)
            .limit(1)
            .execute()
        return try decodeProfiles(from: response.data).first
    }

    /// Patches `apns_token` and/or `live_activity_push_token` on the caller's own profile.
    func updatePushTokens(apnsToken: String? = nil, liveActivityPushToken: String? = nil) async {
        guard apnsToken != nil || liveActivityPushToken != nil else { return }
        guard let client = SupabaseProvider.client else { return }
        do {
            let session = try await client.auth.session
            var fields: [String: String] = [:]
            if let token = apnsToken { fields["apns_token"] = token }
            if let token = liveActivityPushToken { fields["live_activity_push_token"] = token }
            try await client
                .from("profiles")
                .update(fields)
                .eq("auth_user_id", value: session.user.id.uuidString)
                .execute()
        } catch {
            AppLogger.log(
                category: "notifications",
                level: .warning,
                message: "push token update failed: \(error.localizedDescription)"
            )
        }
    }

    func createProfileIfNeeded(authUserId: UUID, displayName: String?) async throws -> Profile {
        if let existing = try await fetchProfile(authUserId: authUserId) {
            return existing
        }

        let resolvedName = Self.resolveDisplayName(displayName: displayName, authUserId: authUserId)
        let row = ProfileInsert(
            authUserId: authUserId,
            displayName: resolvedName,
            initials: Self.initials(from: resolvedName),
            timezone: TimeZone.current.identifier
        )

        try await client.from("profiles").insert(row).execute()

        guard let created = try await fetchProfile(authUserId: authUserId) else {
            throw ProfileRepositoryError.createFailed
        }
        return created
    }

    // MARK: - Notifications toggle

    /// Updates `profiles.notifications_enabled` for the row matching `authUserId`.
    func updateNotificationsEnabled(_ enabled: Bool, authUserId: UUID) async {
        guard let client = SupabaseProvider.client else { return }
        do {
            try await client
                .from("profiles")
                .update(["notifications_enabled": enabled])
                .eq("auth_user_id", value: authUserId.uuidString)
                .execute()
        } catch {
            AppLogger.log(
                category: "auth",
                level: .warning,
                message: "notifications_enabled update failed: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - App logs

    /// Fetches `app_logs` for `userId` created at or after `since`, newest first, capped at 200.
    /// Pass `levelFilter: "error"` to show errors-only; nil for all levels.
    func fetchLogs(userId: UUID, since: Date, levelFilter: String?) async -> [AppLogEntry] {
        guard let client = SupabaseProvider.client else { return [] }
        do {
            let iso = Self.isoFormatter.string(from: since)
            // Apply all filters before order/limit (filter methods live on PostgrestFilterBuilder,
            // not on PostgrestTransformBuilder returned by order/limit).
            var filterQuery = client
                .from("app_logs")
                .select("id, category, level, message, metadata, created_at")
                .eq("user_id", value: userId.uuidString)
                .gte("created_at", value: iso)

            if let levelFilter {
                filterQuery = filterQuery.eq("level", value: levelFilter)
            }

            let response = try await filterQuery
                .order("created_at", ascending: false)
                .limit(200)
                .execute()
            return try decodeEntries(from: response.data)
        } catch {
            AppLogger.log(
                category: "error",
                level: .warning,
                message: "app_logs fetch failed: \(error.localizedDescription)"
            )
            return []
        }
    }

    // MARK: - Private helpers

    private func decodeProfiles(from data: Data) throws -> [Profile] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = Self.isoFormatter.date(from: value) { return date }
            if let fallbackDate = ISO8601DateFormatter().date(from: value) { return fallbackDate }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO date: \(value)"
            )
        }
        return try decoder.decode([Profile].self, from: data)
    }

    private func decodeEntries(from data: Data) throws -> [AppLogEntry] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = Self.isoFormatter.date(from: value) { return date }
            if let date = ISO8601DateFormatter().date(from: value) { return date }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO date: \(value)"
            )
        }
        return try decoder.decode([AppLogEntry].self, from: data)
    }

    private static func resolveDisplayName(displayName: String?, authUserId: UUID) -> String {
        let trimmed = (displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return "FitUp \(authUserId.uuidString.prefix(6))"
    }

    private static func initials(from displayName: String) -> String {
        let words = displayName
            .split(whereSeparator: { $0.isWhitespace || $0 == "_" || $0 == "-" })
            .map(String.init)
            .filter { !$0.isEmpty }

        let letters: [Character]
        if words.count >= 2 {
            letters = [words[0].first, words[1].first].compactMap { $0 }
        } else if let firstWord = words.first {
            letters = Array(firstWord.prefix(2))
        } else {
            letters = ["F", "U"]
        }
        return String(letters).uppercased()
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}

// MARK: - AppLogEntry

/// Decoded row from the `app_logs` Supabase table. `Codable` so it can be JSON-exported.
struct AppLogEntry: Identifiable, Codable {
    let id: UUID
    let category: String
    let level: String
    let message: String
    let createdAt: Date
    /// jsonb metadata column — decoded leniently; nil when absent or non-string-keyed.
    let metadata: [String: String]?

    enum CodingKeys: String, CodingKey {
        case id, category, level, message, metadata
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id        = try c.decode(UUID.self,   forKey: .id)
        category  = try c.decode(String.self, forKey: .category)
        level     = try c.decode(String.self, forKey: .level)
        message   = try c.decode(String.self, forKey: .message)
        createdAt = try c.decode(Date.self,   forKey: .createdAt)
        metadata  = try? c.decodeIfPresent([String: String].self, forKey: .metadata)
    }
}

// MARK: - Private insert model

private struct ProfileInsert: Encodable {
    let authUserId: UUID
    let displayName: String
    let initials: String
    let timezone: String

    enum CodingKeys: String, CodingKey {
        case authUserId = "auth_user_id"
        case displayName = "display_name"
        case initials
        case timezone
    }
}
