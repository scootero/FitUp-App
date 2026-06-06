//
//  HomeViewModel.swift
//  FitUp
//
//  Slice 3 Home screen state and actions.
//

import Combine
import Foundation
import HealthKit
import SwiftUI

/// Slice 7 — holds the outgoing + incoming featured matches while the handoff overlay runs.
struct HeroOpponentHandoffOverlayModel: Equatable {
    /// Hero card shown under the overlay until blackout completes.
    let previousMatch: HomeActiveMatch?
    /// Featured match to show after `completeHeroOpponentHandoff()` (beam intro runs then).
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
    /// Time-stamped intraday samples for the hero day timeline (scrub + accurate *Now placement).
    @Published private(set) var heroSparklineDomain: HomeHeroSparklineDomain?
    /// Last time HealthKit today’s **steps** read succeeded for the hero patch (Slice 6).
    @Published private(set) var heroViewerHealthKitStepsReadAt: Date?
    /// Latest opponent intraday tick `recorded_at` from the last successful sparkline fetch (Slice 6).
    @Published private(set) var heroOpponentIntradayLatestTickAt: Date?
    /// Slice 7: non-nil while the “new opponent” handoff overlay blocks the energy hero card.
    @Published private(set) var heroOpponentHandoff: HeroOpponentHandoffOverlayModel?
    /// User-selected step battle for the energy hero; session-only (cleared on ViewModel recreation).
    @Published private(set) var selectedHeroStepMatchId: UUID?
    @Published private(set) var isHeroLoading = true
    @Published private(set) var isInitialLoading = true
    /// Full rows for the expandable Past Matches card (warmed by stats refresh; lazy-loaded if empty).
    @Published private(set) var completedMatches: [ActivityCompletedMatch] = []
    @Published private(set) var isLoadingCompletedMatches = false
    /// Global weekly steps rank (Ranks tab RPC); nil until cache or background fetch resolves.
    @Published private(set) var globalLeaderboardRank: Int?

    var globalLeaderboardRankDisplay: String {
        guard let globalLeaderboardRank else { return "--" }
        return "#\(globalLeaderboardRank)"
    }

    var hasAnyContent: Bool {
        !searchingRequests.isEmpty || !activeMatches.isEmpty || !pendingMatches.isEmpty
    }

    var activeStepMatches: [HomeActiveMatch] {
        activeMatches.filter { normalizedHeroMetricType($0.metricType) == HomeBattleHeroCard.HeroMetric.steps.metricType }
    }

    /// Steps battles shown on Home (excludes calories).
    var activeStepMatchesForHomeUX: [HomeActiveMatch] {
        activeStepMatches.filter(\.isStepsBattleForHomeUX)
    }

    /// Live step battles eligible for the energy-beam hero (excludes pending finalization).
    var activeStepMatchesEligibleForHero: [HomeActiveMatch] {
        activeStepMatchesForHomeUX.filter { !$0.isEffectivelyOverForHomeUX }
    }

    var hasOnlyPendingFinalizationStepBattles: Bool {
        !activeStepMatchesForHomeUX.isEmpty && activeStepMatchesEligibleForHero.isEmpty
    }

    /// Active step battles for list UI (includes pending finalization); live rows first.
    var sortedActiveMatchesForHome: [HomeActiveMatch] {
        activeStepMatchesForHomeUX.sorted { lhs, rhs in
            if lhs.isEffectivelyOverForHomeUX != rhs.isEffectivelyOverForHomeUX {
                return !lhs.isEffectivelyOverForHomeUX && rhs.isEffectivelyOverForHomeUX
            }
            return sortActiveStepMatches(lhs, rhs)
        }
    }

    /// Opponent picker under hero — live step battles only.
    var sortedActiveStepMatchesForHero: [HomeActiveMatch] {
        activeStepMatchesEligibleForHero.sorted(by: sortActiveStepMatches)
    }

