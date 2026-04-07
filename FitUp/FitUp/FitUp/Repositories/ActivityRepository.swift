//
//  ActivityRepository.swift
//  FitUp
//
//  Slice 8 minimal Activity completed matches feed.
//

import Combine
import Foundation
import Supabase

struct ActivityCompletedMatch: Identifiable, Equatable {
    let id: UUID
    let opponentName: String
    let opponentInitials: String
    let opponentColorHex: String
    let metricType: String
    let durationDays: Int
    let myScore: Int
    let theirScore: Int
    let myWon: Bool
    let rangeLabel: String
    let completedAt: Date?
}

final class ActivityRepository {
    func loadCompletedMatches(currentUserId: UUID) async -> [ActivityCompletedMatch] {
        guard let client = SupabaseProvider.client else { return [] }

        do {
            let participantResponse = try await client
                .from("match_participants")
                .select("match_id")
                .eq("user_id", value: currentUserId.uuidString)
                .execute()

            let matchIds = Set(jsonRows(from: participantResponse.data).compactMap { uuid(from: $0["match_id"]) })
            guard !matchIds.isEmpty else { return [] }

            var rows: [ActivityCompletedMatch] = []
            for matchId in matchIds {
                guard let match = try await fetchMatchRow(client: client, matchId: matchId) else { continue }
                guard string(from: match["state"]) == "completed" else { continue }

                let participants = try await fetchMatchParticipants(client: client, matchId: matchId)
                guard
                    let opponentId = participants
                        .compactMap({ uuid(from: $0["user_id"]) })
                        .first(where: { $0 != currentUserId }),
                    let opponent = try await fetchProfileRow(client: client, profileId: opponentId)
                else {
                    continue
                }

                let dayRows = try await fetchDayRows(client: client, matchId: matchId)
                let score = deriveSeriesScore(dayRows: dayRows, currentUserId: currentUserId, opponentId: opponentId)

                let completedAt = date(from: match["completed_at"]) ?? date(from: match["ends_at"])
                let startsAt = date(from: match["starts_at"])
                rows.append(
                    ActivityCompletedMatch(
                        id: matchId,
                        opponentName: displayName(from: opponent),
                        opponentInitials: initials(from: opponent),
                        opponentColorHex: colorHex(for: opponentId),
                        metricType: string(from: match["metric_type"]) ?? "steps",
                        durationDays: int(from: match["duration_days"]) ?? 1,
                        myScore: score.myScore,
                        theirScore: score.theirScore,
                        myWon: score.myScore >= score.theirScore,
                        rangeLabel: dateRangeLabel(startsAt: startsAt, completedAt: completedAt),
                        completedAt: completedAt
                    )
                )
            }

            return rows.sorted {
                ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
            }
        } catch {
            AppLogger.log(
                category: "match_state",
                level: .warning,
                message: "activity completed matches load failed",
                userId: currentUserId,
                metadata: ["error": error.localizedDescription]
            )
            return []
        }
    }

    private func fetchMatchRow(client: SupabaseClient, matchId: UUID) async throws -> [String: Any]? {
        let response = try await client
            .from("matches")
            .select("id, state, metric_type, duration_days, starts_at, ends_at, completed_at")
            .eq("id", value: matchId.uuidString)
            .limit(1)
            .execute()
        return jsonRows(from: response.data).first
    }

    private func fetchMatchParticipants(client: SupabaseClient, matchId: UUID) async throws -> [[String: Any]] {
        let response = try await client
            .from("match_participants")
            .select("user_id")
            .eq("match_id", value: matchId.uuidString)
            .execute()
        return jsonRows(from: response.data)
    }

    private func fetchProfileRow(client: SupabaseClient, profileId: UUID) async throws -> [String: Any]? {
        let response = try await client
            .from("profiles")
            .select("display_name, initials")
            .eq("id", value: profileId.uuidString)
            .limit(1)
            .execute()
        return jsonRows(from: response.data).first
    }

    private func fetchDayRows(client: SupabaseClient, matchId: UUID) async throws -> [[String: Any]] {
        let response = try await client
            .from("match_days")
            .select("winner_user_id, is_void, status")
            .eq("match_id", value: matchId.uuidString)
            .order("day_number", ascending: true)
            .execute()
        return jsonRows(from: response.data)
    }

    private func deriveSeriesScore(
        dayRows: [[String: Any]],
        currentUserId: UUID,
        opponentId: UUID
    ) -> (myScore: Int, theirScore: Int) {
        var myScore = 0
        var theirScore = 0
        for row in dayRows {
            guard string(from: row["status"]) == "finalized" else { continue }
            if bool(from: row["is_void"]) == true { continue }
            guard let winnerId = uuid(from: row["winner_user_id"]) else { continue }
            if winnerId == currentUserId {
                myScore += 1
            } else if winnerId == opponentId {
                theirScore += 1
            }
        }
        return (myScore, theirScore)
    }

    private func dateRangeLabel(startsAt: Date?, completedAt: Date?) -> String {
        guard let startsAt else { return "Completed" }
        let endDate = completedAt ?? startsAt
        return "\(Self.dateFormatter.string(from: startsAt)) - \(Self.dateFormatter.string(from: endDate))"
    }

    private func displayName(from row: [String: Any]) -> String {
        let raw = string(from: row["display_name"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty {
            return raw
        }
        return "Opponent"
    }

    private func initials(from row: [String: Any]) -> String {
        let raw = string(from: row["initials"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty {
            return raw.uppercased()
        }
        return "OP"
    }

    private func colorHex(for userId: UUID) -> String {
        let palette = ["00AAFF", "FF6200", "BF5FFF", "FFE000", "39FF14", "FF2D9B"]
        let index = abs(userId.uuidString.hashValue) % palette.count
        return palette[index]
    }

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
        if let text = value as? String { return UUID(uuidString: text) }
        return nil
    }

    private func string(from value: Any?) -> String? {
        value as? String
    }

    private func bool(from value: Any?) -> Bool? {
        if let boolValue = value as? Bool { return boolValue }
        if let text = value as? String {
            return NSString(string: text).boolValue
        }
        return nil
    }

    private func int(from value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue.rounded()) }
        if let text = value as? String, let doubleValue = Double(text) {
            return Int(doubleValue.rounded())
        }
        return nil
    }

    private func date(from value: Any?) -> Date? {
        if let dateValue = value as? Date { return dateValue }
        if let text = value as? String {
            if let parsed = Self.isoFormatter.date(from: text) {
                return parsed
            }
            return ISO8601DateFormatter().date(from: text)
        }
        return nil
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()
}
