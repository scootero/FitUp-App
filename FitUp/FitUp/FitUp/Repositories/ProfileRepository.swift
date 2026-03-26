//
//  ProfileRepository.swift
//  FitUp
//
//  Slice 1: all profile table reads/writes for auth flow.
//

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

    func fetchProfile(authUserId: UUID) async throws -> Profile? {
        let response = try await client
            .from("profiles")
            .select()
            .eq("auth_user_id", value: authUserId.uuidString)
            .limit(1)
            .execute()
        return try decodeProfiles(from: response.data).first
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

    private func decodeProfiles(from data: Data) throws -> [Profile] {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = formatter.date(from: value) {
                return date
            }
            if let fallbackDate = ISO8601DateFormatter().date(from: value) {
                return fallbackDate
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO date: \(value)")
        }
        return try decoder.decode([Profile].self, from: data)
    }

    private static func resolveDisplayName(displayName: String?, authUserId: UUID) -> String {
        let trimmed = (displayName ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }
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
}

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
