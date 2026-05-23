//
//  MatchmakingService.swift
//  FitUp
//
//  Slice 4 challenge flow business logic for quick match and entry gating.
//

import Foundation

enum ChallengeMetricType: String, CaseIterable {
    case steps
    case activeCalories = "active_calories"

    var displayName: String {
        switch self {
        case .steps: return "Steps"
        case .activeCalories: return "Calories"
        }
    }
}

enum ChallengeFormatType: CaseIterable {
    case daily
    case firstTo3
    case bestOf5
    case bestOf7

    var displayName: String {
        MatchDurationCopy.competitionLengthBadge(days: durationDays)
    }

    var subtitle: String {
        switch self {
        case .daily:
            return "One competition day. Highest score wins."
        case .firstTo3:
            return "Three competition days. Win more days than your opponent."
        case .bestOf5:
            return "Five competition days. First to 3 day-wins takes the match."
        case .bestOf7:
            return "Seven competition days. First to 4 day-wins takes the match."
        }
    }

    /// One-line explainer for the Duration step “How this works” section.
    var howItWorksLine: String {
        switch self {
        case .daily:
            return "One competition day — highest step count wins."
        case .firstTo3:
            return "Up to 3 competition days — first to 2 day-wins."
        case .bestOf5:
            return "Up to 5 competition days — first to 3 day-wins."
        case .bestOf7:
            return "Up to 7 competition days — first to 4 day-wins."
        }
    }

    var durationDays: Int {
        switch self {
        case .daily: return 1
        case .firstTo3: return 3
        case .bestOf5: return 5
        case .bestOf7: return 7
        }
    }
}

enum ChallengeStartMode: String {
    case today
    case tomorrow
}

enum MatchScoringModePreference: String, CaseIterable {
    case balanced
    case raw

    var title: String {
        switch self {
        case .balanced: return "Balanced Battle"
        case .raw: return "Raw Battle"
        }
    }

    /// Shown on the Challenge review step under the scoring picker (Slice 5).
    var subtitle: String {
        switch self {
        case .balanced:
            return "Balanced Battle uses Battle Score to compare each player against their normal daily pace. Great for fair matches between different step levels."
        case .raw:
            return "Raw Battle uses actual steps. Whoever gets more steps wins."
        }
    }
}

enum MatchDifficultyPreference: String, CaseIterable {
    case easy
    case fair
    case hard

    var title: String {
        switch self {
        case .easy: return "Easy"
        case .fair: return "Fair"
        case .hard: return "Hard"
        }
    }

    /// Raw Battle matchmaking intent; shown on Challenge difficulty step when Raw is selected.
    var subtitle: String {
        switch self {
        case .easy:
            return "We first look for an opponent with a lower or similar daily average."
        case .fair:
            return "We first look for an opponent close to your daily average."
        case .hard:
            return "We first look for an opponent with a higher daily average."
        }
    }

    /// Shown when Raw is selected for a direct (non–Quick Battle) challenge.
    static let directedOpponentFootnote =
        "Choose difficulty in random matches only. Direct battles use Fair matchmaking rules when you use Raw."
}

struct ChallengeOpponent: Identifiable, Equatable {
    let id: UUID
    let displayName: String
    let initials: String
    let colorHex: String
    let todaySteps: Int?
    let wins: Int?
    let losses: Int?
    let rollingStepsBaseline: Double?
    let rollingCaloriesBaseline: Double?
}

struct ChallengeEntryGate {
    let isBlocked: Bool
    let isPremium: Bool
    let usedSlots: Int
    let slotLimit: Int
}

final class MatchmakingService {
    private let repository: MatchRepository

    init(repository: MatchRepository = MatchRepository()) {
        self.repository = repository
    }

    func loadOpponents(
        currentUserId: UUID,
        query: String,
        metricType: ChallengeMetricType
    ) async throws -> [ChallengeOpponent] {
        try await repository
            .fetchOpponentCandidates(
                currentUserId: currentUserId,
                query: query,
                metricType: metricType
            )
            .map { candidate in
                ChallengeOpponent(
                    id: candidate.id,
                    displayName: candidate.displayName,
                    initials: candidate.initials,
                    colorHex: candidate.colorHex,
                    todaySteps: candidate.todaySteps,
                    wins: candidate.wins,
                    losses: candidate.losses,
                    rollingStepsBaseline: candidate.rollingStepsBaseline,
                    rollingCaloriesBaseline: candidate.rollingCaloriesBaseline
                )
            }
    }

