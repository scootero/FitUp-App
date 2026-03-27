//
//  DirectChallengeService.swift
//  FitUp
//
//  Slice 4 direct challenge orchestration.
//

import Foundation

struct DirectChallengeSubmissionResult {
    let matchId: UUID
    let challengeId: UUID
}

final class DirectChallengeService {
    private let repository: MatchRepository

    init(repository: MatchRepository = MatchRepository()) {
        self.repository = repository
    }

    func submitDirectChallenge(
        challengerId: UUID,
        opponentId: UUID,
        metricType: ChallengeMetricType,
        format: ChallengeFormatType,
        startMode: ChallengeStartMode = .today
    ) async throws -> DirectChallengeSubmissionResult {
        let result = try await repository.createDirectChallenge(
            challengerId: challengerId,
            recipientId: opponentId,
            metricType: metricType,
            durationDays: format.durationDays,
            startMode: startMode
        )

        AppLogger.log(
            category: "matchmaking",
            level: .info,
            message: "direct challenge created",
            userId: challengerId,
            metadata: [
                "challenge_id": result.challengeId.uuidString,
                "match_id": result.matchId.uuidString,
                "metric_type": metricType.rawValue,
                "duration_days": String(format.durationDays),
                "start_mode": startMode.rawValue,
            ]
        )

        return DirectChallengeSubmissionResult(
            matchId: result.matchId,
            challengeId: result.challengeId
        )
    }
}
