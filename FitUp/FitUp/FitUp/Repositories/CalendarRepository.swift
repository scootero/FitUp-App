//
//  CalendarRepository.swift
//  FitUp
//
//  Date-range fetch for activity calendar battle states.
//

import Foundation
import Supabase

final class CalendarRepository {
    private let headToHeadRepository = HeadToHeadRepository()
    private let homeRepository = HomeRepository()
    /// Fetches aggregated battle states and summaries keyed by `yyyy-MM-dd` for the inclusive date range.
    func fetchBattleStates(
        currentUserId: UUID,
        startDateKey: String,
        endDateKey: String
    ) async -> CalendarBattleStatesResult {
        guard let client = SupabaseProvider.client else {
            return CalendarBattleStatesResult(states: [:], summaries: [:])
        }
        guard startDateKey <= endDateKey else {
            return CalendarBattleStatesResult(states: [:], summaries: [:])
        }

        do {
            let participantResponse = try await client
                .from("match_participants")
                .select("match_id")
                .eq("user_id", value: currentUserId.uuidString)
                .execute()

            let matchIds = Set(jsonRows(from: participantResponse.data).compactMap { uuid(from: $0["match_id"]) })
            guard !matchIds.isEmpty else {
                return CalendarBattleStatesResult(states: [:], summaries: [:])
            }

            let dayRowsResponse = try await client
                .from("match_days")
                .select("calendar_date, status, winner_user_id, is_void")
                .in("match_id", values: Array(matchIds))
                .gte("calendar_date", value: startDateKey)
                .lte("calendar_date", value: endDateKey)
                .execute()

            var rowsByDate: [String: [CalendarMatchDayRow]] = [:]
            for row in jsonRows(from: dayRowsResponse.data) {
                guard let dateKey = string(from: row["calendar_date"]), !dateKey.isEmpty else { continue }
                let matchDay = CalendarMatchDayRow(
                    calendarDate: dateKey,
                    status: string(from: row["status"]) ?? "pending",
                    isVoid: bool(from: row["is_void"]) == true,
                    winnerUserId: uuid(from: row["winner_user_id"])
                )
                rowsByDate[dateKey, default: []].append(matchDay)
            }

            var states: [String: CalendarDayBattleState] = [:]
            var summaries: [String: CalendarDayBattleSummary] = [:]
            for (dateKey, dayRows) in rowsByDate {
                summaries[dateKey] = CalendarDayBattleSummary.aggregateSummary(dayRows: dayRows, userId: currentUserId)
                states[dateKey] = summaries[dateKey]?.state ?? .none
            }
            return CalendarBattleStatesResult(states: states, summaries: summaries)
        } catch {
            if error is CancellationError {
                return CalendarBattleStatesResult(states: [:], summaries: [:])
            }
            AppLogger.log(
                category: "match_state",
                level: .warning,
                message: "calendar battle states load failed",
                userId: currentUserId,
                metadata: [
                    "error": error.localizedDescription,
                    "start": startDateKey,
                    "end": endDateKey,
                ]
            )
            return CalendarBattleStatesResult(states: [:], summaries: [:])
        }
    }