    func evaluateEntryGate(profile: Profile?) async -> ChallengeEntryGate {
        let isPremium = await MainActor.run { SubscriptionService.shared.isPremium }
        if isPremium {
            return ChallengeEntryGate(
                isBlocked: false,
                isPremium: true,
                usedSlots: 0,
                slotLimit: 1
            )
        }

        // Per spec: the paywall is never shown before the user has completed their first match.
        let canShowPaywall = await MainActor.run { SubscriptionService.shared.canShowPaywall }
        guard let profileId = profile?.id else {
            return ChallengeEntryGate(
                isBlocked: canShowPaywall,
                isPremium: false,
                usedSlots: 1,
                slotLimit: 1
            )
        }

        do {
            let usedSlots = try await repository.countOpenSlots(currentUserId: profileId)
            let isBlocked = canShowPaywall && !(SubscriptionService.shared.canCreateMatch(usedSlots: usedSlots))
            return ChallengeEntryGate(
                isBlocked: isBlocked,
                isPremium: false,
                usedSlots: usedSlots,
                slotLimit: 1
            )
        } catch {
            PaywallLogger.log(
                level: .warning,
                message: "slot gate check failed",
                userId: profile?.id,
                metadata: ["error": error.localizedDescription]
            )
            return ChallengeEntryGate(
                isBlocked: false,
                isPremium: false,
                usedSlots: 0,
                slotLimit: 1
            )
        }
    }

    @discardableResult
    func submitQuickMatch(
        currentUserId: UUID,
        metricType: ChallengeMetricType,
        format: ChallengeFormatType,
        startMode: ChallengeStartMode = .today,
        scoringMode: MatchScoringModePreference?,
        difficulty: MatchDifficultyPreference?
    ) async throws -> UUID {
        let requestId = try await repository.createQuickMatchSearch(
            creatorId: currentUserId,
            metricType: metricType,
            durationDays: format.durationDays,
            startMode: startMode,
            scoringMode: scoringMode,
            difficulty: difficulty
        )

        AppLogger.log(
            category: "matchmaking",
            level: .info,
            message: "quick match request created",
            userId: currentUserId,
            metadata: [
                "request_id": requestId.uuidString,
                "metric_type": metricType.rawValue,
                "duration_days": String(format.durationDays),
                "start_mode": startMode.rawValue,
                "scoring_mode": scoringMode?.rawValue ?? "nil",
                "difficulty": difficulty?.rawValue ?? "nil",
            ]
        )

        ProductAnalytics.track(
            ProductAnalytics.Event.matchmakingStarted,
            userId: currentUserId,
            properties: [
                "request_id": requestId.uuidString,
                "metric_type": metricType.rawValue,
                "duration_days": String(format.durationDays),
                "start_mode": startMode.rawValue,
                "scoring_mode": scoringMode?.rawValue ?? "",
                "difficulty": difficulty?.rawValue ?? "",
            ]
        )

        scheduleMatchmakingRetries(repository: repository, requestId: requestId)

        return requestId
    }

    /// Re-invokes pairing after delays in case the INSERT trigger's pg_net call failed or a partner joined slightly later.
    private func scheduleMatchmakingRetries(repository: MatchRepository, requestId: UUID) {
        Task(priority: .utility) {
            let delaysNanoseconds: [UInt64] = [
                5 * 1_000_000_000,
                15 * 1_000_000_000,
            ]
            for nanos in delaysNanoseconds {
                try? await Task.sleep(nanoseconds: nanos)
                do {
                    try await repository.retryMatchmakingSearch(requestId: requestId)
                    AppLogger.log(
                        category: "matchmaking",
                        level: .debug,
                        message: "matchmaking retry invoked",
                        metadata: ["request_id": requestId.uuidString]
                    )
                } catch {
                    AppLogger.log(
                        category: "matchmaking",
                        level: .warning,
                        message: "matchmaking retry failed",
                        metadata: [
                            "request_id": requestId.uuidString,
                            "error": error.localizedDescription,
                        ]
                    )
                }
            }
        }
    }

}