    /// Single featured step battle for the home hero (never pending-finalization).
    var featuredHomeStepMatch: HomeActiveMatch? {
        let eligible = activeStepMatchesEligibleForHero
        guard !eligible.isEmpty else { return nil }
        if let selectedHeroStepMatchId,
           let selected = eligible.first(where: { $0.id == selectedHeroStepMatchId }) {
            return selected
        }
        return HomeActiveMatch.featuredStepMatch(from: eligible)
    }

    /// Same as ``featuredHomeStepMatch``; kept for call sites that still use the older name.
    var heroPrimaryStepMatch: HomeActiveMatch? { featuredHomeStepMatch }

    private let repository = HomeRepository()
    private let activityRepository = ActivityRepository()
    private let friendshipRepository = FriendshipRepository()
    private let snapshotCacheStore = HomeSnapshotCacheStore()
    private let battleStatsCacheStore = HomeBattleStatsCacheStore()
    private let leaderboardSnapshotCache = LeaderboardSnapshotCacheStore()
    private let leaderboardRepository = LeaderboardRepository()
    private var leaderboardRankRefreshTask: Task<Void, Never>?
    private var userId: UUID?
    private var profileTimeZoneIdentifier: String?
    private var myDisplayName: String = "You"
    private var shouldShowOnboardingPlaceholder = false
    private var pollingTask: Task<Void, Never>?
    private let pollingIntervalNs: UInt64 = 90_000_000_000
    private var isReloadInFlight = false
    private var hasPendingForcedReload = false
    private var hasPendingLightReload = false
    private struct PushRefreshDebounceKey: Hashable {
        let eventType: String
        let matchId: UUID?
    }
    private var lastPushRefreshCompletedAt: [PushRefreshDebounceKey: Date] = [:]
    private let pushReloadDebounceInterval: TimeInterval = 10
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
    private var heroHealthKitPatchCompletedAt: Date?
    private var heroHealthKitPatchCompletedMetric: String?
    private var heroHealthKitPatchCompletedValue: Int?
    private var heroLoadStartedAt: Date?
    private var heroStateResolvedAt: Date?
    private var lastStatsRefreshAt: Date?
    private let statsRefreshMinInterval: TimeInterval = 300
    private var lastHomeProfileLocalDate: String?
    private var completedMatchesListTask: Task<Void, Never>?
    private var lastHomeLayoutLogSignature: String?
    private var lastLoggedSnapshotSummary: String?
    private var lastHeroSnapshotLoadSource: String = "unknown"

    /// Source of steps shown on the home hero (for HK diagnostics).
    var heroDisplayedStepsSource: String {
        if heroHealthKitPatchCompletedAt != nil,
           heroHealthKitValueByMetric["steps"] != nil {
            return "fresh_hk"
        }
        if heroHealthKitValueByMetric["steps"] != nil {
            return "hk_patch_cache"
        }
        switch lastHeroSnapshotLoadSource {
        case "disk": return "disk_snapshot"
        case "none": return "backend"
        default: return lastHeroSnapshotLoadSource
        }
    }

