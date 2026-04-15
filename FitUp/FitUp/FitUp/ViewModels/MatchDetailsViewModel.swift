//
//  MatchDetailsViewModel.swift
//  FitUp
//
//  Match Details screen — v2 data layer: Supabase + HealthKit + head-to-head RPC.
//

import Combine
import Foundation
import SwiftUI

// MARK: - Phase

enum MatchDetailsScreenPhase: String {
    case skeleton
    case partial
    case live
}

// MARK: - Display model (all derived stats are computed here)

struct MatchDetailDisplayModel {
    let snapshot: MatchDetailsSnapshot
    let opponentTodayLastSyncedAt: Date?
    let startsAt: Date?
    let endsAt: Date?
    let matchTimezone: String
    /// Authoritative "my" today value (HealthKit when available).
    let myTodayDisplay: Int
    let theirToday: Int
    let healthKitStale: Bool
    let headToHead: HeadToHeadStats?
    let mergedDayRows: [MatchDetailsDayRow]
    let phase: MatchDetailsScreenPhase

    var metricIsCalories: Bool {
        snapshot.metricType == "active_calories"
    }

    var metricPillLabel: String {
        metricIsCalories ? "CALORIES" : "STEPS"
    }

    var formatDurationPill: String {
        "\(snapshot.seriesLabel) · \(snapshot.durationDays)-Day"
    }

    /// Hero / today: winning side for active matches (completed uses series outcome).
    var isAheadToday: Bool {
        switch snapshot.state {
        case .completed:
            return snapshot.isWinning
        case .active:
            return myTodayDisplay >= theirToday
        case .pending:
            return true
        }
    }

    var glassVariant: GlassCardVariant {
        switch snapshot.state {
        case .pending:
            return .base
        case .active, .completed:
            return isAheadToday ? .win : .lose
        }
    }

    var statusLabel: String {
        switch snapshot.state {
        case .pending:
            return "PENDING"
        case .completed:
            return snapshot.isWinning ? "YOU WON" : "YOU LOST"
        case .active:
            return myTodayDisplay >= theirToday ? "YOU'RE UP" : "YOU'RE DOWN"
        }
    }

    var dayBadgeLabel: String {
        if let today = mergedDayRows.first(where: { $0.isToday }) {
            return "Day \(today.dayNumber)/\(snapshot.durationDays)"
        }
        let finalized = mergedDayRows.filter(\.isFinalized).count
        return "Day \(min(finalized + 1, snapshot.durationDays))/\(snapshot.durationDays)"
    }

    var seriesProgressFraction: Double {
        guard snapshot.durationDays > 0 else { return 0 }
        let finalizedCount = mergedDayRows.filter { $0.isFinalized }.count
        return min(1, Double(finalizedCount) / Double(snapshot.durationDays))
    }

    var daysRemainingLabel: String {
        let finalizedCount = mergedDayRows.filter { $0.isFinalized }.count
        let left = max(0, snapshot.durationDays - finalizedCount)
        return "\(left) day\(left == 1 ? "" : "s") left"
    }

    var percentCompleteLabel: String {
        let p = Int((seriesProgressFraction * 100).rounded())
        return "\(p)% complete"
    }

    var todayDelta: Int {
        myTodayDisplay - theirToday
    }

    var todayDeltaLabel: String {
        let d = todayDelta
        let unit = metricIsCalories ? "kcal" : "steps"
        if d == 0 {
            return "Even"
        }
        if d > 0 {
            return "+\(d) \(unit) ahead"
        }
        return "\(d) \(unit) behind"
    }

    var dailyAverageMine: Double {
        let rows = mergedDayRows.filter { $0.isFinalized && !$0.isTie }
        guard !rows.isEmpty else { return 0 }
        let sum = rows.reduce(0) { $0 + myValue(for: $1) }
        return Double(sum) / Double(rows.count)
    }

    var dailyAverageTheirs: Double {
        let rows = mergedDayRows.filter { $0.isFinalized && !$0.isTie }
        guard !rows.isEmpty else { return 0 }
        let sum = rows.reduce(0) { $0 + $1.theirValue }
        return Double(sum) / Double(rows.count)
    }

    var bestDayMine: Int {
        mergedDayRows.map { myValue(for: $0) }.max() ?? 0
    }

    var bestDayTheirs: Int {
        mergedDayRows.map(\.theirValue).max() ?? 0
    }

