//
//  HomeRepository.swift
//  FitUp
//
//  Slice 3 data access for Home screen sections.
//

import Combine
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

struct DailyBattleMargin: Identifiable, Equatable, Sendable, Codable {
    /// `yyyy-MM-dd` (match calendar date from server).
    let calendarDate: String
    /// Signed daily margin from `home_daily_battle_margins`: your total minus the **closest relevant rival**
    /// for that calendar day (nearest opponent ahead if any are ahead; else nearest behind).
    let margin: Int

    var id: String { calendarDate }
}

struct HomeActiveMatch: Identifiable, Equatable {
    let id: UUID
    let metricType: String
    let durationDays: Int
    let sportLabel: String
    let seriesLabel: String
    let daysLeft: Int
    /// When `daysLeft == 1`, local time when the current match day finalizes (10:00 on the calendar day after `match_days.calendar_date`).
    /// Uses the signed-in user’s `profiles.timezone` when available so this matches server cutoff rules.
    let finalDayCutoffAt: Date?
    /// When `daysLeft == 1`, instant when the scored **calendar day** ends (midnight → start of next day) in profile/device TZ.
    let finalDayScoreEndsAt: Date?
    let myToday: Int
    let theirToday: Int
    let myScore: Int
    let theirScore: Int
    let isWinning: Bool
    let opponent: HomeOpponent
    /// Opponent's sync write time for today's match_day row.
    let opponentTodayUpdatedAt: Date?
    let dayPips: [HomeDayPip]
    /// `balanced` | `raw` | nil (legacy raw scoring).
    let scoringMode: String?
    /// Raw Battle difficulty from `matches.difficulty`; nil for Balanced / legacy.
    let difficulty: String?
    let myBaselineSteps: Double?
    let theirBaselineSteps: Double?
    /// User-facing duration + calendar span for hero header.
    let battleDateRangeLabel: String
    /// Max `match_days.calendar_date` for pending-finalization detection.
    let battleEndDateKey: String?
    /// Profile-local today (`yyyy-MM-dd`) when this snapshot was built.
    let profileTodayKey: String
    let hasUnfinalizedDay: Bool

    init(
        id: UUID,
        metricType: String,
        durationDays: Int,
        sportLabel: String,
        seriesLabel: String,
        daysLeft: Int,
        finalDayCutoffAt: Date?,
        finalDayScoreEndsAt: Date?,
        myToday: Int,
        theirToday: Int,
        myScore: Int,
        theirScore: Int,
        isWinning: Bool,
        opponent: HomeOpponent,
        opponentTodayUpdatedAt: Date?,
        dayPips: [HomeDayPip],
        scoringMode: String?,
        difficulty: String?,
        myBaselineSteps: Double?,
        theirBaselineSteps: Double?,
        battleDateRangeLabel: String = "",
        battleEndDateKey: String? = nil,
        profileTodayKey: String = "",
        hasUnfinalizedDay: Bool = false
    ) {
        self.id = id
        self.metricType = metricType
        self.durationDays = durationDays
        self.sportLabel = sportLabel
        self.seriesLabel = seriesLabel
        self.daysLeft = daysLeft
        self.finalDayCutoffAt = finalDayCutoffAt
        self.finalDayScoreEndsAt = finalDayScoreEndsAt
        self.myToday = myToday
        self.theirToday = theirToday
        self.myScore = myScore
        self.theirScore = theirScore
        self.isWinning = isWinning
        self.opponent = opponent
        self.opponentTodayUpdatedAt = opponentTodayUpdatedAt
        self.dayPips = dayPips
        self.scoringMode = scoringMode
        self.difficulty = difficulty
        self.myBaselineSteps = myBaselineSteps
        self.theirBaselineSteps = theirBaselineSteps
        self.battleDateRangeLabel = battleDateRangeLabel
        self.battleEndDateKey = battleEndDateKey
        self.profileTodayKey = profileTodayKey
        self.hasUnfinalizedDay = hasUnfinalizedDay
    }

    var isBalancedStepsBattle: Bool {
        metricType == "steps" && scoringMode == "balanced"
    }

    func balancedPercent(forSteps steps: Int, baseline: Double?) -> Double {
        Self.balancePercentValue(steps: steps, baseline: baseline)
    }

    var myBalancedPercent: Double {
        balancedPercent(forSteps: myToday, baseline: myBaselineSteps)
    }

    var theirBalancedPercent: Double {
        balancedPercent(forSteps: theirToday, baseline: theirBaselineSteps)
    }

    /// Effective baseline steps: same floor rule as `finalize-match-day` / `balancePercentValue` denominator.
    static func effectiveBaselineSteps(baseline: Double?) -> Double {
        if let baseline, baseline > 0 {
            return max(3000, baseline)
        }
        return 3000
    }

    /// Fairness multiplier for Battle Score: `max(myEff, theirEff) / myEff`.
    static func balanceMultiplier(myEffective: Double, theirEffective: Double) -> Double {
        let higher = max(myEffective, theirEffective)
        guard myEffective > 0 else { return 1 }
        return higher / myEffective
    }

    /// Battle Score for the player whose actual steps are `actualSteps`, using their baseline as `myBaseline` and rival as `theirBaseline`.
    static func battleScore(actualSteps: Int, myBaseline: Double?, theirBaseline: Double?) -> Int {
        let myEff = effectiveBaselineSteps(baseline: myBaseline)
        let theirEff = effectiveBaselineSteps(baseline: theirBaseline)
        let mult = balanceMultiplier(myEffective: myEff, theirEffective: theirEff)
        return Int((Double(actualSteps) * mult).rounded())
    }

    var myBattleScore: Int {
        Self.battleScore(actualSteps: myToday, myBaseline: myBaselineSteps, theirBaseline: theirBaselineSteps)
    }

    var theirBattleScore: Int {
        Self.battleScore(actualSteps: theirToday, myBaseline: theirBaselineSteps, theirBaseline: myBaselineSteps)
    }

