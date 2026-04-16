//
//  MatchDayRepository.swift
//  FitUp
//
//  Slice 7 active match-day row management and metric total writes.
//

import Combine
import Foundation
import Supabase

struct MatchDaySyncWrite {
    let matchId: UUID
    let metricType: HealthMetricType
    let value: Int
    let sourceDate: String
}

struct HistoricalMatchDaySyncTarget: Identifiable {
    let matchId: UUID
    let matchDayId: UUID
    let metricType: HealthMetricType
    let calendarDate: Date
    let calendarDateString: String
    let timeZone: TimeZone?

    var id: UUID { matchDayId }
}

final class MatchDayRepository {
    private var client: SupabaseClient {
        get throws {
            guard let client = SupabaseProvider.client else {
                throw ProfileRepositoryError.supabaseNotConfigured
            }
            return client
        }
    }

    func syncActiveMatchTotals(
        currentUserId: UUID,
        stepsTotal: Int?,
        caloriesTotal: Int?
    ) async -> [MatchDaySyncWrite] {
        do {
            let matches = try await fetchActiveMatches(currentUserId: currentUserId)
            guard !matches.isEmpty else { return [] }

            var writes: [MatchDaySyncWrite] = []
            for match in matches {
                do {
                    let participantIds = try await fetchParticipantIds(matchId: match.id)
                    let dayRows = try await ensureMatchDays(
                        match: match,
                        participantIds: participantIds
                    )
                    guard let targetDay = resolveCurrentDayRow(rows: dayRows, matchTimezone: match.matchTimezone) else {
                        continue
                    }

                    if targetDay.status == "finalized" {
                        continue
                    }

                    let matchTZ = TimeZone(identifier: match.matchTimezone ?? "")
                    let formatter = Self.calendarFormatter(timezone: matchTZ)
                    let todayString = formatter.string(from: Date())

                    let resolvedTotal: Int
                    let querySource: String

                    if targetDay.calendarDate == todayString {
                        let live: Int?
                        switch match.metricType {
                        case .steps:
                            live = stepsTotal
                        case .activeCalories:
                            live = caloriesTotal
                        }
                        guard let live else { continue }
                        resolvedTotal = live
                        querySource = "today"
                    } else {
                        guard let dayDate = dateFromCalendarString(targetDay.calendarDate, timezone: matchTZ) else {
                            continue
                        }
                        do {
                            resolvedTotal = try await HealthKitService.fetchMetricTotal(
                                metricType: match.metricType,
                                for: dayDate,
                                timeZone: matchTZ
                            )
                            querySource = "calendar_day"
                        } catch {
                            AppLogger.log(
                                category: "healthkit_sync",
                                level: .warning,
                                message: "active match calendar-day metric read failed",
                                userId: currentUserId,
                                metadata: [
                                    "match_id": match.id.uuidString,
                                    "calendar_date": targetDay.calendarDate,
                                    "error": error.localizedDescription,
                                ]
                            )
                            continue
                        }
                    }

                    try await updateMetricTotal(
                        matchDayId: targetDay.id,
                        userId: currentUserId,
                        metricTotal: resolvedTotal
                    )
                    try await markDayProvisional(matchDayId: targetDay.id)
                    writes.append(
                        MatchDaySyncWrite(
                            matchId: match.id,
                            metricType: match.metricType,
                            value: resolvedTotal,
                            sourceDate: targetDay.calendarDate
                        )
                    )
                    AppLogger.log(
                        category: "match_debug",
                        level: .debug,
                        message: "active match metric_total sync",
                        userId: currentUserId,
                        metadata: [
                            "match_id": match.id.uuidString,
                            "match_day_id": targetDay.id.uuidString,
                            "calendar_date": targetDay.calendarDate,
                            "query_source": querySource,
                            "metric_total": "\(resolvedTotal)",
                            "metric_type": match.metricType.rawValue,
                        ]
                    )
                } catch {
                    AppLogger.log(
                        category: "healthkit_sync",
                        level: .warning,
                        message: "active match total sync failed",
                        userId: currentUserId,
                        metadata: [
                            "match_id": match.id.uuidString,
                            "error": error.localizedDescription,
                        ]
                    )
                }
            }

            return writes
        } catch {
            AppLogger.log(
                category: "healthkit_sync",
                level: .warning,
                message: "active match list load failed",
                userId: currentUserId,
                metadata: ["error": error.localizedDescription]
            )
            return []
        }
    }