    var totalMine: Int {
        mergedDayRows.reduce(0) { $0 + myValue(for: $1) }
    }

    var totalTheirs: Int {
        mergedDayRows.reduce(0) { $0 + $1.theirValue }
    }

    var daysWonFractionLabel: String {
        "\(snapshot.myScore)/\(snapshot.durationDays)"
    }

    var winRateMinePercent: Double {
        let d = snapshot.myScore + snapshot.theirScore
        guard d > 0 else { return 0 }
        return Double(snapshot.myScore) / Double(d) * 100
    }

    var winRateTheirsPercent: Double {
        let d = snapshot.myScore + snapshot.theirScore
        guard d > 0 else { return 0 }
        return Double(snapshot.theirScore) / Double(d) * 100
    }

    var opponentFirstName: String {
        snapshot.opponent.displayName.split(separator: " ").first.map(String.init) ?? snapshot.opponent.displayName
    }

    var primaryCTATitle: String {
        switch snapshot.state {
        case .completed:
            return "Rematch"
        case .active:
            return isAheadToday ? "Hold the Lead 💪" : "Fight Back Now ⚡"
        case .pending:
            return ""
        }
    }

    var winningAlertText: String {
        "You're ahead today. Final numbers lock at 10:00 AM after the day ends."
    }

    var losingAlertText: String {
        "You're behind — a 30-minute walk can flip today. Cut the gap before tonight."
    }

    func myValue(for row: MatchDetailsDayRow) -> Int {
        row.isToday ? myTodayDisplay : row.myValue
    }

    /// Relative bar height 0...1 for chart (max of both players' best day or totals).
    var chartMaxValue: Double {
        let m = Double(mergedDayRows.map { max(myValue(for: $0), $0.theirValue) }.max() ?? 1)
        return max(m, 1)
    }

    func barHeight(value: Int) -> CGFloat {
        guard chartMaxValue > 0 else { return 0 }
        return CGFloat(Double(value) / chartMaxValue)
    }

    var headToHeadBarFractions: (mine: CGFloat, tie: CGFloat, theirs: CGFloat) {
        guard let h = headToHead else {
            return (0.33, 0.34, 0.33)
        }
        let t = Double(h.viewerWins + h.opponentWins + h.seriesTies)
        guard t > 0 else { return (0.33, 0.34, 0.33) }
        return (
            CGFloat(Double(h.viewerWins) / t),
            CGFloat(Double(h.seriesTies) / t),
            CGFloat(Double(h.opponentWins) / t)
        )
    }

    var lastSyncedRelativeLabel: String? {
        guard let at = opponentTodayLastSyncedAt else { return nil }
        let sec = Int(Date().timeIntervalSince(at))
        if sec < 60 { return "Last synced just now" }
        let min = sec / 60
        if min < 60 { return "Last synced \(min) min ago" }
        let h = min / 60
        return "Last synced \(h) hr ago"
    }
}

// MARK: - View model

@MainActor
final class MatchDetailsViewModel: ObservableObject {
    @Published private(set) var snapshot: MatchDetailsSnapshot?
    @Published private(set) var phase: MatchDetailsScreenPhase = .skeleton
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmittingAction = false
    @Published var errorMessage: String?

    @Published private(set) var opponentTodayLastSyncedAt: Date?
    @Published private(set) var startsAt: Date?
    @Published private(set) var endsAt: Date?
    @Published private(set) var matchTimezone: String = "America/Chicago"

    @Published private(set) var myTodayHK: Int?
    @Published private(set) var healthKitStale = false
    @Published private(set) var headToHead: HeadToHeadStats?

    let matchId: UUID

    private let profile: Profile?
    private let detailsRepository: MatchDetailsRepository
    private let homeRepository: HomeRepository
    private let headToHeadRepository: HeadToHeadRepository
    private var hasStarted = false

    private let cacheKeyPrefix = "matchDetail.cache.v1."

    init(
        matchId: UUID,
        profile: Profile?,
        detailsRepository: MatchDetailsRepository,
        homeRepository: HomeRepository,
        headToHeadRepository: HeadToHeadRepository = HeadToHeadRepository()
    ) {
        self.matchId = matchId
        self.profile = profile
        self.detailsRepository = detailsRepository
        self.homeRepository = homeRepository
        self.headToHeadRepository = headToHeadRepository
        loadCacheSync()
    }