    var myBalanceMultiplierDisplay: String {
        let m = Self.balanceMultiplier(
            myEffective: Self.effectiveBaselineSteps(baseline: myBaselineSteps),
            theirEffective: Self.effectiveBaselineSteps(baseline: theirBaselineSteps)
        )
        return String(format: "%.1f×", m)
    }

    var theirBalanceMultiplierDisplay: String {
        let m = Self.balanceMultiplier(
            myEffective: Self.effectiveBaselineSteps(baseline: theirBaselineSteps),
            theirEffective: Self.effectiveBaselineSteps(baseline: myBaselineSteps)
        )
        return String(format: "%.1f×", m)
    }

    /// Shared semantics with server finalize (floor denominator 3000 when baseline missing).
    static func balancePercentValue(steps: Int, baseline: Double?) -> Double {
        let denominator = effectiveBaselineSteps(baseline: baseline)
        guard denominator > 0 else { return 0 }
        return Double(steps) / denominator * 100
    }
}

/// Home hero, sorting, and summaries: same comparable scores as Match Details (balanced → Battle Score; else raw metric totals).
enum HomeComparableBattleState: Equatable, Sendable {
    case ahead
    case behind
    case tied
}

extension HomeActiveMatch {
    var comparableMyScore: Int {
        isBalancedStepsBattle ? myBattleScore : myToday
    }

    var comparableTheirScore: Int {
        isBalancedStepsBattle ? theirBattleScore : theirToday
    }

    var comparableMargin: Int {
        comparableMyScore - comparableTheirScore
    }

    var homeComparableBattleState: HomeComparableBattleState {
        let m = comparableMargin
        if m > 0 { return .ahead }
        if m < 0 { return .behind }
        return .tied
    }

    /// Featured step battle for Home: closest deficit first, then closest cushion, then strongest opponent by comparable score.
    static func featuredStepMatch(from stepMatches: [HomeActiveMatch]) -> HomeActiveMatch? {
        guard !stepMatches.isEmpty else { return nil }
        let closestAhead = stepMatches
            .filter { $0.comparableTheirScore > $0.comparableMyScore }
            .min(by: {
                ($0.comparableTheirScore - $0.comparableMyScore) < ($1.comparableTheirScore - $1.comparableMyScore)
            })
        if let closestAhead { return closestAhead }
        let closestBehind = stepMatches
            .filter { $0.comparableTheirScore <= $0.comparableMyScore }
            .max(by: { $0.comparableTheirScore < $1.comparableTheirScore })
        if let closestBehind { return closestBehind }
        return stepMatches.max(by: { $0.comparableTheirScore < $1.comparableTheirScore })
    }
}

struct HomePendingMatch: Identifiable, Equatable {
    let id: UUID
    let challengeId: UUID?
    let metricType: String
    let durationDays: Int
    let sportLabel: String
    let seriesLabel: String
    let opponent: HomeOpponent
    /// From `matches.match_type` (e.g. `public_matchmaking`, `direct_challenge`).
    let matchType: String
    /// From `matches.created_at`.
    let createdAt: Date
    /// Current user has set `accepted_at` on `match_participants`.
    let hasAcceptedByMe: Bool
    /// Opponent has set `accepted_at`.
    let hasAcceptedByOpponent: Bool
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

struct HomeStatsSnapshot {
    let effectiveRangeKey: String
    let margins: [DailyBattleMargin]
    let previousPeriodPercent: Int?
    let battleStats: HealthBattleStats
    let battleStatsScope: String
    let rangeSupport: String
}

struct HomeRivalStat: Identifiable, Equatable, Sendable {
    let opponentProfileId: UUID
    let opponentDisplayName: String
    let opponentInitials: String
    let opponentAvatarURL: String?
    let finalizedDaysCompeted: Int
    let matchWins: Int
    let matchLosses: Int
    let matchTies: Int
    let winPercentage: Int
    let avgFinalizedDailyMargin: Double?
    let lastPlayedOn: Date?
    let daysWonByViewer: Int?
    let daysWonByOpponent: Int?
    let avgMarginOnViewerWinDays: Double?
    let avgMarginOnOpponentWinDays: Double?
    let avgViewerStepsPerBattleDay: Double?
    let recentSeriesResults: [String]?
    let activeMatchId: UUID?
    let computedAt: Date?

    var id: UUID { opponentProfileId }

    /// Same opponent shape as Match Details rematch → Challenge flow Duration step.
    func challengePrefillOpponent() -> ChallengePrefillOpponent {
        ChallengePrefillOpponent(
            id: opponentProfileId,
            displayName: opponentDisplayName,
            initials: opponentInitials,
            colorHex: ProfileAccentColor.hex(for: opponentProfileId)
        )
    }
}

final class HomeRepository {
    func fetchStatsSnapshot(rangeKey: String, metricType: String = "steps") async -> HomeStatsSnapshot? {
        guard let client = SupabaseProvider.client else { return nil }
        let params = HomeStatsSnapshotRPCParams(
            p_range_key: rangeKey,
            p_metric_type: metricType
        )
        do {
            let response: PostgrestResponse<HomeStatsSnapshotRPCResult> = try await client
                .rpc("get_profile_stats_snapshot", params: params)
                .execute()
            return response.value.toDomain()
        } catch {
            if error is CancellationError { return nil }
            AppLogger.log(
                category: "matchmaking",
                level: .warning,
                message: "get_profile_stats_snapshot rpc failed",
                metadata: ["error": error.localizedDescription, "range_key": rangeKey]
            )
            return nil
        }
    }

    func loadSnapshot(for currentUserId: UUID, showOnboardingSearching: Bool, profileTimeZoneIdentifier: String? = nil) async -> HomeSnapshot {
        async let searching = fetchSearchingRequests(currentUserId: currentUserId)
        async let cards = fetchActiveAndPendingCards(currentUserId: currentUserId, profileTimeZoneIdentifier: profileTimeZoneIdentifier)

        var searchingRows = await searching
        let (activeRows, pendingRows) = await cards

        if showOnboardingSearching && searchingRows.isEmpty && activeRows.isEmpty && pendingRows.isEmpty {
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
            discoverUsers: []
        )
    }

