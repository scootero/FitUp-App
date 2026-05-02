//
//  HomeViewModel.swift
//  FitUp
//
//  Slice 3 Home screen state and actions.
//

import Combine
import Foundation
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    struct ActivityStats: Equatable {
        let matchCount: Int?
        let winCount: Int?
        let winRatePercent: Int?

        static let unknown = ActivityStats(matchCount: nil, winCount: nil, winRatePercent: nil)

        var matchCountText: String { matchCount.map(String.init) ?? "--" }
        var winCountText: String { winCount.map(String.init) ?? "--" }
        var winRateText: String {
            guard let winRatePercent else { return "--" }
            return "\(winRatePercent)%"
        }
        var hasResolvedValue: Bool {
            matchCount != nil && winCount != nil && winRatePercent != nil
        }
    }

    @Published private(set) var searchingRequests: [HomeSearchingRequest] = []
    @Published private(set) var activeMatches: [HomeActiveMatch] = []
    @Published private(set) var pendingMatches: [HomePendingMatch] = []
    @Published private(set) var discoverUsers: [HomeDiscoverUser] = []
    @Published private(set) var stats = ActivityStats.unknown
    @Published private(set) var isStatsLoading = false
    @Published private(set) var isStatsRefreshing = false
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var activeActionSearchID: UUID?
    @Published private(set) var activeActionPendingMatchID: UUID?
    /// Shown when a new pending match appears or a `match_found` / `challenge_received` push was queued.
    @Published private(set) var matchFoundCelebration: HomePendingMatch?
    /// Shown once when a match becomes active (both accepted) or `match_active` was queued.
    @Published private(set) var matchActiveCelebration: HomeActiveMatch?
    /// Short retro banner after successfully declining a pending match from Home.
    @Published private(set) var declineFeedbackOpponentName: String?
    /// Incoming friend request from DB poll (not from push) — shown when not dismissed and no duplicate push banner.
    @Published private(set) var polledIncomingFriend: (peerId: UUID, fromName: String)?
    @Published private(set) var isFriendRequestActionLoading = false
    /// Steps vs calories for the home hero and margin chart (bound to `HomeBattleHeroCard`).
    @Published var heroMetric: HomeBattleHeroCard.HeroMetric = .steps
    @Published private(set) var dailyBattleMargins: [DailyBattleMargin] = []
    @Published private(set) var isBattleMarginsRefreshing = false
    @Published private(set) var battleMarginsSavedAt: Date?
    /// 7 or 10 calendar days for the signed margin chart.
    @Published var marginChartDayCount: Int = 7
    @Published private(set) var isHeroLoading = true
    @Published private(set) var isInitialLoading = true
    /// Full rows for the expandable Past Matches card (warmed by stats refresh; lazy-loaded if empty).
    @Published private(set) var completedMatches: [ActivityCompletedMatch] = []
    @Published private(set) var isLoadingCompletedMatches = false

    var hasAnyContent: Bool {
        !searchingRequests.isEmpty || !activeMatches.isEmpty || !pendingMatches.isEmpty
            || !discoverUsers.isEmpty
    }

    private let repository = HomeRepository()
    private let activityRepository = ActivityRepository()
    private let friendshipRepository = FriendshipRepository()
    private let leaderboardRepository = LeaderboardRepository()
    private let snapshotCacheStore = HomeSnapshotCacheStore()
    private let battleStatsCacheStore = HomeBattleStatsCacheStore()
    private let marginsCacheStore = HomeDailyBattleMarginsCacheStore()
    private var userId: UUID?
    private var profileTimeZoneIdentifier: String?
    private var myDisplayName: String = "You"
    private var shouldShowOnboardingPlaceholder = false
    private var pollingTask: Task<Void, Never>?
    private let pollingIntervalNs: UInt64 = 90_000_000_000
    private var isReloadInFlight = false
    private var hasPendingForcedReload = false
    private var celebrationDismissTask: Task<Void, Never>?
    private var activeCelebrationDismissTask: Task<Void, Never>?
    private var declineFeedbackDismissTask: Task<Void, Never>?
    private weak var sessionStore: SessionStore?
    /// When match-found and match-live both trigger in one reload, show live after the user dismisses match-found.
    private var deferredMatchActiveCelebration: HomeActiveMatch?
    private var heroHealthKitPatchTask: Task<Void, Never>?
    private var statsRefreshTask: Task<Void, Never>?
    private var marginsRefreshTask: Task<Void, Never>?
    private var heroHealthKitValueByMetric: [String: Int] = [:]
    private var heroLoadStartedAt: Date?
    private var heroStateResolvedAt: Date?
    private var lastStatsRefreshAt: Date?
    private let statsRefreshMinInterval: TimeInterval = 300
    private var marginsRefreshGeneration = 0
    private var lastHomeProfileLocalDate: String?
    private var completedMatchesListTask: Task<Void, Never>?

    func start(profile: Profile?, showOnboardingSearching: Bool, sessionStore: SessionStore) {
        guard let profileId = profile?.id else { return }
        self.sessionStore = sessionStore
        myDisplayName = profile?.displayName ?? "You"
        profileTimeZoneIdentifier = profile?.timezone
        let currentLocalDate = snapshotCacheStore.localDateString(
            now: Date(),
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )

        if userId != profileId {
            stop()
            userId = profileId
            activeMatches = []
            dailyBattleMargins = []
            isHeroLoading = true
            isInitialLoading = true
            stats = .unknown
            isStatsLoading = false
            isStatsRefreshing = false
            isBattleMarginsRefreshing = false
            battleMarginsSavedAt = nil
            heroHealthKitValueByMetric = [:]
            heroLoadStartedAt = Date()
            heroStateResolvedAt = nil
            lastStatsRefreshAt = nil
            marginsRefreshGeneration += 1
            lastHomeProfileLocalDate = currentLocalDate
            completedMatches = []
            completedMatchesListTask?.cancel()
            completedMatchesListTask = nil
            loadHeroSnapshotFromDisk(profileId: profileId)
            loadCachedBattleStats(profileId: profileId)
            loadMarginsFromCache(profileId: profileId)
        } else {
            handleHomeDayRolloverIfNeeded(currentLocalDate: currentLocalDate)
            if !isHeroLoading {
                let localDate = snapshotCacheStore.localDateString(
                    now: Date(),
                    profileTimeZoneIdentifier: profileTimeZoneIdentifier
                )
                logSnapshotLoaded(
                    source: "memory",
                    profileId: profileId,
                    localDate: localDate,
                    savedAt: heroStateResolvedAt
                )
                logHomeReturnNoReload(profileId: profileId)
            }
        }

        startPollingIfNeeded()

        if showOnboardingSearching {
            shouldShowOnboardingPlaceholder = true
        }
        refreshHomeStatsInBackground(userId: profileId, force: false)
        Task { await reload(force: false) }
    }

    func stop() {
        celebrationDismissTask?.cancel()
        celebrationDismissTask = nil
        activeCelebrationDismissTask?.cancel()
        activeCelebrationDismissTask = nil
        declineFeedbackDismissTask?.cancel()
        declineFeedbackDismissTask = nil
        heroHealthKitPatchTask?.cancel()
        heroHealthKitPatchTask = nil
        statsRefreshTask?.cancel()
        statsRefreshTask = nil
        marginsRefreshTask?.cancel()
        marginsRefreshTask = nil
        completedMatchesListTask?.cancel()
        completedMatchesListTask = nil
        matchFoundCelebration = nil
        matchActiveCelebration = nil
        deferredMatchActiveCelebration = nil
        declineFeedbackOpponentName = nil
        pollingTask?.cancel()
        pollingTask = nil
        lastHomeProfileLocalDate = nil
    }

    func reload(force: Bool) async {
        guard let userId else { return }
        if isReloadInFlight {
            if force { hasPendingForcedReload = true }
            return
        }

        isReloadInFlight = true
        defer {
            isReloadInFlight = false
        }

        var carryForce = force
        repeat {
            let shouldForceRefresh = carryForce || hasPendingForcedReload
            carryForce = false
            hasPendingForcedReload = false
            let finished = await performReload(userId: userId, forceRefresh: shouldForceRefresh)
            if !finished { return }
        } while hasPendingForcedReload
    }

    private func performReload(userId: UUID, forceRefresh: Bool) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        handleHomeDayRolloverIfNeeded()

        if forceRefresh {
            await runMetricSyncIfEligible()
        }

        let oldPendingIds = Set(pendingMatches.map(\.id))
        let oldActiveIds = Set(activeMatches.map(\.id))

        async let snapshotTask = repository.loadSnapshot(
            for: userId,
            showOnboardingSearching: shouldShowOnboardingPlaceholder,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )
        let snapshot = await snapshotTask
        guard !Task.isCancelled else {
            return false
        }

        shouldShowOnboardingPlaceholder = false

        let newPendingIds = Set(snapshot.pendingMatches.map(\.id))
        let newPendingMatchIds = newPendingIds.subtracting(oldPendingIds)

        for mid in newPendingMatchIds {
            ProductAnalytics.track(
                ProductAnalytics.Event.matchCreated,
                userId: userId,
                properties: ["match_id": mid.uuidString, "source": "pending_row"]
            )
        }

        searchingRequests = snapshot.searching
        activeMatches = applyHealthKitOverrides(to: snapshot.activeMatches)
        pendingMatches = snapshot.pendingMatches
        discoverUsers = snapshot.discoverUsers
        syncHeroMetricWithActiveMatches()
        if isHeroLoading { isHeroLoading = false }
        persistFreshHeroSnapshot(profileId: userId)

        var celebration: HomePendingMatch?
        if !newPendingMatchIds.isEmpty,
           let m = snapshot.pendingMatches.first(where: { newPendingMatchIds.contains($0.id) && !MatchFoundCelebrationStore.hasShown(profileId: userId, matchId: $0.id) }) {
            celebration = m
        }

        if celebration == nil {
            let pendingIds = Set(snapshot.pendingMatches.map(\.id))
            if let qid = sessionStore?.takePendingMatchFoundCelebrationIfPendingContains(pendingIds),
               let m = snapshot.pendingMatches.first(where: { $0.id == qid }),
               !MatchFoundCelebrationStore.hasShown(profileId: userId, matchId: m.id) {
                celebration = m
            }
        }

        let newActiveIds = Set(snapshot.activeMatches.map(\.id))
        let newActiveMatchIds = newActiveIds.subtracting(oldActiveIds)

        var activeCelebration: HomeActiveMatch?
        if let qid = sessionStore?.takePendingMatchActiveCelebrationIfActiveContains(newActiveIds),
           let m = snapshot.activeMatches.first(where: { $0.id == qid }),
           !MatchActiveCelebrationStore.hasShown(profileId: userId, matchId: m.id) {
            activeCelebration = m
        } else if !newActiveMatchIds.isEmpty,
                  let m = snapshot.activeMatches.first(where: { newActiveMatchIds.contains($0.id) && !MatchActiveCelebrationStore.hasShown(profileId: userId, matchId: $0.id) }) {
            activeCelebration = m
        }

        if let celebration {
            activeCelebrationDismissTask?.cancel()
            activeCelebrationDismissTask = nil
            matchActiveCelebration = nil
            matchFoundCelebration = celebration
            scheduleCelebrationDismiss()
            deferredMatchActiveCelebration = activeCelebration
        } else if let activeCelebration {
            if matchFoundCelebration != nil {
                deferredMatchActiveCelebration = activeCelebration
            } else {
                deferredMatchActiveCelebration = nil
                presentMatchActiveCelebration(activeCelebration)
            }
        }

        await refreshFriendIncomingPoll()
        syncLiveActivity()
        if isInitialLoading {
            isInitialLoading = false
        }

        if forceRefresh {
            await refreshHomeStatsAwaiting(userId: userId)
            marginsRefreshTask?.cancel()
            marginsRefreshTask = nil
            await refreshBattleMargins()
            await executeHeroHealthKitPatch(userId: userId)
        } else {
            refreshHomeStatsInBackground(userId: userId, force: true)
            marginsRefreshTask?.cancel()
            marginsRefreshTask = Task { [weak self] in
                await self?.refreshBattleMargins()
            }
            scheduleHeroHealthKitPatch()
        }
        return true
    }

    func syncHeroMetricWithActiveMatches() {
        let hasSteps = activeMatches.contains { $0.metricType != "active_calories" }
        let hasCalories = activeMatches.contains { $0.metricType == "active_calories" }
        if hasSteps, hasCalories { return }
        if hasSteps {
            heroMetric = .steps
        } else if hasCalories {
            heroMetric = .calories
        } else {
            heroMetric = .steps
        }
    }

    func setMarginChartDayCount(_ n: Int) async {
        let clamped = n >= 10 ? 10 : 7
        guard marginChartDayCount != clamped else { return }
        marginChartDayCount = clamped
        await refreshBattleMargins()
    }

    func refreshBattleMargins() async {
        guard let userId else {
            dailyBattleMargins = []
            battleMarginsSavedAt = nil
            isBattleMarginsRefreshing = false
            return
        }
        let didLoadCachedMargins = loadMarginsFromCache(profileId: userId)
        if !didLoadCachedMargins {
            dailyBattleMargins = []
            battleMarginsSavedAt = nil
        }
        marginsRefreshGeneration += 1
        let generation = marginsRefreshGeneration
        isBattleMarginsRefreshing = true
        defer {
            if generation == marginsRefreshGeneration {
                isBattleMarginsRefreshing = false
            }
        }
        let rows = await repository.fetchDailyBattleMargins(
            endDate: Date(),
            dayCount: marginChartDayCount,
            metricType: heroMetric.metricType,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )
        guard !Task.isCancelled, self.userId == userId, generation == marginsRefreshGeneration else { return }
        dailyBattleMargins = rows
#if DEBUG
        let series = rows.map { "\($0.calendarDate)=\($0.margin)" }.joined(separator: ", ")
        let todayKey = HomeRepository.formatProfileCalendarDate(
            Date(),
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )
        let todayRpcMargin = rows.first(where: { $0.calendarDate == todayKey })?.margin ?? 0
        var seenMatchIds = Set<UUID>()
        let todayLocalEdgeSum = activeMatches
            .filter { $0.metricType == heroMetric.metricType }
            .filter { seenMatchIds.insert($0.id).inserted }
            .reduce(0) { $0 + ($1.myToday - $1.theirToday) }
        AppLogger.log(
            category: "matchmaking",
            level: .debug,
            message: "home_daily_battle_margins debug",
            userId: userId,
            metadata: [
                "metric_type": heroMetric.metricType,
                "day_count": String(marginChartDayCount),
                "series": series,
                "today_key": todayKey,
                "today_rpc_margin": String(todayRpcMargin),
                "today_local_edge_sum": String(todayLocalEdgeSum)
            ]
        )
#endif
        let savedAt = Date()
        battleMarginsSavedAt = savedAt
        let cached = marginsCacheStore.makeCached(
            profileId: userId,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier,
            metricKey: heroMetric.metricType,
            dayCount: marginChartDayCount,
            rows: rows,
            savedAt: savedAt
        )
        marginsCacheStore.save(cached)
    }

    private func startPollingIfNeeded() {
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                try? await Task.sleep(nanoseconds: self.pollingIntervalNs)
                await self.reload(force: true)
            }
        }
    }

    // MARK: - Friend request poll (in-app when push missed)

    func refreshFriendIncomingPoll() async {
        guard let userId else { return }
        do {
            let rows = try await friendshipRepository.fetchFriendshipRows(currentProfileId: userId)
            let incoming = rows.first { $0.status == "pending" && $0.requestedBy != userId }
            guard let row = incoming else {
                polledIncomingFriend = nil
                return
            }
            let peer = row.aId == userId ? row.bId : row.aId
            if isFriendPeerDismissed(peerId: peer, for: userId) {
                polledIncomingFriend = nil
                return
            }
            if sessionStore?.friendRequestBannerFromPush?.0 == peer {
                polledIncomingFriend = nil
                return
            }
            let map = try await leaderboardRepository.fetchProfiles(userIds: [peer])
            let name = map[peer]?.displayName ?? "Player"
            polledIncomingFriend = (peer, name)
        } catch {
            polledIncomingFriend = nil
        }
    }

    func markFriendPeerDismissedForLater(peerId: UUID) {
        guard let userId else { return }
        var set = Set<String>(UserDefaults.standard.stringArray(forKey: Self.dismissedFriendPeersKey(for: userId)) ?? [])
        set.insert(peerId.uuidString)
        UserDefaults.standard.set(Array(set), forKey: Self.dismissedFriendPeersKey(for: userId))
        if polledIncomingFriend?.peerId == peerId { polledIncomingFriend = nil }
    }

    func makePrefillForPeer(_ peerId: UUID) async -> ChallengePrefillOpponent? {
        do {
            let map = try await leaderboardRepository.fetchProfiles(userIds: [peerId])
            let s = map[peerId]
            let name = s?.displayName ?? "Player"
            let ini = s?.initials ?? String(name.prefix(2)).uppercased()
            return ChallengePrefillOpponent(
                id: peerId,
                displayName: name,
                initials: ini,
                colorHex: ProfileAccentColor.hex(for: peerId)
            )
        } catch {
            return nil
        }
    }

    func acceptFriendRequestBackground(peerId: UUID) async -> ChallengePrefillOpponent? {
        guard let userId else { return nil }
        isFriendRequestActionLoading = true
        defer { isFriendRequestActionLoading = false }
        do {
            let (a, b) = FriendshipRepository.orderedPair(userId, peerId)
            try await friendshipRepository.acceptRequest(aId: a, bId: b)
            if polledIncomingFriend?.peerId == peerId { polledIncomingFriend = nil }
            sessionStore?.dismissFriendRequestFromPush()
            return await makePrefillForPeer(peerId)
        } catch {
            errorMessage = "Could not accept friend request."
            return nil
        }
    }

    private static func dismissedFriendPeersKey(for profileId: UUID) -> String {
        "fitup.dismissedFriendRequestPeers.\(profileId.uuidString)"
    }

    private func isFriendPeerDismissed(peerId: UUID, for profileId: UUID) -> Bool {
        let list = UserDefaults.standard.stringArray(forKey: Self.dismissedFriendPeersKey(for: profileId)) ?? []
        return list.contains(peerId.uuidString)
    }

    func dismissMatchFoundCelebration() {
        celebrationDismissTask?.cancel()
        celebrationDismissTask = nil
        if let id = matchFoundCelebration?.id, let profileId = userId {
            MatchFoundCelebrationStore.markShown(profileId: profileId, matchId: id)
        }
        let deferred = deferredMatchActiveCelebration
        deferredMatchActiveCelebration = nil
        matchFoundCelebration = nil
        if let deferred {
            presentMatchActiveCelebration(deferred)
        }
    }

    func dismissMatchActiveCelebration() {
        activeCelebrationDismissTask?.cancel()
        activeCelebrationDismissTask = nil
        if let id = matchActiveCelebration?.id, let profileId = userId {
            MatchActiveCelebrationStore.markShown(profileId: profileId, matchId: id)
        }
        matchActiveCelebration = nil
    }

    private func presentMatchActiveCelebration(_ match: HomeActiveMatch) {
        activeCelebrationDismissTask?.cancel()
        activeCelebrationDismissTask = nil
        matchActiveCelebration = match
        scheduleActiveCelebrationDismiss()
    }

    private func scheduleCelebrationDismiss() {
        celebrationDismissTask?.cancel()
        celebrationDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            dismissMatchFoundCelebration()
        }
    }

    private func scheduleActiveCelebrationDismiss() {
        activeCelebrationDismissTask?.cancel()
        activeCelebrationDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            dismissMatchActiveCelebration()
        }
    }

    func dismissDeclineFeedback() {
        declineFeedbackDismissTask?.cancel()
        declineFeedbackDismissTask = nil
        declineFeedbackOpponentName = nil
    }

    /// Loads completed match rows for the Past Matches card if the list is still empty (e.g. before stats refresh finished).
    func loadCompletedMatchesIfNeeded() async {
        guard let userId else { return }
        if !completedMatches.isEmpty { return }
        if isLoadingCompletedMatches { return }
        isLoadingCompletedMatches = true
        defer { isLoadingCompletedMatches = false }
        completedMatchesListTask?.cancel()
        completedMatchesListTask = Task { [weak self] in
            guard let self else { return }
            let rows = await activityRepository.loadCompletedMatches(currentUserId: userId)
            guard !Task.isCancelled else { return }
            guard self.userId == userId else { return }
            self.completedMatches = rows
        }
        await completedMatchesListTask?.value
    }

    private func showDeclineFeedback(opponentName: String) {
        declineFeedbackDismissTask?.cancel()
        declineFeedbackOpponentName = opponentName
        declineFeedbackDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            guard !Task.isCancelled else { return }
            dismissDeclineFeedback()
        }
    }

    private static func makeStats(from completedMatches: [ActivityCompletedMatch]) -> ActivityStats {
        let matchCount = completedMatches.count
        let winCount = completedMatches.filter(\.myWon).count
        guard matchCount > 0 else {
            return ActivityStats(matchCount: 0, winCount: 0, winRatePercent: 0)
        }

        let rate = Int((Double(winCount) / Double(matchCount) * 100).rounded())
        return ActivityStats(matchCount: matchCount, winCount: winCount, winRatePercent: rate)
    }

    // MARK: - Home Battle Stats Cache

    private func loadCachedBattleStats(profileId: UUID) {
        guard let cached = battleStatsCacheStore.loadTodayStats(
            profileId: profileId,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        ) else {
            stats = .unknown
            isStatsLoading = true
            return
        }
        stats = ActivityStats(
            matchCount: cached.matchCount,
            winCount: cached.winCount,
            winRatePercent: cached.winRatePercent
        )
        isStatsLoading = false
    }

    private func refreshHomeStatsInBackground(userId: UUID, force: Bool) {
        let now = Date()
        if !force,
           let lastStatsRefreshAt,
           now.timeIntervalSince(lastStatsRefreshAt) < statsRefreshMinInterval {
            return
        }
        statsRefreshTask?.cancel()
        if !stats.hasResolvedValue {
            isStatsLoading = true
        }
        isStatsRefreshing = true
        statsRefreshTask = Task { [weak self] in
            guard let self else { return }
            defer { self.isStatsRefreshing = false }
            let completed = await activityRepository.loadCompletedMatches(currentUserId: userId)
            guard !Task.isCancelled else { return }
            guard self.userId == userId else { return }
            let freshStats = Self.makeStats(from: completed)
            self.stats = freshStats
            self.completedMatches = completed
            self.isStatsLoading = false
            self.lastStatsRefreshAt = Date()

            let cached = self.battleStatsCacheStore.makeStats(
                profileId: userId,
                profileTimeZoneIdentifier: self.profileTimeZoneIdentifier,
                stats: freshStats,
                now: Date()
            )
            self.battleStatsCacheStore.saveTodayStats(cached)
        }
    }

    private func refreshHomeStatsAwaiting(userId: UUID) async {
        statsRefreshTask?.cancel()
        statsRefreshTask = nil
        if !stats.hasResolvedValue {
            isStatsLoading = true
        }
        isStatsRefreshing = true
        defer { isStatsRefreshing = false }
        let completed = await activityRepository.loadCompletedMatches(currentUserId: userId)
        guard !Task.isCancelled, self.userId == userId else { return }
        let freshStats = Self.makeStats(from: completed)
        stats = freshStats
        completedMatches = completed
        isStatsLoading = false
        lastStatsRefreshAt = Date()
        let cached = battleStatsCacheStore.makeStats(
            profileId: userId,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier,
            stats: freshStats,
            now: Date()
        )
        battleStatsCacheStore.saveTodayStats(cached)
    }

    @discardableResult
    private func loadMarginsFromCache(profileId: UUID) -> Bool {
        guard let cached = marginsCacheStore.load(
            profileId: profileId,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier,
            metricKey: heroMetric.metricType,
            dayCount: marginChartDayCount
        ) else { return false }
        dailyBattleMargins = cached.rows.map {
            DailyBattleMargin(calendarDate: $0.calendarDate, margin: $0.margin)
        }
        battleMarginsSavedAt = cached.savedAt
        return true
    }

    // MARK: - Live Activity sync

    private func syncLiveActivity() {
        guard let firstActive = activeMatches.first else {
            LiveActivityCoordinator.shared.endActivity()
            return
        }

        let currentDay = firstActive.dayPips.first(where: { $0.state == .today })?.dayNumber ?? 1
        LiveActivityCoordinator.shared.startIfNeeded(
            matchId: firstActive.id,
            myDisplayName: myDisplayName,
            opponentDisplayName: firstActive.opponent.displayName,
            metricType: firstActive.metricType,
            durationDays: firstActive.durationDays,
            myTotal: firstActive.myToday,
            opponentTotal: firstActive.theirToday,
            myScore: firstActive.myScore,
            theirScore: firstActive.theirScore,
            dayNumber: currentDay
        )
    }

    // MARK: - Hero HealthKit patch

    private func scheduleHeroHealthKitPatch() {
        guard let userId else { return }
        guard activeMatches.first != nil else { return }
        heroHealthKitPatchTask?.cancel()
        heroHealthKitPatchTask = Task { [weak self] in
            guard let self else { return }
            await self.executeHeroHealthKitPatch(userId: userId)
        }
    }

    private func executeHeroHealthKitPatch(userId: UUID) async {
        guard let firstActive = activeMatches.first else { return }
        let metricType = normalizedHeroMetricType(firstActive.metricType)
        let readStartedAt = Date()
        let value: Int
        do {
            if metricType == "active_calories" {
                value = try await HealthKitService.fetchTodayActiveCalories()
            } else {
                value = try await HealthKitService.fetchTodayStepCount()
            }
        } catch {
            return
        }
        applyHeroHealthKitPatch(
            value: value,
            metricType: metricType,
            readStartedAt: readStartedAt,
            userId: userId
        )
    }

    private func applyHeroHealthKitPatch(
        value: Int,
        metricType: String,
        readStartedAt: Date,
        userId: UUID
    ) {
        guard self.userId == userId else { return }
        heroHealthKitValueByMetric[metricType] = value
        activeMatches = applyHealthKitOverrides(to: activeMatches)
        syncLiveActivity()
        persistFreshHeroSnapshot(profileId: userId)
        let elapsedMs: Int
        if let startedAt = heroLoadStartedAt {
            elapsedMs = max(0, Int(Date().timeIntervalSince(startedAt) * 1000))
        } else {
            elapsedMs = max(0, Int(Date().timeIntervalSince(readStartedAt) * 1000))
        }
        AppLogger.log(
            category: "home_perf",
            level: .info,
            message: "hk_patch",
            userId: userId,
            metadata: [
                "hk_patch_ms": "\(elapsedMs)",
                "metric_type": metricType,
                "value": "\(value)",
            ]
        )
    }

    private func applyHealthKitOverrides(to matches: [HomeActiveMatch]) -> [HomeActiveMatch] {
        matches.map { match in
            let metricType = normalizedHeroMetricType(match.metricType)
            guard let hkValue = heroHealthKitValueByMetric[metricType] else {
                return match
            }
            return HomeActiveMatch(
                id: match.id,
                metricType: match.metricType,
                durationDays: match.durationDays,
                sportLabel: match.sportLabel,
                seriesLabel: match.seriesLabel,
                daysLeft: match.daysLeft,
                finalDayCutoffAt: match.finalDayCutoffAt,
                finalDayScoreEndsAt: match.finalDayScoreEndsAt,
                myToday: hkValue,
                theirToday: match.theirToday,
                myScore: match.myScore,
                theirScore: match.theirScore,
                isWinning: hkValue >= match.theirToday,
                opponent: match.opponent,
                opponentTodayUpdatedAt: match.opponentTodayUpdatedAt,
                dayPips: match.dayPips
            )
        }
    }

    private func runMetricSyncIfEligible() async {
        guard let sessionStore else { return }
        let isSyncEligible = sessionStore.isOnboardingComplete || sessionStore.healthKitPromptCompleted
        guard isSyncEligible else { return }
        await MetricSyncCoordinator.shared.requestSync(trigger: .manual, force: true)
    }

    private func handleHomeDayRolloverIfNeeded(currentLocalDate: String? = nil) {
        let localDate = currentLocalDate ?? snapshotCacheStore.localDateString(
            now: Date(),
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )
        defer { lastHomeProfileLocalDate = localDate }
        guard let previousDate = lastHomeProfileLocalDate, previousDate != localDate else { return }
        heroHealthKitValueByMetric.removeAll()
        guard !activeMatches.isEmpty else { return }
        activeMatches = activeMatches.map { match in
            HomeActiveMatch(
                id: match.id,
                metricType: match.metricType,
                durationDays: match.durationDays,
                sportLabel: match.sportLabel,
                seriesLabel: match.seriesLabel,
                daysLeft: match.daysLeft,
                finalDayCutoffAt: match.finalDayCutoffAt,
                finalDayScoreEndsAt: match.finalDayScoreEndsAt,
                myToday: 0,
                theirToday: 0,
                myScore: match.myScore,
                theirScore: match.theirScore,
                isWinning: true,
                opponent: match.opponent,
                opponentTodayUpdatedAt: nil,
                dayPips: match.dayPips
            )
        }
        syncLiveActivity()
        if let userId {
            persistFreshHeroSnapshot(profileId: userId)
        }
    }

    private func normalizedHeroMetricType(_ metricType: String) -> String {
        metricType == "active_calories" ? "active_calories" : "steps"
    }

    // MARK: - Home Hero Snapshot Cache

    private func loadHeroSnapshotFromDisk(profileId: UUID) {
        let now = Date()
        let localDate = snapshotCacheStore.localDateString(
            now: now,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )
        guard let cached = snapshotCacheStore.loadTodaySnapshot(
            profileId: profileId,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier,
            now: now
        ) else {
            logSnapshotLoaded(
                source: "none",
                profileId: profileId,
                localDate: localDate,
                savedAt: nil
            )
            return
        }

        heroMetric = snapshotCacheStore.heroMetric(from: cached)
        activeMatches = applyHealthKitOverrides(to: snapshotCacheStore.toDomain(cached))
        syncHeroMetricWithActiveMatches()
        isHeroLoading = false
        heroStateResolvedAt = now
        scheduleHeroHealthKitPatch()
        logSnapshotLoaded(
            source: "disk",
            profileId: profileId,
            localDate: cached.localDate,
            savedAt: cached.savedAt
        )
    }

    private func persistFreshHeroSnapshot(profileId: UUID) {
        let snapshot = snapshotCacheStore.makeSnapshot(
            profileId: profileId,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier,
            heroMetric: heroMetric,
            activeMatches: activeMatches,
            now: Date()
        )
        snapshotCacheStore.saveTodaySnapshot(snapshot)
        heroStateResolvedAt = snapshot.savedAt
        logSnapshotSaved(profileId: profileId, localDate: snapshot.localDate)
    }

    private func logSnapshotLoaded(
        source: String,
        profileId: UUID,
        localDate: String,
        savedAt: Date?
    ) {
        let ageSeconds: Int
        if let savedAt {
            ageSeconds = max(0, Int(Date().timeIntervalSince(savedAt)))
        } else {
            ageSeconds = 0
        }
        AppLogger.log(
            category: "home_snapshot",
            level: .info,
            message: "home_snapshot_loaded",
            userId: profileId,
            metadata: [
                "source": source,
                "profile_id": profileId.uuidString,
                "local_date": localDate,
                "age_seconds": "\(ageSeconds)",
                "active_count": "\(activeMatches.count)",
                "hero_metric": heroMetric.rawValue,
                "summary": snapshotCacheStore.makeCompactSummary(
                    activeMatches: activeMatches,
                    heroMetric: heroMetric
                ),
            ]
        )
    }

    private func logSnapshotSaved(profileId: UUID, localDate: String) {
        AppLogger.log(
            category: "home_snapshot",
            level: .info,
            message: "home_snapshot_saved",
            userId: profileId,
            metadata: [
                "profile_id": profileId.uuidString,
                "local_date": localDate,
                "active_count": "\(activeMatches.count)",
                "hero_metric": heroMetric.rawValue,
                "summary": snapshotCacheStore.makeCompactSummary(
                    activeMatches: activeMatches,
                    heroMetric: heroMetric
                ),
            ]
        )
    }

    private func logHomeReturnNoReload(profileId: UUID) {
        AppLogger.log(
            category: "home_snapshot",
            level: .info,
            message: "home_return_no_reload",
            userId: profileId,
            metadata: [
                "reason": "has_memory_state",
                "active_count": "\(activeMatches.count)",
                "hero_metric": heroMetric.rawValue,
                "summary": snapshotCacheStore.makeCompactSummary(
                    activeMatches: activeMatches,
                    heroMetric: heroMetric
                ),
            ]
        )
    }

    func cancelSearch(_ searchId: UUID) async {
        activeActionSearchID = searchId
        defer { activeActionSearchID = nil }

        do {
            try await repository.cancelSearchRequest(searchId: searchId)
            if let userId {
                ProductAnalytics.track(
                    ProductAnalytics.Event.matchmakingCancelled,
                    userId: userId,
                    properties: ["search_request_id": searchId.uuidString]
                )
            }
            await reload(force: true)
        } catch {
            errorMessage = "Could not cancel search right now."
            AppLogger.log(category: "matchmaking", level: .warning, message: "cancel search failed", metadata: ["error": error.localizedDescription])
        }
    }

    func acceptPendingMatch(_ pendingMatch: HomePendingMatch) async {
        guard let userId else { return }
        activeActionPendingMatchID = pendingMatch.id
        defer { activeActionPendingMatchID = nil }

        do {
            try await repository.acceptPendingMatch(matchId: pendingMatch.id, userId: userId)
            ProductAnalytics.track(
                ProductAnalytics.Event.matchAccepted,
                userId: userId,
                properties: [
                    "match_id": pendingMatch.id.uuidString,
                    "opponent_user_id": pendingMatch.opponent.id.uuidString,
                ]
            )
            await reload(force: true)
        } catch {
            errorMessage = "Could not accept challenge right now."
            AppLogger.log(category: "matchmaking", level: .warning, message: "accept challenge failed", metadata: ["error": error.localizedDescription])
        }
    }

    func declinePendingMatch(_ pendingMatch: HomePendingMatch) async {
        activeActionPendingMatchID = pendingMatch.id
        defer { activeActionPendingMatchID = nil }

        let opponentName = pendingMatch.opponent.displayName
        do {
            try await repository.declinePendingMatch(challengeId: pendingMatch.challengeId, matchId: pendingMatch.id)
            if let userId {
                ProductAnalytics.track(
                    ProductAnalytics.Event.matchDeclined,
                    userId: userId,
                    properties: [
                        "match_id": pendingMatch.id.uuidString,
                        "opponent_user_id": pendingMatch.opponent.id.uuidString,
                    ]
                )
            }
            await reload(force: true)
            showDeclineFeedback(opponentName: opponentName)
        } catch {
            errorMessage = "Could not decline challenge right now."
            AppLogger.log(category: "matchmaking", level: .warning, message: "decline challenge failed", metadata: ["error": error.localizedDescription])
        }
    }

}