    var displayModel: MatchDetailDisplayModel? {
        guard let snapshot else { return nil }
        let merged = mergedDayRows()
        let myToday = resolvedMyToday(snapshot: snapshot)
        let theirToday = snapshot.dayRows.first(where: { $0.isToday })?.theirValue ?? snapshot.theirToday
        return MatchDetailDisplayModel(
            snapshot: snapshot,
            opponentTodayLastSyncedAt: opponentTodayLastSyncedAt,
            startsAt: startsAt,
            endsAt: endsAt,
            matchTimezone: matchTimezone,
            myTodayDisplay: myToday,
            theirToday: theirToday,
            healthKitStale: healthKitStale,
            headToHead: headToHead,
            mergedDayRows: merged,
            phase: phase
        )
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        Task { await initialLoad() }
        detailsRepository.startLiveRefresh(matchId: matchId) { [weak self] in
            guard let self else { return }
            await self.refreshSupabaseOnly()
        }
    }

    func stop() {
        detailsRepository.stopLiveRefresh()
        hasStarted = false
        headToHeadRepository.clearMemoryCache()
    }

    private func loadCacheSync() {
        guard let data = UserDefaults.standard.data(forKey: cacheKeyPrefix + matchId.uuidString),
              let cached = try? JSONDecoder().decode(MatchDetailsSnapshot.self, from: data)
        else {
            return
        }
        snapshot = cached
        phase = .partial
    }

    private func saveCache(_ snap: MatchDetailsSnapshot) {
        guard let data = try? JSONEncoder().encode(snap) else { return }
        UserDefaults.standard.set(data, forKey: cacheKeyPrefix + matchId.uuidString)
    }

    private func initialLoad() async {
        guard let profile else {
            errorMessage = "You must be signed in to view this match."
            phase = .live
            return
        }

        if snapshot == nil {
            phase = .skeleton
        }

        isLoading = true
        defer { isLoading = false }

        let bundle: MatchDetailBundle
        do {
            bundle = try await detailsRepository.loadMatchDetailBundle(matchId: matchId, currentUser: profile)
        } catch {
            errorMessage = "Could not load this match right now."
            AppLogger.log(
                category: "match_details",
                level: .warning,
                message: "match details load failed",
                userId: profile.id,
                metadata: ["error": error.localizedDescription]
            )
            if snapshot != nil {
                phase = .partial
            } else {
                phase = .live
            }
            return
        }

        applyBundle(bundle)

        async let hkTask = fetchMyTodayHK(metricType: bundle.snapshot.metricType)
        async let h2hTask: HeadToHeadStats? = {
            let oid = bundle.snapshot.opponent.id
            return try? await headToHeadRepository.fetchStats(opponentId: oid, viewerId: profile.id)
        }()

        let hk = await hkTask
        applyHK(hk, fallbackMyToday: bundle.snapshot.myToday)

        headToHead = await h2hTask

        saveCache(bundle.snapshot)
        phase = .live
        errorMessage = nil

        if bundle.snapshot.state == .completed && bundle.snapshot.myScore > bundle.snapshot.theirScore {
            SubscriptionService.shared.markFirstMatchWon()
        } else if bundle.snapshot.state == .completed {
            SubscriptionService.shared.markFirstMatchCompleted()
        }
    }

    private func fetchMyTodayHK(metricType: String) async -> (value: Int?, stale: Bool) {
        do {
            if metricType == "active_calories" {
                let v = try await HealthKitService.fetchTodayActiveCalories()
                return (v, false)
            }
            let v = try await HealthKitService.fetchTodayStepCount()
            return (v, false)
        } catch {
            return (nil, true)
        }
    }

    private func applyHK(_ result: (value: Int?, stale: Bool), fallbackMyToday: Int) {
        if let v = result.value {
            myTodayHK = v
            healthKitStale = false
        } else {
            myTodayHK = myTodayHK ?? fallbackMyToday
            healthKitStale = result.stale
        }
    }

    private func applyBundle(_ bundle: MatchDetailBundle) {
        snapshot = bundle.snapshot
        opponentTodayLastSyncedAt = bundle.opponentTodayLastSyncedAt
        startsAt = bundle.startsAt
        endsAt = bundle.endsAt
        matchTimezone = bundle.matchTimezone
    }

    private func resolvedMyToday(snapshot: MatchDetailsSnapshot) -> Int {
        if let hk = myTodayHK {
            return hk
        }
        return snapshot.myToday
    }