    func loadActiveMatches(for currentUserId: UUID, profileTimeZoneIdentifier: String? = nil) async -> [HomeActiveMatch] {
        let (activeMatches, _) = await fetchActiveAndPendingCards(currentUserId: currentUserId, profileTimeZoneIdentifier: profileTimeZoneIdentifier)
        return activeMatches
    }

    func fetchMyRivalStats(limit: Int = 3) async -> [HomeRivalStat] {
        guard let client = SupabaseProvider.client else { return [] }
        let params = HomeMyRivalStatsRPCParams(p_limit: max(1, limit))
        do {
            let response: PostgrestResponse<[HomeMyRivalStatsRPCRow]> = try await client
                .rpc("get_my_rival_stats", params: params)
                .execute()
            return response.value.map(\.toDomain)
        } catch {
            if error is CancellationError { return [] }
            AppLogger.log(
                category: "matchmaking",
                level: .warning,
                message: "get_my_rival_stats rpc failed",
                metadata: ["error": error.localizedDescription, "limit": "\(limit)"]
            )
            return []
        }
    }

    func fetchOpponentStepsRollups() async -> StatsOpponentStepsRollups? {
        guard let client = SupabaseProvider.client else { return nil }
        do {
            let response: PostgrestResponse<StatsOpponentStepsRollupsRPCResult> = try await client
                .rpc("get_stats_opponent_steps_rollups")
                .execute()
            return response.value.toDomain()
        } catch {
            if error is CancellationError { return nil }
            AppLogger.log(
                category: "matchmaking",
                level: .warning,
                message: "get_stats_opponent_steps_rollups rpc failed",
                metadata: ["error": error.localizedDescription]
            )
            return nil
        }
    }

    /// End date should be “today” in the user’s profile timezone when available (same convention as live match days).
    func fetchDailyBattleMargins(
        endDate: Date,
        dayCount: Int,
        metricType: String,
        profileTimeZoneIdentifier: String?
    ) async -> [DailyBattleMargin] {
        guard let client = SupabaseProvider.client else { return [] }
        let endStr = Self.formatProfileCalendarDate(endDate, profileTimeZoneIdentifier: profileTimeZoneIdentifier)
        let params = HomeDailyBattleMarginsRPCParams(
            p_end_date: endStr,
            p_day_count: dayCount,
            p_metric_type: metricType
        )
        do {
            let response: PostgrestResponse<[HomeDailyBattleMarginsRow]> = try await client
                .rpc("home_daily_battle_margins", params: params)
                .execute()
            return response.value.map {
                DailyBattleMargin(calendarDate: $0.date, margin: Self.safeInt(from: $0.margin))
            }
        } catch {
            if error is CancellationError { return [] }
            AppLogger.log(
                category: "matchmaking",
                level: .warning,
                message: "home_daily_battle_margins rpc failed",
                metadata: ["error": error.localizedDescription]
            )
            return []
        }
    }

    fileprivate static func safeInt(from int64: Int64) -> Int {
        if int64 >= Int64(Int.max) { return Int.max }
        if int64 <= Int64(Int.min) { return Int.min }
        return Int(int64)
    }

