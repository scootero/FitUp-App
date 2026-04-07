//
//  MetricSyncCoordinator.swift
//  FitUp
//
//  Slice 7 orchestration for HealthKit -> Supabase live metric sync.
//

import Foundation
import UIKit

enum MetricSyncTrigger: String {
    case foreground
    case observer
    case liveMatchRead
    case manual
}

actor MetricSyncCoordinator {
    static let shared = MetricSyncCoordinator()

    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()

    /// `HKObserverQuery` + background delivery: steps + active energy only (`HealthKitService`).
    private static let observerMetricLabels = "stepCount, activeEnergyBurned"

    private let snapshotRepository = MetricSnapshotRepository()
    private let matchDayRepository = MatchDayRepository()

    private var activeProfile: Profile?
    private var hasObserverPipeline = false
    private var isSyncing = false
    private var needsResync = false
    private var lastSyncAt: Date?
    private var lastObserverWakeAt: Date?
    private var lastSyncCompletedAt: Date?

    private let minimumLiveSyncInterval: TimeInterval = 8

    func updateProfile(_ profile: Profile?) async {
        let previousProfileId = activeProfile?.id
        activeProfile = profile

        guard let profile else {
            HealthKitService.stopMetricObservers()
            hasObserverPipeline = false
            return
        }

        if !hasObserverPipeline || previousProfileId != profile.id {
            await HealthKitService.startMetricObservers { _ in
                await MetricSyncCoordinator.shared.handleObserverWake()
            }
            hasObserverPipeline = true
        }
    }

    func appDidBecomeActive() async {
        await requestSync(trigger: .foreground, force: true)
    }

    func requestSync(trigger: MetricSyncTrigger = .manual, force: Bool = false) async {
        if !force, trigger == .liveMatchRead, shouldThrottleLiveSync() {
            return
        }

        if isSyncing {
            needsResync = true
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        repeat {
            needsResync = false
            await performSync(trigger: trigger)
        } while needsResync
    }

    private func shouldThrottleLiveSync() -> Bool {
        guard let lastSyncAt else { return false }
        return Date().timeIntervalSince(lastSyncAt) < minimumLiveSyncInterval
    }

    private func handleObserverWake() async {
        lastObserverWakeAt = Date()
        if let uid = activeProfile?.id, let wake = lastObserverWakeAt {
            AppLogger.log(
                category: "healthkit_sync",
                level: .info,
                message: "HealthKit observer fired (steps or active energy changed)",
                userId: uid,
                metadata: [
                    "pipeline": "HKObserverQuery → MetricSyncCoordinator.handleObserverWake",
                    "observer_wake_at": Self.iso8601.string(from: wake),
                    "hk_observer_types": Self.observerMetricLabels,
                    "hk_observer_count": "2",
                ]
            )
        }

        let backgroundTaskId = await MainActor.run {
            UIApplication.shared.beginBackgroundTask(withName: "FitUpHealthObserverSync")
        }

        await requestSync(trigger: .observer, force: true)

        await MainActor.run {
            if backgroundTaskId != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskId)
            }
        }
    }

    private func performSync(trigger: MetricSyncTrigger) async {
        guard let profile = activeProfile else { return }

        let syncStarted = Date()
        AppLogger.log(
            category: "healthkit_sync",
            level: .info,
            message: "metric sync started",
            userId: profile.id,
            metadata: [
                "trigger": trigger.rawValue,
                "pipeline": "MetricSyncCoordinator.performSync",
                "hk_observer_types": Self.observerMetricLabels,
                "hk_observer_count": "2",
                "last_sync_completed_at": lastSyncCompletedAt.map { Self.iso8601.string(from: $0) } ?? "never",
                "last_observer_wake_at": lastObserverWakeAt.map { Self.iso8601.string(from: $0) } ?? "never",
            ]
        )

        var stepsTotal: Int?
        var caloriesTotal: Int?

        do {
            stepsTotal = try await HealthKitService.fetchTodayStepCount()
        } catch {
            handleHealthReadError(error, profile: profile, metricType: .steps)
        }

        do {
            caloriesTotal = try await HealthKitService.fetchTodayActiveCalories()
        } catch {
            handleHealthReadError(error, profile: profile, metricType: .activeCalories)
        }

        var writes = await matchDayRepository.syncActiveMatchTotals(
            currentUserId: profile.id,
            stepsTotal: stepsTotal,
            caloriesTotal: caloriesTotal
        )
        let historicalTargets = await matchDayRepository.pendingHistoricalSyncTargets(currentUserId: profile.id)
        var historicalCache: [String: Int] = [:]
        for target in historicalTargets {
            let cacheKey = "\(target.metricType.rawValue)|\(target.calendarDateString)|\(target.timeZone?.identifier ?? "current")"

            let total: Int
            if let cached = historicalCache[cacheKey] {
                total = cached
            } else {
                do {
                    total = try await HealthKitService.fetchMetricTotal(
                        metricType: target.metricType,
                        for: target.calendarDate,
                        timeZone: target.timeZone
                    )
                    historicalCache[cacheKey] = total
                } catch {
                    handleHealthReadError(error, profile: profile, metricType: target.metricType)
                    continue
                }
            }

            do {
                try await matchDayRepository.confirmHistoricalDayTotal(
                    matchDayId: target.matchDayId,
                    userId: profile.id,
                    metricTotal: total
                )
                writes.append(
                    MatchDaySyncWrite(
                        matchId: target.matchId,
                        metricType: target.metricType,
                        value: total,
                        sourceDate: target.calendarDateString
                    )
                )
            } catch {
                AppLogger.log(
                    category: "healthkit_sync",
                    level: .warning,
                    message: "historical day confirm write failed",
                    userId: profile.id,
                    metadata: [
                        "match_id": target.matchId.uuidString,
                        "match_day_id": target.matchDayId.uuidString,
                        "metric_type": target.metricType.rawValue,
                        "error": error.localizedDescription,
                    ]
                )
            }
        }

        for write in writes {
            do {
                let metadata: [String: String] = [
                    "trigger": trigger.rawValue,
                    "sync_scope": historicalTargets.contains(where: { target in
                        target.matchId == write.matchId && target.calendarDateString == write.sourceDate
                    }) ? "historical_day" : "live_day",
                ]

                try await snapshotRepository.insertSnapshots(
                    matchIds: [write.matchId],
                    userId: profile.id,
                    metricType: write.metricType,
                    value: write.value,
                    sourceDate: write.sourceDate,
                    metadata: metadata
                )
            } catch {
                AppLogger.log(
                    category: "healthkit_sync",
                    level: .warning,
                    message: "metric snapshot write failed",
                    userId: profile.id,
                    metadata: [
                        "match_id": write.matchId.uuidString,
                        "metric_type": write.metricType.rawValue,
                        "error": error.localizedDescription,
                    ]
                )
            }
        }

        do {
            let stepsAverage = try? await HealthKitService.fetchSevenDayStepAverage()
            let caloriesAverage = try? await HealthKitService.fetchSevenDayActiveCaloriesAverage()
            try await snapshotRepository.upsertRollingBaselines(
                userId: profile.id,
                stepsAverage: stepsAverage,
                caloriesAverage: caloriesAverage
            )
        } catch {
            AppLogger.log(
                category: "healthkit_sync",
                level: .warning,
                message: "baseline upsert failed",
                userId: profile.id,
                metadata: ["error": error.localizedDescription]
            )
        }

        lastSyncAt = Date()
        lastSyncCompletedAt = lastSyncAt
        let durationMs = Int(syncStarted.timeIntervalSinceNow * -1000)
        AppLogger.log(
            category: "healthkit_sync",
            level: .info,
            message: "metric sync finished",
            userId: profile.id,
            metadata: [
                "trigger": trigger.rawValue,
                "pipeline": "MetricSyncCoordinator.performSync",
                "duration_ms": "\(durationMs)",
                "steps_today": stepsTotal.map(String.init) ?? "nil",
                "active_calories_today": caloriesTotal.map(String.init) ?? "nil",
                "historical_targets": "\(historicalTargets.count)",
                "snapshot_writes": "\(writes.count)",
            ]
        )
    }

    private func handleHealthReadError(
        _ error: Error,
        profile: Profile,
        metricType: HealthMetricType
    ) {
        let level: LogLevel
        if let healthError = error as? HealthKitError, case .authorizationDenied = healthError {
            level = .info
        } else {
            level = .warning
        }
        AppLogger.log(
            category: "healthkit_sync",
            level: level,
            message: "metric read skipped during sync",
            userId: profile.id,
            metadata: [
                "metric_type": metricType.rawValue,
                "error": error.localizedDescription,
                "error_type": String(describing: type(of: error)),
            ]
        )
    }
}
