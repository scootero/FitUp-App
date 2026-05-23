//
//  HealthKitService.swift
//  FitUp
//
//  Slice 7: HealthKit reads + observer delivery for live sync.
//

import Foundation
import HealthKit
import OSLog

// MARK: - Health screen summaries (Slice 12)

enum HealthMetricType: String {
    case steps
    case activeCalories = "active_calories"
}

/// Cumulative metric samples for intraday charts (e.g. Match Details).
struct HealthIntradayCumulativePoint: Equatable, Identifiable {
    let date: Date
    let cumulative: Int

    var id: Date { date }
}

/// One bucket of hour-level activity (e.g. 9–10 AM produced this many steps). Used by the Stats 1D charts.
struct HealthIntradayHourlyBucket: Equatable, Identifiable, Sendable {
    /// Start of the hour bucket (anchored to the local timezone).
    let hourStart: Date
    /// Sum of the metric (steps or active calories) accumulated within this hour. Always ≥ 0.
    let value: Int

    var id: Date { hourStart }
}

enum HealthKitService {
#if DEBUG
    private static let bestStatsAuditLogger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "FitUp", category: "healthkit_best_stats")
#endif
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
    static func requestAuthorizationIfNeeded(analyticsUserId: UUID? = nil) async {
        guard isHealthDataAvailable else { return }
        guard anyReadTypeIsNotDetermined() else { return }
        if let uid = analyticsUserId {
            ProductAnalytics.track(
                ProductAnalytics.Event.healthPermissionRequested,
                userId: uid,
                properties: ["source": "health_tab"]
            )
        }
        do {
            try await requestAuthorization()
            if let uid = analyticsUserId {
                ProductAnalytics.track(
                    ProductAnalytics.Event.healthPermissionGranted,
                    userId: uid,
                    properties: ["source": "health_tab"]
                )
            }
        } catch {
            if let uid = analyticsUserId {
                let denied = (error as? HealthKitError).map {
                    if case .authorizationDenied = $0 { return true }
                    return false
                } ?? false
                ProductAnalytics.track(
                    ProductAnalytics.Event.healthPermissionDenied,
                    userId: uid,
                    properties: [
                        "source": "health_tab",
                        "reason": denied ? "authorization_denied" : "error",
                    ]
                )
            }
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
        try await fetchNDayStepAverage(days: 7)
    }

    /// Average daily steps over the last `days` calendar days (including today). No samples uploaded — aggregate only.
    static func fetchNDayStepAverage(days: Int) async throws -> Double {
        guard days >= 1 else {
            throw HealthKitError.invalidDateRange
        }
        return try await fetchNDayAverage(
            quantityIdentifier: .stepCount,
            unit: .count(),
            days: days
        )
    }

    /// Returns the average daily active calories over the last 7 calendar days (including today).
    static func fetchSevenDayActiveCaloriesAverage() async throws -> Double {
        try await fetchNDayAverage(
            quantityIdentifier: .activeEnergyBurned,
            unit: .kilocalorie(),
            days: 7
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

    /// Returns a cumulative metric total for an arbitrary absolute date range.
    static func fetchMetricTotal(
        metricType: HealthMetricType,
        startDate: Date,
        endDate: Date
    ) async throws -> Int {
        guard endDate > startDate else { return 0 }
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
        let total = try await fetchCumulativeTotal(
            quantityIdentifier: quantityIdentifier,
            unit: unit,
            startDate: startDate,
            endDate: endDate
        )
        return Int(total.rounded())
    }

    /// Intraday **cumulative** series for `calendarDate` in `timeZone`, from midnight through the end of the visible window
    /// (`now` when that date is “today”, otherwise end of that calendar day). Uses 15-minute buckets, then reduces to at most
    /// `maxPoints`. The final sample matches `fetchCumulativeTotal` over the same `[dayStart, chartEnd]` window.
    static func fetchIntradayCumulativeSeries(
        metricType: HealthMetricType,
        for calendarDate: Date,
        timeZone: TimeZone? = nil,
        maxPoints: Int = 48
    ) async throws -> [HealthIntradayCumulativePoint] {
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

        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }
        guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityIdentifier) else {
            throw typeError(for: quantityIdentifier)
        }

        var calendar = Calendar.current
        calendar.timeZone = timeZone ?? .current
        let dayStart = calendar.startOfDay(for: calendarDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            throw HealthKitError.invalidDateRange
        }

        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let chartEnd = dayStart == todayStart ? min(now, dayEnd) : dayEnd
        if chartEnd <= dayStart {
            return [HealthIntradayCumulativePoint(date: dayStart, cumulative: 0)]
        }

        let authoritative = Int(
            try await fetchCumulativeTotal(
                quantityIdentifier: quantityIdentifier,
                unit: unit,
                startDate: dayStart,
                endDate: chartEnd
            ).rounded()
        )

        let predicate = HKQuery.predicateForSamples(
            withStart: dayStart,
            end: chartEnd,
            options: [.strictStartDate]
        )

        let interval = DateComponents(minute: 15)
        var bucketPoints: [HealthIntradayCumulativePoint] = [
            HealthIntradayCumulativePoint(date: dayStart, cumulative: 0),
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum],
                anchorDate: dayStart,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: mapHealthKitError(error, context: "fetchIntradayCumulativeSeries"))
                    return
                }
                guard let collection else {
                    continuation.resume()
                    return
                }

                var running = 0
                collection.enumerateStatistics(from: dayStart, to: chartEnd) { statistics, _ in
                    let delta = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    running += Int(delta.rounded())
                    let t = min(statistics.endDate, chartEnd)
                    if t > dayStart {
                        bucketPoints.append(HealthIntradayCumulativePoint(date: t, cumulative: running))
                    }
                }
                continuation.resume()
            }

            store.execute(query)
        }

        if bucketPoints.last?.date != chartEnd || bucketPoints.last?.cumulative != authoritative {
            if bucketPoints.last?.date == chartEnd {
                bucketPoints[bucketPoints.count - 1] = HealthIntradayCumulativePoint(date: chartEnd, cumulative: authoritative)
            } else {
                bucketPoints.append(HealthIntradayCumulativePoint(date: chartEnd, cumulative: authoritative))
            }
        }

        return downsampleIntradaySeries(bucketPoints, maxPoints: max(4, maxPoints))
    }

    /// Hourly delta buckets for `calendarDate`, anchored to local timezone hours. Each bucket's `value` is the per-hour
    /// sum of the metric (e.g. steps walked between 9–10 AM). Leading buckets with `value == 0` are dropped so the
    /// returned series starts at the first hour with real activity. For "today", the final bucket may be partial (covers
    /// up through `now`).
    static func fetchIntradayHourlyDeltas(
        metricType: HealthMetricType,
        for calendarDate: Date,
        timeZone: TimeZone? = nil
    ) async throws -> [HealthIntradayHourlyBucket] {
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

        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }
        guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityIdentifier) else {
            throw typeError(for: quantityIdentifier)
        }

        var calendar = Calendar.current
        calendar.timeZone = timeZone ?? .current
        let dayStart = calendar.startOfDay(for: calendarDate)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            throw HealthKitError.invalidDateRange
        }

        let now = Date()
        let todayStart = calendar.startOfDay(for: now)
        let chartEnd = dayStart == todayStart ? min(now, dayEnd) : dayEnd
        if chartEnd <= dayStart {
            return []
        }

        let predicate = HKQuery.predicateForSamples(
            withStart: dayStart,
            end: chartEnd,
            options: [.strictStartDate]
        )

        let interval = DateComponents(hour: 1)
        var hourlyBuckets: [HealthIntradayHourlyBucket] = []

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let query = HKStatisticsCollectionQuery(
                quantityType: quantityType,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum],
                anchorDate: dayStart,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: mapHealthKitError(error, context: "fetchIntradayHourlyDeltas"))
                    return
                }
                guard let collection else {
                    continuation.resume()
                    return
                }

                collection.enumerateStatistics(from: dayStart, to: chartEnd) { statistics, _ in
                    let delta = statistics.sumQuantity()?.doubleValue(for: unit) ?? 0
                    let value = max(0, Int(delta.rounded()))
                    hourlyBuckets.append(
                        HealthIntradayHourlyBucket(hourStart: statistics.startDate, value: value)
                    )
                }
                continuation.resume()
            }

            store.execute(query)
        }

        if let firstActiveIndex = hourlyBuckets.firstIndex(where: { $0.value > 0 }) {
            return Array(hourlyBuckets[firstActiveIndex...])
        }
        return []
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

    /// Daily step totals keyed by `yyyy-MM-dd` in the profile (or device) timezone, inclusive of both bounds.
    static func fetchDailyStepsByCalendarDate(
        startCalendarDateKey: String,
        endCalendarDateKey: String,
        profileTimeZoneIdentifier: String?
    ) async throws -> [String: Int] {
        guard isHealthDataAvailable else { throw HealthKitError.notAvailable }
        guard startCalendarDateKey <= endCalendarDateKey else { return [:] }

        let tz = profileTimeZoneIdentifier.flatMap { TimeZone(identifier: $0) } ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz

        guard
            let startDate = parseCalendarDateKey(startCalendarDateKey, calendar: calendar),
            let endDate = parseCalendarDateKey(endCalendarDateKey, calendar: calendar)
        else {
            throw HealthKitError.invalidDateRange
        }

        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)

        var result: [String: Int] = [:]
        var day = startDay
        while day <= endDay {
            let key = formatCalendarDateKey(day, calendar: calendar, timeZone: tz)
            let steps = try await fetchMetricTotal(metricType: .steps, for: day, timeZone: tz)
            result[key] = steps
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    private static func parseCalendarDateKey(_ key: String, calendar: Calendar) -> Date? {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components)
    }

    private static func formatCalendarDateKey(_ date: Date, calendar: Calendar, timeZone: TimeZone) -> String {
        var cal = calendar
        cal.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = timeZone
        return formatter.string(from: date)
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

        let result = HealthKitAllTimeBests(
            stepsBestDay: bestSingleDay(from: s),
            stepsBestWeek: bestRollingSevenDaySum(from: s),
            calsBestDay: bestSingleDay(from: c),
            calsBestWeek: bestRollingSevenDaySum(from: c)
        )
#if DEBUG
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let stepsDayStr = result.stepsBestDay.map { "\($0)" } ?? "nil"
        let stepsWeekStr = result.stepsBestWeek.map { "\($0)" } ?? "nil"
        let calsDayStr = result.calsBestDay.map { "\($0)" } ?? "nil"
        let calsWeekStr = result.calsBestWeek.map { "\($0)" } ?? "nil"
        let auditLine = [
            "[BEST_STATS_AUDIT]",
            "steps_best_day=\(stepsDayStr)",
            "steps_best_week=\(stepsWeekStr)",
            "cals_best_day=\(calsDayStr)",
            "cals_best_week=\(calsWeekStr)",
            "data_points_count=\(s.count)",
            "date_range_start=\(iso.string(from: startDate))",
            "date_range_end=\(iso.string(from: endDate))",
        ].joined(separator: " ")
        bestStatsAuditLogger.debug("\(auditLine, privacy: .public)")
#endif
        return result
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

    private static func fetchNDayAverage(
        quantityIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        days: Int
    ) async throws -> Double {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }

        guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityIdentifier) else {
            throw typeError(for: quantityIdentifier)
        }

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: endDate)) else {
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
                    continuation.resume(throwing: mapHealthKitError(error, context: "fetchNDayAverage"))
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

    private static func downsampleIntradaySeries(
        _ series: [HealthIntradayCumulativePoint],
        maxPoints: Int
    ) -> [HealthIntradayCumulativePoint] {
        guard maxPoints > 1, series.count > maxPoints else { return series }
        let n = series.count
        var result: [HealthIntradayCumulativePoint] = []
        for i in 0..<maxPoints {
            let idx = min(n - 1, Int((Double(i) * Double(n - 1) / Double(maxPoints - 1)).rounded()))
            let p = series[idx]
            if let last = result.last, last.date == p.date {
                result[result.count - 1] = p
            } else {
                result.append(p)
            }
        }
        if let last = series.last, result.last?.cumulative != last.cumulative || result.last?.date != last.date {
            if !result.isEmpty {
                result[result.count - 1] = last
            } else {
                result.append(last)
            }
        }
        return result
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
                    if let hk = error as? HKError, hk.code == .errorNoData {
                        continuation.resume(returning: 0)
                        return
                    }
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