    static func formatProfileCalendarDate(_ date: Date, profileTimeZoneIdentifier: String?) -> String {
        let tz = profileTimeZoneIdentifier.flatMap { TimeZone(identifier: $0) } ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = tz
        return formatter.string(from: date)
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

    func declinePendingMatch(challengeId _: UUID?, matchId: UUID) async throws {
        guard let client = SupabaseProvider.client else {
            throw ProfileRepositoryError.supabaseNotConfigured
        }
        let params = DeclinePendingMatchRPCParams(p_match_id: matchId)
        let response: PostgrestResponse<DeclinePendingMatchRPCResult> = try await client.rpc(
            "decline_pending_match",
            params: params
        ).execute()
        guard response.value.ok else {
            throw ProfileRepositoryError.updateFailed
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
            if error is CancellationError { return [] }
            AppLogger.log(category: "matchmaking", level: .warning, message: "search requests load failed", metadata: ["error": error.localizedDescription])
            return []
        }
    }

    // MARK: Load Active + Pending

    private func fetchActiveAndPendingCards(currentUserId: UUID, profileTimeZoneIdentifier: String? = nil) async -> ([HomeActiveMatch], [HomePendingMatch]) {
        guard let client = SupabaseProvider.client else { return ([], []) }
        do {
            let participantResponse = try await client
                .from("match_participants")
                .select("match_id")
                .eq("user_id", value: currentUserId.uuidString)
                .execute()
            let matchIds = Set(jsonRows(from: participantResponse.data).compactMap { uuid(from: $0["match_id"]) })
            guard !matchIds.isEmpty else { return ([], []) }

            let profileTimeZone = profileTimeZoneIdentifier.flatMap { TimeZone(identifier: $0) }
            let matchRowsResponse = try await client
                .from("matches")
                .select("id, state, metric_type, duration_days, match_type, created_at, scoring_mode, difficulty")
                .in("id", values: Array(matchIds))
                .in("state", values: ["active", "pending"])
                .execute()
            let matchRows = jsonRows(from: matchRowsResponse.data)
            guard !matchRows.isEmpty else { return ([], []) }

            let filteredMatchIds = Set(matchRows.compactMap { uuid(from: $0["id"]) })
            guard !filteredMatchIds.isEmpty else { return ([], []) }

            let participantRowsResponse = try await client
                .from("match_participants")
                .select("match_id, user_id, accepted_at, baseline_steps")
                .in("match_id", values: Array(filteredMatchIds))
                .execute()
            let participantRows = jsonRows(from: participantRowsResponse.data)

            let dayRowsResponse = try await client
                .from("match_days")
                .select("id, match_id, day_number, status, winner_user_id, is_void, calendar_date")
                .in("match_id", values: Array(filteredMatchIds))
                .order("day_number", ascending: true)
                .execute()
            let dayRowsAll = jsonRows(from: dayRowsResponse.data)
            let dayIds = Set(dayRowsAll.compactMap { uuid(from: $0["id"]) })

            var dayParticipantRows: [[String: Any]] = []
            if !dayIds.isEmpty {
                let dayParticipantsResponse = try await client
                    .from("match_day_participants")
                    .select("match_day_id, user_id, metric_total, finalized_value, last_updated_at")
                    .in("match_day_id", values: Array(dayIds))
                    .execute()
                dayParticipantRows = jsonRows(from: dayParticipantsResponse.data)
            }

            let pendingMatchIds = Set(matchRows.compactMap { row -> UUID? in
                guard string(from: row["state"]) == "pending" else { return nil }
                return uuid(from: row["id"])
            })

            var challengeIdByMatch: [UUID: UUID] = [:]
            if !pendingMatchIds.isEmpty {
                let challengesResponse = try await client
                    .from("direct_challenges")
                    .select("id, match_id")
                    .in("match_id", values: Array(pendingMatchIds))
                    .eq("status", value: "pending")
                    .execute()
                let challengeRows = jsonRows(from: challengesResponse.data)
                for row in challengeRows {
                    guard let matchId = uuid(from: row["match_id"]), let challengeId = uuid(from: row["id"]) else { continue }
                    challengeIdByMatch[matchId] = challengeId
                }
            }

            var participantsByMatch: [UUID: [[String: Any]]] = [:]
            for row in participantRows {
                guard let matchId = uuid(from: row["match_id"]) else { continue }
                participantsByMatch[matchId, default: []].append(row)
            }

            var dayRowsByMatch: [UUID: [[String: Any]]] = [:]
            for row in dayRowsAll {
                guard let matchId = uuid(from: row["match_id"]) else { continue }
                dayRowsByMatch[matchId, default: []].append(row)
            }

            var dayParticipantsByDay: [UUID: [[String: Any]]] = [:]
            for row in dayParticipantRows {
                guard let dayId = uuid(from: row["match_day_id"]) else { continue }
                dayParticipantsByDay[dayId, default: []].append(row)
            }

            let opponentIds = Set(participantRows.compactMap { row -> UUID? in
                guard let uid = uuid(from: row["user_id"]), uid != currentUserId else { return nil }
                return uid
            })
            var opponentCache: [UUID: HomeOpponent] = [:]
            if !opponentIds.isEmpty {
                let opponentProfilesResponse = try await client
                    .from("profiles")
                    .select("id, display_name, initials")
                    .in("id", values: Array(opponentIds))
                    .execute()
                for row in jsonRows(from: opponentProfilesResponse.data) {
                    guard let id = uuid(from: row["id"]) else { continue }
                    opponentCache[id] = HomeOpponent(
                        id: id,
                        displayName: string(from: row["display_name"]) ?? "Opponent",
                        initials: string(from: row["initials"]) ?? "OP",
                        colorHex: colorHex(for: id)
                    )
                }
            }

            var active: [HomeActiveMatch] = []
            var pending: [HomePendingMatch] = []
            let profileTodayKey = Self.formatProfileCalendarDate(
                Date(),
                profileTimeZoneIdentifier: profileTimeZoneIdentifier
            )

            for match in matchRows {
                guard let matchId = uuid(from: match["id"]) else { continue }
                let state = string(from: match["state"]) ?? "pending"
                guard state == "active" || state == "pending" else { continue }

                let metricType = string(from: match["metric_type"]) ?? "steps"
                let durationDays = int(from: match["duration_days"]) ?? 1
                let scoringMode = string(from: match["scoring_mode"])
                let matchDifficulty = string(from: match["difficulty"])
                let participants = participantsByMatch[matchId] ?? []
                guard let opponentId = participants.compactMap({ uuid(from: $0["user_id"]) }).first(where: { $0 != currentUserId }) else {
                    continue
                }
                let opponent = opponentCache[opponentId] ?? HomeOpponent(
                    id: opponentId,
                    displayName: "Opponent",
                    initials: "OP",
                    colorHex: colorHex(for: opponentId)
                )
                let myAccepted = participants
                    .first(where: { uuid(from: $0["user_id"]) == currentUserId })
                    .flatMap { date(from: $0["accepted_at"]) } != nil
                let theyAccepted = participants
                    .first(where: { uuid(from: $0["user_id"]) == opponentId })
                    .flatMap { date(from: $0["accepted_at"]) } != nil

                let dayRows = dayRowsByMatch[matchId] ?? []
                let scores = deriveScores(dayRows: dayRows, currentUserId: currentUserId, opponentId: opponentId)
                let totals = todayTotals(
                    dayRows: dayRows,
                    dayParticipantsByDay: dayParticipantsByDay,
                    currentUserId: currentUserId,
                    opponentId: opponentId,
                    todayString: profileTodayKey
                )
                let myBaseline = participants
                    .first(where: { uuid(from: $0["user_id"]) == currentUserId })
                    .flatMap { double(from: $0["baseline_steps"]) }
                let theirBaseline = participants
                    .first(where: { uuid(from: $0["user_id"]) == opponentId })
                    .flatMap { double(from: $0["baseline_steps"]) }
                let useBalancedUI = scoringMode == "balanced" && metricType == "steps"
                let isWinning: Bool
                if useBalancedUI {
                    let myBS = HomeActiveMatch.battleScore(
                        actualSteps: totals.myTotal,
                        myBaseline: myBaseline,
                        theirBaseline: theirBaseline
                    )
                    let theirBS = HomeActiveMatch.battleScore(
                        actualSteps: totals.theirTotal,
                        myBaseline: theirBaseline,
                        theirBaseline: myBaseline
                    )
                    isWinning = myBS >= theirBS
                } else {
                    isWinning = totals.myTotal >= totals.theirTotal
                }
                let dayPips = deriveDayPips(
                    dayRows: dayRows,
                    durationDays: durationDays,
                    currentUserId: currentUserId,
                    todayString: profileTodayKey
                )
                let finalizedCount = dayRows.filter { string(from: $0["status"]) == "finalized" }.count
                let daysLeft = max(durationDays - finalizedCount, 0)
                let finalCutoff = finalDayCutoff(from: dayRows, daysLeft: daysLeft, timeZone: profileTimeZone)
                let scoreEndsAt = finalDayScoreEndsAt(from: dayRows, daysLeft: daysLeft, timeZone: profileTimeZone)
                let calendarBounds = deriveBattleCalendarBounds(
                    dayRows: dayRows,
                    durationDays: durationDays,
                    timeZone: profileTimeZone
                )
                let hasUnfinalized = dayRows.contains { string(from: $0["status"]) != "finalized" }
                let rangeLabel = BattleDateRangeFormatting.label(
                    durationDays: durationDays,
                    startDateKey: calendarBounds.startDateKey,
                    endDateKey: calendarBounds.endDateKey,
                    timeZone: profileTimeZone
                )

                #if DEBUG
                if daysLeft == 1, let cutoff = finalCutoff, Date() > cutoff,
                   let pendingDay = dayRows.first(where: { string(from: $0["status"]) != "finalized" }),
                   let pendingDayId = uuid(from: pendingDay["id"]) {
                    AppLogger.log(
                        category: "matchmaking",
                        level: .warning,
                        message: "final day cutoff passed but match_day not finalized (client view)",
                        userId: currentUserId,
                        metadata: [
                            "match_id": matchId.uuidString,
                            "match_day_id": pendingDayId.uuidString,
                        ]
                    )
                }
                #endif

                if state == "active" {
                    active.append(
                        HomeActiveMatch(
                            id: matchId,
                            metricType: metricType,
                            durationDays: durationDays,
                            sportLabel: sportLabel(for: metricType),
                            seriesLabel: seriesLabel(for: durationDays),
                            daysLeft: daysLeft,
                            finalDayCutoffAt: finalCutoff,
                            finalDayScoreEndsAt: scoreEndsAt,
                            myToday: totals.myTotal,
                            theirToday: totals.theirTotal,
                            myScore: scores.myScore,
                            theirScore: scores.theirScore,
                            isWinning: isWinning,
                            opponent: opponent,
                            opponentTodayUpdatedAt: totals.opponentTodayUpdatedAt,
                            dayPips: dayPips,
                            scoringMode: scoringMode,
                            difficulty: matchDifficulty,
                            myBaselineSteps: myBaseline,
                            theirBaselineSteps: theirBaseline,
                            battleDateRangeLabel: rangeLabel,
                            battleEndDateKey: calendarBounds.endDateKey,
                            profileTodayKey: profileTodayKey,
                            hasUnfinalizedDay: hasUnfinalized
                        )
                    )
                } else if state == "pending" {
                    let challengeId = challengeIdByMatch[matchId]
                    let matchType = string(from: match["match_type"]) ?? "public_matchmaking"
                    let createdAt = date(from: match["created_at"]) ?? Date()
                    pending.append(
                        HomePendingMatch(
                            id: matchId,
                            challengeId: challengeId,
                            metricType: metricType,
                            durationDays: durationDays,
                            sportLabel: sportLabel(for: metricType),
                            seriesLabel: seriesLabel(for: durationDays),
                            opponent: opponent,
                            matchType: matchType,
                            createdAt: createdAt,
                            hasAcceptedByMe: myAccepted,
                            hasAcceptedByOpponent: theyAccepted
                        )
                    )
                }
            }

            return (
                active.sorted(by: { $0.id.uuidString < $1.id.uuidString }),
                pending.sorted(by: { $0.id.uuidString < $1.id.uuidString })
            )
        } catch {
            if error is CancellationError { return ([], []) }
            AppLogger.log(category: "matchmaking", level: .warning, message: "active/pending load failed", metadata: ["error": error.localizedDescription])
            return ([], [])
        }
    }

    private func todayTotals(
        dayRows: [[String: Any]],
        dayParticipantsByDay: [UUID: [[String: Any]]],
        currentUserId: UUID,
        opponentId: UUID,
        todayString: String
    ) -> (myTotal: Int, theirTotal: Int, opponentTodayUpdatedAt: Date?) {
        guard let todayRow = dayRows.first(where: { string(from: $0["calendar_date"]) == todayString }),
              let dayId = uuid(from: todayRow["id"])
        else { return (0, 0, nil) }
        let rows = dayParticipantsByDay[dayId] ?? []
        let myTotal = rows.first(where: { uuid(from: $0["user_id"]) == currentUserId }).flatMap { int(from: $0["finalized_value"]) ?? int(from: $0["metric_total"]) } ?? 0
        let opponentRow = rows.first(where: { uuid(from: $0["user_id"]) == opponentId })
        let theirTotal = opponentRow.flatMap { int(from: $0["finalized_value"]) ?? int(from: $0["metric_total"]) } ?? 0
        let opponentTodayUpdatedAt = date(from: opponentRow?["last_updated_at"])
        return (myTotal, theirTotal, opponentTodayUpdatedAt)
    }

    private func fetchMatchRow(matchId: UUID) async -> [String: Any]? {
        guard let client = SupabaseProvider.client else { return nil }
        do {
            let response = try await client
                .from("matches")
                .select("id, state, metric_type, duration_days, match_type, created_at")
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
        let today = Self.formatProfileCalendarDate(Date(), profileTimeZoneIdentifier: nil)
        guard let todayRow = dayRows.first(where: { string(from: $0["calendar_date"]) == today }),
              let dayId = uuid(from: todayRow["id"])
        else { return (0, 0) }

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

    private func deriveDayPips(
        dayRows: [[String: Any]],
        durationDays: Int,
        currentUserId: UUID,
        todayString: String
    ) -> [HomeDayPip] {
        let byNumber = Dictionary(uniqueKeysWithValues: dayRows.compactMap { row -> (Int, [String: Any])? in
            guard let dayNumber = int(from: row["day_number"]) else { return nil }
            return (dayNumber, row)
        })

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

    /// First non-finalized day’s cutoff: 10:00 local on the calendar day after `calendar_date` (matches `day_cutoff_check` in slice8).
    /// Uses `profiles.timezone` when provided so the countdown aligns with server rules; otherwise device calendar.
    private func deriveBattleCalendarBounds(
        dayRows: [[String: Any]],
        durationDays: Int,
        timeZone: TimeZone?
    ) -> (startDateKey: String?, endDateKey: String?) {
        let keys = dayRows.compactMap { string(from: $0["calendar_date"]) }.sorted()
        if keys.isEmpty {
            return (nil, nil)
        }
        return (keys.first, keys.last)
    }

    private func finalDayCutoff(from dayRows: [[String: Any]], daysLeft: Int, timeZone: TimeZone?) -> Date? {
        guard daysLeft == 1 else { return nil }
        guard let pending = dayRows.first(where: { string(from: $0["status"]) != "finalized" }),
              let calStr = string(from: pending["calendar_date"]) else { return nil }
        return Self.cutoffDateAfterMatchDay(calendarDateString: calStr, timeZone: timeZone)
    }

    private func finalDayScoreEndsAt(from dayRows: [[String: Any]], daysLeft: Int, timeZone: TimeZone?) -> Date? {
        guard daysLeft == 1 else { return nil }
        guard let pending = dayRows.first(where: { string(from: $0["status"]) != "finalized" }),
              let calStr = string(from: pending["calendar_date"]) else { return nil }
        return Self.endOfMatchScorePeriod(calendarDateString: calStr, timeZone: timeZone)
    }

    /// Start of the calendar day after `calendar_date` (when the competition day ends for scoring).
    private static func endOfMatchScorePeriod(calendarDateString: String, timeZone: TimeZone?) -> Date? {
        let tz = timeZone ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = tz
        guard let dayStart = formatter.date(from: calendarDateString) else { return nil }
        return cal.date(byAdding: .day, value: 1, to: dayStart)
    }

    private static func cutoffDateAfterMatchDay(calendarDateString: String, timeZone: TimeZone?) -> Date? {
        let tz = timeZone ?? .current
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = tz
        guard let dayStart = formatter.date(from: calendarDateString) else { return nil }
        guard let nextDayStart = cal.date(byAdding: .day, value: 1, to: dayStart) else { return nil }
        return cal.date(bySettingHour: 10, minute: 0, second: 0, of: nextDayStart)
    }

    // MARK: Load Discover

    private func fetchDiscoverUsers(currentUserId: UUID) async -> [HomeDiscoverUser] {
        guard let client = SupabaseProvider.client else { return [] }
        do {
            let response = try await client
                .from("profiles")
                .select("id, display_name, initials")
                .neq("id", value: currentUserId.uuidString)
                .order("created_at", ascending: false)
                .limit(8)
                .execute()

            let profileRows = jsonRows(from: response.data)
            let discoverIds = profileRows.compactMap { uuid(from: $0["id"]) }

            var latestStatsByUser: [UUID: (wins: Int?, losses: Int?)] = [:]
            if !discoverIds.isEmpty {
                let leaderboardResponse = try await client
                    .from("leaderboard_entries")
                    .select("user_id, wins, losses, week_start")
                    .in("user_id", values: discoverIds)
                    .order("week_start", ascending: false)
                    .execute()
                for row in jsonRows(from: leaderboardResponse.data) {
                    guard let userId = uuid(from: row["user_id"]), latestStatsByUser[userId] == nil else { continue }
                    latestStatsByUser[userId] = (int(from: row["wins"]), int(from: row["losses"]))
                }
            }

            var latestStepsByUser: [UUID: Int] = [:]
            if !discoverIds.isEmpty {
                let today = Self.calendarFormatter.string(from: Date())
                let stepsResponse = try await client
                    .from("metric_snapshots")
                    .select("user_id, value, synced_at")
                    .in("user_id", values: discoverIds)
                    .eq("metric_type", value: "steps")
                    .eq("source_date", value: today)
                    .order("synced_at", ascending: false)
                    .execute()
                for row in jsonRows(from: stepsResponse.data) {
                    guard let userId = uuid(from: row["user_id"]), latestStepsByUser[userId] == nil else { continue }
                    latestStepsByUser[userId] = int(from: row["value"])
                }
            }

            var discover: [HomeDiscoverUser] = []
            for row in profileRows {
                guard let id = uuid(from: row["id"]) else { continue }
                let displayName = string(from: row["display_name"]) ?? "Player"
                let initials = string(from: row["initials"]) ?? Self.initials(from: displayName)
                let stats = latestStatsByUser[id]
                discover.append(
                    HomeDiscoverUser(
                        id: id,
                        displayName: displayName,
                        initials: initials,
                        colorHex: colorHex(for: id),
                        todaySteps: latestStepsByUser[id],
                        wins: stats?.wins,
                        losses: stats?.losses
                    )
                )
            }
            return discover
        } catch {
            if error is CancellationError { return [] }
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
        MatchDurationCopy.competitionLengthBadge(days: durationDays)
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

    private func double(from value: Any?) -> Double? {
        if let doubleValue = value as? Double { return doubleValue }
        if let intValue = value as? Int { return Double(intValue) }
        if let stringValue = value as? String { return Double(stringValue) }
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

// MARK: - home_daily_battle_margins RPC (closest-rival daily margin; see supabase/scripts/sql-editor/04_home_daily_battle_margins_rpc.sql)

private struct HomeDailyBattleMarginsRPCParams: Sendable {
    let p_end_date: String
    let p_day_count: Int
    let p_metric_type: String
}

extension HomeDailyBattleMarginsRPCParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_end_date, forKey: .p_end_date)
        try c.encode(p_day_count, forKey: .p_day_count)
        try c.encode(p_metric_type, forKey: .p_metric_type)
    }

    enum CodingKeys: String, CodingKey {
        case p_end_date
        case p_day_count
        case p_metric_type
    }
}

private struct HomeDailyBattleMarginsRow: Decodable, Sendable {
    let date: String
    let margin: Int64
}

private struct HomeStatsSnapshotRPCParams: Sendable {
    let p_range_key: String
    let p_metric_type: String
}

extension HomeStatsSnapshotRPCParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_range_key, forKey: .p_range_key)
        try c.encode(p_metric_type, forKey: .p_metric_type)
    }

    enum CodingKeys: String, CodingKey {
        case p_range_key
        case p_metric_type
    }
}

private struct HomeMyRivalStatsRPCParams: Sendable {
    let p_limit: Int
}

extension HomeMyRivalStatsRPCParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_limit, forKey: .p_limit)
    }