    /// Steps-only battle states for the inclusive date range (`nil` when the fetch fails).
    func fetchStepsBattleStates(
        currentUserId: UUID,
        startDateKey: String,
        endDateKey: String
    ) async -> [String: CalendarDayBattleState]? {
        guard let client = SupabaseProvider.client else { return nil }
        guard startDateKey <= endDateKey else { return [:] }

        do {
            let participantResponse = try await client
                .from("match_participants")
                .select("match_id")
                .eq("user_id", value: currentUserId.uuidString)
                .execute()

            let allMatchIds = Set(jsonRows(from: participantResponse.data).compactMap { uuid(from: $0["match_id"]) })
            guard !allMatchIds.isEmpty else { return [:] }

            let stepsMatchResponse = try await client
                .from("matches")
                .select("id")
                .in("id", values: Array(allMatchIds))
                .eq("metric_type", value: "steps")
                .in("state", values: ["active", "completed"])
                .execute()

            let stepMatchIds = Set(jsonRows(from: stepsMatchResponse.data).compactMap { uuid(from: $0["id"]) })
            guard !stepMatchIds.isEmpty else { return [:] }

            let dayRowsResponse = try await client
                .from("match_days")
                .select("calendar_date, status, winner_user_id, is_void")
                .in("match_id", values: Array(stepMatchIds))
                .gte("calendar_date", value: startDateKey)
                .lte("calendar_date", value: endDateKey)
                .execute()

            var rowsByDate: [String: [CalendarMatchDayRow]] = [:]
            for row in jsonRows(from: dayRowsResponse.data) {
                guard let dateKey = string(from: row["calendar_date"]), !dateKey.isEmpty else { continue }
                let matchDay = CalendarMatchDayRow(
                    calendarDate: dateKey,
                    status: string(from: row["status"]) ?? "pending",
                    isVoid: bool(from: row["is_void"]) == true,
                    winnerUserId: uuid(from: row["winner_user_id"])
                )
                rowsByDate[dateKey, default: []].append(matchDay)
            }

            var result: [String: CalendarDayBattleState] = [:]
            for (dateKey, dayRows) in rowsByDate {
                result[dateKey] = CalendarDayBattleState.aggregate(dayRows: dayRows, userId: currentUserId)
            }
            return result
        } catch {
            if error is CancellationError { return nil }
            AppLogger.log(
                category: "match_state",
                level: .warning,
                message: "calendar steps battle states load failed",
                userId: currentUserId,
                metadata: [
                    "error": error.localizedDescription,
                    "start": startDateKey,
                    "end": endDateKey,
                ]
            )
            return nil
        }
    }

    /// Non-void `steps` battle day keys (`yyyy-MM-dd`) for the user (includes in-progress days).
    func fetchStepsBattleDateKeys(
        currentUserId: UUID,
        startDateKey: String,
        endDateKey: String
    ) async -> Set<String> {
        guard let client = SupabaseProvider.client else { return [] }
        guard startDateKey <= endDateKey else { return [] }

        do {
            let participantResponse = try await client
                .from("match_participants")
                .select("match_id")
                .eq("user_id", value: currentUserId.uuidString)
                .execute()

            let allMatchIds = Set(jsonRows(from: participantResponse.data).compactMap { uuid(from: $0["match_id"]) })
            guard !allMatchIds.isEmpty else { return [] }

            let stepsMatchResponse = try await client
                .from("matches")
                .select("id")
                .in("id", values: Array(allMatchIds))
                .eq("metric_type", value: "steps")
                .in("state", values: ["active", "completed"])
                .execute()

            let stepMatchIds = Set(jsonRows(from: stepsMatchResponse.data).compactMap { uuid(from: $0["id"]) })
            guard !stepMatchIds.isEmpty else { return [] }

            let dayRowsResponse = try await client
                .from("match_days")
                .select("calendar_date")
                .in("match_id", values: Array(stepMatchIds))
                .eq("is_void", value: false)
                .gte("calendar_date", value: startDateKey)
                .lte("calendar_date", value: endDateKey)
                .execute()

            let keys = jsonRows(from: dayRowsResponse.data).compactMap { string(from: $0["calendar_date"]) }
            return Set(keys.filter { !$0.isEmpty })
        } catch {
            if error is CancellationError { return [] }
            AppLogger.log(
                category: "match_state",
                level: .warning,
                message: "calendar steps battle day keys load failed",
                userId: currentUserId,
                metadata: [
                    "error": error.localizedDescription,
                    "start": startDateKey,
                    "end": endDateKey,
                ]
            )
            return []
        }
    }

