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
    private let publicDailyActivityRepository = PublicDailyActivityRepository()
    private let intradayStepTicksRepository = UserIntradayStepTicksRepository()
    private let userDailyStepTotalsRepository = UserDailyStepTotalsRepository()

    private var activeProfile: Profile?
    private var hasObserverPipeline = false
    private var isSyncing = false
    private var needsResync = false
    private var lastSyncAt: Date?
    private var lastObserverWakeAt: Date?
    private var lastSyncCompletedAt: Date?

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

    private func handleObserverWake() async {
        lastObserverWakeAt = Date()
        guard let profile = activeProfile else { return }

        if let wake = lastObserverWakeAt {
            AppLogger.log(
                category: "healthkit_sync",
                level: .info,
                message: "HealthKit observer fired (steps or active energy changed)",
                userId: profile.id,
                metadata: [
                    "pipeline": "HKObserverQuery → MetricSyncCoordinator.handleObserverWake",
                    "observer_wake_at": Self.iso8601.string(from: wake),
                    "hk_observer_types": Self.observerMetricLabels,
                    "hk_observer_count": "2",
                ]
            )
        }

        let tzId = profile.timezone ?? TimeZone.current.identifier
        let calendarDateStr = HomeRepository.formatProfileCalendarDate(Date(), profileTimeZoneIdentifier: tzId)
        let stepsTotal = try? await HealthKitService.fetchTodayStepCount()
        let caloriesTotal = try? await HealthKitService.fetchTodayActiveCalories()

        let observerDecision = MetricSyncUploadPolicy.observerDecision(
            now: Date(),
            stepsTotal: stepsTotal,
            caloriesTotal: caloriesTotal,
            profileId: profile.id,
            calendarDateStr: calendarDateStr
        )

        switch observerDecision {
        case .proceed:
            break
        case .skipUnchanged:
            AppLogger.log(
                category: "healthkit_sync",
                level: .info,
                message: "metric sync skipped (observer unchanged)",
                userId: profile.id,
                metadata: [
                    "reason": "skip_observer_unchanged",
                    "steps_today": stepsTotal.map(String.init) ?? "nil",
                    "active_calories_today": caloriesTotal.map(String.init) ?? "nil",
                ]
            )
            return
        case let .skipDebounce(remainingSeconds):
            AppLogger.log(
                category: "healthkit_sync",
                level: .info,
                message: "metric sync skipped (observer debounce)",
                userId: profile.id,
                metadata: [
                    "reason": "skip_observer_debounce",
                    "remaining_debounce_s": String(format: "%.1f", remainingSeconds),
                ]
            )
            return
        case let .skipInsufficientStepIncrease(delta, lastSynced):
            AppLogger.log(
                category: "healthkit_sync",
                level: .info,
                message: "metric sync skipped (observer step delta < 100)",
                userId: profile.id,
                metadata: [
                    "reason": "skip_observer_delta",
                    "delta": "\(delta)",
                    "last_synced_steps": "\(lastSynced)",
                ]
            )
            return
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

        var healthSyncPipelineFailed = false
        var stepsTotal: Int?
        var caloriesTotal: Int?

        do {
            stepsTotal = try await HealthKitService.fetchTodayStepCount()
        } catch {
            handleHealthReadError(error, profile: profile, metricType: .steps)
        }

        let intradayTickLogSummary = await appendIntradayStepTickIfEligible(
            profile: profile,
            stepsTotal: stepsTotal,
            trigger: trigger
        )

        do {
            caloriesTotal = try await HealthKitService.fetchTodayActiveCalories()
        } catch {
            handleHealthReadError(error, profile: profile, metricType: .activeCalories)
        }

        do {
            try await publicDailyActivityRepository.upsertMyPublicDailyActivity(
                userId: profile.id,
                activeDate: PublicDailyActivityRepository.activeDateString(for: profile),
                steps: stepsTotal,
                activeCalories: caloriesTotal
            )
        } catch {
            healthSyncPipelineFailed = true
            AppLogger.log(
                category: "healthkit_sync",
                level: .warning,
                message: "public daily activity upsert failed",
                userId: profile.id,
                metadata: ["error": error.localizedDescription]
            )
        }

        let tzIdForDay = profile.timezone ?? TimeZone.current.identifier
        let calendarDateStr = HomeRepository.formatProfileCalendarDate(Date(), profileTimeZoneIdentifier: tzIdForDay)
        if MetricSyncUploadPolicy.shouldSyncRollingDailyTotals(
            trigger: trigger,
            profileId: profile.id,
            calendarDateStr: calendarDateStr
        ) {
            do {
                try await userDailyStepTotalsRepository.syncRollingSevenCalendarDays(profile: profile)
                MetricSyncUploadPolicy.markRollingDailyTotalsSynced(
                    profileId: profile.id,
                    calendarDateStr: calendarDateStr
                )
            } catch {
                AppLogger.log(
                    category: "healthkit_sync",
                    level: .warning,
                    message: "user_daily_step_totals sync failed",
                    userId: profile.id,
                    metadata: ["error": error.localizedDescription]
                )
            }
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

        var snapshotInserted = 0
        var snapshotUpdated = 0
        for write in writes {
            do {
                let metadata: [String: String] = [
                    "trigger": trigger.rawValue,
                    "sync_scope": historicalTargets.contains(where: { target in
                        target.matchId == write.matchId && target.calendarDateString == write.sourceDate
                    }) ? "historical_day" : "live_day",
                ]

                let results = try await snapshotRepository.insertSnapshots(
                    matchIds: [write.matchId],
                    userId: profile.id,
                    metricType: write.metricType,
                    value: write.value,
                    sourceDate: write.sourceDate,
                    metadata: metadata
                )
                for result in results {
                    if result.wasUpdated {
                        snapshotUpdated += 1
                    } else {
                        snapshotInserted += 1
                    }
                    AppLogger.log(
                        category: "healthkit_sync",
                        level: .info,
                        message: result.wasUpdated ? "metric snapshot updated (same value)" : "metric snapshot inserted",
                        userId: profile.id,
                        metadata: [
                            "match_id": write.matchId.uuidString,
                            "metric_type": write.metricType.rawValue,
                            "value": "\(write.value)",
                            "snapshot_id": result.snapshotId.uuidString,
                            "action": result.wasUpdated ? "snapshot_upserted" : "snapshot_inserted",
                        ]
                    )
                }
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
            let stepsAvg7 = try? await HealthKitService.fetchNDayStepAverage(days: 7)
            let stepsAvg30 = try? await HealthKitService.fetchNDayStepAverage(days: 30)
            let stepsAvg90 = try? await HealthKitService.fetchNDayStepAverage(days: 90)
            let caloriesAverage = try? await HealthKitService.fetchSevenDayActiveCaloriesAverage()
            try await snapshotRepository.upsertRollingBaselines(
                userId: profile.id,
                stepsAverage7d: stepsAvg7,
                stepsAverage30d: stepsAvg30,
                stepsAverage90d: stepsAvg90,
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
        MetricSyncUploadPolicy.markSyncCompleted(
            profileId: profile.id,
            calendarDateStr: calendarDateStr,
            stepsTotal: stepsTotal,
            caloriesTotal: caloriesTotal,
            at: lastSyncAt ?? Date()
        )
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
                "snapshot_inserted": "\(snapshotInserted)",
                "snapshot_updated": "\(snapshotUpdated)",
                "intraday_tick": intradayTickLogSummary,
            ]
        )

        if healthSyncPipelineFailed {
            let analyticsProps: [String: String] = [
                "trigger": trigger.rawValue,
                "duration_ms": "\(durationMs)",
                "snapshot_writes": "\(writes.count)",
                "historical_targets": "\(historicalTargets.count)",
            ]
            ProductAnalytics.track(
                ProductAnalytics.Event.healthSyncFailed,
                userId: profile.id,
                properties: analyticsProps.merging(["failure_stage": "public_daily_activity"], uniquingKeysWith: { _, new in new })
            )
        }
    }

    /// Slice 4: upload cumulative today steps for the intraday chart pipeline (throttled).
    private func appendIntradayStepTickIfEligible(
        profile: Profile,
        stepsTotal: Int?,
        trigger: MetricSyncTrigger
    ) async -> String {
        guard let steps = stepsTotal else {
            return "no_steps"
        }

        let tzIdForDay = profile.timezone ?? TimeZone.current.identifier
        let calendarDateStr = HomeRepository.formatProfileCalendarDate(Date(), profileTimeZoneIdentifier: tzIdForDay)
        let now = Date()
        let decision = IntradayStepTickUploadPolicy.decision(
            now: now,
            stepsTotal: steps,
            profileId: profile.id,
            calendarDateStr: calendarDateStr
        )

        let baseMeta: [String: String] = [
            "trigger": trigger.rawValue,
            "pipeline": "MetricSyncCoordinator.appendIntradayStepTickIfEligible",
            "calendar_date": calendarDateStr,
            "steps": "\(steps)",
        ]

        switch decision {
        case .skipNoSteps:
            return "skip_invalid_steps"
        case .skipUnchanged:
            AppLogger.log(
                category: "healthkit_sync",
                level: .info,
                message: "intraday step tick skipped (unchanged vs last upload)",
                userId: profile.id,
                metadata: baseMeta
            )
            return "skip_unchanged"
        case let .skipDebounce(remainingSeconds):
            AppLogger.log(
                category: "healthkit_sync",
                level: .info,
                message: "intraday step tick skipped (debounce)",
                userId: profile.id,
                metadata: baseMeta.merging([
                    "remaining_debounce_s": String(format: "%.1f", remainingSeconds),
                ], uniquingKeysWith: { _, new in new })
            )
            return "skip_debounce"
        case let .skipInsufficientIncrease(delta, lastUploaded):
            AppLogger.log(
                category: "healthkit_sync",
                level: .info,
                message: "intraday step tick skipped (delta < 100)",
                userId: profile.id,
                metadata: baseMeta.merging([
                    "delta": "\(delta)",
                    "last_uploaded_steps": "\(lastUploaded)",
                ], uniquingKeysWith: { _, new in new })
            )
            return "skip_delta"
        case .upload:
            do {
                let tickId = try await intradayStepTicksRepository.appendTick(
                    calendarDate: now,
                    profileTimeZoneIdentifier: profile.timezone,
                    cumulativeSteps: steps,
                    recordedAt: now
                )
                IntradayStepTickUploadPolicy.markUploaded(
                    profileId: profile.id,
                    calendarDateStr: calendarDateStr,
                    steps: steps,
                    at: now
                )
                AppLogger.log(
                    category: "healthkit_sync",
                    level: .info,
                    message: "intraday step tick appended",
                    userId: profile.id,
                    metadata: baseMeta.merging([
                        "tick_id": tickId.uuidString,
                    ], uniquingKeysWith: { _, new in new })
                )
                return "appended"
            } catch {
                AppLogger.log(
                    category: "healthkit_sync",
                    level: .warning,
                    message: "intraday step tick append failed",
                    userId: profile.id,
                    metadata: baseMeta.merging([
                        "error": error.localizedDescription,
                    ], uniquingKeysWith: { _, new in new })
                )
                return "append_failed"
            }
        }
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