    enum CodingKeys: String, CodingKey {
        case p_limit
    }
}

private struct HomeMyRivalStatsRPCRow: Decodable, Sendable {
    let opponent_profile_id: UUID
    let opponent_display_name: String
    let opponent_initials: String
    let opponent_avatar_url: String?
    let finalized_days_competed: Int
    let match_wins: Int
    let match_losses: Int
    let match_ties: Int
    let win_percentage: Int
    let avg_finalized_daily_margin: Double?
    let last_played_on: Date?
    let days_won_by_viewer: Int?
    let days_won_by_opponent: Int?
    let avg_margin_on_viewer_win_days: Double?
    let avg_margin_on_opponent_win_days: Double?
    let avg_viewer_steps_per_battle_day: Double?
    let recent_series_results: [String]?
    let active_match_id: UUID?
    let computed_at: Date?

    enum CodingKeys: String, CodingKey {
        case opponent_profile_id
        case opponent_display_name
        case opponent_initials
        case opponent_avatar_url
        case finalized_days_competed
        case match_wins
        case match_losses
        case match_ties
        case win_percentage
        case avg_finalized_daily_margin
        case last_played_on
        case days_won_by_viewer
        case days_won_by_opponent
        case avg_margin_on_viewer_win_days
        case avg_margin_on_opponent_win_days
        case avg_viewer_steps_per_battle_day
        case recent_series_results
        case active_match_id
        case computed_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        opponent_profile_id = try c.decode(UUID.self, forKey: .opponent_profile_id)
        opponent_display_name = try c.decode(String.self, forKey: .opponent_display_name)
        opponent_initials = try c.decode(String.self, forKey: .opponent_initials)
        opponent_avatar_url = try c.decodeIfPresent(String.self, forKey: .opponent_avatar_url)
        finalized_days_competed = Self.decodeInt(c, key: .finalized_days_competed)
        match_wins = Self.decodeInt(c, key: .match_wins)
        match_losses = Self.decodeInt(c, key: .match_losses)
        match_ties = Self.decodeInt(c, key: .match_ties)
        win_percentage = Self.decodeInt(c, key: .win_percentage)
        avg_finalized_daily_margin = Self.decodeOptionalNumericDouble(c, key: .avg_finalized_daily_margin)
        last_played_on = Self.decodeOptionalPostgresDate(c, key: .last_played_on)
        days_won_by_viewer = Self.decodeOptionalInt(c, key: .days_won_by_viewer)
        days_won_by_opponent = Self.decodeOptionalInt(c, key: .days_won_by_opponent)
        avg_margin_on_viewer_win_days = Self.decodeOptionalNumericDouble(c, key: .avg_margin_on_viewer_win_days)
        avg_margin_on_opponent_win_days = Self.decodeOptionalNumericDouble(c, key: .avg_margin_on_opponent_win_days)
        avg_viewer_steps_per_battle_day = Self.decodeOptionalNumericDouble(c, key: .avg_viewer_steps_per_battle_day)
        recent_series_results = Self.decodeOptionalStringArray(c, key: .recent_series_results)
        active_match_id = try c.decodeIfPresent(UUID.self, forKey: .active_match_id)
        computed_at = try c.decodeIfPresent(Date.self, forKey: .computed_at)
    }

