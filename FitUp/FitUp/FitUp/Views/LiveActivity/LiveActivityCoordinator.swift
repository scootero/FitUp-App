//
//  LiveActivityCoordinator.swift
//  FitUp
//
//  Slice 9: Manages the ActivityKit Live Activity lifecycle for the
//  current active match — start, push-token upload, and end.
//
//  Call `startIfNeeded` when Home detects an active match.
//  Call `endActivity` when the match completes.
//

import ActivityKit
import Foundation

@MainActor
final class LiveActivityCoordinator {

    static let shared = LiveActivityCoordinator()

    private var currentActivity: Activity<FitUpActivityAttributes>?
    private var pushTokenTask: Task<Void, Never>?

    private init() {}

    // MARK: - Start

    /// Starts a Live Activity for the given active match if one isn't already running.
    func startIfNeeded(
        matchId: UUID,
        myDisplayName: String,
        opponentDisplayName: String,
        metricType: String,
        durationDays: Int,
        myTotal: Int,
        opponentTotal: Int,
        myScore: Int,
        theirScore: Int,
        dayNumber: Int
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // Resume existing if same match.
        if let existing = Activity<FitUpActivityAttributes>.activities.first(where: {
            $0.attributes.matchId == matchId
        }) {
            currentActivity = existing
            subscribeToPushTokenUpdates()
            return
        }

        let attributes = FitUpActivityAttributes(
            matchId: matchId,
            myDisplayName: myDisplayName,
            opponentDisplayName: opponentDisplayName,
            metricType: metricType,
            durationDays: durationDays
        )
        let state = FitUpActivityAttributes.ContentState(
            myTotal: myTotal,
            opponentTotal: opponentTotal,
            myScore: myScore,
            theirScore: theirScore,
            dayNumber: dayNumber
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: .token
            )
            currentActivity = activity
            AppLogger.log(
                category: "notifications",
                level: .info,
                message: "Live Activity started",
                metadata: ["match_id": matchId.uuidString, "activity_id": activity.id]
            )
            subscribeToPushTokenUpdates()
        } catch {
            AppLogger.log(
                category: "notifications",
                level: .warning,
                message: "Live Activity start failed: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Update (local, for foreground refreshes)

    func updateState(
        myTotal: Int,
        opponentTotal: Int,
        myScore: Int,
        theirScore: Int,
        dayNumber: Int
    ) {
        guard let activity = currentActivity else { return }
        let newState = FitUpActivityAttributes.ContentState(
            myTotal: myTotal,
            opponentTotal: opponentTotal,
            myScore: myScore,
            theirScore: theirScore,
            dayNumber: dayNumber
        )
        Task {
            await activity.update(.init(state: newState, staleDate: nil))
        }
    }

    // MARK: - End

    /// Ends the Live Activity and clears the stored push token.
    func endActivity() {
        guard let activity = currentActivity else { return }
        pushTokenTask?.cancel()
        pushTokenTask = nil
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
            await ProfileRepository().updatePushTokens(liveActivityPushToken: "")
            AppLogger.log(category: "notifications", level: .info, message: "Live Activity ended")
        }
        currentActivity = nil
    }

    // MARK: - Push token subscription

    private func subscribeToPushTokenUpdates() {
        pushTokenTask?.cancel()
        guard let activity = currentActivity else { return }

        pushTokenTask = Task {
            for await tokenData in activity.pushTokenUpdates {
                NotificationService.shared.storeLiveActivityToken(tokenData)
                AppLogger.log(
                    category: "notifications",
                    level: .info,
                    message: "Live Activity push token refreshed"
                )
            }
        }
    }
}