    /// Returns finalized, non-void `steps` battle day keys (`yyyy-MM-dd`) where the current user participated.
    func fetchFinalizedStepsBattleDateKeys(
        currentUserId: UUID,
        startDateKey: String,
        endDateKey: String
    ) async -> Set<String> {
        guard let client = SupabaseProvider.client else { return [] }
        guard startDateKey <= endDateKey else { return [] }

        do {
            let participantResponse = try await client
                .from("match_participants")
                .select("match_id")
                .eq("user_id", value: currentUserId.uuidString)
                .execute()

            let allMatchIds = Set(jsonRows(from: participantResponse.data).compactMap { uuid(from: $0["match_id"]) })
            guard !allMatchIds.isEmpty else { return [] }

            let stepsMatchResponse = try await client
                .from("matches")
                .select("id")
                .in("id", values: Array(allMatchIds))
                .eq("metric_type", value: "steps")
                .in("state", values: ["active", "completed"])
                .execute()

            let stepMatchIds = Set(jsonRows(from: stepsMatchResponse.data).compactMap { uuid(from: $0["id"]) })
            guard !stepMatchIds.isEmpty else { return [] }

            let dayRowsResponse = try await client
                .from("match_days")
                .select("calendar_date")
                .in("match_id", values: Array(stepMatchIds))
                .eq("status", value: "finalized")
                .eq("is_void", value: false)
                .gte("calendar_date", value: startDateKey)
                .lte("calendar_date", value: endDateKey)
                .execute()

            let keys = jsonRows(from: dayRowsResponse.data).compactMap { string(from: $0["calendar_date"]) }
            return Set(keys.filter { !$0.isEmpty })
        } catch {
            if error is CancellationError { return [] }
            AppLogger.log(
                category: "match_state",
                level: .warning,
                message: "calendar finalized steps day keys load failed",
                userId: currentUserId,
                metadata: [
                    "error": error.localizedDescription,
                    "start": startDateKey,
                    "end": endDateKey,
                ]
            )
            return []
        }
    }

