//
//  PublicDailyActivityRepository.swift
//  FitUp
//
//  Reads and writes per-user public “today” step/calorie totals for the challenge rival strip.
//

import Foundation
import Supabase

struct ChallengeRivalStripEntry: Identifiable, Equatable {
    var id: UUID { userId }
    let userId: UUID
    let displayName: String
    let initials: String
    let colorHex: String
    let steps: Int?
    let activeCalories: Int?
    let comparison: ChallengeRivalComparison
}

enum ChallengeRivalComparison: Equatable {
    case opponentAhead
    case youAhead
    case tie
    case unknown
}

final class PublicDailyActivityRepository {
    private var client: SupabaseClient {
        get throws {
            guard let client = SupabaseProvider.client else {
                throw ProfileRepositoryError.supabaseNotConfigured
            }
            return client
        }
    }

    // MARK: - Date helpers (profile TZ for writes; device calendar for read filter per plan)

    /// Calendar day in the user’s profile timezone, or device if unset.
    static func activeDateString(for profile: Profile, now: Date = Date()) -> String {
        localCalendarDateString(for: now, timeZoneIdentifier: profile.timezone)
    }

    /// `yyyy-MM-dd` in the given timezone, or the device timezone.
    static func localCalendarDateString(for date: Date, timeZoneIdentifier: String?) -> String {
        var calendar = Calendar(identifier: .gregorian)
        if let id = timeZoneIdentifier, let tz = TimeZone(identifier: id) {
            calendar.timeZone = tz
        } else {
            calendar.timeZone = .current
        }
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            c.year ?? 0,
            c.month ?? 0,
            c.day ?? 0
        )
    }

    static func viewerLocalDateString(now: Date = Date()) -> String {
        localCalendarDateString(for: now, timeZoneIdentifier: nil)
    }

    static func colorHex(for userId: UUID) -> String {
        let palette = ["00AAFF", "FF6200", "BF5FFF", "FFE000", "39FF14", "FF2D9B"]
        let index = abs(userId.hashValue) % palette.count
        return palette[index]
    }

    // MARK: - Public daily write

    func upsertMyPublicDailyActivity(
        userId: UUID,
        activeDate: String,
        steps: Int?,
        activeCalories: Int?
    ) async throws {
        guard steps != nil || activeCalories != nil else { return }

        let c = try client
        let nowIso = Self.isoFormatter.string(from: Date())

        let existsResponse = try await c
            .from("user_public_daily_activity")
            .select("user_id")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()

        let payload = PublicDailyRow(
            userId: userId,
            activeDate: activeDate,
            steps: steps,
            activeCalories: activeCalories,
            updatedAt: nowIso
        )

        if jsonRows(from: existsResponse.data).isEmpty {
            try await c
                .from("user_public_daily_activity")
                .insert(payload)
                .execute()
        } else {
            try await c
                .from("user_public_daily_activity")
                .update(
                    PublicDailyUpdate(
                        activeDate: activeDate,
                        steps: steps,
                        activeCalories: activeCalories,
                        updatedAt: nowIso
                    )
                )
                .eq("user_id", value: userId.uuidString)
                .execute()
        }
    }

    // MARK: - Rival strip

    /// Loads other users’ public activity for the viewer’s local calendar `active_date`, sorted by steps then active calories.
    func fetchRivalStripEntries(
        currentUserId: UUID,
        viewerLocalActiveDate: String
    ) async throws -> (rivals: [ChallengeRivalStripEntry], mySteps: Int?, myCalories: Int?) {
        let c = try client

        let mineResponse = try await c
            .from("user_public_daily_activity")
            .select("steps, active_calories")
            .eq("user_id", value: currentUserId.uuidString)
            .eq("active_date", value: viewerLocalActiveDate)
            .limit(1)
            .execute()

        let myRow = jsonRows(from: mineResponse.data).first
        let mySteps = int(from: myRow?["steps"])
        let myCalories = int(from: myRow?["active_calories"])

        let response = try await c
            .from("user_public_daily_activity")
            .select(
                """
                user_id,
                steps,
                active_calories,
                active_date,
                profiles!inner(display_name, initials)
                """
            )
            .eq("active_date", value: viewerLocalActiveDate)
            .neq("user_id", value: currentUserId.uuidString)
            .limit(50)
            .execute()

        var entries: [ChallengeRivalStripEntry] = []
        for row in jsonRows(from: response.data) {
            guard let userId = uuid(from: row["user_id"]) else { continue }
            let profile = (row["profiles"] as? [String: Any]) ?? (row["profiles"] as? [[String: Any]])?.first
            guard let profile else { continue }

            let displayName = (string(from: profile["display_name"]) ?? "Player").trimmingCharacters(in: .whitespacesAndNewlines)
            let initials = string(from: profile["initials"])?.trimmingCharacters(in: .whitespacesAndNewlines)
            let initialsOut: String
            if let initials, !initials.isEmpty {
                initialsOut = initials.uppercased()
            } else {
                initialsOut = String(displayName.prefix(2)).uppercased()
            }
            let stepsV = int(from: row["steps"])
            let calsV = int(from: row["active_calories"])
            let cmp = compareOpponent(
                mySteps: mySteps,
                myCalories: myCalories,
                theirSteps: stepsV,
                theirCalories: calsV
            )
            entries.append(
                ChallengeRivalStripEntry(
                    userId: userId,
                    displayName: displayName,
                    initials: initialsOut,
                    colorHex: Self.colorHex(for: userId),
                    steps: stepsV,
                    activeCalories: calsV,
                    comparison: cmp
                )
            )
        }

        entries.sort { a, b in
            if (a.steps ?? -1) != (b.steps ?? -1) {
                return (a.steps ?? -1) > (b.steps ?? -1)
            }
            if (a.activeCalories ?? -1) != (b.activeCalories ?? -1) {
                return (a.activeCalories ?? -1) > (b.activeCalories ?? -1)
            }
            return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }

        return (entries, mySteps, myCalories)
    }

    // MARK: - Compare

    private func compareOpponent(
        mySteps: Int?,
        myCalories: Int?,
        theirSteps: Int?,
        theirCalories: Int?
    ) -> ChallengeRivalComparison {
        if mySteps == nil, myCalories == nil { return .unknown }
        if theirSteps == nil, theirCalories == nil { return .unknown }

        if let ts = theirSteps, let ms = mySteps {
            if ts > ms { return .opponentAhead }
            if ts < ms { return .youAhead }
        } else if theirSteps != nil, mySteps == nil {
            return .opponentAhead
        } else if mySteps != nil, theirSteps == nil {
            return .youAhead
        }

        if let tc = theirCalories, let mc = myCalories {
            if tc > mc { return .opponentAhead }
            if tc < mc { return .youAhead }
            return .tie
        }
        if theirCalories == nil, myCalories == nil, theirSteps != nil, mySteps != nil {
            return .tie
        }
        return .unknown
    }

    // MARK: - JSON

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func jsonRows(from data: Data) -> [[String: Any]] {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let rows = object as? [[String: Any]]
        else {
            return []
        }
        return rows
    }

    private func uuid(from value: Any?) -> UUID? {
        if let uuid = value as? UUID { return uuid }
        if let string = value as? String { return UUID(uuidString: string) }
        return nil
    }

    private func string(from value: Any?) -> String? {
        value as? String
    }

    private func int(from value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue.rounded()) }
        if let text = value as? String, let doubleValue = Double(text) {
            return Int(doubleValue.rounded())
        }
        return nil
    }
}

private struct PublicDailyRow: Encodable {
    let userId: UUID
    let activeDate: String
    let steps: Int?
    let activeCalories: Int?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case activeDate = "active_date"
        case steps
        case activeCalories = "active_calories"
        case updatedAt = "updated_at"
    }
}

private struct PublicDailyUpdate: Encodable {
    let activeDate: String
    let steps: Int?
    let activeCalories: Int?
    let updatedAt: String

    enum CodingKeys: String, CodingKey {
        case activeDate = "active_date"
        case steps
        case activeCalories = "active_calories"
        case updatedAt = "updated_at"
    }
}