    var battleSummaryStats: BattleSummaryStats {
        let liveStepBattles = activeStepMatchesForHomeUX.filter { !$0.isEffectivelyOverForHomeUX }
        guard !liveStepBattles.isEmpty else {
            return BattleSummaryStats(
                totalActive: 0,
                winningCount: 0,
                losingCount: 0,
                closestLead: nil,
                closestDeficit: nil
            )
        }
        let matchMargins = liveStepBattles.map(\.matchScoreMargin)
        let winningCount = matchMargins.filter { $0 > 0 }.count
        let losingCount = matchMargins.filter { $0 < 0 }.count
        return BattleSummaryStats(
            totalActive: liveStepBattles.count,
            winningCount: winningCount,
            losingCount: losingCount,
            closestLead: matchMargins.filter { $0 > 0 }.min(),
            closestDeficit: matchMargins.filter { $0 < 0 }.max()
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

    /// True when hero state was resolved from disk or network and can be shown without a cold-load skeleton.
    var hasMemoryState: Bool {
        heroStateResolvedAt != nil || !activeMatches.isEmpty
    }

    var heroSummaryText: String? {
        guard let total = battleSummaryStats.totalActive, total > 0 else { return nil }
        let wins = battleSummaryStats.winningCount ?? 0
        let losses = battleSummaryStats.losingCount ?? 0
        let liveStepBattles = activeStepMatchesForHomeUX.filter { !$0.isEffectivelyOverForHomeUX }
        let ties = liveStepBattles.filter { $0.matchScoreMargin == 0 }.count

        if wins == 0, losses > 0 {
            return "Losing \(losses) of \(total) battles"
        }
        if ties == total {
            return "All \(total) battles tied on match score"
        }
        if wins == total {
            return "Winning all \(total) battles"
        }
        return "Winning \(wins) of \(total) battles"
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
            return "Waiting for another player…"
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

    /// Closest losing battle for Home stat-card deep link (smallest match-score deficit first).
    var primaryLosingMatchForHome: HomeActiveMatch? {
        activeStepMatchesEligibleForHero
            .filter { $0.matchScoreMargin < 0 }
            .max(by: { $0.matchScoreMargin < $1.matchScoreMargin })
    }

    /// Closest winning battle for Home stat-card deep link (smallest match-score cushion first).
    var primaryWinningMatchForHome: HomeActiveMatch? {
        activeStepMatchesEligibleForHero
            .filter { $0.matchScoreMargin > 0 }
            .min(by: { $0.matchScoreMargin < $1.matchScoreMargin })
    }

    private func sortActiveStepMatches(_ lhs: HomeActiveMatch, _ rhs: HomeActiveMatch) -> Bool {
        let lhsMargin = lhs.matchScoreMargin
        let rhsMargin = rhs.matchScoreMargin

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

    func start(profile: Profile?, showOnboardingSearching: Bool, sessionStore: SessionStore) {
        guard let profileId = profile?.id else { return }
        self.sessionStore = sessionStore
        myDisplayName = profile?.displayName ?? "You"
        profileTimeZoneIdentifier = profile?.timezone
        let currentLocalDate = snapshotCacheStore.localDateString(
            now: Date(),
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )

        _ = applyPersistedProfileLocalDayChangeIfNeeded(
            profileId: profileId,
            currentLocalDate: currentLocalDate,
            knownMatchIds: []
        )
        lastHomeProfileLocalDate = currentLocalDate

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
            heroHealthKitPatchCompletedAt = nil
            heroHealthKitPatchCompletedMetric = nil
            heroHealthKitPatchCompletedValue = nil
            heroSparklineUserSeries = nil
            heroSparklineOpponentSeries = nil
            heroSparklineDomain = nil
            heroViewerHealthKitStepsReadAt = nil
            heroOpponentIntradayLatestTickAt = nil
            heroSparklineLoadGeneration &+= 1
            heroOpponentHandoff = nil
            selectedHeroStepMatchId = nil
            heroLoadStartedAt = Date()
            heroStateResolvedAt = nil
            lastStatsRefreshAt = nil
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

    /// Resumes background polling when Home becomes visible again (e.g. after tab switch or full-screen cover).
    func resumeHomeLivePipeline(profile: Profile?, sessionStore: SessionStore) {
        guard let profileId = profile?.id, profileId == userId else { return }
        self.sessionStore = sessionStore
        myDisplayName = profile?.displayName ?? "You"
        profileTimeZoneIdentifier = profile?.timezone
        startPollingIfNeeded()
    }

    /// Pauses polling and in-flight hero tasks when Home leaves the screen; keeps in-memory hero state.
    func pauseLivePipeline() {
        heroHealthKitPatchTask?.cancel()
        heroHealthKitPatchTask = nil
        heroSparklineFetchTask?.cancel()
        heroSparklineFetchTask = nil
        heroSparklineLoadGeneration &+= 1
        statsRefreshTask?.cancel()
        statsRefreshTask = nil
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Soft refresh when returning to foreground with warm hero state.
    func refreshOnForeground() async {
        guard userId != nil else { return }
        await reload(force: false)
        if !shouldSkipSchedulingHeroHealthKitPatch() {
            scheduleHeroHealthKitPatch()
        }
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
        leaderboardRankRefreshTask?.cancel()
        leaderboardRankRefreshTask = nil
        globalLeaderboardRank = nil
        matchFoundCelebration = nil
        matchActiveCelebration = nil
        deferredMatchActiveCelebration = nil
        declineFeedbackOpponentName = nil
        pollingTask?.cancel()
        pollingTask = nil
        hasPendingLightReload = false
        lastPushRefreshCompletedAt = [:]
        lastHomeProfileLocalDate = nil
        lastHomeLayoutLogSignature = nil
    }

    func reload(force: Bool) async {
        guard let userId else { return }
        if isReloadInFlight {
            if force {
                hasPendingForcedReload = true
            } else {
                hasPendingLightReload = true
            }
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
            if shouldForceRefresh {
                hasPendingForcedReload = false
            } else {
                hasPendingLightReload = false
            }
            let finished = await performReload(userId: userId, forceRefresh: shouldForceRefresh)
            if !finished { return }
        } while hasPendingForcedReload || hasPendingLightReload
    }

    /// Light Home reload after a match-lifecycle push (`match_active`, `match_found`). Skips HealthKit→Supabase metric sync.
    func reloadFromMatchPush(context: HomeLightRefreshContext) async {
        let debounceKey = PushRefreshDebounceKey(eventType: context.eventType, matchId: context.matchId)
        var metadata: [String: String] = [
            "event_type": context.eventType,
            "match_id": context.matchId?.uuidString ?? "nil",
        ]

        AppLogger.log(
            category: "home_snapshot",
            level: .debug,
            message: "home_push_refresh_requested",
            userId: userId,
            metadata: metadata
        )

        if let lastCompleted = lastPushRefreshCompletedAt[debounceKey],
           Date().timeIntervalSince(lastCompleted) < pushReloadDebounceInterval {
            metadata["seconds_since_last"] = String(format: "%.1f", Date().timeIntervalSince(lastCompleted))
            AppLogger.log(
                category: "home_snapshot",
                level: .debug,
                message: "home_push_refresh_skipped_debounce",
                userId: userId,
                metadata: metadata
            )
            return
        }

        if isReloadInFlight {
            hasPendingLightReload = true
            AppLogger.log(
                category: "home_snapshot",
                level: .debug,
                message: "home_push_refresh_coalesced_in_flight",
                userId: userId,
                metadata: metadata
            )
            return
        }

        await reload(force: false)

        lastPushRefreshCompletedAt[debounceKey] = Date()

        metadata["active_match_count"] = "\(activeMatches.count)"
        metadata["pending_match_count"] = "\(pendingMatches.count)"
        metadata["selected_hero_match_id"] = selectedHeroStepMatchId?.uuidString ?? "nil"
        AppLogger.log(
            category: "home_snapshot",
            level: .debug,
            message: "home_push_refresh_completed",
            userId: userId,
            metadata: metadata
        )
    }

    private func performReload(userId: UUID, forceRefresh: Bool) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        let didRollover = handleHomeDayRolloverIfNeeded()
        let effectiveForce = forceRefresh || didRollover

        if effectiveForce {
            await runMetricSyncIfEligible()
        }
        if didRollover {
            AppLogger.log(
                category: "home_snapshot",
                level: .debug,
                message: "home_forced_reload_after_rollover",
                userId: userId
            )
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
        reconcileSelectedHeroStepMatch(userId: userId)
        applyLeaderboardRankFromCache(profileId: userId)
        scheduleGlobalLeaderboardRankRefresh(profileId: userId)
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

        if effectiveForce {
            await refreshHomeStatsAwaiting(userId: userId)
            await executeHeroHealthKitPatch(userId: userId)
        } else {
            refreshHomeStatsInBackground(userId: userId, force: true)
            if !shouldSkipSchedulingHeroHealthKitPatch() {
                scheduleHeroHealthKitPatch()
            }
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
        guard let firstActive = activeStepMatchesForHomeUX.first(where: { !$0.isEffectivelyOverForHomeUX }) else {
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

    private func clearHeroSparklineSlotsForMatchSwitch() {
        heroSparklineFetchTask?.cancel()
        heroSparklineLoadGeneration &+= 1
        heroSparklineUserSeries = nil
        heroSparklineOpponentSeries = nil
        heroSparklineDomain = nil
        heroOpponentIntradayLatestTickAt = nil
    }

    private func scheduleHeroSparklineRefresh() {
        heroSparklineFetchTask?.cancel()

        guard let match = featuredHomeStepMatch else {
            heroSparklineLoadGeneration &+= 1
            heroSparklineUserSeries = nil
            heroSparklineOpponentSeries = nil
            heroSparklineDomain = nil
            heroOpponentIntradayLatestTickAt = nil
            return
        }
        guard normalizedHeroMetricType(match.metricType) == "steps" else {
            heroSparklineLoadGeneration &+= 1
            heroSparklineUserSeries = nil
            heroSparklineOpponentSeries = nil
            heroSparklineDomain = nil
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
            self.heroSparklineDomain = result.domain
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
            let env = await MainActor.run {
                HealthKitEnvironmentSnapshot.captureStored(scenePhaseRaw: "active")
            }
            var meta = env.metadata
            meta["displayed_steps_source"] = heroDisplayedStepsSource
            meta["metric_type"] = metricType
            if let hk = error as? HKError {
                meta["hk_error_code"] = "\(hk.code.rawValue)"
            } else {
                meta["hk_error_code"] = "n/a"
            }
            meta["error"] = error.localizedDescription
            HealthKitDiagnosticsStore.homeHeroStepsSource = heroDisplayedStepsSource
            AppLogger.log(
                category: "home_perf",
                level: .warning,
                message: "hk_patch_failed",
                userId: userId,
                metadata: meta
            )
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

        if metricType == "active_calories",
           let featured = featuredHomeStepMatch,
           normalizedHeroMetricType(featured.metricType) == "steps" {
            heroHealthKitValueByMetric[metricType] = value
            return
        }

        if heroHealthKitValueByMetric[metricType] == value {
            AppLogger.log(
                category: "home_perf",
                level: .debug,
                message: "hk_patch_skipped",
                userId: userId,
                metadata: [
                    "reason": "unchanged_value",
                    "metric_type": metricType,
                    "value": "\(value)",
                ]
            )
            return
        }

        heroHealthKitValueByMetric[metricType] = value
        activeMatches = applyHealthKitOverrides(to: activeMatches)
        syncLiveActivity()
        persistFreshHeroSnapshot(profileId: userId)
        heroHealthKitPatchCompletedAt = Date()
        heroHealthKitPatchCompletedMetric = metricType
        heroHealthKitPatchCompletedValue = value
        let elapsedMs: Int
        if let startedAt = heroLoadStartedAt {
            elapsedMs = max(0, Int(Date().timeIntervalSince(startedAt) * 1000))
        } else {
            elapsedMs = max(0, Int(Date().timeIntervalSince(readStartedAt) * 1000))
        }
        HealthKitDiagnosticsStore.homeHeroStepsSource = "fresh_hk"
        AppLogger.log(
            category: "home_perf",
            level: .debug,
            message: "hk_patch",
            userId: userId,
            metadata: [
                "hk_patch_ms": "\(elapsedMs)",
                "metric_type": metricType,
                "value": "\(value)",
                "displayed_steps_source": "fresh_hk",
            ]
        )
        if metricType == "steps" {
            heroViewerHealthKitStepsReadAt = Date()
        }
        scheduleHeroSparklineRefresh()
    }

    private func shouldSkipSchedulingHeroHealthKitPatch() -> Bool {
        guard let completedAt = heroHealthKitPatchCompletedAt,
              let metric = heroHealthKitPatchCompletedMetric,
              let completedValue = heroHealthKitPatchCompletedValue,
              Date().timeIntervalSince(completedAt) < 2 else {
            return false
        }
        guard let firstActive = activeMatches.first else { return false }
        let expectedMetric = normalizedHeroMetricType(firstActive.metricType)
        return metric == expectedMetric && heroHealthKitValueByMetric[expectedMetric] == completedValue
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
                theirBaselineSteps: match.theirBaselineSteps,
                battleDateRangeLabel: match.battleDateRangeLabel,
                battleEndDateKey: match.battleEndDateKey,
                profileTodayKey: match.profileTodayKey,
                hasUnfinalizedDay: match.hasUnfinalizedDay
            )
        }
    }

    private func runMetricSyncIfEligible() async {
        guard let sessionStore else { return }
        let isSyncEligible = sessionStore.isOnboardingComplete || sessionStore.healthKitPromptCompleted
        guard isSyncEligible else { return }
        await MetricSyncCoordinator.shared.requestSync(trigger: .homeRefresh, force: true)
    }

    @discardableResult
    private func applyPersistedProfileLocalDayChangeIfNeeded(
        profileId: UUID,
        currentLocalDate: String,
        knownMatchIds: [UUID] = []
    ) -> Bool {
        let persisted = HomeHeroLastProfileLocalDateStore.load(profileId: profileId)
        defer {
            HomeHeroLastProfileLocalDateStore.save(profileId: profileId, localDate: currentLocalDate)
        }

        guard let persisted, persisted != currentLocalDate else { return false }

        let uniqueMatchIds = Array(Set(knownMatchIds))
        if !uniqueMatchIds.isEmpty {
            EnergyBeamHeroLastDisplayedSnapshotStore.clearAll(matchIds: uniqueMatchIds)
        }
        EnergyBeamHeroLastDisplayedSnapshotStore.clearAllPersistedSnapshots()

        AppLogger.log(
            category: "hero_anim",
            level: .debug,
            message: "hero_userdefaults_snapshot_cleared",
            userId: profileId,
            metadata: [
                "cleared_match_count": "\(uniqueMatchIds.count)",
                "previous_date": persisted,
                "local_date": currentLocalDate,
                "source": "persisted_day_change",
            ]
        )
        AppLogger.log(
            category: "home_snapshot",
            level: .debug,
            message: "home_cold_launch_day_rollover",
            userId: profileId,
            metadata: [
                "previous_date": persisted,
                "local_date": currentLocalDate,
                "known_match_count": "\(uniqueMatchIds.count)",
            ]
        )
        return true
    }

    @discardableResult
    private func handleHomeDayRolloverIfNeeded(currentLocalDate: String? = nil) -> Bool {
        let localDate = currentLocalDate ?? snapshotCacheStore.localDateString(
            now: Date(),
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )
        defer {
            lastHomeProfileLocalDate = localDate
            if let userId {
                HomeHeroLastProfileLocalDateStore.save(profileId: userId, localDate: localDate)
            }
        }
        guard let previousDate = lastHomeProfileLocalDate, previousDate != localDate else { return false }

        var matchIdsToClear = activeMatches.map(\.id)
        if let selectedId = selectedHeroStepMatchId, !matchIdsToClear.contains(selectedId) {
            matchIdsToClear.append(selectedId)
        }
        EnergyBeamHeroLastDisplayedSnapshotStore.clearAll(matchIds: matchIdsToClear)
        AppLogger.log(
            category: "hero_anim",
            level: .debug,
            message: "hero_userdefaults_snapshot_cleared",
            userId: userId,
            metadata: [
                "cleared_match_count": "\(matchIdsToClear.count)",
                "previous_date": previousDate,
                "local_date": localDate,
            ]
        )
        AppLogger.log(
            category: "home_snapshot",
            level: .debug,
            message: "home_day_rollover_detected",
            userId: userId,
            metadata: [
                "previous_date": previousDate,
                "local_date": localDate,
                "cleared_match_count": "\(matchIdsToClear.count)",
            ]
        )

        heroHealthKitValueByMetric.removeAll()
        heroSparklineUserSeries = nil
        heroSparklineOpponentSeries = nil
        heroSparklineDomain = nil
        heroViewerHealthKitStepsReadAt = nil
        heroOpponentIntradayLatestTickAt = nil
        heroSparklineLoadGeneration &+= 1
        if !activeMatches.isEmpty {
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
                    theirBaselineSteps: match.theirBaselineSteps,
                    battleDateRangeLabel: match.battleDateRangeLabel,
                    battleEndDateKey: match.battleEndDateKey,
                    profileTodayKey: localDate,
                    hasUnfinalizedDay: match.hasUnfinalizedDay
                )
            }
        }
        syncLiveActivity()
        if let userId {
            persistFreshHeroSnapshot(profileId: userId)
        }
        return true
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

    // MARK: - Global leaderboard rank (Home stat card)

    private func applyLeaderboardRankFromCache(profileId: UUID) {
        let weekStart = LeaderboardRepository.weekStartUTC()
        let weekStartIso = LeaderboardRepository.weekStartISOString(from: weekStart)
        guard let entries = leaderboardSnapshotCache.load(
            profileId: profileId,
            weekStartIso: weekStartIso,
            tabRaw: LeaderboardRepository.LeaderboardScope.global.rawValue
        ) else {
            return
        }
        globalLeaderboardRank = Self.rank(for: profileId, in: entries)
    }

    private func scheduleGlobalLeaderboardRankRefresh(profileId: UUID) {
        leaderboardRankRefreshTask?.cancel()
        leaderboardRankRefreshTask = Task { [weak self] in
            await self?.refreshGlobalLeaderboardRankInBackground(profileId: profileId)
        }
    }

    private func refreshGlobalLeaderboardRankInBackground(profileId: UUID) async {
        let weekStart = LeaderboardRepository.weekStartUTC()
        let weekStartIso = LeaderboardRepository.weekStartISOString(from: weekStart)
        let tabRaw = LeaderboardRepository.LeaderboardScope.global.rawValue

        if globalLeaderboardRank == nil,
           let cached = leaderboardSnapshotCache.load(
               profileId: profileId,
               weekStartIso: weekStartIso,
               tabRaw: tabRaw
           ),
           let rank = Self.rank(for: profileId, in: cached) {
            globalLeaderboardRank = rank
        }

        guard !Task.isCancelled else { return }

        do {
            let entries = try await leaderboardRepository.fetchWeeklyStepsLeaderboard(
                weekStart: weekStart,
                scope: .global
            )
            guard !Task.isCancelled else { return }
            leaderboardSnapshotCache.save(
                entries: entries,
                profileId: profileId,
                weekStartIso: weekStartIso,
                tabRaw: tabRaw
            )
            globalLeaderboardRank = Self.rank(for: profileId, in: entries)
        } catch {
            // Keep cache-derived rank or "--"; do not block Home.
        }
    }

    private static func rank(for profileId: UUID, in entries: [WeeklyStepsLeaderboardRecord]) -> Int? {
        entries.first(where: { $0.userId == profileId })?.rank
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
            lastHeroSnapshotLoadSource = "none"
            HealthKitDiagnosticsStore.homeHeroStepsSource = heroDisplayedStepsSource
            return
        }

        heroMetric = .steps
        activeMatches = applyHealthKitOverrides(to: snapshotCacheStore.toDomain(cached))
        reconcileSelectedHeroStepMatch(userId: profileId)
        applyLeaderboardRankFromCache(profileId: profileId)
        scheduleGlobalLeaderboardRankRefresh(profileId: profileId)
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
        lastHeroSnapshotLoadSource = "disk"
        HealthKitDiagnosticsStore.homeHeroStepsSource = heroDisplayedStepsSource
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
        lastHeroSnapshotLoadSource = source
        let ageSeconds: Int
        if let savedAt {
            ageSeconds = max(0, Int(Date().timeIntervalSince(savedAt)))
        } else {
            ageSeconds = 0
        }
        AppLogger.log(
            category: "home_snapshot",
            level: .debug,
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
        let summary = snapshotCacheStore.makeCompactSummary(
            activeMatches: activeMatches,
            heroMetric: heroMetric
        )
        guard summary != lastLoggedSnapshotSummary else { return }
        lastLoggedSnapshotSummary = summary
        AppLogger.log(
            category: "home_snapshot",
            level: .debug,
            message: "home_snapshot_saved",
            userId: profileId,
            metadata: [
                "profile_id": profileId.uuidString,
                "local_date": localDate,
                "active_count": "\(activeMatches.count)",
                "hero_metric": heroMetric.rawValue,
                "summary": summary,
            ]
        )
    }

    private func logHomeReturnNoReload(profileId: UUID) {
        AppLogger.log(
            category: "home_snapshot",
            level: .debug,
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

    func selectHeroStepMatch(_ match: HomeActiveMatch) {
        guard match.isStepsBattleForHomeUX else { return }
        guard !match.isEffectivelyOverForHomeUX else { return }
        guard activeStepMatchesEligibleForHero.contains(where: { $0.id == match.id }) else { return }
        guard selectedHeroStepMatchId != match.id else { return }

        selectedHeroStepMatchId = match.id
        if let userId {
            FeaturedOpponentHandoffStore.saveLastOpponent(match.opponent.id, userId: userId)
        }
        clearHeroSparklineSlotsForMatchSwitch()
        scheduleHeroSparklineRefresh()
    }

    func selectAdjacentHeroStepMatch(offset: Int) {
        let matches = sortedActiveStepMatchesForHero
        guard matches.count > 1,
              let currentId = featuredHomeStepMatch?.id,
              let index = matches.firstIndex(where: { $0.id == currentId }) else { return }
        let nextIndex = index + offset
        guard matches.indices.contains(nextIndex) else { return }
        selectHeroStepMatch(matches[nextIndex])
    }

    var canSelectPreviousHeroStepMatch: Bool {
        guard let index = featuredHeroStepMatchIndex else { return false }
        return index > 0
    }

    var canSelectNextHeroStepMatch: Bool {
        guard let index = featuredHeroStepMatchIndex else { return false }
        return index < sortedActiveStepMatchesForHero.count - 1
    }

    private var featuredHeroStepMatchIndex: Int? {
        let matches = sortedActiveStepMatchesForHero
        guard let currentId = featuredHomeStepMatch?.id else { return nil }
        return matches.firstIndex(where: { $0.id == currentId })
    }

    private func reconcileSelectedHeroStepMatch(userId: UUID) {
        guard let selectedHeroStepMatchId else { return }
        let isEligible = activeStepMatchesEligibleForHero.contains(where: { $0.id == selectedHeroStepMatchId })
        guard isEligible else {
            self.selectedHeroStepMatchId = nil
            return
        }
    }

    // MARK: - Featured opponent handoff (Slice 7)

    private enum HomeHeroLastProfileLocalDateStore {
        private static func key(profileId: UUID) -> String {
            "fitup.home.lastProfileLocalDate.\(profileId.uuidString)"
        }

        static func load(profileId: UUID) -> String? {
            UserDefaults.standard.string(forKey: key(profileId: profileId))
        }

        static func save(profileId: UUID, localDate: String) {
            UserDefaults.standard.set(localDate, forKey: key(profileId: profileId))
        }
    }

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
        if let previousOppId = FeaturedOpponentHandoffStore.lastOpponentProfileId(userId: userId), previousOppId != newOppId {
            let previousMatch = activeStepMatches.first { $0.opponent.id == previousOppId }
            heroOpponentHandoff = HeroOpponentHandoffOverlayModel(previousMatch: previousMatch, newMatch: match)
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
        let previous = activeStepMatches.first { $0.opponent.id != m.opponent.id } ?? m
        heroOpponentHandoff = HeroOpponentHandoffOverlayModel(previousMatch: previous, newMatch: m)
    }
    #endif

}