    /// Full battle breakdown for one calendar date (all matches that day).
    func fetchDayBattleDetail(currentUserId: UUID, dateKey: String) async -> CalendarDayBattleDetail? {
        guard let client = SupabaseProvider.client else { return nil }

        do {
            let participantResponse = try await client
                .from("match_participants")
                .select("match_id")
                .eq("user_id", value: currentUserId.uuidString)
                .execute()

            let matchIds = Set(jsonRows(from: participantResponse.data).compactMap { uuid(from: $0["match_id"]) })
            guard !matchIds.isEmpty else { return emptyBattleDetail(dateKey: dateKey) }

            let dayRowsResponse = try await client
                .from("match_days")
                .select("id, match_id, status, winner_user_id, is_void")
                .in("match_id", values: Array(matchIds))
                .eq("calendar_date", value: dateKey)
                .execute()

            let dayRows = jsonRows(from: dayRowsResponse.data)
            guard !dayRows.isEmpty else { return emptyBattleDetail(dateKey: dateKey) }

            let dayIds = dayRows.compactMap { uuid(from: $0["id"]) }
            var dayParticipantRows: [[String: Any]] = []
            if !dayIds.isEmpty {
                let dayParticipantsResponse = try await client
                    .from("match_day_participants")
                    .select("match_day_id, user_id, metric_total, finalized_value")
                    .in("match_day_id", values: dayIds)
                    .execute()
                dayParticipantRows = jsonRows(from: dayParticipantsResponse.data)
            }

            let involvedMatchIds = Set(dayRows.compactMap { uuid(from: $0["match_id"]) })
            let participantsResponse = try await client
                .from("match_participants")
                .select("match_id, user_id")
                .in("match_id", values: Array(involvedMatchIds))
                .execute()
            let participantRows = jsonRows(from: participantsResponse.data)

            var participantsByMatch: [UUID: [UUID]] = [:]
            for row in participantRows {
                guard let matchId = uuid(from: row["match_id"]), let uid = uuid(from: row["user_id"]) else { continue }
                participantsByMatch[matchId, default: []].append(uid)
            }

            let opponentIds = Set(
                participantsByMatch.values
                    .flatMap { $0 }
                    .filter { $0 != currentUserId }
            )

            var profileById: [UUID: CalendarOpponentSummary] = [:]
            if !opponentIds.isEmpty {
                let profilesResponse = try await client
                    .from("profiles")
                    .select("id, display_name, initials")
                    .in("id", values: Array(opponentIds))
                    .execute()
                for row in jsonRows(from: profilesResponse.data) {
                    guard let id = uuid(from: row["id"]) else { continue }
                    profileById[id] = CalendarOpponentSummary(
                        id: id,
                        displayName: displayName(from: row),
                        initials: initials(from: row),
                        colorHex: homeRepository.colorHex(for: id)
                    )
                }
            }

            var dayParticipantsByDay: [UUID: [[String: Any]]] = [:]
            for row in dayParticipantRows {
                guard let dayId = uuid(from: row["match_day_id"]) else { continue }
                dayParticipantsByDay[dayId, default: []].append(row)
            }

            var matchDetails: [CalendarDayBattleMatchDetail] = []
            var aggregateRows: [CalendarMatchDayRow] = []

            for rawDay in dayRows {
                guard
                    let dayId = uuid(from: rawDay["id"]),
                    let matchId = uuid(from: rawDay["match_id"])
                else { continue }

                let status = string(from: rawDay["status"]) ?? "pending"
                let isVoid = bool(from: rawDay["is_void"]) == true
                let winnerId = uuid(from: rawDay["winner_user_id"])
                aggregateRows.append(
                    CalendarMatchDayRow(
                        calendarDate: dateKey,
                        status: status,
                        isVoid: isVoid,
                        winnerUserId: winnerId
                    )
                )

                guard
                    let opponentId = participantsByMatch[matchId]?.first(where: { $0 != currentUserId }),
                    let opponent = profileById[opponentId]
                else { continue }

                let partRows = dayParticipantsByDay[dayId] ?? []
                let myRow = partRows.first { uuid(from: $0["user_id"]) == currentUserId }
                let theirRow = partRows.first { uuid(from: $0["user_id"]) == opponentId }
                let mySteps = metricTotal(from: myRow, finalized: status == "finalized")
                let theirSteps = metricTotal(from: theirRow, finalized: status == "finalized")

                let myWon: Bool?
                if status != "finalized" {
                    myWon = nil
                } else if isVoid {
                    myWon = nil
                } else if let winnerId {
                    myWon = winnerId == currentUserId
                } else {
                    myWon = nil
                }

                async let h2h = try? headToHeadRepository.fetchStats(opponentId: opponentId, viewerId: currentUserId)
                async let emblems = fetchRivalryEmblems(
                    client: client,
                    currentUserId: currentUserId,
                    opponentId: opponentId
                )

                let headToHead = await h2h
                let rivalryEmblems = await emblems

                matchDetails.append(
                    CalendarDayBattleMatchDetail(
                        id: dayId,
                        matchId: matchId,
                        opponent: opponent,
                        mySteps: mySteps,
                        theirSteps: theirSteps,
                        myWon: myWon,
                        isVoid: isVoid,
                        isFinalized: status == "finalized",
                        headToHead: headToHead,
                        rivalryEmblems: rivalryEmblems
                    )
                )
            }

            let aggregate = CalendarDayBattleState.aggregate(dayRows: aggregateRows, userId: currentUserId)
            return CalendarDayBattleDetail(
                dateKey: dateKey,
                displayTitle: formattedDayTitle(dateKey: dateKey),
                summaryLine: battleSummaryLine(state: aggregate, matchCount: matchDetails.count),
                aggregateState: aggregate,
                matches: matchDetails.sorted { $0.theirSteps > $1.theirSteps }
            )
        } catch {
            if error is CancellationError { return nil }
            AppLogger.log(
                category: "match_state",
                level: .warning,
                message: "calendar day battle detail failed",
                userId: currentUserId,
                metadata: ["error": error.localizedDescription, "date": dateKey]
            )
            return nil
        }
    }

    private func emptyBattleDetail(dateKey: String) -> CalendarDayBattleDetail {
        CalendarDayBattleDetail(
            dateKey: dateKey,
            displayTitle: formattedDayTitle(dateKey: dateKey),
            summaryLine: "No battles logged this day.",
            aggregateState: .none,
            matches: []
        )
    }

