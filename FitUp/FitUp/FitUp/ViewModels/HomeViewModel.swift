//
//  HomeViewModel.swift
//  FitUp
//
//  Slice 3 Home screen state and actions.
//

import Combine
import Foundation

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var searchingRequests: [HomeSearchingRequest] = []
    @Published private(set) var activeMatches: [HomeActiveMatch] = []
    @Published private(set) var pendingMatches: [HomePendingMatch] = []
    @Published private(set) var discoverUsers: [HomeDiscoverUser] = []
    @Published private(set) var isLoading = false
    @Published private(set) var now = Date()
    @Published var errorMessage: String?
    @Published private(set) var activeActionSearchID: UUID?
    @Published private(set) var activeActionPendingMatchID: UUID?

    var hasAnyContent: Bool {
        !searchingRequests.isEmpty || !activeMatches.isEmpty || !pendingMatches.isEmpty || !discoverUsers.isEmpty
    }

    private let repository = HomeRepository()
    private var userId: UUID?
    private var myDisplayName: String = "You"
    private var waitTimerCancellable: AnyCancellable?
    private var shouldShowOnboardingPlaceholder = false
    private var hasStartedRealtime = false

    func start(profile: Profile?, showOnboardingSearching: Bool) {
        guard let profileId = profile?.id else { return }
        myDisplayName = profile?.displayName ?? "You"

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
        repository.stopRealtimeSubscriptions()
        hasStartedRealtime = false
    }

    func reload(force: Bool) async {
        guard let userId else { return }
        if isLoading && !force { return }

        isLoading = true
        defer { isLoading = false }

        let snapshot = await repository.loadSnapshot(
            for: userId,
            showOnboardingSearching: shouldShowOnboardingPlaceholder
        )
        shouldShowOnboardingPlaceholder = false

        searchingRequests = snapshot.searching
        activeMatches = snapshot.activeMatches
        pendingMatches = snapshot.pendingMatches
        discoverUsers = snapshot.discoverUsers

        syncLiveActivity()
    }

    // MARK: - Live Activity sync

    private func syncLiveActivity() {
        guard let firstActive = activeMatches.first,
              let userId else {
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

        do {
            try await repository.declinePendingMatch(challengeId: pendingMatch.challengeId, matchId: pendingMatch.id)
            await reload(force: true)
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
