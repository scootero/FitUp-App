//
//  HomeRepository.swift
//  FitUp
//
//  Slice 3 data access for Home screen sections.
//

import Foundation
import Supabase

struct HomeSnapshot {
    var searching: [HomeSearchingRequest]
    var activeMatches: [HomeActiveMatch]
    var pendingMatches: [HomePendingMatch]
    var discoverUsers: [HomeDiscoverUser]
}

struct HomeSearchingRequest: Identifiable, Equatable {
    let id: UUID
    let metricType: String
    let durationDays: Int
    let startMode: String
    let createdAt: Date
    let isLocalPlaceholder: Bool
}

struct HomeOpponent: Equatable {
    let id: UUID
    let displayName: String
    let initials: String
    let colorHex: String
}

enum HomeDayPipState: Equatable {
    case future
    case won
    case lost
    case today
    case voided
}

struct HomeDayPip: Identifiable, Equatable {
    let dayNumber: Int
    let state: HomeDayPipState

    var id: Int { dayNumber }
}

struct HomeActiveMatch: Identifiable, Equatable {
    let id: UUID
    let metricType: String
    let durationDays: Int
    let sportLabel: String
    let seriesLabel: String
    let daysLeft: Int
    let myToday: Int
    let theirToday: Int
    let myScore: Int
    let theirScore: Int
    let isWinning: Bool
    let opponent: HomeOpponent
    let dayPips: [HomeDayPip]
}

struct HomePendingMatch: Identifiable, Equatable {
    let id: UUID
    let challengeId: UUID?
    let metricType: String
    let durationDays: Int
    let sportLabel: String
    let seriesLabel: String
    let opponent: HomeOpponent
}

struct HomeDiscoverUser: Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let initials: String
    let colorHex: String
    let todaySteps: Int?
    let wins: Int?
    let losses: Int?
}

final class HomeRepository {
    private var realtimeChannel: RealtimeChannelV2?
    private var matchDayUpdateTask: Task<Void, Never>?
    private var matchDayInsertTask: Task<Void, Never>?
    private var matchStateTask: Task<Void, Never>?
    private var searchUpdateTask: Task<Void, Never>?
    private var searchInsertTask: Task<Void, Never>?

    deinit {
        stopRealtimeSubscriptions()
    }

    func loadSnapshot(for currentUserId: UUID, showOnboardingSearching: Bool) async -> HomeSnapshot {
        async let searching = fetchSearchingRequests(currentUserId: currentUserId)
        async let cards = fetchActiveAndPendingCards(currentUserId: currentUserId)
        async let discover = fetchDiscoverUsers(currentUserId: currentUserId)

        var searchingRows = await searching
        let (activeRows, pendingRows) = await cards
        let discoverRows = await discover

        if showOnboardingSearching && searchingRows.isEmpty {
            searchingRows = [HomeSearchingRequest(
                id: UUID(),
                metricType: "steps",
                durationDays: 1,
                startMode: "today",
                createdAt: Date(),
                isLocalPlaceholder: true
            )]
        }

        return HomeSnapshot(
            searching: searchingRows,
            activeMatches: activeRows,
            pendingMatches: pendingRows,
            discoverUsers: discoverRows
        )
    }

    func loadActiveMatches(for currentUserId: UUID) async -> [HomeActiveMatch] {
        let (activeMatches, _) = await fetchActiveAndPendingCards(currentUserId: currentUserId)
        return activeMatches
    }

    // MARK: Actions

    func cancelSearchRequest(searchId: UUID) async throws {
        guard let client = SupabaseProvider.client else {
            throw ProfileRepositoryError.supabaseNotConfigured
        }
        try await client
            .from("match_search_requests")
            .update(["status": "cancelled"])
            .eq("id", value: searchId.uuidString)
            .execute()
    }

    func acceptPendingMatch(matchId: UUID, userId: UUID) async throws {
        guard let client = SupabaseProvider.client else {
            throw ProfileRepositoryError.supabaseNotConfigured
        }
        try await client
            .from("match_participants")
            .update(["accepted_at": Self.isoFormatter.string(from: Date())])
            .eq("match_id", value: matchId.uuidString)
            .eq("user_id", value: userId.uuidString)
            .execute()
    }

