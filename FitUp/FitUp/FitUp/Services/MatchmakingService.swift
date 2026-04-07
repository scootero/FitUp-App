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
        switch self {
        case .daily: return "Daily"
        case .firstTo3: return "First to 3"
        case .bestOf5: return "Best of 5"
        case .bestOf7: return "Best of 7"
        }
    }

    var subtitle: String {
        switch self {
        case .daily: return "Single day showdown"
        case .firstTo3: return "First to 3 wins"
        case .bestOf5: return "First to 3 wins"
        case .bestOf7: return "First to 4 wins"
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
            AppLogger.log(
                category: "paywall",
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
        startMode: ChallengeStartMode = .today
    ) async throws -> UUID {
        let requestId = try await repository.createQuickMatchSearch(
            creatorId: currentUserId,
            metricType: metricType,
            durationDays: format.durationDays,
            startMode: startMode
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
