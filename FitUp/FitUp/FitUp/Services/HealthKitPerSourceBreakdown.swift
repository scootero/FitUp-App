//
//  HealthKitPerSourceBreakdown.swift
//  FitUp
//
//  Read-only per-source metrics for the Health Data Info debug screen.
//  Uses a dedicated HKHealthStore to avoid touching HealthKitService internals.
//

import Foundation
import HealthKit

/// One row for a metric’s per-source attribution (pre-formatted `detail` for display).
struct MetricSourceRow: Identifiable, Equatable {
    let id: String
    let sourceName: String
    let detail: String
}

/// Aggregated per-source breakdown for the Health Data Info screen.
struct HealthDataInfoBreakdownResult: Equatable {
    let stepsSources: [MetricSourceRow]
    let caloriesSources: [MetricSourceRow]
    /// Approximate asleep hours per source (simple sum; does not match canonical `fetchSleepSummary`).
    let sleepSources: [MetricSourceRow]
    /// Latest resting HR sample per source in the lookback window (may differ from global “most recent” headline).
    let restingHRSources: [MetricSourceRow]
    let stepsSampleCount: Int
    let caloriesSampleCount: Int
    let sleepSampleCount: Int
    let restingHRSampleCount: Int
    let todayQueryStart: Date
    let todayQueryEnd: Date
    let lastNightWindowStart: Date
    let lastNightWindowEnd: Date
}

enum HealthKitPerSourceBreakdown {
    private static let store = HKHealthStore()

    /// Resting HR lookback for “latest per source” (matches query window).
    static let restingHeartRateLookbackDays = 30

    // MARK: - Public entry

    /// Fetches all per-source breakdowns used by Health Data Info (read-only).
    static func fetchHealthDataInfoBreakdown(referenceNow: Date = Date()) async throws -> HealthDataInfoBreakdownResult {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        let calendar = Calendar.current

        let (todayStart, todayEnd) = todayQueryBounds(now: referenceNow)
        let todayPredicate = HKQuery.predicateForSamples(
            withStart: todayStart,
            end: todayEnd,
            options: [.strictStartDate]
        )

        async let stepsCalsTask = fetchStepsAndCaloriesToday(
            predicate: todayPredicate,
            todayStart: todayStart,
            todayEnd: todayEnd
        )
        async let sleepTask = fetchSleepPerSourceApproximate(calendar: calendar, referenceNow: referenceNow)
        async let rhrTask = fetchRestingHRPerSourceLatest(referenceNow: referenceNow)

        let (stepsBy, calsBy, stepsCount, calsCount) = try await stepsCalsTask
        let (sleepBy, sleepCount, lnStart, lnEnd) = try await sleepTask
        let (rhrBy, rhrCount) = try await rhrTask

        let nameUnion = Set(stepsBy.keys).union(calsBy.keys)
        let sortedNames = nameUnion.sorted()

        let stepsSources: [MetricSourceRow] = sortedNames.map { name in
            MetricSourceRow(
                id: "steps-\(name)",
                sourceName: name,
                detail: "\(Int((stepsBy[name] ?? 0).rounded()))"
            )
        }

        let caloriesSources: [MetricSourceRow] = sortedNames.map { name in
            MetricSourceRow(
                id: "cals-\(name)",
                sourceName: name,
                detail: "\(Int((calsBy[name] ?? 0).rounded()))"
            )
        }

        let sleepSources: [MetricSourceRow] = sleepBy.keys.sorted().map { name in
            let hrs = (sleepBy[name] ?? 0) / 3600
            return MetricSourceRow(
                id: "sleep-\(name)",
                sourceName: name,
                detail: String(format: "%.1fh", hrs)
            )
        }

        let restingHRSources: [MetricSourceRow] = rhrBy.keys.sorted().map { name in
            MetricSourceRow(
                id: "rhr-\(name)",
                sourceName: name,
                detail: "\(Int((rhrBy[name] ?? 0).rounded()))"
            )
        }

        return HealthDataInfoBreakdownResult(
            stepsSources: stepsSources,
            caloriesSources: caloriesSources,
            sleepSources: sleepSources,
            restingHRSources: restingHRSources,
            stepsSampleCount: stepsCount,
            caloriesSampleCount: calsCount,
            sleepSampleCount: sleepCount,
            restingHRSampleCount: rhrCount,
            todayQueryStart: todayStart,
            todayQueryEnd: todayEnd,
            lastNightWindowStart: lnStart,
            lastNightWindowEnd: lnEnd
        )
    }

    // MARK: - Time windows

    /// Today window: local calendar start of day through now (matches `HealthKitService.fetchTodayTotal`).
    static func todayQueryBounds(now: Date = Date()) -> (start: Date, end: Date) {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        return (start, now)
    }