    func declinePendingMatch(challengeId: UUID?, matchId: UUID) async throws {
        guard let client = SupabaseProvider.client else {
            throw ProfileRepositoryError.supabaseNotConfigured
        }
        if let challengeId {
            try await client
                .from("direct_challenges")
                .update(["status": "declined"])
                .eq("id", value: challengeId.uuidString)
                .execute()
        } else {
            try await client
                .from("direct_challenges")
                .update(["status": "declined"])
                .eq("match_id", value: matchId.uuidString)
                .execute()
        }
    }

    // MARK: Realtime

    func startRealtimeSubscriptions(
        for currentUserId: UUID,
        onChange: @escaping @Sendable () async -> Void
    ) {
        stopRealtimeSubscriptions()
        guard let client = SupabaseProvider.client else { return }

        let channel = client.channel("home-live-\(currentUserId.uuidString)")
        realtimeChannel = channel

        let matchDayUpdateStream = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "match_day_participants"
        )
        let matchDayInsertStream = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "match_day_participants"
        )
        let matchStateUpdateStream = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "matches"
        )
        let searchUpdateStream = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "match_search_requests",
            filter: .eq("creator_id", value: currentUserId)
        )
        let searchInsertStream = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "match_search_requests",
            filter: .eq("creator_id", value: currentUserId)
        )

        Task {
            do {
                try await channel.subscribeWithError()
                AppLogger.log(
                    category: "match_state",
                    level: .debug,
                    message: "home realtime subscribed",
                    metadata: ["user_id": currentUserId.uuidString]
                )
            } catch {
                AppLogger.log(
                    category: "match_state",
                    level: .warning,
                    message: "home realtime subscribe failed",
                    metadata: ["error": error.localizedDescription]
                )
            }
        }

        matchDayUpdateTask = Task {
            for await _ in matchDayUpdateStream {
                await onChange()
            }
        }
        matchDayInsertTask = Task {
            for await _ in matchDayInsertStream {
                await onChange()
            }
        }
        matchStateTask = Task {
            for await _ in matchStateUpdateStream {
                await onChange()
            }
        }
        searchUpdateTask = Task {
            for await _ in searchUpdateStream {
                await onChange()
            }
        }
        searchInsertTask = Task {
            for await _ in searchInsertStream {
                await onChange()
            }
        }
    }

    func stopRealtimeSubscriptions() {
        matchDayUpdateTask?.cancel()
        matchDayUpdateTask = nil
        matchDayInsertTask?.cancel()
        matchDayInsertTask = nil
        matchStateTask?.cancel()
        matchStateTask = nil
        searchUpdateTask?.cancel()
        searchUpdateTask = nil
        searchInsertTask?.cancel()
        searchInsertTask = nil

        guard let channel = realtimeChannel else { return }
        realtimeChannel = nil

        guard let client = SupabaseProvider.client else { return }
        Task {
            await client.removeChannel(channel)
            AppLogger.log(category: "match_state", level: .debug, message: "home realtime unsubscribed")
        }
    }

    // MARK: Load Searching

    private func fetchSearchingRequests(currentUserId: UUID) async -> [HomeSearchingRequest] {
        guard let client = SupabaseProvider.client else { return [] }
        do {
            let response = try await client
                .from("match_search_requests")
                .select("id, metric_type, duration_days, start_mode, created_at")
                .eq("creator_id", value: currentUserId.uuidString)
                .eq("status", value: "searching")
                .execute()

            return jsonRows(from: response.data).compactMap { row in
                guard
                    let id = uuid(from: row["id"]),
                    let metricType = string(from: row["metric_type"]),
                    let durationDays = int(from: row["duration_days"]),
                    let startMode = string(from: row["start_mode"]),
                    let createdAt = date(from: row["created_at"])
                else {
                    return nil
                }
                return HomeSearchingRequest(
                    id: id,
                    metricType: metricType,
                    durationDays: durationDays,
                    startMode: startMode,
                    createdAt: createdAt,
                    isLocalPlaceholder: false
                )
            }
            .sorted(by: { $0.createdAt < $1.createdAt })
        } catch {
            AppLogger.log(category: "matchmaking", level: .warning, message: "search requests load failed", metadata: ["error": error.localizedDescription])
            return []
        }
    }

    // MARK: Load Active + Pending

    private func fetchActiveAndPendingCards(currentUserId: UUID) async -> ([HomeActiveMatch], [HomePendingMatch]) {
        guard let client = SupabaseProvider.client else { return ([], []) }
        do {
            let participantResponse = try await client
                .from("match_participants")
                .select("match_id")
                .eq("user_id", value: currentUserId.uuidString)
                .execute()
            let matchIds = Set(jsonRows(from: participantResponse.data).compactMap { uuid(from: $0["match_id"]) })
            guard !matchIds.isEmpty else { return ([], []) }

            var active: [HomeActiveMatch] = []
            var pending: [HomePendingMatch] = []
            var opponentCache: [UUID: HomeOpponent] = [:]

            for matchId in matchIds {
                guard let match = await fetchMatchRow(matchId: matchId) else { continue }
                let state = string(from: match["state"]) ?? "pending"
                guard state == "active" || state == "pending" else { continue }

                let metricType = string(from: match["metric_type"]) ?? "steps"
                let durationDays = int(from: match["duration_days"]) ?? 1
                let participantRows = await fetchParticipantRows(matchId: matchId)
                guard let opponentId = participantRows.compactMap({ uuid(from: $0["user_id"]) }).first(where: { $0 != currentUserId }) else {
                    continue
                }
                let opponent = await resolveOpponent(opponentId: opponentId, cache: &opponentCache)
                let myAccepted = participantRows
                    .first(where: { uuid(from: $0["user_id"]) == currentUserId })
                    .flatMap { date(from: $0["accepted_at"]) } != nil

                let dayRows = await fetchDayRows(matchId: matchId)
                let scores = deriveScores(dayRows: dayRows, currentUserId: currentUserId, opponentId: opponentId)
                let totals = await fetchTodayTotals(dayRows: dayRows, currentUserId: currentUserId, opponentId: opponentId)
                let dayPips = deriveDayPips(dayRows: dayRows, durationDays: durationDays, currentUserId: currentUserId)
                let finalizedCount = dayRows.filter { string(from: $0["status"]) == "finalized" }.count
                let daysLeft = max(durationDays - finalizedCount, 0)

                if state == "active" {
                    active.append(
                        HomeActiveMatch(
                            id: matchId,
                            metricType: metricType,
                            durationDays: durationDays,
                            sportLabel: sportLabel(for: metricType),
                            seriesLabel: seriesLabel(for: durationDays),
                            daysLeft: daysLeft,
                            myToday: totals.myTotal,
                            theirToday: totals.theirTotal,
                            myScore: scores.myScore,
                            theirScore: scores.theirScore,
                            isWinning: totals.myTotal >= totals.theirTotal,
                            opponent: opponent,
                            dayPips: dayPips
                        )
                    )
                } else if !myAccepted {
                    let challengeId = await fetchChallengeId(matchId: matchId)
                    pending.append(
                        HomePendingMatch(
                            id: matchId,
                            challengeId: challengeId,
                            metricType: metricType,
                            durationDays: durationDays,
                            sportLabel: sportLabel(for: metricType),
                            seriesLabel: seriesLabel(for: durationDays),
                            opponent: opponent
                        )
                    )
                }
            }

            return (
                active.sorted(by: { $0.id.uuidString < $1.id.uuidString }),
                pending.sorted(by: { $0.id.uuidString < $1.id.uuidString })
            )
        } catch {
            AppLogger.log(category: "matchmaking", level: .warning, message: "active/pending load failed", metadata: ["error": error.localizedDescription])
            return ([], [])
        }
    }

    private func fetchMatchRow(matchId: UUID) async -> [String: Any]? {
        guard let client = SupabaseProvider.client else { return nil }
        do {
            let response = try await client
                .from("matches")
                .select("id, state, metric_type, duration_days")
                .eq("id", value: matchId.uuidString)
                .limit(1)
                .execute()
            return jsonRows(from: response.data).first
        } catch {
            return nil
        }
    }

    private func fetchParticipantRows(matchId: UUID) async -> [[String: Any]] {
        guard let client = SupabaseProvider.client else { return [] }
        do {
            let response = try await client
                .from("match_participants")
                .select("user_id, accepted_at")
                .eq("match_id", value: matchId.uuidString)
                .execute()
            return jsonRows(from: response.data)
        } catch {
            return []
        }
    }

    private func fetchDayRows(matchId: UUID) async -> [[String: Any]] {
        guard let client = SupabaseProvider.client else { return [] }
        do {
            let response = try await client
                .from("match_days")
                .select("id, day_number, status, winner_user_id, is_void, calendar_date")
                .eq("match_id", value: matchId.uuidString)
                .order("day_number", ascending: true)
                .execute()
            return jsonRows(from: response.data)
        } catch {
            return []
        }
    }

    private func fetchTodayTotals(dayRows: [[String: Any]], currentUserId: UUID, opponentId: UUID) async -> (myTotal: Int, theirTotal: Int) {
        guard let client = SupabaseProvider.client else { return (0, 0) }
        let today = Self.calendarFormatter.string(from: Date())
        let todayRow = dayRows.first(where: { string(from: $0["calendar_date"]) == today }) ?? dayRows.last
        guard let dayId = uuid(from: todayRow?["id"]) else { return (0, 0) }

        do {
            let response = try await client
                .from("match_day_participants")
                .select("user_id, metric_total")
                .eq("match_day_id", value: dayId.uuidString)
                .execute()
            let rows = jsonRows(from: response.data)
            let myTotal = rows.first(where: { uuid(from: $0["user_id"]) == currentUserId }).flatMap { int(from: $0["metric_total"]) } ?? 0
            let theirTotal = rows.first(where: { uuid(from: $0["user_id"]) == opponentId }).flatMap { int(from: $0["metric_total"]) } ?? 0
            return (myTotal, theirTotal)
        } catch {
            return (0, 0)
        }
    }

    private func fetchChallengeId(matchId: UUID) async -> UUID? {
        guard let client = SupabaseProvider.client else { return nil }
        do {
            let response = try await client
                .from("direct_challenges")
                .select("id, status")
                .eq("match_id", value: matchId.uuidString)
                .eq("status", value: "pending")
                .limit(1)
                .execute()
            return jsonRows(from: response.data).first.flatMap { uuid(from: $0["id"]) }
        } catch {
            return nil
        }
    }

    private func deriveScores(dayRows: [[String: Any]], currentUserId: UUID, opponentId: UUID) -> (myScore: Int, theirScore: Int) {
        var myScore = 0
        var theirScore = 0
        for dayRow in dayRows {
            if bool(from: dayRow["is_void"]) == true { continue }
            if let winner = uuid(from: dayRow["winner_user_id"]) {
                if winner == currentUserId {
                    myScore += 1
                } else if winner == opponentId {
                    theirScore += 1
                }
            }
        }
        return (myScore, theirScore)
    }

    private func deriveDayPips(dayRows: [[String: Any]], durationDays: Int, currentUserId: UUID) -> [HomeDayPip] {
        let byNumber = Dictionary(uniqueKeysWithValues: dayRows.compactMap { row -> (Int, [String: Any])? in
            guard let dayNumber = int(from: row["day_number"]) else { return nil }
            return (dayNumber, row)
        })
        let todayString = Self.calendarFormatter.string(from: Date())

        return (1...max(durationDays, 1)).map { dayNumber in
            guard let row = byNumber[dayNumber] else {
                return HomeDayPip(dayNumber: dayNumber, state: .future)
            }
            if bool(from: row["is_void"]) == true {
                return HomeDayPip(dayNumber: dayNumber, state: .voided)
            }
            if string(from: row["status"]) == "finalized" {
                if uuid(from: row["winner_user_id"]) == currentUserId {
                    return HomeDayPip(dayNumber: dayNumber, state: .won)
                }
                return HomeDayPip(dayNumber: dayNumber, state: .lost)
            }

            if string(from: row["calendar_date"]) == todayString {
                return HomeDayPip(dayNumber: dayNumber, state: .today)
            }
            return HomeDayPip(dayNumber: dayNumber, state: .future)
        }
    }

    // MARK: Load Discover

    private func fetchDiscoverUsers(currentUserId: UUID) async -> [HomeDiscoverUser] {
        guard let client = SupabaseProvider.client else { return [] }
        do {
            let response = try await client
                .from("profiles")
                .select("id, display_name, initials")
                .order("created_at", ascending: false)
                .limit(24)
                .execute()

            var discover: [HomeDiscoverUser] = []
            for row in jsonRows(from: response.data) {
                guard let id = uuid(from: row["id"]), id != currentUserId else { continue }
                let displayName = string(from: row["display_name"]) ?? "Player"
                let initials = string(from: row["initials"]) ?? Self.initials(from: displayName)
                let stats = await fetchLatestLeaderboardStats(userId: id)
                let todaySteps = await fetchLatestTodaySteps(userId: id)
                discover.append(
                    HomeDiscoverUser(
                        id: id,
                        displayName: displayName,
                        initials: initials,
                        colorHex: colorHex(for: id),
                        todaySteps: todaySteps,
                        wins: stats.wins,
                        losses: stats.losses
                    )
                )
            }
            return Array(discover.prefix(8))
        } catch {
            AppLogger.log(category: "matchmaking", level: .warning, message: "discover load failed", metadata: ["error": error.localizedDescription])
            return []
        }
    }

    private func fetchLatestLeaderboardStats(userId: UUID) async -> (wins: Int?, losses: Int?) {
        guard let client = SupabaseProvider.client else { return (nil, nil) }
        do {
            let response = try await client
                .from("leaderboard_entries")
                .select("wins, losses, week_start")
                .eq("user_id", value: userId.uuidString)
                .order("week_start", ascending: false)
                .limit(1)
                .execute()
            let row = jsonRows(from: response.data).first
            return (int(from: row?["wins"]), int(from: row?["losses"]))
        } catch {
            return (nil, nil)
        }
    }

    private func fetchLatestTodaySteps(userId: UUID) async -> Int? {
        guard let client = SupabaseProvider.client else { return nil }
        do {
            let response = try await client
                .from("metric_snapshots")
                .select("value, synced_at")
                .eq("user_id", value: userId.uuidString)
                .eq("metric_type", value: "steps")
                .eq("source_date", value: Self.calendarFormatter.string(from: Date()))
                .order("synced_at", ascending: false)
                .limit(1)
                .execute()
            let row = jsonRows(from: response.data).first
            return int(from: row?["value"])
        } catch {
            return nil
        }
    }

    // MARK: Opponent

    private func resolveOpponent(opponentId: UUID, cache: inout [UUID: HomeOpponent]) async -> HomeOpponent {
        if let cached = cache[opponentId] { return cached }
        guard let client = SupabaseProvider.client else {
            let fallback = HomeOpponent(
                id: opponentId,
                displayName: "Opponent",
                initials: "OP",
                colorHex: colorHex(for: opponentId)
            )
            cache[opponentId] = fallback
            return fallback
        }

        do {
            let response = try await client
                .from("profiles")
                .select("id, display_name, initials")
                .eq("id", value: opponentId.uuidString)
                .limit(1)
                .execute()
            let row = jsonRows(from: response.data).first
            let opponent = HomeOpponent(
                id: opponentId,
                displayName: string(from: row?["display_name"]) ?? "Opponent",
                initials: string(from: row?["initials"]) ?? "OP",
                colorHex: colorHex(for: opponentId)
            )
            cache[opponentId] = opponent
            return opponent
        } catch {
            let fallback = HomeOpponent(
                id: opponentId,
                displayName: "Opponent",
                initials: "OP",
                colorHex: colorHex(for: opponentId)
            )
            cache[opponentId] = fallback
            return fallback
        }
    }

    // MARK: Display helpers

    func sportLabel(for metricType: String) -> String {
        metricType == "active_calories" ? "Calories" : "Steps"
    }

    func seriesLabel(for durationDays: Int) -> String {
        switch durationDays {
        case 1: return "Daily"
        case 3: return "First to 3"
        case 5: return "Best of 5"
        case 7: return "Best of 7"
        default: return "Best of \(durationDays)"
        }
    }

    func colorHex(for userId: UUID) -> String {
        let palette = ["00AAFF", "FF6200", "BF5FFF", "FFE000", "39FF14", "FF2D9B"]
        let index = abs(userId.hashValue) % palette.count
        return palette[index]
    }

    // MARK: JSON helpers

    private func jsonRows(from data: Data) -> [[String: Any]] {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let array = object as? [[String: Any]]
        else {
            return []
        }
        return array
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

    private func bool(from value: Any?) -> Bool? {
        if let boolValue = value as? Bool { return boolValue }
        if let intValue = value as? Int { return intValue != 0 }
        if let stringValue = value as? String {
            return (stringValue as NSString).boolValue
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

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let calendarFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func initials(from displayName: String) -> String {
        let words = displayName.split(separator: " ").map(String.init)
        if words.count >= 2, let first = words.first?.first, let second = words.dropFirst().first?.first {
            return "\(first)\(second)".uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }
}