    private static func decodeInt(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int {
        if let v = try? c.decode(Int.self, forKey: key) { return v }
        if let d = try? c.decode(Double.self, forKey: key) { return Int(d.rounded()) }
        if let s = try? c.decode(String.self, forKey: key), let v = Int(s) { return v }
        return 0
    }

    private static func decodeOptionalNumericDouble(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Double? {
        guard c.contains(key) else { return nil }
        if (try? c.decodeNil(forKey: key)) == true { return nil }
        if let v = try? c.decode(Double.self, forKey: key) { return v }
        if let v = try? c.decode(Int.self, forKey: key) { return Double(v) }
        if let s = try? c.decode(String.self, forKey: key), let v = Double(s) { return v }
        return nil
    }

    private static func decodeOptionalInt(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int? {
        guard c.contains(key) else { return nil }
        if (try? c.decodeNil(forKey: key)) == true { return nil }
        if let v = try? c.decode(Int.self, forKey: key) { return v }
        if let d = try? c.decode(Double.self, forKey: key) { return Int(d.rounded()) }
        if let s = try? c.decode(String.self, forKey: key), let v = Int(s) { return v }
        return nil
    }

    private static func decodeOptionalStringArray(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> [String]? {
        guard c.contains(key) else { return nil }
        if (try? c.decodeNil(forKey: key)) == true { return nil }
        if let arr = try? c.decode([String].self, forKey: key) {
            return arr
        }
        if let raw = try? c.decode(String.self, forKey: key) {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("{"), trimmed.hasSuffix("}") else { return nil }
            let content = String(trimmed.dropFirst().dropLast())
            if content.isEmpty { return [] }
            return content
                .split(separator: ",")
                .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "") }
                .filter { !$0.isEmpty }
        }
        return nil
    }

    private static func decodeOptionalPostgresDate(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Date? {
        guard c.contains(key) else { return nil }
        if (try? c.decodeNil(forKey: key)) == true { return nil }
        if let d = try? c.decode(Date.self, forKey: key) { return d }
        guard let s = try? c.decode(String.self, forKey: key), !s.isEmpty else { return nil }
        let isoDate = DateFormatter()
        isoDate.calendar = Calendar(identifier: .gregorian)
        isoDate.locale = Locale(identifier: "en_US_POSIX")
        isoDate.timeZone = TimeZone(secondsFromGMT: 0)
        isoDate.dateFormat = "yyyy-MM-dd"
        return isoDate.date(from: s)
    }

    var toDomain: HomeRivalStat {
        HomeRivalStat(
            opponentProfileId: opponent_profile_id,
            opponentDisplayName: opponent_display_name,
            opponentInitials: opponent_initials,
            opponentAvatarURL: opponent_avatar_url,
            finalizedDaysCompeted: max(0, finalized_days_competed),
            matchWins: max(0, match_wins),
            matchLosses: max(0, match_losses),
            matchTies: max(0, match_ties),
            winPercentage: max(0, min(100, win_percentage)),
            avgFinalizedDailyMargin: avg_finalized_daily_margin,
            lastPlayedOn: last_played_on,
            daysWonByViewer: days_won_by_viewer.map { max(0, $0) },
            daysWonByOpponent: days_won_by_opponent.map { max(0, $0) },
            avgMarginOnViewerWinDays: avg_margin_on_viewer_win_days,
            avgMarginOnOpponentWinDays: avg_margin_on_opponent_win_days,
            avgViewerStepsPerBattleDay: avg_viewer_steps_per_battle_day,
            recentSeriesResults: recent_series_results,
            activeMatchId: active_match_id,
            computedAt: computed_at
        )
    }
}

private struct StatsOpponentStepsRollupsRPCResult: Decodable, Sendable {
    let lifetime_steps: Int64
    let rolling_365d_steps: Int64
    let current_month_steps: Int64
    let computed_at: Date?

    enum CodingKeys: String, CodingKey {
        case lifetime_steps
        case rolling_365d_steps
        case current_month_steps
        case computed_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        lifetime_steps = Self.decodeInt64(c, key: .lifetime_steps)
        rolling_365d_steps = Self.decodeInt64(c, key: .rolling_365d_steps)
        current_month_steps = Self.decodeInt64(c, key: .current_month_steps)
        computed_at = try c.decodeIfPresent(Date.self, forKey: .computed_at)
    }

    private static func decodeInt64(_ c: KeyedDecodingContainer<CodingKeys>, key: CodingKeys) -> Int64 {
        if let v = try? c.decode(Int64.self, forKey: key) { return v }
        if let v = try? c.decode(Int.self, forKey: key) { return Int64(v) }
        if let d = try? c.decode(Double.self, forKey: key) { return Int64(d.rounded()) }
        if let s = try? c.decode(String.self, forKey: key), let v = Int64(s) { return v }
        return 0
    }

    func toDomain() -> StatsOpponentStepsRollups {
        StatsOpponentStepsRollups(
            lifetimeSteps: HomeRepository.safeInt(from: lifetime_steps),
            rolling365dSteps: HomeRepository.safeInt(from: rolling_365d_steps),
            currentMonthSteps: HomeRepository.safeInt(from: current_month_steps),
            computedAt: computed_at
        )
    }
}

private struct HomeStatsSnapshotRPCResult: Decodable, Sendable {
    let effective_range_key: String
    let summary: Summary
    let chart: Chart
    let scope_flags: ScopeFlags

    struct Summary: Decodable, Sendable {
        let net_margin: Int64?
        let previous_period_percent: Int?
        let wins: Int
        let losses: Int
        let ties: Int
        let win_rate_percent: Int
        let current_streak_type: String
        let current_streak_count: Int
    }

    struct Chart: Decodable, Sendable {
        let points: [Point]
    }

    struct Point: Decodable, Sendable {
        let date: String
        let margin: Int64
    }

    struct ScopeFlags: Decodable, Sendable {
        let battle_stats_scope: String
        let range_support: String
    }

    func toDomain() -> HomeStatsSnapshot {
        HomeStatsSnapshot(
            effectiveRangeKey: effective_range_key,
            margins: chart.points.map { DailyBattleMargin(calendarDate: $0.date, margin: HomeRepository.safeInt(from: $0.margin)) },
            previousPeriodPercent: summary.previous_period_percent,
            battleStats: HealthBattleStats(
                matchesPlayed: max(0, summary.wins + summary.losses + summary.ties),
                wins: max(0, summary.wins),
                losses: max(0, summary.losses),
                ties: max(0, summary.ties),
                winRate: max(0, min(100, summary.win_rate_percent)),
                currentStreakType: HealthBattleStats.StreakType(rawValue: summary.current_streak_type) ?? .none,
                currentStreakCount: max(0, summary.current_streak_count)
            ),
            battleStatsScope: scope_flags.battle_stats_scope,
            rangeSupport: scope_flags.range_support
        )
    }
}

// MARK: - decline_pending_match RPC (see supabase/sql/slice4e-decline-pending-match.sql)

private struct DeclinePendingMatchRPCParams: Sendable {
    let p_match_id: UUID
}

extension DeclinePendingMatchRPCParams: Encodable {
    nonisolated func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(p_match_id, forKey: .p_match_id)
    }

    enum CodingKeys: String, CodingKey {
        case p_match_id
    }
}

private struct DeclinePendingMatchRPCResult: Sendable {
    let ok: Bool
    let reason: String?
}

extension DeclinePendingMatchRPCResult: Decodable {
    nonisolated init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decode(Bool.self, forKey: .ok)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
    }

    enum CodingKeys: String, CodingKey {
        case ok
        case reason
    }
}