    /// Same clock window as `HealthKitService.lastNightClockWindowBounds` (previous day 18:00 → today 12:00 local).
    static func lastNightClockWindowBounds(calendar: Calendar = .current, referenceNow: Date = Date()) -> (start: Date, end: Date)? {
        let todayStart = calendar.startOfDay(for: referenceNow)
        guard let yesterdayStart = calendar.date(byAdding: .day, value: -1, to: todayStart),
              let windowStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: yesterdayStart),
              let windowEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: todayStart),
              windowStart < windowEnd else { return nil }
        return (windowStart, windowEnd)
    }

    // MARK: - Steps + calories

    private static func fetchStepsAndCaloriesToday(
        predicate: NSPredicate,
        todayStart: Date,
        todayEnd: Date
    ) async throws -> ([String: Double], [String: Double], Int, Int) {
        async let stepsOutcome = fetchQuantitySamplesGrouped(
            quantityIdentifier: .stepCount,
            unit: .count(),
            predicate: predicate
        )
        async let calsOutcome = fetchQuantitySamplesGrouped(
            quantityIdentifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            predicate: predicate
        )
        let (stepsBy, stepsCount) = try await stepsOutcome
        let (calsBy, calsCount) = try await calsOutcome
        return (stepsBy, calsBy, stepsCount, calsCount)
    }

    private static func fetchQuantitySamplesGrouped(
        quantityIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        predicate: NSPredicate
    ) async throws -> ([String: Double], Int) {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityIdentifier) else {
            throw HealthKitError.noStatisticsData
        }

        let raw = try await executeSampleQuery(sampleType: quantityType, predicate: predicate)
        let samples = raw.compactMap { $0 as? HKQuantitySample }
        var bySource: [String: Double] = [:]
        for sample in samples {
            let key = sourceKey(for: sample)
            bySource[key, default: 0] += sample.quantity.doubleValue(for: unit)
        }
        return (bySource, samples.count)
    }

    // MARK: - Sleep (approximate)

    /// Sums clipped asleep segment length per source; does **not** replicate canonical overlap resolution in `HealthKitService`.
    private static func fetchSleepPerSourceApproximate(
        calendar: Calendar,
        referenceNow: Date
    ) async throws -> ([String: TimeInterval], Int, Date, Date) {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthKitError.noStatisticsData
        }
        guard let bounds = lastNightClockWindowBounds(calendar: calendar, referenceNow: referenceNow) else {
            return ([:], 0, referenceNow, referenceNow)
        }
        let windowStart = bounds.start
        let windowEnd = bounds.end

        // Include samples overlapping the window (do not use `.strictStartDate` — segments may start before the window).
        let predicate = HKQuery.predicateForSamples(
            withStart: windowStart,
            end: windowEnd,
            options: []
        )

        let raw = try await executeSampleQuery(sampleType: sleepType, predicate: predicate)
        let samples = raw.compactMap { $0 as? HKCategorySample }
        let overlapping = samples.filter { $0.startDate < windowEnd && $0.endDate > windowStart }

        var asleepSecondsBySource: [String: TimeInterval] = [:]
        for sample in overlapping {
            let clipStart = max(sample.startDate, windowStart)
            let clipEnd = min(sample.endDate, windowEnd)
            guard clipStart < clipEnd else { continue }
            guard let category = HKCategoryValueSleepAnalysis(rawValue: sample.value), isAsleepCategory(category) else {
                continue
            }
            let duration = clipEnd.timeIntervalSince(clipStart)
            let key = sourceKey(for: sample)
            asleepSecondsBySource[key, default: 0] += duration
        }

        return (asleepSecondsBySource, overlapping.count, windowStart, windowEnd)
    }

    /// Asleep stages only (excludes awake and inBed — simple attribution sum).
    private static func isAsleepCategory(_ v: HKCategoryValueSleepAnalysis) -> Bool {
        switch v {
        case .asleepDeep, .asleepCore, .asleepREM, .asleepUnspecified:
            return true
        default:
            return false
        }
    }

    // MARK: - Resting HR (latest per source)

    private static func fetchRestingHRPerSourceLatest(referenceNow: Date) async throws -> ([String: Double], Int) {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            throw HealthKitError.noStatisticsData
        }
        let calendar = Calendar.current
        guard let lookbackStart = calendar.date(byAdding: .day, value: -restingHeartRateLookbackDays, to: referenceNow) else {
            throw HealthKitError.invalidDateRange
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: lookbackStart,
            end: referenceNow,
            options: []
        )

        let raw = try await executeSampleQuery(sampleType: quantityType, predicate: predicate)
        let samples = raw.compactMap { $0 as? HKQuantitySample }
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        var latestBySource: [String: HKQuantitySample] = [:]
        for sample in samples {
            let key = sourceKey(for: sample)
            if let existing = latestBySource[key] {
                if sample.endDate > existing.endDate {
                    latestBySource[key] = sample
                }
            } else {
                latestBySource[key] = sample
            }
        }

        var bpmBySource: [String: Double] = [:]
        for (key, sample) in latestBySource {
            bpmBySource[key] = sample.quantity.doubleValue(for: bpmUnit)
        }
        return (bpmBySource, samples.count)
    }

    // MARK: - Shared query + source keys

    private static func executeSampleQuery(
        sampleType: HKSampleType,
        predicate: NSPredicate
    ) async throws -> [HKSample] {
        try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: sampleType,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, results, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: results ?? [])
            }
            store.execute(query)
        }
    }

    private static func sourceKey(for sample: HKQuantitySample) -> String {
        let name = sample.sourceRevision.source.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        let bundle = sample.sourceRevision.source.bundleIdentifier
        if !bundle.isEmpty { return bundle }
        return "Unknown"
    }

    private static func sourceKey(for sample: HKCategorySample) -> String {
        let name = sample.sourceRevision.source.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { return name }
        let bundle = sample.sourceRevision.source.bundleIdentifier
        if !bundle.isEmpty { return bundle }
        return "Unknown"
    }
}
