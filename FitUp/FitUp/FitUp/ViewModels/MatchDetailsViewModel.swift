//
//  MatchDetailsViewModel.swift
//  FitUp
//
//  Slice 5 state orchestration for Match Details screen.
//

import Combine
import Foundation

@MainActor
final class MatchDetailsViewModel: ObservableObject {
    @Published private(set) var snapshot: MatchDetailsSnapshot?
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmittingAction = false
    @Published var errorMessage: String?

    let matchId: UUID

    private let profile: Profile?
    private let detailsRepository: MatchDetailsRepository
    private let homeRepository: HomeRepository
    private var hasStarted = false

    init(
        matchId: UUID,
        profile: Profile?,
        detailsRepository: MatchDetailsRepository,
        homeRepository: HomeRepository
    ) {
        self.matchId = matchId
        self.profile = profile
        self.detailsRepository = detailsRepository
        self.homeRepository = homeRepository
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        Task { await refresh(showLoading: true) }
        detailsRepository.startLiveRefresh(matchId: matchId) { [weak self] in
            guard let self else { return }
            await self.refresh(showLoading: false)
        }
    }

    func stop() {
        detailsRepository.stopLiveRefresh()
        hasStarted = false
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
            snapshot = try await detailsRepository.loadSnapshot(matchId: matchId, currentUser: profile)
            if errorMessage != nil {
                errorMessage = nil
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
        guard snapshot.state == .completed else { return nil }

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
