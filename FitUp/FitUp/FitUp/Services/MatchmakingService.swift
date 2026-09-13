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
            return "Highest step count wins — ends at midnight same day."
        case .firstTo3:
            return "First to 2 day-wins — up to 3 days if tied."
        case .bestOf5:
            return "First to 3 day-wins — up to 5 days if tied."
        case .bestOf7:
            return "First to 4 day-wins — up to 7 days if tied."
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
    let pastMatchCount: Int?
    let rollingStepsBaseline: Double?
    let rollingCaloriesBaseline: Double?
}

enum ChallengeEntryBlockReason: Equatable {
    case none
    case noProfile
    case slotLimit
    case cooldown
}

struct ChallengeEntryGate {
    let isBlocked: Bool
    let isPremium: Bool
    let usedSlots: Int
    let slotLimit: Int
    let blockReason: ChallengeEntryBlockReason
    /// Local calendar day when a free user may start again (start-of-day), if blocked for cooldown.
    let cooldownEarliestStart: Date?

    static func open(isPremium: Bool, usedSlots: Int = 0) -> ChallengeEntryGate {
        ChallengeEntryGate(
            isBlocked: false,
            isPremium: isPremium,
            usedSlots: usedSlots,
            slotLimit: FreeTierRules.slotLimit,
            blockReason: .none,
            cooldownEarliestStart: nil
        )
    }
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
                    pastMatchCount: candidate.pastMatchCount,
                    rollingStepsBaseline: candidate.rollingStepsBaseline,
                    rollingCaloriesBaseline: candidate.rollingCaloriesBaseline
                )
            }
    }

    func evaluateEntryGate(profile: Profile?) async -> ChallengeEntryGate {
        let subscription = SubscriptionService.shared
        let isPremium = await MainActor.run { subscription.isPremium }
        if isPremium {
            return .open(isPremium: true)
        }

        // Per spec: the paywall is never shown before the user has completed their first match.
        let canShowPaywall = await MainActor.run { subscription.canShowPaywall }
        guard let profileId = profile?.id else {
            return ChallengeEntryGate(
                isBlocked: canShowPaywall,
                isPremium: false,
                usedSlots: 1,
                slotLimit: FreeTierRules.slotLimit,
                blockReason: canShowPaywall ? .noProfile : .none,
                cooldownEarliestStart: nil
            )
        }

        do {
            let usedSlots = try await repository.countOpenSlots(currentUserId: profileId)
            let lastCompletedEnd = try await repository.fetchLatestCompletedMatchEndDate(currentUserId: profileId)

            let slotOK = await MainActor.run { subscription.canCreateMatch(usedSlots: usedSlots) }
            let cooldownOK = await MainActor.run {
                subscription.canStartFreeBattleAfterCooldown(lastCompletedEndDate: lastCompletedEnd)
            }

            if canShowPaywall, !slotOK {
                return ChallengeEntryGate(
                    isBlocked: true,
                    isPremium: false,
                    usedSlots: usedSlots,
                    slotLimit: FreeTierRules.slotLimit,
                    blockReason: .slotLimit,
                    cooldownEarliestStart: nil
                )
            }

            if canShowPaywall, !cooldownOK, let lastCompletedEnd {
                let earliest = await MainActor.run {
                    subscription.freeCooldownEarliestStartDate(after: lastCompletedEnd)
                }
                return ChallengeEntryGate(
                    isBlocked: true,
                    isPremium: false,
                    usedSlots: usedSlots,
                    slotLimit: FreeTierRules.slotLimit,
                    blockReason: .cooldown,
                    cooldownEarliestStart: earliest
                )
            }

            return .open(isPremium: false, usedSlots: usedSlots)
        } catch {
            PaywallLogger.log(
                level: .warning,
                message: "slot gate check failed",
                userId: profile?.id,
                metadata: ["error": error.localizedDescription]
            )
            // Fail closed for free users once paywall is eligible so cooldown/slot cannot be bypassed.
            if canShowPaywall {
                return ChallengeEntryGate(
                    isBlocked: true,
                    isPremium: false,
                    usedSlots: 1,
                    slotLimit: FreeTierRules.slotLimit,
                    blockReason: .slotLimit,
                    cooldownEarliestStart: nil
                )
            }
            return .open(isPremium: false)
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
