//
//  HomeViewModel.swift
//  FitUp
//
//  Slice 3 Home screen state and actions.
//

import Combine
import Foundation
import SwiftUI

/// Slice 7 — holds the next featured match while the opponent handoff overlay runs.
struct HeroOpponentHandoffOverlayModel: Equatable {
    let newMatch: HomeActiveMatch
}

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

    struct BattleSummaryStats: Equatable {
        let totalActive: Int?
        let winningCount: Int?
        let losingCount: Int?
        let closestLead: Int?
        let closestDeficit: Int?
    }

    enum StatusStripState: Equatable {
        case searching(activeSearchCount: Int)
        case invitesWaiting(count: Int)
        case waitingOnOpponent(count: Int)
        case noActiveBattles
        case allBattlesActive(activeCount: Int)
    }

    enum StatusStripPillKind: Equatable {
        case invitesWaiting
        case waitingOnOpponent
        case searching
    }

    struct StatusStripPill: Identifiable, Equatable {
        let kind: StatusStripPillKind
        let count: Int

        var id: String { "\(kind)-\(count)" }
        var label: String {
            switch kind {
            case .invitesWaiting:
                return count == 1 ? "1 invite waiting" : "\(count) invites waiting"
            case .waitingOnOpponent:
                return count == 1 ? "1 waiting" : "\(count) waiting"
            case .searching:
                return count == 1 ? "1 search active" : "\(count) search active"
            }
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
    /// Home hero stack is steps-only in this slice; kept for cache/logging compatibility.
    @Published var heroMetric: HomeBattleHeroCard.HeroMetric = .steps
    /// Normalized 0…1 intraday samples for the energy hero sparkline; `nil` uses mock curves in `HomeEnergyBeamHeroCard`.
    @Published private(set) var heroSparklineUserSeries: [CGFloat]?
    @Published private(set) var heroSparklineOpponentSeries: [CGFloat]?
    /// Last time HealthKit today’s **steps** read succeeded for the hero patch (Slice 6).
    @Published private(set) var heroViewerHealthKitStepsReadAt: Date?
    /// Latest opponent intraday tick `recorded_at` from the last successful sparkline fetch (Slice 6).
    @Published private(set) var heroOpponentIntradayLatestTickAt: Date?
    /// Slice 7: non-nil while the “new opponent” handoff overlay blocks the energy hero card.
    @Published private(set) var heroOpponentHandoff: HeroOpponentHandoffOverlayModel?
    @Published private(set) var isHeroLoading = true
    @Published private(set) var isInitialLoading = true
    /// Full rows for the expandable Past Matches card (warmed by stats refresh; lazy-loaded if empty).
    @Published private(set) var completedMatches: [ActivityCompletedMatch] = []
    @Published private(set) var isLoadingCompletedMatches = false

    var hasAnyContent: Bool {
        !searchingRequests.isEmpty || !activeMatches.isEmpty || !pendingMatches.isEmpty
    }

    var activeStepMatches: [HomeActiveMatch] {
        activeMatches.filter { normalizedHeroMetricType($0.metricType) == HomeBattleHeroCard.HeroMetric.steps.metricType }
    }

    /// Single featured step battle for the home hero, tap target, and comparable-margin summaries (balanced → Battle Score).
    var featuredHomeStepMatch: HomeActiveMatch? {
        HomeActiveMatch.featuredStepMatch(from: activeStepMatches)
    }

    /// Same as ``featuredHomeStepMatch``; kept for call sites that still use the older name.
    var heroPrimaryStepMatch: HomeActiveMatch? { featuredHomeStepMatch }

    private let repository = HomeRepository()
    private let activityRepository = ActivityRepository()
    private let friendshipRepository = FriendshipRepository()
    private let snapshotCacheStore = HomeSnapshotCacheStore()
    private let battleStatsCacheStore = HomeBattleStatsCacheStore()
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
    private var heroSparklineFetchTask: Task<Void, Never>?
    /// Bumps whenever sparkline scheduling changes so stale async results are ignored (Slice 5 + 6).
    private var heroSparklineLoadGeneration: UInt64 = 0
    private var statsRefreshTask: Task<Void, Never>?
    private var heroHealthKitValueByMetric: [String: Int] = [:]
    private var heroLoadStartedAt: Date?
    private var heroStateResolvedAt: Date?
    private var lastStatsRefreshAt: Date?
    private let statsRefreshMinInterval: TimeInterval = 300
    private var lastHomeProfileLocalDate: String?
    private var completedMatchesListTask: Task<Void, Never>?
    private var lastHomeLayoutLogSignature: String?

    var battleSummaryStats: BattleSummaryStats {
        guard !activeMatches.isEmpty else {
            return BattleSummaryStats(
                totalActive: 0,
                winningCount: 0,
                losingCount: 0,
                closestLead: nil,
                closestDeficit: nil
            )
        }
        let margins = activeMatches.map(\.comparableMargin)
        let winningCount = margins.filter { $0 > 0 }.count
        let losingCount = margins.filter { $0 < 0 }.count
        return BattleSummaryStats(
            totalActive: activeMatches.count,
            winningCount: winningCount,
            losingCount: losingCount,
            closestLead: margins.filter { $0 > 0 }.min(),
            closestDeficit: margins.filter { $0 < 0 }.max()
        )
    }

    var receivedPendingMatches: [HomePendingMatch] {
        pendingMatches.filter { !$0.hasAcceptedByMe }
    }

    /// Oldest invite the current user still needs to act on, used by the home status
    /// strip to deep-link directly into the match detail when the strip is tapped.
    var oldestReceivedPendingMatch: HomePendingMatch? {
        receivedPendingMatches.min { $0.createdAt < $1.createdAt }
    }

    var sentPendingMatchesWaitingOnOpponent: [HomePendingMatch] {
        pendingMatches.filter { $0.hasAcceptedByMe && !$0.hasAcceptedByOpponent }
    }

    var activeSearchCount: Int { searchingRequests.count }
    var invitesWaitingCount: Int { receivedPendingMatches.count }
    var waitingOnOpponentCount: Int { sentPendingMatchesWaitingOnOpponent.count }
    var activeBattleCount: Int { activeMatches.count }

    var heroSummaryText: String? {
        guard let total = battleSummaryStats.totalActive, total > 0 else { return nil }
        let wins = battleSummaryStats.winningCount ?? 0
        let losses = battleSummaryStats.losingCount ?? 0
        let margins = activeMatches.map(\.comparableMargin)
        let ties = margins.filter { $0 == 0 }.count
        let hasBalanced = activeMatches.contains(where: \.isBalancedStepsBattle)

        if let closestLead = battleSummaryStats.closestLead {
            let leadSuffix = hasBalanced
                ? " · Closest lead (Battle Score): +\(closestLead.formatted())"
                : " · Closest: +\(closestLead.formatted()) steps"
            return "Ahead in \(wins) / \(total) matches\(leadSuffix)"
        }

        if wins == 0, losses > 0 {
            return "Trailing in \(losses) / \(total) matches"
        }
        if ties == total {
            return "All \(total) matches tied right now"
        }
        return "Ahead in \(wins) / \(total) matches"
    }

    var statusStripState: StatusStripState {
        // Invites waiting are action-required, so they take priority over a passive
        // matchmaking search. This also keeps the blinking/tappable strip in HomeView
        // semantically aligned with its message.
        if invitesWaitingCount > 0 {
            return .invitesWaiting(count: invitesWaitingCount)
        }

        if activeSearchCount > 0 {
            return .searching(activeSearchCount: activeSearchCount)
        }

        if waitingOnOpponentCount > 0 {
            return .waitingOnOpponent(count: waitingOnOpponentCount)
        }

        if activeBattleCount == 0 {
            return .noActiveBattles
        }

        return .allBattlesActive(activeCount: activeBattleCount)
    }

    var statusStripMessage: String {
        switch statusStripState {
        case .searching:
            return "Searching for random opponent..."
        case let .invitesWaiting(count):
            return count == 1 ? "1 invite waiting" : "\(count) invites waiting"
        case let .waitingOnOpponent(count):
            return count == 1 ? "Waiting on opponent" : "Waiting on opponents"
        case .noActiveBattles:
            return "No active battles — find one now"
        case let .allBattlesActive(activeCount):
            if activeCount == 1 {
                return "You’re active in 1 battle"
            }
            return "You’re active in \(activeCount) battles"
        }
    }

    var statusStripSecondaryPills: [StatusStripPill] {
        let primaryKind: StatusStripPillKind? = switch statusStripState {
        case .searching:
            .searching
        case .invitesWaiting:
            .invitesWaiting
        case .waitingOnOpponent(_):
            .waitingOnOpponent
        case .noActiveBattles, .allBattlesActive:
            nil
        }

        let candidates: [(StatusStripPillKind, Int)] = [
            (.invitesWaiting, invitesWaitingCount),
            (.waitingOnOpponent, waitingOnOpponentCount),
            (.searching, activeSearchCount)
        ]

        return candidates.compactMap { kind, count in
            guard count > 0 else { return nil }
            guard primaryKind != kind else { return nil }
            return StatusStripPill(kind: kind, count: count)
        }
    }

    var sortedActiveMatchesForHome: [HomeActiveMatch] {
        activeMatches.sorted { lhs, rhs in
            let lhsMargin = lhs.comparableMargin
            let rhsMargin = rhs.comparableMargin

            let lhsCategory = sortCategory(for: lhsMargin)
            let rhsCategory = sortCategory(for: rhsMargin)
            if lhsCategory != rhsCategory {
                return lhsCategory < rhsCategory
            }

            if lhsMargin != rhsMargin {
                if lhsMargin < 0 && rhsMargin < 0 {
                    return lhsMargin > rhsMargin
                }
                if lhsMargin > 0 && rhsMargin > 0 {
                    return lhsMargin < rhsMargin
                }
            }

            let lhsTs = lhs.opponentTodayUpdatedAt?.timeIntervalSince1970
            let rhsTs = rhs.opponentTodayUpdatedAt?.timeIntervalSince1970
            if lhsTs != rhsTs {
                switch (lhsTs, rhsTs) {
                case let (l?, r?):
                    return l < r
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    break
                }
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

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
            isHeroLoading = true
            isInitialLoading = true
            stats = .unknown
            isStatsLoading = false
            isStatsRefreshing = false
            heroHealthKitValueByMetric = [:]
            heroSparklineUserSeries = nil
            heroSparklineOpponentSeries = nil
            heroViewerHealthKitStepsReadAt = nil
            heroOpponentIntradayLatestTickAt = nil
            heroSparklineLoadGeneration &+= 1
            heroOpponentHandoff = nil
            heroLoadStartedAt = Date()
            heroStateResolvedAt = nil
            lastStatsRefreshAt = nil
            lastHomeProfileLocalDate = currentLocalDate
            completedMatches = []
            completedMatchesListTask?.cancel()
            completedMatchesListTask = nil
            lastHomeLayoutLogSignature = nil
            loadHeroSnapshotFromDisk(profileId: profileId)
            loadCachedBattleStats(profileId: profileId)
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

    /// Resumes background polling when Home becomes visible again (e.g. after `stop()` ran under a full-screen cover).
    func resumeHomeLivePipeline(profile: Profile?, sessionStore: SessionStore) {
        guard let profileId = profile?.id, profileId == userId else { return }
        self.sessionStore = sessionStore
        startPollingIfNeeded()
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
        heroSparklineFetchTask?.cancel()
        heroSparklineFetchTask = nil
        heroSparklineLoadGeneration &+= 1
        heroOpponentHandoff = nil
        statsRefreshTask?.cancel()
        statsRefreshTask = nil
        completedMatchesListTask?.cancel()
        completedMatchesListTask = nil
        matchFoundCelebration = nil
        matchActiveCelebration = nil
        deferredMatchActiveCelebration = nil
        declineFeedbackOpponentName = nil
        pollingTask?.cancel()
        pollingTask = nil
        lastHomeProfileLocalDate = nil
        lastHomeLayoutLogSignature = nil
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

        let baselineFloor = max(3000, ReadinessGoals.loadFromUserDefaults().stepsGoal)

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
        Task { await self.refreshFeaturedOpponentLatestTickFromBatch(userId: userId) }
        await MatchRepository().syncBalancedBaselineFloorsIfNeeded(userId: userId, floorSteps: baselineFloor)

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
        logHomeLayoutSnapshotIfNeeded(userId: userId)

        if forceRefresh {
            await refreshHomeStatsAwaiting(userId: userId)
            await executeHeroHealthKitPatch(userId: userId)
        } else {
            refreshHomeStatsInBackground(userId: userId, force: true)
            scheduleHeroHealthKitPatch()
        }
        evaluateHeroOpponentHandoffIfNeeded(userId: userId)
        return true
    }

    private func sortCategory(for margin: Int) -> Int {
        if margin < 0 { return 0 }
        if margin == 0 { return 1 }
        return 2
    }

    func syncHeroMetricWithActiveMatches() {
        heroMetric = .steps
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
            let map = try await friendshipRepository.fetchPeerProfileSummaries(profileIds: [peer])
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
            let map = try await friendshipRepository.fetchPeerProfileSummaries(profileIds: [peerId])
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

    // MARK: - Energy beam hero sparklines (Slice 5)

    private func scheduleHeroSparklineRefresh() {
        heroSparklineFetchTask?.cancel()

        guard let match = featuredHomeStepMatch else {
            heroSparklineLoadGeneration &+= 1
            heroSparklineUserSeries = nil
            heroSparklineOpponentSeries = nil
            heroOpponentIntradayLatestTickAt = nil
            return
        }
        guard normalizedHeroMetricType(match.metricType) == "steps" else {
            heroSparklineLoadGeneration &+= 1
            heroSparklineUserSeries = nil
            heroSparklineOpponentSeries = nil
            heroOpponentIntradayLatestTickAt = nil
            return
        }

        heroSparklineLoadGeneration &+= 1
        let generation = heroSparklineLoadGeneration
        let matchId = match.id
        let tzId = profileTimeZoneIdentifier

        heroSparklineFetchTask = Task { [weak self] in
            guard let self else { return }
            let result = await HomeHeroSparklineLoader.loadSparklineSeries(
                profileTimeZoneIdentifier: tzId,
                match: match
            )
            guard !Task.isCancelled else { return }
            guard self.heroSparklineLoadGeneration == generation else { return }
            guard self.featuredHomeStepMatch?.id == matchId else { return }
            self.heroSparklineUserSeries = result.userSeries
            self.heroSparklineOpponentSeries = result.opponentSeries
            self.heroOpponentIntradayLatestTickAt = result.opponentLatestTickRecordedAt
        }
    }

    /// Slice 8: one RPC for latest opponent tick times; primes ``heroOpponentIntradayLatestTickAt`` before the heavier sparkline fetch.
    private func refreshFeaturedOpponentLatestTickFromBatch(userId: UUID) async {
        guard self.userId == userId else { return }
        guard let match = featuredHomeStepMatch else { return }
        guard normalizedHeroMetricType(match.metricType) == "steps" else { return }
        let opponentId = match.opponent.id
        let featuredId = match.id
        let tz = profileTimeZoneIdentifier

        do {
            let rows = try await UserIntradayStepTicksRepository().fetchLatestOpponentTicksForActiveMatches(
                calendarDate: Date(),
                viewerTimezoneIdentifier: tz
            )
            guard self.userId == userId else { return }
            guard let row = rows.first(where: { $0.opponentProfileId == opponentId }) else { return }
            guard featuredHomeStepMatch?.id == featuredId else { return }
            if let existing = heroOpponentIntradayLatestTickAt {
                heroOpponentIntradayLatestTickAt = max(existing, row.recordedAt)
            } else {
                heroOpponentIntradayLatestTickAt = row.recordedAt
            }
        } catch {
            // RPC may be absent until manual SQL is applied; sparkline path still backfills.
        }
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
            scheduleHeroSparklineRefresh()
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
        if metricType == "steps" {
            heroViewerHealthKitStepsReadAt = Date()
        }
        scheduleHeroSparklineRefresh()
    }

    private func applyHealthKitOverrides(to matches: [HomeActiveMatch]) -> [HomeActiveMatch] {
        matches.map { match in
            let metricType = normalizedHeroMetricType(match.metricType)
            guard let hkValue = heroHealthKitValueByMetric[metricType] else {
                return match
            }
            let winning: Bool
            if match.isBalancedStepsBattle {
                let myBS = HomeActiveMatch.battleScore(
                    actualSteps: hkValue,
                    myBaseline: match.myBaselineSteps,
                    theirBaseline: match.theirBaselineSteps
                )
                winning = myBS >= match.theirBattleScore
            } else {
                winning = hkValue >= match.theirToday
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
                isWinning: winning,
                opponent: match.opponent,
                opponentTodayUpdatedAt: match.opponentTodayUpdatedAt,
                dayPips: match.dayPips,
                scoringMode: match.scoringMode,
                difficulty: match.difficulty,
                myBaselineSteps: match.myBaselineSteps,
                theirBaselineSteps: match.theirBaselineSteps
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
        heroSparklineUserSeries = nil
        heroSparklineOpponentSeries = nil
        heroViewerHealthKitStepsReadAt = nil
        heroOpponentIntradayLatestTickAt = nil
        heroSparklineLoadGeneration &+= 1
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
                dayPips: match.dayPips,
                scoringMode: match.scoringMode,
                difficulty: match.difficulty,
                myBaselineSteps: match.myBaselineSteps,
                theirBaselineSteps: match.theirBaselineSteps
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

    private func logHomeLayoutSnapshotIfNeeded(userId: UUID) {
        let summary = battleSummaryStats
        let signature = [
            "wins:\(summary.winningCount ?? -1)",
            "total:\(summary.totalActive ?? -1)",
            "lead:\(summary.closestLead ?? -1)",
            "deficit:\(summary.closestDeficit ?? -1)",
            "strip:\(statusStripMessage)",
            "active:\(sortedActiveMatchesForHome.count)",
            "invites_waiting:\(invitesWaitingCount)",
            "waiting_on_opponent:\(waitingOnOpponentCount)",
            "searching:\(activeSearchCount)"
        ].joined(separator: "|")
        guard signature != lastHomeLayoutLogSignature else { return }
        lastHomeLayoutLogSignature = signature

        AppLogger.log(
            category: "home_layout",
            level: .debug,
            message: "slice1_home_sections",
            userId: userId,
            metadata: [
                "hero_summary": heroSummaryText ?? "none",
                "winning_count": "\(summary.winningCount ?? 0)",
                "losing_count": "\(summary.losingCount ?? 0)",
                "total_active": "\(summary.totalActive ?? 0)",
                "closest_lead": summary.closestLead.map(String.init) ?? "none",
                "closest_deficit": summary.closestDeficit.map(String.init) ?? "none",
                "status_strip": statusStripMessage,
                "active_rows": "\(sortedActiveMatchesForHome.count)",
                "searching_count": "\(activeSearchCount)",
                "invites_waiting_count": "\(invitesWaitingCount)",
                "waiting_on_opponent_count": "\(waitingOnOpponentCount)",
                "active_battle_count": "\(activeBattleCount)"
            ]
        )
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

        heroMetric = .steps
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

    // MARK: - Featured opponent handoff (Slice 7)

    private enum FeaturedOpponentHandoffStore {
        private static func key(userId: UUID) -> String {
            "fitup.heroHandoff.lastFeaturedOpponentProfile.\(userId.uuidString)"
        }

        static func lastOpponentProfileId(userId: UUID) -> UUID? {
            guard let s = UserDefaults.standard.string(forKey: key(userId: userId)),
                  let u = UUID(uuidString: s) else { return nil }
            return u
        }

        static func saveLastOpponent(_ opponentProfileId: UUID, userId: UUID) {
            UserDefaults.standard.set(opponentProfileId.uuidString, forKey: key(userId: userId))
        }

        static func clear(userId: UUID) {
            UserDefaults.standard.removeObject(forKey: key(userId: userId))
        }
    }

    private func evaluateHeroOpponentHandoffIfNeeded(userId: UUID) {
        guard HomeFeaturedOpponentHandoffFeature.isEnabled else { return }
        guard self.userId == userId else { return }
        guard !isHeroLoading else { return }

        if let handoff = heroOpponentHandoff {
            if let cur = featuredHomeStepMatch,
               cur.opponent.id == handoff.newMatch.opponent.id,
               cur.id == handoff.newMatch.id {
                return
            }
            heroOpponentHandoff = nil
        }

        guard let match = featuredHomeStepMatch else {
            FeaturedOpponentHandoffStore.clear(userId: userId)
            return
        }
        guard normalizedHeroMetricType(match.metricType) == "steps" else { return }

        let newOppId = match.opponent.id
        if let previous = FeaturedOpponentHandoffStore.lastOpponentProfileId(userId: userId), previous != newOppId {
            heroOpponentHandoff = HeroOpponentHandoffOverlayModel(newMatch: match)
        } else {
            FeaturedOpponentHandoffStore.saveLastOpponent(newOppId, userId: userId)
        }
    }

    func completeHeroOpponentHandoff() {
        guard let userId else {
            heroOpponentHandoff = nil
            return
        }
        guard let model = heroOpponentHandoff else { return }
        FeaturedOpponentHandoffStore.saveLastOpponent(model.newMatch.opponent.id, userId: userId)
        heroOpponentHandoff = nil
        scheduleHeroSparklineRefresh()
    }

    #if DEBUG
    /// DEBUG only — plays Slice 7 overlay using the current featured opponent (no opponent change required).
    func debugPreviewHeroOpponentHandoff() {
        guard heroOpponentHandoff == nil else { return }
        guard let m = featuredHomeStepMatch else { return }
        guard normalizedHeroMetricType(m.metricType) == "steps" else { return }
        heroOpponentHandoff = HeroOpponentHandoffOverlayModel(newMatch: m)
    }
    #endif

}
