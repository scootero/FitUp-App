//
//  HealthKitService.swift
//  FitUp
//
//  Slice 7: HealthKit reads + observer delivery for live sync.
//

import Foundation
import HealthKit

// MARK: - Health screen summaries (Slice 12)

struct HealthSleepStagePercentages: Equatable {
    var deep: Double
    var core: Double
    var rem: Double
    var awake: Double
}

/// Stage slice for the last-night hypnogram (chronological segments).
enum HealthSleepTimelineStage: String, Equatable {
    case deep
    case core
    case rem
    case awake
}

struct HealthSleepTimelineSegment: Equatable {
    let start: Date
    let end: Date
    let stage: HealthSleepTimelineStage

    var duration: TimeInterval { end.timeIntervalSince(start) }
}

/// Deep / Light (core + fallback asleep) / REM — percents are % of total sleep (awake excluded).
struct SleepRatioBreakdown: Equatable {
    var deepHours: Double
    var lightHours: Double
    var remHours: Double
    var deepPercent: Double
    var lightPercent: Double
    var remPercent: Double
}

struct HealthSleepSummary: Equatable {
    /// Mean hours asleep across the last `nights` calendar days (0 if no data).
    var averageHoursLastNights: Double
    /// Sample standard deviation of nightly hours (0 if &lt; 2 nights of data).
    var varianceHours: Double
    /// Aggregate stage mix over the 7 wake days (percentages sum to ~100).
    var stagePercentagesSevenNight: HealthSleepStagePercentages
    /// Longest contiguous asleep hours for **today’s** wake day (primary sleep; aligns with Apple Health headline).
    var lastNightAsleepHours: Double?
    /// Hours asleep per wake day, **oldest first** (same order as 7-day charts).
    var nightlyAsleepHoursOldestFirst: [Double]
    /// Stage mix for `lastNightAsleepHours` only; nil when no last-night data.
    var lastNightStagePercentages: HealthSleepStagePercentages?
    /// Chronological segments for the last wake night (for hypnogram); empty if none.
    var lastNightTimeline: [HealthSleepTimelineSegment]
    /// Deep / Light / REM for the selected last night; nil when no data.
    var lastNightSleepRatio: SleepRatioBreakdown?
}

struct HealthHRZoneRow: Identifiable, Equatable {
    let id: Int
    let label: String
    let valueLabel: String
    let percent: Double
}

enum HealthMetricType: String {
    case steps
    case activeCalories = "active_calories"
}

enum HealthKitService {
    private static let store = HKHealthStore()
    private static var observerQueries: [HKQuantityTypeIdentifier: HKObserverQuery] = [:]

    static var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// Read types requested by `requestAuthorization()` (single source of truth).
    private static var readAuthorizationTypes: Set<HKObjectType> {
        [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
            HKObjectType.workoutType(),
        ]
    }

    /// True if any requested read type is still `notDetermined` (user has not been through the system prompt).
    private static func anyReadTypeIsNotDetermined() -> Bool {
        for objectType in readAuthorizationTypes {
            if store.authorizationStatus(for: objectType) == .notDetermined {
                return true
            }
        }
        return false
    }

    /// Calls `requestAuthorization()` only when at least one read type is `notDetermined`, to avoid redundant prompts after denial.
    static func requestAuthorizationIfNeeded() async {
        guard isHealthDataAvailable else { return }
        guard anyReadTypeIsNotDetermined() else { return }
        do {
            try await requestAuthorization()
        } catch {
            // Denied, unavailable, or other; Health screen / banner handle recovery.
        }
    }

