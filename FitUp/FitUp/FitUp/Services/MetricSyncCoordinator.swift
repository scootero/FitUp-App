//
//  MetricSyncCoordinator.swift
//  FitUp
//
//  Slice 7 orchestration for HealthKit -> Supabase live metric sync.
//

import Foundation
import HealthKit
import SwiftUI
import UIKit

enum MetricSyncTrigger: String {
    case appLaunch
    case foreground
    case observer
    case manual
    case homeRefresh
    case backgroundObserver
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
    private let userBattleStepTotalsRepository = UserBattleStepTotalsRepository()
    private let calendarRepository = CalendarRepository()

    private var activeProfile: Profile?
    private var hasObserverPipeline = false
    private var isSyncing = false
    private var needsResync = false
    private var lastSyncAt: Date?
    private var lastObserverWakeAt: Date?
    private var lastSyncCompletedAt: Date?
    private var scenePhaseRaw: String = "active"
    private var pendingObserverPreReadCount = 0

    func updateScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active: scenePhaseRaw = "active"
        case .inactive: scenePhaseRaw = "inactive"
        case .background: scenePhaseRaw = "background"
        @unknown default: scenePhaseRaw = "unknown"
        }
    }

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
                level: .debug,
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
        pendingObserverPreReadCount = 2
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
                level: .debug,
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
                level: .debug,
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
                level: .debug,
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

        let observerTrigger: MetricSyncTrigger = scenePhaseRaw == "active" ? .observer : .backgroundObserver
        await requestSync(trigger: observerTrigger, force: true)

        await MainActor.run {
            if backgroundTaskId != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskId)
            }
        }
    }

    private func performSync(trigger: MetricSyncTrigger) async {
        guard let profile = activeProfile else { return }

        let syncStarted = Date()
        let diagnosticsSession = HealthKitSyncSessionContext.begin()
        diagnosticsSession.observerPreReadQueryCount = pendingObserverPreReadCount
        pendingObserverPreReadCount = 0
        defer { HealthKitSyncSessionContext.end() }

        let phaseRaw = scenePhaseRaw
        let environment = await MainActor.run {
            HealthKitEnvironmentSnapshot.captureStored(scenePhaseRaw: phaseRaw)
        }

        AppLogger.log(
            category: "healthkit_sync",
            level: .debug,
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
            diagnosticsSession.stepsReadOk = true
        } catch {
            handleHealthReadError(error, profile: profile, metricType: .steps)
        }

        let intradayTickLogSummary = await appendIntradayStepTickIfEligible(
            profile: profile,
            stepsTotal: stepsTotal,
            trigger: trigger
        )
        diagnosticsSession.intradayTickOutcome = intradayTickLogSummary

        do {
            caloriesTotal = try await HealthKitService.fetchTodayActiveCalories()
            diagnosticsSession.caloriesReadOk = true
        } catch {
            handleHealthReadError(error, profile: profile, metricType: .activeCalories)
        }

        diagnosticsSession.publicDailyAttempted = true
        if stepsTotal == nil && caloriesTotal == nil {
            diagnosticsSession.writesSkippedNil = 1
            diagnosticsSession.nilPreventedPublicDaily = 1
        } else if stepsTotal == nil || caloriesTotal == nil {
            diagnosticsSession.nilPreventedPublicDaily = 1
        }

        do {
            if stepsTotal != nil || caloriesTotal != nil {
                try await publicDailyActivityRepository.upsertMyPublicDailyActivity(
                    userId: profile.id,
                    activeDate: PublicDailyActivityRepository.activeDateString(for: profile),
                    steps: stepsTotal,
                    activeCalories: caloriesTotal
                )
                diagnosticsSession.publicDailyWritten = true
                HealthKitDiagnosticsStore.markBackendWriteSuccess()
            }
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
                let dailyCounts = try await userDailyStepTotalsRepository.syncRollingSevenCalendarDays(profile: profile)
                diagnosticsSession.dailyTotalsDaysOk = dailyCounts.ok
                diagnosticsSession.dailyTotalsDaysSkipped = dailyCounts.skipped
                diagnosticsSession.dailyTotalsDaysSkippedHK6 = dailyCounts.skippedHK6
                MetricSyncUploadPolicy.markRollingDailyTotalsSynced(
                    profileId: profile.id,
                    calendarDateStr: calendarDateStr
                )
                let battleCounts = await syncProvisionalBattleStepTotals(profile: profile, endDateKey: calendarDateStr)
                diagnosticsSession.battleDaysOk = battleCounts.ok
                diagnosticsSession.battleDaysSkippedHK6 = battleCounts.skippedHK6
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

        let matchSyncResult = await matchDayRepository.syncActiveMatchTotals(
            currentUserId: profile.id,
            stepsTotal: stepsTotal,
            caloriesTotal: caloriesTotal
        )
        var writes = matchSyncResult.writes
        diagnosticsSession.battleDaysSkipped = matchSyncResult.writesSkippedNil
        diagnosticsSession.matchWrites = writes.count
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
                    diagnosticsSession.historicalSkipped += 1
                    continue
                }
            }

            do {
                try await matchDayRepository.confirmHistoricalDayTotal(
                    matchDayId: target.matchDayId,
                    userId: profile.id,
                    metricTotal: total
                )
                diagnosticsSession.historicalConfirmed += 1
                HealthKitDiagnosticsStore.markBackendWriteSuccess()
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
                diagnosticsSession.snapshotWrites += results.count
                HealthKitDiagnosticsStore.markBackendWriteSuccess()
                for result in results {
                    if result.wasUpdated {
                        snapshotUpdated += 1
                    } else {
                        snapshotInserted += 1
                    }
                    AppLogger.log(
                        category: "healthkit_sync",
                        level: .debug,
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
            diagnosticsSession.baselinesAttempted = true
            let stepsAvg7 = try? await HealthKitService.fetchNDayStepAverage(days: 7)
            let stepsAvg30 = try? await HealthKitService.fetchNDayStepAverage(days: 30)
            let stepsAvg90 = try? await HealthKitService.fetchNDayStepAverage(days: 90)
            let caloriesAverage = try? await HealthKitService.fetchSevenDayActiveCaloriesAverage()
            if stepsAvg7 == nil { diagnosticsSession.nilPreventedBaselines += 1 }
            if stepsAvg30 == nil { diagnosticsSession.nilPreventedBaselines += 1 }
            if stepsAvg90 == nil { diagnosticsSession.nilPreventedBaselines += 1 }
            if caloriesAverage == nil { diagnosticsSession.nilPreventedBaselines += 1 }
            try await snapshotRepository.upsertRollingBaselines(
                userId: profile.id,
                stepsAverage7d: stepsAvg7,
                stepsAverage30d: stepsAvg30,
                stepsAverage90d: stepsAvg90,
                caloriesAverage: caloriesAverage
            )
            HealthKitDiagnosticsStore.markBackendWriteSuccess()
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
        var summaryMeta: [String: String] = [
            "trigger": trigger.rawValue,
            "pipeline": "MetricSyncCoordinator.performSync",
            "duration_ms": "\(durationMs)",
            "steps_today": stepsTotal.map(String.init) ?? "nil",
            "active_calories_today": caloriesTotal.map(String.init) ?? "nil",
            "historical_targets": "\(historicalTargets.count)",
            "snapshot_inserted": "\(snapshotInserted)",
            "snapshot_updated": "\(snapshotUpdated)",
        ]
        summaryMeta.merge(environment.metadata) { _, new in new }
        summaryMeta.merge(diagnosticsSession.summaryMetadata) { _, new in new }

        let summaryLevel: LogLevel =
            diagnosticsSession.stepsReadOk
            && diagnosticsSession.caloriesReadOk
            && diagnosticsSession.hkError6Count == 0
            ? .info
            : .warning
        AppLogger.log(
            category: "healthkit_sync",
            level: summaryLevel,
            message: "healthkit_sync_summary",
            userId: profile.id,
            metadata: summaryMeta
        )

        await MainActor.run {
            NotificationCenter.default.post(name: .fitupMetricSyncDidComplete, object: nil)
        }

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
                level: .debug,
                message: "intraday step tick skipped (unchanged vs last upload)",
                userId: profile.id,
                metadata: baseMeta
            )
            return "skip_unchanged"
        case let .skipDebounce(remainingSeconds):
            AppLogger.log(
                category: "healthkit_sync",
                level: .debug,
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
                level: .debug,
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
                    level: .debug,
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

    private func syncProvisionalBattleStepTotals(profile: Profile, endDateKey: String) async -> HealthKitDaySyncCounts {
        var empty = HealthKitDaySyncCounts()
        let tzId = profile.timezone
        let timeZone = (tzId.flatMap { TimeZone(identifier: $0) }) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let endDate = dateFromCalendarDateKey(endDateKey, calendar: calendar) else { return empty }
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: endDate) else { return empty }
        let startKey = PublicDailyActivityRepository.localCalendarDateString(
            for: startDate,
            timeZoneIdentifier: tzId
        )
        let battleKeys = await calendarRepository.fetchStepsBattleDateKeys(
            currentUserId: profile.id,
            startDateKey: startKey,
            endDateKey: endDateKey
        )
        return await userBattleStepTotalsRepository.syncProvisionalBattleDays(
            profile: profile,
            battleDateKeys: battleKeys
        )
    }

    private func dateFromCalendarDateKey(_ key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]),
              let m = Int(parts[1]),
              let d = Int(parts[2])
        else { return nil }
        return calendar.date(from: DateComponents(year: y, month: m, day: d))
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
        var meta: [String: String] = [
            "metric_type": metricType.rawValue,
            "error": error.localizedDescription,
            "error_type": String(describing: type(of: error)),
        ]
        if let hk = error as? HKError {
            meta["hk_error_code"] = "\(hk.code.rawValue)"
        }
        let logLevel: LogLevel = HealthKitSyncSessionContext.hasActiveSession && error.isHealthKitProtectedDataUnavailable
            ? .debug
            : level
        AppLogger.log(
            category: "healthkit_sync",
            level: logLevel,
            message: "metric read skipped during sync",
            userId: profile.id,
            metadata: meta
        )
    }
}
