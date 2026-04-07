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

struct HealthSleepSummary: Equatable {
    /// Mean hours asleep across the last `nights` calendar days (0 if no data).
    var averageHoursLastNights: Double
    /// Sample standard deviation of nightly hours (0 if &lt; 2 nights of data).
    var varianceHours: Double
    /// Aggregate stage mix over the 7 wake days (percentages sum to ~100).
    var stagePercentagesSevenNight: HealthSleepStagePercentages
    /// Total asleep hours for the most recent wake day that has data (readiness / chips).
    var lastNightAsleepHours: Double?
    /// Hours asleep per wake day, **oldest first** (same order as 7-day charts).
    var nightlyAsleepHoursOldestFirst: [Double]
    /// Stage mix for `lastNightAsleepHours` only; nil when no last-night data.
    var lastNightStagePercentages: HealthSleepStagePercentages?
    /// Chronological segments for the last wake night (for hypnogram); empty if none.
    var lastNightTimeline: [HealthSleepTimelineSegment]
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

        var secondsAsleepByDay: [Date: Double] = [:]
        var stageSecondsSevenNight: [String: Double] = [
            "deep": 0, "core": 0, "rem": 0, "awake": 0,
        ]

        let dayStarts: [Date] = (0..<nights).compactMap { i in
            calendar.date(byAdding: .day, value: -(nights - 1 - i), to: calendar.startOfDay(for: endDate))
        }
        let daySet = Set(dayStarts)

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            guard duration > 0 else { continue }
            let dayKey = calendar.startOfDay(for: sample.endDate)
            let value = sample.value

            if let asleep = asleepSecondsContribution(for: value, duration: duration) {
                secondsAsleepByDay[dayKey, default: 0] += asleep
            }
            if daySet.contains(dayKey) {
                accumulateSleepStage(value: value, duration: duration, into: &stageSecondsSevenNight)
            }
        }

        var nightlyHours: [Double] = []
        for day in dayStarts {
            let hrs = (secondsAsleepByDay[day] ?? 0) / 3600
            nightlyHours.append(hrs)
        }

        let sumH = nightlyHours.reduce(0, +)
        let avg = nightlyHours.isEmpty ? 0 : sumH / Double(nightlyHours.count)
        let variance: Double = {
            guard nightlyHours.count >= 2 else { return 0 }
            let mean = avg
            let v = nightlyHours.map { pow($0 - mean, 2) }.reduce(0, +) / Double(nightlyHours.count - 1)
            return sqrt(v)
        }()

        let totalStage7 = stageSecondsSevenNight.values.reduce(0, +)
        let pct7: (Double) -> Double = { totalStage7 > 0 ? ($0 / totalStage7) * 100 : 0 }
        let stagesSevenNight = HealthSleepStagePercentages(
            deep: pct7(stageSecondsSevenNight["deep"] ?? 0),
            core: pct7(stageSecondsSevenNight["core"] ?? 0),
            rem: pct7(stageSecondsSevenNight["rem"] ?? 0),
            awake: pct7(stageSecondsSevenNight["awake"] ?? 0)
        )

        let lastWakeDay: Date? = dayStarts.reversed().first { (secondsAsleepByDay[$0] ?? 0) > 0 }
        let lastNightHours: Double? = lastWakeDay.map { (secondsAsleepByDay[$0] ?? 0) / 3600 }

        var lastNightStageSeconds: [String: Double] = [
            "deep": 0, "core": 0, "rem": 0, "awake": 0,
        ]
        var lastNightTimeline: [HealthSleepTimelineSegment] = []
        if let wake = lastWakeDay {
            let nightSamples = samples
                .filter { calendar.startOfDay(for: $0.endDate) == wake }
                .sorted { $0.startDate < $1.startDate }
            for sample in nightSamples {
                let duration = sample.endDate.timeIntervalSince(sample.startDate)
                guard duration > 0 else { continue }
                accumulateSleepStage(value: sample.value, duration: duration, into: &lastNightStageSeconds)
                if let stage = timelineStage(for: sample.value) {
                    lastNightTimeline.append(
                        HealthSleepTimelineSegment(start: sample.startDate, end: sample.endDate, stage: stage)
                    )
                }
            }
        }

        let totalStageLN = lastNightStageSeconds.values.reduce(0, +)
        let pctLN: (Double) -> Double = { totalStageLN > 0 ? ($0 / totalStageLN) * 100 : 0 }
        let lastNightStages: HealthSleepStagePercentages? = (lastWakeDay != nil && totalStageLN > 0)
            ? HealthSleepStagePercentages(
                deep: pctLN(lastNightStageSeconds["deep"] ?? 0),
                core: pctLN(lastNightStageSeconds["core"] ?? 0),
                rem: pctLN(lastNightStageSeconds["rem"] ?? 0),
                awake: pctLN(lastNightStageSeconds["awake"] ?? 0)
            )
            : nil

        return HealthSleepSummary(
            averageHoursLastNights: avg,
            varianceHours: variance,
            stagePercentagesSevenNight: stagesSevenNight,
            lastNightAsleepHours: lastNightHours,
            nightlyAsleepHoursOldestFirst: nightlyHours,
            lastNightStagePercentages: lastNightStages,
            lastNightTimeline: lastNightTimeline
        )
    }

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