    /// Requests read access for v1 HealthKit types (fitup-docs-pack §11).
    static func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }

        try await store.requestAuthorization(toShare: [], read: readAuthorizationTypes)
        await configureBackgroundDelivery()
    }

    static func startMetricObservers(
        onUpdate: @escaping @Sendable (HealthMetricType) async -> Void
    ) async {
        guard isHealthDataAvailable else { return }
        stopMetricObservers()

        for metric in observedMetrics {
            guard let quantityType = HKObjectType.quantityType(forIdentifier: metric.identifier) else {
                continue
            }

            let query = HKObserverQuery(sampleType: quantityType, predicate: nil) { _, completionHandler, error in
                if let error {
                    var meta: [String: String] = [
                        "metric_type": metric.metricType.rawValue,
                        "error": error.localizedDescription,
                    ]
                    if let hk = error as? HKError {
                        meta["hk_error_code"] = "\(hk.code.rawValue)"
                        meta["hk_error_domain"] = String(describing: hk.code)
                    }
                    AppLogger.log(
                        category: "healthkit_sync",
                        level: .warning,
                        message: "health observer callback failed",
                        metadata: meta
                    )
                    completionHandler()
                    return
                }

                Task {
                    await onUpdate(metric.metricType)
                    completionHandler()
                }
            }

            observerQueries[metric.identifier] = query
            store.execute(query)
        }

        await configureBackgroundDelivery()

        AppLogger.log(
            category: "healthkit_sync",
            level: .info,
            message: "metric observers started",
            metadata: [
                "pipeline": "HealthKitService.startMetricObservers",
                "hk_observer_count": "\(observerQueries.count)",
                "hk_observer_types": "stepCount, activeEnergyBurned",
                "background_delivery_frequency": "immediate",
            ]
        )
    }

    static func stopMetricObservers() {
        let count = observerQueries.count
        for query in observerQueries.values {
            store.stop(query)
        }
        observerQueries.removeAll()
        if count > 0 {
            AppLogger.log(
                category: "healthkit_sync",
                level: .info,
                message: "metric observers stopped",
                metadata: [
                    "pipeline": "HealthKitService.stopMetricObservers",
                    "stopped_count": "\(count)",
                ]
            )
        }
    }

    /// Returns the average daily steps over the last 7 calendar days (including today).
    static func fetchSevenDayStepAverage() async throws -> Double {
        try await fetchSevenDayAverage(
            quantityIdentifier: .stepCount,
            unit: .count()
        )
    }

    /// Returns the average daily active calories over the last 7 calendar days (including today).
    static func fetchSevenDayActiveCaloriesAverage() async throws -> Double {
        try await fetchSevenDayAverage(
            quantityIdentifier: .activeEnergyBurned,
            unit: .kilocalorie()
        )
    }

    /// Returns today's step total from HealthKit.
    static func fetchTodayStepCount() async throws -> Int {
        let total = try await fetchTodayTotal(
            quantityIdentifier: .stepCount,
            unit: .count()
        )
        let rounded = Int(total.rounded())
        AppLogger.log(
            category: "healthkit_read",
            level: .debug,
            message: "today steps read",
            metadata: ["value": "\(rounded)"]
        )
        return rounded
    }

    /// Returns today's active calories total from HealthKit (kcal).
    static func fetchTodayActiveCalories() async throws -> Int {
        let total = try await fetchTodayTotal(
            quantityIdentifier: .activeEnergyBurned,
            unit: .kilocalorie()
        )
        let rounded = Int(total.rounded())
        AppLogger.log(
            category: "healthkit_read",
            level: .debug,
            message: "today active calories read",
            metadata: ["value": "\(rounded)"]
        )
        return rounded
    }

    /// Returns yesterday's full-day step total (00:00 -> 24:00 local day).
    static func fetchYesterdayStepCount() async throws -> Int {
        let calendarDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return try await fetchMetricTotal(metricType: .steps, for: calendarDate)
    }

    /// Returns yesterday's full-day active calories total (00:00 -> 24:00 local day).
    static func fetchYesterdayActiveCalories() async throws -> Int {
        let calendarDate = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        return try await fetchMetricTotal(metricType: .activeCalories, for: calendarDate)
    }

    /// Returns a full calendar-day total for the requested metric in the provided timezone.
    static func fetchMetricTotal(
        metricType: HealthMetricType,
        for calendarDate: Date,
        timeZone: TimeZone? = nil
    ) async throws -> Int {
        let quantityIdentifier: HKQuantityTypeIdentifier
        let unit: HKUnit
        switch metricType {
        case .steps:
            quantityIdentifier = .stepCount
            unit = .count()
        case .activeCalories:
            quantityIdentifier = .activeEnergyBurned
            unit = .kilocalorie()
        }

        let total = try await fetchCalendarDayTotal(
            quantityIdentifier: quantityIdentifier,
            unit: unit,
            calendarDate: calendarDate,
            timeZone: timeZone
        )
        return Int(total.rounded())
    }

    /// Most recent resting heart rate sample (bpm), if any.
    static func fetchRestingHeartRate() async throws -> Double? {
        guard isHealthDataAvailable else { throw HealthKitError.notAvailable }
        guard let quantityType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            throw HealthKitError.noStatisticsData
        }
        return try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: quantityType,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: mapHealthKitError(error, context: "fetchRestingHeartRate"))
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: bpm)
            }
            store.execute(query)
        }
    }

    /// Seven daily totals, **oldest first**, index 6 = today (`HealthScreen` week chart).
    static func fetchSevenDayStepsArray() async throws -> [Int] {
        try await fetchSevenDayDailyTotals(quantityIdentifier: .stepCount, unit: .count())
    }

    /// Seven daily active calorie totals (kcal), **oldest first**, index 6 = today.
    static func fetchSevenDayCaloriesArray() async throws -> [Int] {
        try await fetchSevenDayDailyTotals(quantityIdentifier: .activeEnergyBurned, unit: .kilocalorie())
    }

    /// Best single-day and best rolling 7-day totals from Apple Health (up to 10 years of daily sums).
    static func fetchAllTimeBestsFromHealth() async throws -> HealthKitAllTimeBests {
        guard isHealthDataAvailable else { throw HealthKitError.notAvailable }
        let calendar = Calendar.current
        let endDate = Date()
        let todayStart = calendar.startOfDay(for: endDate)
        guard let startDate = calendar.date(byAdding: .year, value: -10, to: todayStart) else {
            throw HealthKitError.invalidDateRange
        }

        async let stepsDaily = fetchDailyTotalsInRange(
            quantityIdentifier: .stepCount,
            unit: .count(),
            startDate: startDate,
            endDate: endDate
        )
        async let calsDaily = fetchDailyTotalsInRange(
            quantityIdentifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            startDate: startDate,
            endDate: endDate
        )

        let s = try await stepsDaily
        let c = try await calsDaily

        return HealthKitAllTimeBests(
            stepsBestDay: bestSingleDay(from: s),
            stepsBestWeek: bestRollingSevenDaySum(from: s),
            calsBestDay: bestSingleDay(from: c),
            calsBestWeek: bestRollingSevenDaySum(from: c)
        )
    }

    /// Sleep aggregates for the Health screen (last `nights` local calendar days).
    static func fetchSleepSummary(nights: Int = 7) async throws -> HealthSleepSummary {
        guard isHealthDataAvailable else { throw HealthKitError.notAvailable }
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.noStatisticsData
        }
        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -(nights + 2), to: calendar.startOfDay(for: endDate)) else {
            throw HealthKitError.invalidDateRange
        }

        let samples: [HKCategorySample] = try await fetchSleepCategorySamples(type: sleepType, start: startDate, end: endDate)

        let dayStarts: [Date] = (0..<nights).compactMap { i in
            calendar.date(byAdding: .day, value: -(nights - 1 - i), to: calendar.startOfDay(for: endDate))
        }

        var breakdownByWakeDay: [Date: CanonicalNightMetrics] = [:]
        for d in dayStarts {
            breakdownByWakeDay[d] = canonicalMetricsForWakeDay(samples: samples, wakeDay: d, calendar: calendar)
        }

        var nightlyHours: [Double] = []
        for day in dayStarts {
            let hrs = (breakdownByWakeDay[day]?.totalAsleepSeconds ?? 0) / 3600
            nightlyHours.append(hrs)
        }

        let sumH = nightlyHours.reduce(0, +)
        // Average over exactly `nights` wake days (including zero-sleep days). Differs from Health averages that omit missing nights.
        let avg = nightlyHours.isEmpty ? 0 : sumH / Double(nightlyHours.count)
        let variance: Double = {
            guard nightlyHours.count >= 2 else { return 0 }
            let mean = avg
            let v = nightlyHours.map { pow($0 - mean, 2) }.reduce(0, +) / Double(nightlyHours.count - 1)
            return sqrt(v)
        }()

        var stageSecondsSevenNight: [String: Double] = ["deep": 0, "core": 0, "rem": 0, "awake": 0]
        for day in dayStarts {
            guard let m = breakdownByWakeDay[day] else { continue }
            stageSecondsSevenNight["deep", default: 0] += m.deepSeconds
            stageSecondsSevenNight["core", default: 0] += m.coreSeconds
            stageSecondsSevenNight["rem", default: 0] += m.remSeconds
            stageSecondsSevenNight["awake", default: 0] += m.awakeSeconds
            // Light (fallback asleep) rolls into "core" bucket for aggregate mix to match deep/core/rem/awake chart semantics.
            stageSecondsSevenNight["core", default: 0] += m.lightSeconds
        }

        let totalStage7 = stageSecondsSevenNight.values.reduce(0, +)
        let pct7: (Double) -> Double = { totalStage7 > 0 ? ($0 / totalStage7) * 100 : 0 }
        let stagesSevenNight = HealthSleepStagePercentages(
            deep: pct7(stageSecondsSevenNight["deep"] ?? 0),
            core: pct7(stageSecondsSevenNight["core"] ?? 0),
            rem: pct7(stageSecondsSevenNight["rem"] ?? 0),
            awake: pct7(stageSecondsSevenNight["awake"] ?? 0)
        )

        // “Last night” = **today’s** wake day only (no fallback to prior days). Duration = longest contiguous asleep run
        // (primary sleep), matching Apple Health’s headline figure; hypnogram/ratio use that same run.
        let targetLastNightWakeDay = dayStarts.last
        let todayMetrics = targetLastNightWakeDay.flatMap { breakdownByWakeDay[$0] }
        let runTimeline = todayMetrics.map { longestAsleepRunTimeline(from: $0.timeline) } ?? []
        let runMetrics = runTimeline.isEmpty ? nil : canonicalMetricsFromAsleepRunSegments(runTimeline)

        let lastNightHours: Double? = {
            guard let m = todayMetrics, m.totalAsleepSeconds > 0, let r = runMetrics, r.totalAsleepSeconds > 0 else { return nil }
            return r.totalAsleepSeconds / 3600
        }()

        var lastNightStageSeconds: [String: Double] = ["deep": 0, "core": 0, "rem": 0, "awake": 0]
        var lastNightTimeline: [HealthSleepTimelineSegment] = []
        var lastNightRatio: SleepRatioBreakdown?

        if let r = runMetrics {
            lastNightTimeline = r.timeline
            lastNightStageSeconds["deep"] = r.deepSeconds
            lastNightStageSeconds["core"] = r.coreSeconds + r.lightSeconds
            lastNightStageSeconds["rem"] = r.remSeconds
            lastNightStageSeconds["awake"] = r.awakeSeconds
            lastNightRatio = sleepRatioBreakdown(from: r)
        }

        let totalStageLN = lastNightStageSeconds.values.reduce(0, +)
        let pctLN: (Double) -> Double = { totalStageLN > 0 ? ($0 / totalStageLN) * 100 : 0 }
        let lastNightStages: HealthSleepStagePercentages? = (runMetrics != nil && totalStageLN > 0)
            ? HealthSleepStagePercentages(
                deep: pctLN(lastNightStageSeconds["deep"] ?? 0),
                core: pctLN(lastNightStageSeconds["core"] ?? 0),
                rem: pctLN(lastNightStageSeconds["rem"] ?? 0),
                awake: pctLN(lastNightStageSeconds["awake"] ?? 0)
            )
            : nil

        #if DEBUG
        logSleepAuditDebug(
            queryStart: startDate,
            queryEnd: endDate,
            samples: samples,
            dayStarts: dayStarts,
            breakdownByWakeDay: breakdownByWakeDay,
            lastWakeDay: targetLastNightWakeDay,
            averageHours: avg,
            nightlyHours: nightlyHours,
            lastRatio: lastNightRatio
        )
        #endif

        return HealthSleepSummary(
            averageHoursLastNights: avg,
            varianceHours: variance,
            stagePercentagesSevenNight: stagesSevenNight,
            lastNightAsleepHours: lastNightHours,
            nightlyAsleepHoursOldestFirst: nightlyHours,
            lastNightStagePercentages: lastNightStages,
            lastNightTimeline: lastNightTimeline,
            lastNightSleepRatio: lastNightRatio
        )
    }

    // MARK: - Canonical sleep (wake-day timeline)

    private struct CanonicalNightMetrics {
        var totalAsleepSeconds: Double
        var deepSeconds: Double
        var coreSeconds: Double
        var lightSeconds: Double
        var remSeconds: Double
        var awakeSeconds: Double
        var inBedSeconds: Double
        var timeline: [HealthSleepTimelineSegment]
        var longestAsleepContiguousSeconds: TimeInterval
    }

    private static func sleepRatioBreakdown(from m: CanonicalNightMetrics) -> SleepRatioBreakdown? {
        let total = m.deepSeconds + m.lightSeconds + m.coreSeconds + m.remSeconds
        guard total > 0 else { return nil }
        let lightTotal = m.lightSeconds + m.coreSeconds
        let pct: (Double) -> Double = { total > 0 ? ($0 / total) * 100 : 0 }
        return SleepRatioBreakdown(
            deepHours: m.deepSeconds / 3600,
            lightHours: lightTotal / 3600,
            remHours: m.remSeconds / 3600,
            deepPercent: pct(m.deepSeconds),
            lightPercent: pct(lightTotal),
            remPercent: pct(m.remSeconds)
        )
    }

    private static func canonicalMetricsForWakeDay(samples: [HKCategorySample], wakeDay: Date, calendar: Calendar) -> CanonicalNightMetrics {
        let daySamples = samples.filter { calendar.startOfDay(for: $0.endDate) == wakeDay }
        guard !daySamples.isEmpty else {
            return CanonicalNightMetrics(
                totalAsleepSeconds: 0, deepSeconds: 0, coreSeconds: 0, lightSeconds: 0, remSeconds: 0,
                awakeSeconds: 0, inBedSeconds: 0, timeline: [], longestAsleepContiguousSeconds: 0
            )
        }

        let hasStagedSleep = daySamples.contains { sample in
            guard let v = HKCategoryValueSleepAnalysis(rawValue: sample.value) else { return false }
            switch v {
            case .asleepDeep, .asleepCore, .asleepREM: return true
            default: return false
            }
        }

        var boundaries = Set<Date>()
        for s in daySamples {
            boundaries.insert(s.startDate)
            boundaries.insert(s.endDate)
        }
        let sortedBounds = boundaries.sorted()
        guard sortedBounds.count >= 2 else {
            return CanonicalNightMetrics(
                totalAsleepSeconds: 0, deepSeconds: 0, coreSeconds: 0, lightSeconds: 0, remSeconds: 0,
                awakeSeconds: 0, inBedSeconds: 0, timeline: [], longestAsleepContiguousSeconds: 0
            )
        }

        var deepSec: Double = 0
        var coreSec: Double = 0
        var lightSec: Double = 0
        var remSec: Double = 0
        var awakeSec: Double = 0
        var inBedSec: Double = 0
        var timelinePieces: [HealthSleepTimelineSegment] = []

        for i in 0..<(sortedBounds.count - 1) {
            let a = sortedBounds[i]
            let b = sortedBounds[i + 1]
            let duration = b.timeIntervalSince(a)
            guard duration > 1e-9 else { continue }
            let mid = a.addingTimeInterval(duration / 2)
            guard let winner = winningSleepCategory(at: mid, daySamples: daySamples, hasStagedSleep: hasStagedSleep) else { continue }

            switch winner {
            case .asleepDeep:
                deepSec += duration
                timelinePieces.append(HealthSleepTimelineSegment(start: a, end: b, stage: .deep))
            case .asleepCore:
                coreSec += duration
                timelinePieces.append(HealthSleepTimelineSegment(start: a, end: b, stage: .core))
            case .asleepREM:
                remSec += duration
                timelinePieces.append(HealthSleepTimelineSegment(start: a, end: b, stage: .rem))
            case .asleepUnspecified:
                lightSec += duration
                timelinePieces.append(HealthSleepTimelineSegment(start: a, end: b, stage: .core))
            case .awake:
                awakeSec += duration
                timelinePieces.append(HealthSleepTimelineSegment(start: a, end: b, stage: .awake))
            case .inBed:
                inBedSec += duration
            @unknown default:
                break
            }
        }

        let mergedTimeline = mergeAdjacentTimelineSegments(timelinePieces)
        let totalAsleep = deepSec + coreSec + lightSec + remSec
        let longestAsleep = longestContiguousAsleepRun(in: mergedTimeline)

        return CanonicalNightMetrics(
            totalAsleepSeconds: totalAsleep,
            deepSeconds: deepSec,
            coreSeconds: coreSec,
            lightSeconds: lightSec,
            remSeconds: remSec,
            awakeSeconds: awakeSec,
            inBedSeconds: inBedSec,
            timeline: mergedTimeline,
            longestAsleepContiguousSeconds: longestAsleep
        )
    }

    /// Higher wins when multiple samples cover the same instant (dedupes overlapping sources).
    private static func sleepCategoryPriority(_ v: HKCategoryValueSleepAnalysis) -> Int {
        switch v {
        case .asleepDeep: return 60
        case .asleepREM: return 50
        case .asleepCore: return 40
        case .awake: return 30
        case .asleepUnspecified: return 20
        case .inBed: return 10
        @unknown default: return 0
        }
    }

    /// When `hasStagedSleep` is true, generic asleep only applies where no staged deep/core/rem/awake covers `mid`.
    private static func winningSleepCategory(at mid: Date, daySamples: [HKCategorySample], hasStagedSleep: Bool) -> HKCategoryValueSleepAnalysis? {
        let covering = daySamples.filter { $0.startDate <= mid && mid < $0.endDate }
        guard !covering.isEmpty else { return nil }
        if !hasStagedSleep {
            return covering.compactMap { s -> (HKCategorySample, HKCategoryValueSleepAnalysis)? in
                guard let c = s.resolvedSleepCategory else { return nil }
                return (s, c)
            }.max(by: { sleepCategoryPriority($0.1) < sleepCategoryPriority($1.1) })?.1
        }
        let staged = covering.compactMap { s -> (HKCategorySample, HKCategoryValueSleepAnalysis)? in
            guard let c = s.resolvedSleepCategory else { return nil }
            switch c {
            case .asleepDeep, .asleepCore, .asleepREM, .awake: return (s, c)
            default: return nil
            }
        }
        if let best = staged.max(by: { sleepCategoryPriority($0.1) < sleepCategoryPriority($1.1) }) {
            return best.1
        }
        let genericOrBed = covering.compactMap { s -> (HKCategorySample, HKCategoryValueSleepAnalysis)? in
            guard let c = s.resolvedSleepCategory else { return nil }
            switch c {
            case .asleepUnspecified, .inBed: return (s, c)
            default: return nil
            }
        }
        return genericOrBed.max(by: { sleepCategoryPriority($0.1) < sleepCategoryPriority($1.1) })?.1
    }

    private static func mergeAdjacentTimelineSegments(_ segments: [HealthSleepTimelineSegment]) -> [HealthSleepTimelineSegment] {
        let sorted = segments.sorted { $0.start < $1.start }
        var out: [HealthSleepTimelineSegment] = []
        for seg in sorted {
            guard let last = out.last else {
                out.append(seg)
                continue
            }
            if last.stage == seg.stage, abs(last.end.timeIntervalSince(seg.start)) < 1e-6 {
                out[out.count - 1] = HealthSleepTimelineSegment(start: last.start, end: seg.end, stage: seg.stage)
            } else {
                out.append(seg)
            }
        }
        return out
    }

    private static func longestContiguousAsleepRun(in timeline: [HealthSleepTimelineSegment]) -> TimeInterval {
        longestAsleepRunTimeline(from: timeline).reduce(0) { $0 + $1.duration }
    }

    /// Contiguous asleep segments with maximum total duration (primary sleep window); empty if none.
    private static func longestAsleepRunTimeline(from mergedTimeline: [HealthSleepTimelineSegment]) -> [HealthSleepTimelineSegment] {
        let sorted = mergedTimeline.sorted { $0.start < $1.start }
        var best: [HealthSleepTimelineSegment] = []
        var current: [HealthSleepTimelineSegment] = []
        var currentDur: TimeInterval = 0
        var bestDur: TimeInterval = 0
        for seg in sorted {
            let asleep = seg.stage == .deep || seg.stage == .core || seg.stage == .rem
            if asleep {
                current.append(seg)
                currentDur += seg.duration
            } else {
                if currentDur > bestDur {
                    bestDur = currentDur
                    best = current
                }
                current = []
                currentDur = 0
            }
        }
        if currentDur > bestDur {
            best = current
        }
        return best
    }

    /// Stage totals and timeline for one contiguous asleep run (hypnogram + ratio match `lastNightAsleepHours`).
    private static func canonicalMetricsFromAsleepRunSegments(_ segments: [HealthSleepTimelineSegment]) -> CanonicalNightMetrics {
        var deepSec: Double = 0
        var coreSec: Double = 0
        var remSec: Double = 0
        for seg in segments {
            switch seg.stage {
            case .deep: deepSec += seg.duration
            case .core: coreSec += seg.duration
            case .rem: remSec += seg.duration
            case .awake: break
            }
        }
        let total = deepSec + coreSec + remSec
        return CanonicalNightMetrics(
            totalAsleepSeconds: total,
            deepSeconds: deepSec,
            coreSeconds: coreSec,
            lightSeconds: 0,
            remSeconds: remSec,
            awakeSeconds: 0,
            inBedSeconds: 0,
            timeline: segments,
            longestAsleepContiguousSeconds: total
        )
    }

    #if DEBUG
    private static func logSleepAuditDebug(
        queryStart: Date,
        queryEnd: Date,
        samples: [HKCategorySample],
        dayStarts: [Date],
        breakdownByWakeDay: [Date: CanonicalNightMetrics],
        lastWakeDay: Date?,
        averageHours: Double,
        nightlyHours: [Double],
        lastRatio: SleepRatioBreakdown?
    ) {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var lines: [String] = []
        lines.append("=== Sleep audit (DEBUG) ===")
        lines.append("query: \(fmt.string(from: queryStart)) .. \(fmt.string(from: queryEnd))")
        lines.append("raw sample count: \(samples.count)")
        for (idx, s) in samples.enumerated() {
            let v = HKCategoryValueSleepAnalysis(rawValue: s.value)
            let name = String(describing: v)
            let src = s.sourceRevision.source.name
            lines.append("  [\(idx)] \(fmt.string(from: s.startDate)) .. \(fmt.string(from: s.endDate)) dur=\(String(format: "%.1f", s.endDate.timeIntervalSince(s.startDate)))s \(name) source=\(src)")
        }
        let cal = Calendar.current
        for d in dayStarts {
            guard let m = breakdownByWakeDay[d] else { continue }
            let key = ISO8601DateFormatter().string(from: d)
            let rawOnDay = samples.filter { cal.startOfDay(for: $0.endDate) == d }
            var stagedOnly: Double = 0
            var genericOnly: Double = 0
            for s in rawOnDay {
                let dur = s.endDate.timeIntervalSince(s.startDate)
                guard dur > 0, let v = HKCategoryValueSleepAnalysis(rawValue: s.value) else { continue }
                switch v {
                case .asleepDeep, .asleepCore, .asleepREM: stagedOnly += dur
                case .asleepUnspecified: genericOnly += dur
                default: break
                }
            }
            lines.append("wakeDay \(key): canonical_total_h=\(String(format: "%.3f", m.totalAsleepSeconds / 3600)) staged_raw_sum_h=\(String(format: "%.3f", stagedOnly / 3600)) generic_raw_sum_h=\(String(format: "%.3f", genericOnly / 3600)) longest_asleep_h=\(String(format: "%.3f", m.longestAsleepContiguousSeconds / 3600))")
        }
        lines.append("7-night avg h=\(String(format: "%.3f", averageHours)) nightly_h=[\(nightlyHours.map { String(format: "%.3f", $0) }.joined(separator: ","))]")
        if let w = lastWakeDay {
            lines.append("selected lastWakeDay=\(ISO8601DateFormatter().string(from: w))")
        }
        if let r = lastRatio {
            lines.append("Sleep Ratio: deep \(String(format: "%.1f%%", r.deepPercent)) \(String(format: "%.2f", r.deepHours))h | light \(String(format: "%.1f%%", r.lightPercent)) \(String(format: "%.2f", r.lightHours))h | rem \(String(format: "%.1f%%", r.remPercent)) \(String(format: "%.2f", r.remHours))h")
        }
        print(lines.joined(separator: "\n"))
    }
    #endif

    /// Heart-rate zone distribution from the most recent workout (percent of samples in each zone).
    static func fetchHRZoneRows(defaultMaxHeartRate: Double = 190) async throws -> [HealthHRZoneRow] {
        guard isHealthDataAvailable else { throw HealthKitError.notAvailable }
        guard let hrType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            throw HealthKitError.noStatisticsData
        }
        guard let workout = try await fetchMostRecentWorkout() else {
            return Self.emptyHRZoneRows
        }

        let samples: [HKQuantitySample] = try await fetchQuantitySamples(
            type: hrType,
            start: workout.startDate,
            end: workout.endDate
        )

        guard !samples.isEmpty else {
            return Self.emptyHRZoneRows
        }

        var buckets = [Int: Int]()
        for s in samples {
            let bpm = s.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
            let z = zoneIndex(bpm: bpm, maxHR: defaultMaxHeartRate)
            buckets[z, default: 0] += 1
        }

        let total = max(samples.count, 1)
        let labels = [
            "Zone 1 · Rest",
            "Zone 2 · Fat burn",
            "Zone 3 · Cardio",
            "Zone 4 · Peak",
            "Zone 5 · Max",
        ]
        return (0..<5).map { i in
            let c = buckets[i] ?? 0
            let p = Double(c) / Double(total) * 100
            return HealthHRZoneRow(
                id: i,
                label: labels[i],
                valueLabel: "\(Int(p.rounded()))%",
                percent: p
            )
        }
    }

    private static let emptyHRZoneRows: [HealthHRZoneRow] = [
        HealthHRZoneRow(id: 0, label: "Zone 1 · Rest", valueLabel: "0%", percent: 0),
        HealthHRZoneRow(id: 1, label: "Zone 2 · Fat burn", valueLabel: "0%", percent: 0),
        HealthHRZoneRow(id: 2, label: "Zone 3 · Cardio", valueLabel: "0%", percent: 0),
        HealthHRZoneRow(id: 3, label: "Zone 4 · Peak", valueLabel: "0%", percent: 0),
        HealthHRZoneRow(id: 4, label: "Zone 5 · Max", valueLabel: "0%", percent: 0),
    ]

    private static func zoneIndex(bpm: Double, maxHR: Double) -> Int {
        let pct = bpm / maxHR
        if pct < 0.6 { return 0 }
        if pct < 0.7 { return 1 }
        if pct < 0.8 { return 2 }
        if pct < 0.9 { return 3 }
        return 4
    }

    private static func fetchMostRecentWorkout() async throws -> HKWorkout? {
        let type = HKObjectType.workoutType()

        return try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: nil,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: mapHealthKitError(error, context: "fetchMostRecentWorkout"))
                    return
                }
                continuation.resume(returning: samples?.first as? HKWorkout)
            }
            store.execute(query)
        }
    }

    private static func fetchQuantitySamples(type: HKQuantityType, start: Date, end: Date) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: mapHealthKitError(error, context: "fetchQuantitySamples"))
                    return
                }
                let qs = (samples as? [HKQuantitySample]) ?? []
                continuation.resume(returning: qs)
            }
            store.execute(query)
        }
    }

    private static func fetchCategorySamples(type: HKCategoryType, start: Date, end: Date) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: mapHealthKitError(error, context: "fetchCategorySamples"))
                    return
                }
                let cs = (samples as? [HKCategorySample]) ?? []
                continuation.resume(returning: cs)
            }
            store.execute(query)
        }
    }

    /// Overlapping sleep samples (no `strictStartDate`) so segments that begin before the window still count.
    private static func fetchSleepCategorySamples(type: HKCategoryType, start: Date, end: Date) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: mapHealthKitError(error, context: "fetchSleepCategorySamples"))
                    return
                }
                let cs = (samples as? [HKCategorySample]) ?? []
                continuation.resume(returning: cs)
            }
            store.execute(query)
        }
    }

    private static func timelineStage(for value: Int) -> HealthSleepTimelineStage? {
        guard let v = HKCategoryValueSleepAnalysis(rawValue: value) else { return nil }
        switch v {
        case .asleepDeep:
            return .deep
        case .asleepCore, .asleepUnspecified:
            return .core
        case .asleepREM:
            return .rem
        case .awake:
            return .awake
        case .inBed:
            return nil
        @unknown default:
            return nil
        }
    }

    private static func asleepSecondsContribution(for value: Int, duration: TimeInterval) -> Double? {
        guard let v = HKCategoryValueSleepAnalysis(rawValue: value) else { return nil }
        switch v {
        case .asleepDeep, .asleepCore, .asleepREM, .asleepUnspecified:
            return duration
        case .awake, .inBed:
            return nil
        @unknown default:
            return nil
        }
    }

    private static func accumulateSleepStage(value: Int, duration: TimeInterval, into dict: inout [String: Double]) {
        guard let v = HKCategoryValueSleepAnalysis(rawValue: value) else { return }
        switch v {
        case .asleepDeep:
            dict["deep", default: 0] += duration
        case .asleepCore, .asleepUnspecified:
            dict["core", default: 0] += duration
        case .asleepREM:
            dict["rem", default: 0] += duration
        case .awake:
            dict["awake", default: 0] += duration
        case .inBed:
            break
        @unknown default:
            break
        }
    }

    /// One value per local calendar day from `startDate` through today (inclusive), **oldest first**.
    private static func fetchDailyTotalsInRange(
        quantityIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        endDate: Date
    ) async throws -> [Double] {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityIdentifier) else {
            throw typeError(for: quantityIdentifier)
        }

        let calendar = Calendar.current
        let anchorDate = calendar.startOfDay(for: endDate)
        let interval = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        let byDayStart: [Date: Double] = try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum],
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: mapHealthKitError(error, context: "fetchDailyTotalsInRange"))
                    return
                }

                var map: [Date: Double] = [:]
                collection?.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let dayStart = calendar.startOfDay(for: statistics.startDate)
                    let value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    map[dayStart] = value
                }
                continuation.resume(returning: map)
            }

            store.execute(query)
        }

        let lastDay = calendar.startOfDay(for: endDate)
        var daily: [Double] = []
        var d = calendar.startOfDay(for: startDate)
        while d <= lastDay {
            daily.append(byDayStart[d] ?? 0)
            guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return daily
    }

    private static func bestSingleDay(from daily: [Double]) -> Int? {
        guard let maxV = daily.max(), maxV > 0 else { return nil }
        return Int(maxV.rounded())
    }

    /// Maximum sum over any 7 consecutive calendar days (requires at least 7 days in range).
    private static func bestRollingSevenDaySum(from daily: [Double]) -> Int? {
        guard daily.count >= 7 else { return nil }
        var best = 0
        for i in 0...(daily.count - 7) {
            let sum = daily[i..<(i + 7)].reduce(0, +)
            best = max(best, Int(sum.rounded()))
        }
        return best > 0 ? best : nil
    }

    private static func fetchSevenDayDailyTotals(quantityIdentifier: HKQuantityTypeIdentifier, unit: HKUnit) async throws -> [Int] {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        var values: [Int] = []
        for offset in (0..<7).reversed() {
            guard let dayStart = calendar.date(byAdding: .day, value: -offset, to: todayStart) else {
                values.append(0)
                continue
            }
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
            let endBound = offset == 0 ? Date() : dayEnd
            let total = try await fetchCumulativeTotal(
                quantityIdentifier: quantityIdentifier,
                unit: unit,
                startDate: dayStart,
                endDate: endBound
            )
            values.append(Int(total.rounded()))
        }
        return values
    }

    private static var observedMetrics: [(identifier: HKQuantityTypeIdentifier, metricType: HealthMetricType)] {
        [
            (.stepCount, .steps),
            (.activeEnergyBurned, .activeCalories),
        ]
    }

    private static func fetchSevenDayAverage(
        quantityIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> Double {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }

        guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityIdentifier) else {
            throw typeError(for: quantityIdentifier)
        }

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: endDate)) else {
            throw HealthKitError.invalidDateRange
        }
        let anchorDate = calendar.startOfDay(for: endDate)
        let interval = DateComponents(day: 1)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum],
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: mapHealthKitError(error, context: "fetchSevenDayAverage"))
                    return
                }
                guard let collection else {
                    continuation.resume(throwing: HealthKitError.noStatisticsData)
                    return
                }

                var totalValue = 0.0
                var dayCount = 0.0
                collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let value = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    totalValue += value
                    dayCount += 1
                }

                guard dayCount > 0 else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: totalValue / dayCount)
            }

            store.execute(query)
        }
    }

    private static func fetchTodayTotal(
        quantityIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> Double {
        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = Date()
        return try await fetchCumulativeTotal(
            quantityIdentifier: quantityIdentifier,
            unit: unit,
            startDate: startDate,
            endDate: endDate
        )
    }

    private static func fetchPreviousDayTotal(
        quantityIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> Double {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: Date())
        guard let previousDayStart = calendar.date(byAdding: .day, value: -1, to: todayStart) else {
            throw HealthKitError.invalidDateRange
        }
        return try await fetchCumulativeTotal(
            quantityIdentifier: quantityIdentifier,
            unit: unit,
            startDate: previousDayStart,
            endDate: todayStart
        )
    }

    private static func fetchCalendarDayTotal(
        quantityIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        calendarDate: Date,
        timeZone: TimeZone?
    ) async throws -> Double {
        var calendar = Calendar.current
        calendar.timeZone = timeZone ?? .current
        let startDate = calendar.startOfDay(for: calendarDate)
        guard let endDate = calendar.date(byAdding: .day, value: 1, to: startDate) else {
            throw HealthKitError.invalidDateRange
        }
        return try await fetchCumulativeTotal(
            quantityIdentifier: quantityIdentifier,
            unit: unit,
            startDate: startDate,
            endDate: endDate
        )
    }

    private static func fetchCumulativeTotal(
        quantityIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        startDate: Date,
        endDate: Date
    ) async throws -> Double {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }
        guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityIdentifier) else {
            throw typeError(for: quantityIdentifier)
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: startDate,
            end: endDate,
            options: [.strictStartDate]
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum]
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: mapHealthKitError(error, context: "fetchCumulativeTotal"))
                    return
                }
                let total = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: total)
            }
            store.execute(query)
        }
    }

    private static func configureBackgroundDelivery() async {
        for metric in observedMetrics {
            guard let quantityType = HKObjectType.quantityType(forIdentifier: metric.identifier) else {
                continue
            }
            do {
                try await enableBackgroundDelivery(for: quantityType)
            } catch {
                AppLogger.log(
                    category: "healthkit_sync",
                    level: .warning,
                    message: "enable background delivery failed",
                    metadata: [
                        "metric_type": metric.metricType.rawValue,
                        "error": error.localizedDescription,
                    ]
                )
            }
        }
    }

    private static func enableBackgroundDelivery(for quantityType: HKQuantityType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.enableBackgroundDelivery(for: quantityType, frequency: .immediate) { success, error in
                if let error {
                    continuation.resume(throwing: mapHealthKitError(error, context: "enableBackgroundDelivery"))
                    return
                }
                guard success else {
                    continuation.resume(throwing: HealthKitError.backgroundDeliveryFailed)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    private static func logHealthKitQueryFailure(_ error: Error, context: String) {
        if let hk = error as? HKError {
            AppLogger.log(
                category: "healthkit_read",
                level: .warning,
                message: "HealthKit query failed",
                metadata: [
                    "context": context,
                    "hk_error_code": "\(hk.code.rawValue)",
                    "hk_error_domain": String(describing: hk.code),
                    "error": hk.localizedDescription,
                ]
            )
        } else {
            AppLogger.log(
                category: "healthkit_read",
                level: .warning,
                message: "HealthKit query failed",
                metadata: [
                    "context": context,
                    "error_type": String(describing: type(of: error)),
                    "error": error.localizedDescription,
                ]
            )
        }
    }

    private static func mapHealthKitError(_ error: Error, context: String) -> Error {
        logHealthKitQueryFailure(error, context: context)
        guard let healthError = error as? HKError else { return error }
        if healthError.code == .errorAuthorizationDenied {
            return HealthKitError.authorizationDenied
        }
        return healthError
    }

    private static func typeError(for identifier: HKQuantityTypeIdentifier) -> HealthKitError {
        switch identifier {
        case .stepCount:
            return .stepTypeUnavailable
        case .activeEnergyBurned:
            return .activeEnergyTypeUnavailable
        default:
            return .noStatisticsData
        }
    }
}

private extension HKCategorySample {
    var resolvedSleepCategory: HKCategoryValueSleepAnalysis? {
        HKCategoryValueSleepAnalysis(rawValue: value)
    }
}

enum HealthKitError: LocalizedError {
    case notAvailable
    case stepTypeUnavailable
    case activeEnergyTypeUnavailable
    case invalidDateRange
    case noStatisticsData
    case authorizationDenied
    case backgroundDeliveryFailed

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Health data is not available on this device."
        case .stepTypeUnavailable:
            return "Step count type is unavailable."
        case .activeEnergyTypeUnavailable:
            return "Active energy type is unavailable."
        case .invalidDateRange:
            return "Unable to construct a date range."
        case .noStatisticsData:
            return "No HealthKit statistics were returned."
        case .authorizationDenied:
            return "Health access is disabled. Re-enable Health permissions in Settings."
        case .backgroundDeliveryFailed:
            return "HealthKit background delivery could not be enabled."
        }
    }
}