    private func fetchRivalryEmblems(
        client: SupabaseClient,
        currentUserId: UUID,
        opponentId: UUID
    ) async -> [CalendarRivalryEmblem] {
        do {
            let myMatchesResponse = try await client
                .from("match_participants")
                .select("match_id")
                .eq("user_id", value: currentUserId.uuidString)
                .execute()
            let myMatchIds = Set(jsonRows(from: myMatchesResponse.data).compactMap { uuid(from: $0["match_id"]) })
            guard !myMatchIds.isEmpty else { return [] }

            let opponentMatchesResponse = try await client
                .from("match_participants")
                .select("match_id")
                .eq("user_id", value: opponentId.uuidString)
                .in("match_id", values: Array(myMatchIds))
                .execute()
            let sharedMatchIds = Set(jsonRows(from: opponentMatchesResponse.data).compactMap { uuid(from: $0["match_id"]) })
            guard !sharedMatchIds.isEmpty else { return [] }

            let matchesResponse = try await client
                .from("matches")
                .select("id, state, completed_at")
                .in("id", values: Array(sharedMatchIds))
                .eq("state", value: "completed")
                .order("completed_at", ascending: true)
                .execute()

            let completedRows = jsonRows(from: matchesResponse.data)
            var emblems: [CalendarRivalryEmblem] = []

            for matchRow in completedRows {
                guard let matchId = uuid(from: matchRow["id"]) else { continue }
                let dayRowsResponse = try await client
                    .from("match_days")
                    .select("winner_user_id, is_void, status")
                    .eq("match_id", value: matchId.uuidString)
                    .execute()
                let dayRows = jsonRows(from: dayRowsResponse.data)
                var myScore = 0
                var theirScore = 0
                for day in dayRows {
                    guard string(from: day["status"]) == "finalized" else { continue }
                    if bool(from: day["is_void"]) == true { continue }
                    guard let winnerId = uuid(from: day["winner_user_id"]) else { continue }
                    if winnerId == currentUserId {
                        myScore += 1
                    } else if winnerId == opponentId {
                        theirScore += 1
                    }
                }
                let viewerWon = myScore >= theirScore
                emblems.append(
                    CalendarRivalryEmblem(
                        id: matchId,
                        viewerWon: viewerWon,
                        completedAt: date(from: matchRow["completed_at"])
                    )
                )
            }

            return emblems
        } catch {
            return []
        }
    }

    private func formattedDayTitle(dateKey: String) -> String {
        let parts = dateKey.split(separator: "-")
        guard parts.count == 3,
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else { return dateKey.uppercased() }
        let monthSymbols = ["", "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        let monthLabel = (1...12).contains(month) ? monthSymbols[month] : "???"
        return "\(monthLabel) \(day)"
    }

    private func battleSummaryLine(state: CalendarDayBattleState, matchCount: Int) -> String {
        switch state {
        case .none:
            return "No battles logged this day."
        case .inProgress:
            return matchCount == 1 ? "Battle in progress — day not finalized yet." : "\(matchCount) battles in progress today."
        case .wonAny:
            return matchCount == 1 ? "You took the day." : "You won at least one battle today."
        case .lostAll:
            return matchCount == 1 ? "Tough day — rival edged you out." : "No wins today across \(matchCount) battles."
        case .voidOnly:
            return "Day ended in a tie or void."
        }
    }

    private func metricTotal(from row: [String: Any]?, finalized: Bool) -> Int {
        guard let row else { return 0 }
        if finalized, let v = int(from: row["finalized_value"]) { return v }
        return int(from: row["metric_total"]) ?? 0
    }

    private func displayName(from row: [String: Any]) -> String {
        let raw = string(from: row["display_name"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty { return raw }
        return "Rival"
    }

    private func initials(from row: [String: Any]) -> String {
        let raw = string(from: row["initials"])?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw, !raw.isEmpty { return String(raw.prefix(2)).uppercased() }
        return "RV"
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
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = f.date(from: text) { return d }
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: text)
        }
        return nil
    }

    // MARK: - JSON helpers

    private func jsonRows(from data: Data) -> [[String: Any]] {
        guard
            let json = try? JSONSerialization.jsonObject(with: data),
            let rows = json as? [[String: Any]]
        else {
            return []
        }
        return rows
    }

    private func uuid(from value: Any?) -> UUID? {
        if let uuid = value as? UUID { return uuid }
        if let str = value as? String { return UUID(uuidString: str) }
        return nil
    }

    private func string(from value: Any?) -> String? {
        value as? String
    }

    private func bool(from value: Any?) -> Bool? {
        if let b = value as? Bool { return b }
        if let n = value as? Int { return n != 0 }
        if let s = value as? String {
            switch s.lowercased() {
            case "true", "t", "1", "yes": return true
            case "false", "f", "0", "no": return false
            default: return nil
            }
        }
        return nil
    }
}