    func pendingHistoricalSyncTargets(currentUserId: UUID) async -> [HistoricalMatchDaySyncTarget] {
        do {
            let matches = try await fetchActiveMatches(currentUserId: currentUserId)
            guard !matches.isEmpty else { return [] }

            var targets: [HistoricalMatchDaySyncTarget] = []
            for match in matches {
                let dayRows = try await ensureMatchDays(
                    match: match,
                    participantIds: try await fetchParticipantIds(matchId: match.id)
                )
                let timezone = TimeZone(identifier: match.matchTimezone ?? "")
                let todayString = Self.calendarFormatter(timezone: timezone).string(from: Date())
                let pendingPastRows = dayRows.filter { row in
                    row.status != "finalized" && row.calendarDate < todayString
                }

                for dayRow in pendingPastRows {
                    guard let participantStatus = try await fetchParticipantStatus(
                        matchDayId: dayRow.id,
                        userId: currentUserId
                    ) else {
                        continue
                    }
                    if participantStatus == "confirmed" {
                        continue
                    }
                    guard let parsedDate = dateFromCalendarString(dayRow.calendarDate, timezone: timezone) else {
                        continue
                    }
                    targets.append(
                        HistoricalMatchDaySyncTarget(
                            matchId: match.id,
                            matchDayId: dayRow.id,
                            metricType: match.metricType,
                            calendarDate: parsedDate,
                            calendarDateString: dayRow.calendarDate,
                            timeZone: timezone
                        )
                    )
                }
            }

            return targets
        } catch {
            AppLogger.log(
                category: "healthkit_sync",
                level: .warning,
                message: "historical day targets load failed",
                userId: currentUserId,
                metadata: ["error": error.localizedDescription]
            )
            return []
        }
    }

    func confirmHistoricalDayTotal(
        matchDayId: UUID,
        userId: UUID,
        metricTotal: Int
    ) async throws {
        try await updateMetricTotal(
            matchDayId: matchDayId,
            userId: userId,
            metricTotal: metricTotal,
            dataStatus: "confirmed"
        )
        try await markDayProvisional(matchDayId: matchDayId)
    }

    private func fetchActiveMatches(currentUserId: UUID) async throws -> [ActiveMatchData] {
        let participantResponse = try await client
            .from("match_participants")
            .select("match_id")
            .eq("user_id", value: currentUserId.uuidString)
            .execute()
        let matchIds = Set(jsonRows(from: participantResponse.data).compactMap { uuid(from: $0["match_id"]) })
        guard !matchIds.isEmpty else { return [] }

        var activeRows: [ActiveMatchData] = []
        for matchId in matchIds {
            let response = try await client
                .from("matches")
                .select("id, state, metric_type, duration_days, starts_at, match_timezone")
                .eq("id", value: matchId.uuidString)
                .limit(1)
                .execute()
            guard let row = jsonRows(from: response.data).first else { continue }
            guard string(from: row["state"]) == "active" else { continue }
            guard
                let metricRaw = string(from: row["metric_type"]),
                let metricType = HealthMetricType(rawValue: metricRaw),
                let durationDays = int(from: row["duration_days"])
            else {
                continue
            }
            activeRows.append(
                ActiveMatchData(
                    id: matchId,
                    metricType: metricType,
                    durationDays: durationDays,
                    startsAt: date(from: row["starts_at"]),
                    matchTimezone: string(from: row["match_timezone"])
                )
            )
        }
        return activeRows
    }

    private func fetchParticipantIds(matchId: UUID) async throws -> [UUID] {
        let response = try await client
            .from("match_participants")
            .select("user_id")
            .eq("match_id", value: matchId.uuidString)
            .execute()
        return jsonRows(from: response.data).compactMap { uuid(from: $0["user_id"]) }
    }

    private func ensureMatchDays(
        match: ActiveMatchData,
        participantIds: [UUID]
    ) async throws -> [MatchDayRow] {
        var dayRows = try await fetchMatchDayRows(matchId: match.id)

        if dayRows.count < max(match.durationDays, 1) {
            let timezone = TimeZone(identifier: match.matchTimezone ?? "")
            var calendar = Calendar.current
            if let timezone {
                calendar.timeZone = timezone
            }
            let formatter = Self.calendarFormatter(timezone: timezone)
            let startDate = calendar.startOfDay(for: match.startsAt ?? Date())

            let existingDayNumbers = Set(dayRows.map(\.dayNumber))
            var inserts: [MatchDayInsert] = []
            for dayNumber in 1...max(match.durationDays, 1) where !existingDayNumbers.contains(dayNumber) {
                guard let dayDate = calendar.date(byAdding: .day, value: dayNumber - 1, to: startDate) else {
                    continue
                }
                inserts.append(
                    MatchDayInsert(
                        matchId: match.id,
                        dayNumber: dayNumber,
                        calendarDate: formatter.string(from: dayDate),
                        status: "pending"
                    )
                )
            }

            if !inserts.isEmpty {
                try await client
                    .from("match_days")
                    .insert(inserts)
                    .execute()
                dayRows = try await fetchMatchDayRows(matchId: match.id)
            }
        }

        for dayRow in dayRows {
            let existingParticipantResponse = try await client
                .from("match_day_participants")
                .select("user_id")
                .eq("match_day_id", value: dayRow.id.uuidString)
                .execute()
            let existingUserIds = Set(jsonRows(from: existingParticipantResponse.data).compactMap { uuid(from: $0["user_id"]) })
            let missing = participantIds.filter { !existingUserIds.contains($0) }
            guard !missing.isEmpty else { continue }

            let inserts = missing.map { userId in
                MatchDayParticipantInsert(
                    matchDayId: dayRow.id,
                    userId: userId,
                    metricTotal: 0
                )
            }
            try await client
                .from("match_day_participants")
                .insert(inserts)
                .execute()
        }

        return dayRows
    }

