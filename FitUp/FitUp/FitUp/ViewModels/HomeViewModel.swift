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
        let matchCount: Int
        let winCount: Int
        let winRateText: String
    }

    @Published private(set) var searchingRequests: [HomeSearchingRequest] = []
    @Published private(set) var activeMatches: [HomeActiveMatch] = []
    @Published private(set) var pendingMatches: [HomePendingMatch] = []
    @Published private(set) var discoverUsers: [HomeDiscoverUser] = []
    @Published private(set) var completedMatches: [ActivityCompletedMatch] = []
    @Published private(set) var stats = ActivityStats(matchCount: 0, winCount: 0, winRateText: "0%")
    @Published private(set) var isLoading = false
    @Published private(set) var now = Date()
    @Published var errorMessage: String?
    @Published private(set) var activeActionSearchID: UUID?
    @Published private(set) var activeActionPendingMatchID: UUID?
    /// Shown when a search (including onboarding placeholder) resolves into a new pending match while Home is loaded.
    @Published private(set) var matchFoundCelebration: HomePendingMatch?
    /// Short retro banner after successfully declining a pending match from Home.
    @Published private(set) var declineFeedbackOpponentName: String?

    var hasAnyContent: Bool {
        !searchingRequests.isEmpty || !activeMatches.isEmpty || !pendingMatches.isEmpty
            || !discoverUsers.isEmpty || !completedMatches.isEmpty
    }

    private let repository = HomeRepository()
    private let activityRepository = ActivityRepository()
    private var userId: UUID?
    private var profileTimeZoneIdentifier: String?
    private var myDisplayName: String = "You"
    private var waitTimerCancellable: AnyCancellable?
    private var shouldShowOnboardingPlaceholder = false
    private var hasStartedRealtime = false
    private var celebrationDismissTask: Task<Void, Never>?
    private var declineFeedbackDismissTask: Task<Void, Never>?
    private weak var sessionStore: SessionStore?

    private static let publicMatchmakingMatchType = "public_matchmaking"
    private static let matchFoundCelebrationFreshnessSeconds: TimeInterval = 300

    private static func isMatchCreationFreshForCelebration(_ pending: HomePendingMatch) -> Bool {
        max(0, Date().timeIntervalSince(pending.createdAt)) < matchFoundCelebrationFreshnessSeconds
    }

    func start(profile: Profile?, showOnboardingSearching: Bool, sessionStore: SessionStore) {
        guard let profileId = profile?.id else { return }
        self.sessionStore = sessionStore
        myDisplayName = profile?.displayName ?? "You"
        profileTimeZoneIdentifier = profile?.timezone

        if userId != profileId {
            stop()
            userId = profileId
        }

        if !hasStartedRealtime {
            hasStartedRealtime = true
            repository.startRealtimeSubscriptions(for: profileId) { [weak self] in
                guard let self else { return }
                await self.reload(force: true)
            }
        }

        if showOnboardingSearching {
            shouldShowOnboardingPlaceholder = true
        }
        startWaitTimer()

        Task { await reload(force: false) }
    }

    func stop() {
        waitTimerCancellable?.cancel()
        waitTimerCancellable = nil
        celebrationDismissTask?.cancel()
        celebrationDismissTask = nil
        declineFeedbackDismissTask?.cancel()
        declineFeedbackDismissTask = nil
        matchFoundCelebration = nil
        declineFeedbackOpponentName = nil
        repository.stopRealtimeSubscriptions()
        hasStartedRealtime = false
    }

    func reload(force: Bool) async {
        guard let userId else { return }
        if isLoading && !force { return }

        isLoading = true
        defer { isLoading = false }

        let hadSearchingUI = !searchingRequests.isEmpty
        let oldPendingIds = Set(pendingMatches.map(\.id))

        async let snapshotTask = repository.loadSnapshot(
            for: userId,
            showOnboardingSearching: shouldShowOnboardingPlaceholder,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )
        async let completedTask = activityRepository.loadCompletedMatches(currentUserId: userId)

        let snapshot = await snapshotTask
        let completed = await completedTask
        shouldShowOnboardingPlaceholder = false

        let newPendingIds = Set(snapshot.pendingMatches.map(\.id))
        let newPendingMatchIds = newPendingIds.subtracting(oldPendingIds)

        searchingRequests = snapshot.searching
        activeMatches = snapshot.activeMatches
        pendingMatches = snapshot.pendingMatches
        discoverUsers = snapshot.discoverUsers
        completedMatches = completed
        stats = Self.makeStats(from: completed)

        var celebration: HomePendingMatch?
        if snapshot.searching.isEmpty, !newPendingMatchIds.isEmpty {
            if hadSearchingUI,
               let m = snapshot.pendingMatches.first(where: { newPendingMatchIds.contains($0.id) }),
               !MatchFoundCelebrationStore.hasShown(profileId: userId, matchId: m.id) {
                celebration = m
            } else if !hadSearchingUI,
                      let m = snapshot.pendingMatches.first(where: { pending in
                          newPendingMatchIds.contains(pending.id)
                              && pending.matchType == Self.publicMatchmakingMatchType
                              && Self.isMatchCreationFreshForCelebration(pending)
                      }),
                      !MatchFoundCelebrationStore.hasShown(profileId: userId, matchId: m.id) {
                celebration = m
            }
        }

        if celebration == nil, snapshot.searching.isEmpty {
            let pendingIds = Set(snapshot.pendingMatches.map(\.id))
            if let qid = sessionStore?.takePendingMatchFoundCelebrationIfPendingContains(pendingIds),
               let m = snapshot.pendingMatches.first(where: { $0.id == qid }),
               m.matchType == Self.publicMatchmakingMatchType,
               !MatchFoundCelebrationStore.hasShown(profileId: userId, matchId: m.id) {
                celebration = m
            }
        }

        if let celebration {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                matchFoundCelebration = celebration
            }
            scheduleCelebrationDismiss()
        }

        syncLiveActivity()
    }

    func dismissMatchFoundCelebration() {
        celebrationDismissTask?.cancel()
        celebrationDismissTask = nil
        if let id = matchFoundCelebration?.id, let profileId = userId {
            MatchFoundCelebrationStore.markShown(profileId: profileId, matchId: id)
        }
        withAnimation(.easeOut(duration: 0.22)) {
            matchFoundCelebration = nil
        }
    }

    private func scheduleCelebrationDismiss() {
        celebrationDismissTask?.cancel()
        celebrationDismissTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            guard !Task.isCancelled else { return }
            dismissMatchFoundCelebration()
        }
    }

    func dismissDeclineFeedback() {
        declineFeedbackDismissTask?.cancel()
        declineFeedbackDismissTask = nil
        withAnimation(.easeOut(duration: 0.22)) {
            declineFeedbackOpponentName = nil
        }
    }

    private func showDeclineFeedback(opponentName: String) {
        declineFeedbackDismissTask?.cancel()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            declineFeedbackOpponentName = opponentName
        }
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
            return ActivityStats(matchCount: 0, winCount: 0, winRateText: "0%")
        }

        let rate = Int((Double(winCount) / Double(matchCount) * 100).rounded())
        return ActivityStats(matchCount: matchCount, winCount: winCount, winRateText: "\(rate)%")
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

    func cancelSearch(_ searchId: UUID) async {
        activeActionSearchID = searchId
        defer { activeActionSearchID = nil }

        do {
            try await repository.cancelSearchRequest(searchId: searchId)
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
            await reload(force: true)
            showDeclineFeedback(opponentName: opponentName)
        } catch {
            errorMessage = "Could not decline challenge right now."
            AppLogger.log(category: "matchmaking", level: .warning, message: "decline challenge failed", metadata: ["error": error.localizedDescription])
        }
    }

    func waitTimeLabel(for request: HomeSearchingRequest) -> String {
        let elapsed = max(0, Int(now.timeIntervalSince(request.createdAt)))
        let minutes = elapsed / 60
        let seconds = elapsed % 60
        return "\(minutes)m \(String(format: "%02d", seconds))s"
    }

    private func startWaitTimer() {
        guard waitTimerCancellable == nil else { return }
        waitTimerCancellable = Timer
            .publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.now = date
            }
    }
}