    private func mergedDayRows() -> [MatchDetailsDayRow] {
        guard let snapshot else { return [] }
        let my = resolvedMyToday(snapshot: snapshot)
        return snapshot.dayRows.map { row in
            row.isToday ? row.withMyValue(my) : row
        }
    }

    private func refreshSupabaseOnly() async {
        guard let profile else { return }
        do {
            let bundle = try await detailsRepository.loadMatchDetailBundle(matchId: matchId, currentUser: profile)
            applyBundle(bundle)
            saveCache(bundle.snapshot)
            if errorMessage != nil {
                errorMessage = nil
            }
        } catch {
            AppLogger.log(
                category: "match_details",
                level: .debug,
                message: "match details realtime refresh failed",
                userId: profile.id,
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    func refresh(showLoading: Bool) async {
        guard let profile else {
            errorMessage = "You must be signed in to view this match."
            return
        }

        if showLoading {
            isLoading = true
        }
        defer {
            if showLoading {
                isLoading = false
            }
        }

        do {
            let bundle = try await detailsRepository.loadMatchDetailBundle(matchId: matchId, currentUser: profile)
            applyBundle(bundle)
            let hk = await fetchMyTodayHK(metricType: bundle.snapshot.metricType)
            applyHK(hk, fallbackMyToday: bundle.snapshot.myToday)
            headToHead = try? await headToHeadRepository.fetchStats(
                opponentId: bundle.snapshot.opponent.id,
                viewerId: profile.id
            )
            saveCache(bundle.snapshot)
            phase = .live
            errorMessage = nil

            if bundle.snapshot.state == .completed && bundle.snapshot.myScore > bundle.snapshot.theirScore {
                SubscriptionService.shared.markFirstMatchWon()
            } else if bundle.snapshot.state == .completed {
                SubscriptionService.shared.markFirstMatchCompleted()
            }
        } catch {
            errorMessage = "Could not load this match right now."
            AppLogger.log(
                category: "match_details",
                level: .warning,
                message: "match details load failed",
                userId: profile.id,
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    func acceptPendingChallenge() async {
        guard let profileId = profile?.id else { return }
        isSubmittingAction = true
        defer { isSubmittingAction = false }

        do {
            try await homeRepository.acceptPendingMatch(matchId: matchId, userId: profileId)
            AppLogger.log(
                category: "matchmaking",
                level: .info,
                message: "pending match accepted from details",
                userId: profileId,
                metadata: ["match_id": matchId.uuidString]
            )
            await refresh(showLoading: false)
        } catch {
            errorMessage = "Could not accept challenge right now."
            AppLogger.log(
                category: "matchmaking",
                level: .warning,
                message: "pending accept failed from details",
                userId: profileId,
                metadata: ["error": error.localizedDescription]
            )
        }
    }

    func declinePendingChallenge() async -> Bool {
        guard let profileId = profile?.id else { return false }
        isSubmittingAction = true
        defer { isSubmittingAction = false }

        do {
            try await homeRepository.declinePendingMatch(
                challengeId: snapshot?.challengeId,
                matchId: matchId
            )
            AppLogger.log(
                category: "matchmaking",
                level: .info,
                message: "pending match declined from details",
                userId: profileId,
                metadata: ["match_id": matchId.uuidString]
            )
            return true
        } catch {
            errorMessage = "Could not decline challenge right now."
            AppLogger.log(
                category: "matchmaking",
                level: .warning,
                message: "pending decline failed from details",
                userId: profileId,
                metadata: ["error": error.localizedDescription]
            )
            return false
        }
    }

    func makeRematchLaunchContext() -> ChallengeLaunchContext? {
        guard let snapshot else { return nil }

        let metric: ChallengeMetricType = snapshot.metricType == ChallengeMetricType.activeCalories.rawValue ? .activeCalories : .steps
        let format: ChallengeFormatType
        switch snapshot.durationDays {
        case 1: format = .daily
        case 3: format = .firstTo3
        case 5: format = .bestOf5
        case 7: format = .bestOf7
        default:
            return nil
        }

        let opponent = ChallengePrefillOpponent(
            id: snapshot.opponent.id,
            displayName: snapshot.opponent.displayName,
            initials: snapshot.opponent.initials,
            colorHex: snapshot.opponent.colorHex
        )
        return .rematch(opponent: opponent, metric: metric, format: format)
    }
}