    private func fetchMatchDayRows(matchId: UUID) async throws -> [MatchDayRow] {
        let response = try await client
            .from("match_days")
            .select("id, day_number, calendar_date, status")
            .eq("match_id", value: matchId.uuidString)
            .order("day_number", ascending: true)
            .execute()

        return jsonRows(from: response.data).compactMap { row in
            guard
                let id = uuid(from: row["id"]),
                let dayNumber = int(from: row["day_number"]),
                let calendarDate = string(from: row["calendar_date"])
            else {
                return nil
            }
            return MatchDayRow(
                id: id,
                dayNumber: dayNumber,
                calendarDate: calendarDate,
                status: string(from: row["status"]) ?? "pending"
            )
        }
    }

    private func resolveCurrentDayRow(
        rows: [MatchDayRow],
        matchTimezone: String?
    ) -> MatchDayRow? {
        guard !rows.isEmpty else { return nil }

        let timezone = TimeZone(identifier: matchTimezone ?? "")
        let formatter = Self.calendarFormatter(timezone: timezone)
        let todayString = formatter.string(from: Date())

        if let exactToday = rows.first(where: { $0.calendarDate == todayString && $0.status != "finalized" }) {
            return exactToday
        }

        let candidates = rows.filter { $0.calendarDate <= todayString && $0.status != "finalized" }
        if let latestPast = candidates.max(by: { $0.dayNumber < $1.dayNumber }) {
            return latestPast
        }

        return rows.filter { $0.status != "finalized" }.max(by: { $0.dayNumber < $1.dayNumber })
    }

    private func updateMetricTotal(
        matchDayId: UUID,
        userId: UUID,
        metricTotal: Int,
        dataStatus: String? = nil
    ) async throws {
        let updatePayload = MatchDayParticipantMetricUpdate(
            metricTotal: metricTotal,
            dataStatus: dataStatus,
            lastUpdatedAt: Self.isoFormatter.string(from: Date())
        )
        try await client
            .from("match_day_participants")
            .update(updatePayload)
            .eq("match_day_id", value: matchDayId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    private func markDayProvisional(matchDayId: UUID) async throws {
        try await client
            .from("match_days")
            .update(["status": "provisional"])
            .eq("id", value: matchDayId.uuidString)
            .neq("status", value: "finalized")
            .execute()
    }

    private func fetchParticipantStatus(matchDayId: UUID, userId: UUID) async throws -> String? {
        let response = try await client
            .from("match_day_participants")
            .select("data_status")
            .eq("match_day_id", value: matchDayId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
        return jsonRows(from: response.data).first.flatMap { string(from: $0["data_status"]) }
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
        if let string = value as? String { return UUID(uuidString: string) }
        return nil
    }

    private func string(from value: Any?) -> String? {
        value as? String
    }

    private func int(from value: Any?) -> Int? {
        if let intValue = value as? Int { return intValue }
        if let doubleValue = value as? Double { return Int(doubleValue.rounded()) }
        if let stringValue = value as? String, let doubleValue = Double(stringValue) {
            return Int(doubleValue.rounded())
        }
        return nil
    }

    private func date(from value: Any?) -> Date? {
        if let dateValue = value as? Date { return dateValue }
        if let stringValue = value as? String {
            if let parsed = Self.isoFormatter.date(from: stringValue) {
                return parsed
            }
            return ISO8601DateFormatter().date(from: stringValue)
        }
        return nil
    }

    private static func calendarFormatter(timezone: TimeZone?) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.timeZone = timezone ?? .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private func dateFromCalendarString(_ value: String, timezone: TimeZone?) -> Date? {
        Self.calendarFormatter(timezone: timezone).date(from: value)
    }
}

private struct ActiveMatchData {
    let id: UUID
    let metricType: HealthMetricType
    let durationDays: Int
    let startsAt: Date?
    let matchTimezone: String?
}

private struct MatchDayRow {
    let id: UUID
    let dayNumber: Int
    let calendarDate: String
    let status: String
}

private struct MatchDayInsert: Encodable {
    let matchId: UUID
    let dayNumber: Int
    let calendarDate: String
    let status: String

    enum CodingKeys: String, CodingKey {
        case matchId = "match_id"
        case dayNumber = "day_number"
        case calendarDate = "calendar_date"
        case status
    }
}

private struct MatchDayParticipantInsert: Encodable {
    let matchDayId: UUID
    let userId: UUID
    let metricTotal: Int

    enum CodingKeys: String, CodingKey {
        case matchDayId = "match_day_id"
        case userId = "user_id"
        case metricTotal = "metric_total"
    }
}

private struct MatchDayParticipantMetricUpdate: Encodable {
    let metricTotal: Int
    let dataStatus: String?
    let lastUpdatedAt: String

    enum CodingKeys: String, CodingKey {
        case metricTotal = "metric_total"
        case dataStatus = "data_status"
        case lastUpdatedAt = "last_updated_at"
    }
}
