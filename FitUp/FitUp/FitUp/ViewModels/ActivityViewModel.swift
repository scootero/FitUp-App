//
//  ActivityViewModel.swift
//  FitUp
//
//  Slice 8 minimal Activity state.
//

import Combine
import Foundation

@MainActor
final class ActivityViewModel: ObservableObject {
    struct ActivityStats: Equatable {
        let matchCount: Int
        let winCount: Int
        let winRateText: String
    }

    @Published private(set) var activeMatches: [HomeActiveMatch] = []
    @Published private(set) var completedMatches: [ActivityCompletedMatch] = []
    @Published private(set) var stats = ActivityStats(matchCount: 0, winCount: 0, winRateText: "0%")
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let repository = ActivityRepository()
    private let homeRepository = HomeRepository()
    private var userId: UUID?

    func start(profile: Profile?) {
        guard let profileId = profile?.id else {
            completedMatches = []
            userId = nil
            return
        }

        if userId != profileId {
            userId = profileId
        }
        Task { await reload() }
    }

    func reload() async {
        guard let userId else { return }
        if isLoading { return }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil

        async let completedTask = repository.loadCompletedMatches(currentUserId: userId)
        async let activeTask = homeRepository.loadActiveMatches(for: userId)

        let matches = await completedTask
        let active = await activeTask

        completedMatches = matches
        activeMatches = active
        stats = Self.makeStats(from: matches)

        if matches.isEmpty && active.isEmpty {
            AppLogger.log(
                category: "match_state",
                level: .debug,
                message: "activity feed empty",
                userId: userId
            )
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
}
