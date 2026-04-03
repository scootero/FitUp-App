//
//  HealthKitService.swift
//  FitUp
//
//  Slice 7: HealthKit reads + observer delivery for live sync.
//

import Foundation
import HealthKit

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

    /// Requests read access for v1 HealthKit types (fitup-docs-pack §11).
    static func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }

        let readTypes: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
        ]

        try await store.requestAuthorization(toShare: [], read: readTypes)
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
                    AppLogger.log(
                        category: "healthkit_sync",
                        level: .warning,
                        message: "health observer callback failed",
                        metadata: [
                            "metric_type": metric.metricType.rawValue,
                            "error": error.localizedDescription,
                        ]
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
    }

    static func stopMetricObservers() {
        for query in observerQueries.values {
            store.stop(query)
        }
        observerQueries.removeAll()
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
        try assertNotDenied(quantityType: quantityType)

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
                    continuation.resume(throwing: mapHealthKitError(error))
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
        try assertNotDenied(quantityType: quantityType)

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
                    continuation.resume(throwing: mapHealthKitError(error))
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
                    continuation.resume(throwing: mapHealthKitError(error))
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

    private static func assertNotDenied(quantityType: HKQuantityType) throws {
        if store.authorizationStatus(for: quantityType) == .sharingDenied {
            throw HealthKitError.authorizationDenied
        }
    }

    private static func mapHealthKitError(_ error: Error) -> Error {
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
