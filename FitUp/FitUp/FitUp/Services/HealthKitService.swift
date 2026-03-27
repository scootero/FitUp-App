//
//  HealthKitService.swift
//  FitUp
//
//  Slice 0: authorization only — no metric reads yet.
//

import Foundation
import HealthKit

enum HealthKitService {
    private static let store = HKHealthStore()

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
    }

    /// Returns the average daily steps over the last 7 calendar days (including today).
    static func fetchSevenDayStepAverage() async throws -> Double {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }

        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw HealthKitError.stepTypeUnavailable
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
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: [.cumulativeSum],
                anchorDate: anchorDate,
                intervalComponents: interval
            )

            query.initialResultsHandler = { _, collection, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let collection else {
                    continuation.resume(throwing: HealthKitError.noStatisticsData)
                    return
                }

                var totalSteps = 0.0
                var dayCount = 0.0
                collection.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                    let value = statistics.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
                    totalSteps += value
                    dayCount += 1
                }

                guard dayCount > 0 else {
                    continuation.resume(returning: 0)
                    return
                }
                continuation.resume(returning: totalSteps / dayCount)
            }

            store.execute(query)
        }
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

    private static func fetchTodayTotal(
        quantityIdentifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async throws -> Double {
        guard isHealthDataAvailable else {
            throw HealthKitError.notAvailable
        }
        guard let quantityType = HKObjectType.quantityType(forIdentifier: quantityIdentifier) else {
            switch quantityIdentifier {
            case .stepCount:
                throw HealthKitError.stepTypeUnavailable
            case .activeEnergyBurned:
                throw HealthKitError.activeEnergyTypeUnavailable
            default:
                throw HealthKitError.noStatisticsData
            }
        }

        let calendar = Calendar.current
        let startDate = calendar.startOfDay(for: Date())
        let endDate = Date()
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
                    continuation.resume(throwing: error)
                    return
                }
                let total = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: total)
            }
            store.execute(query)
        }
    }
}

enum HealthKitError: LocalizedError {
    case notAvailable
    case stepTypeUnavailable
    case activeEnergyTypeUnavailable
    case invalidDateRange
    case noStatisticsData

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Health data is not available on this device."
        case .stepTypeUnavailable:
            return "Step count type is unavailable."
        case .activeEnergyTypeUnavailable:
            return "Active energy type is unavailable."
        case .invalidDateRange:
            return "Unable to construct a 7-day date range."
        case .noStatisticsData:
            return "No HealthKit statistics were returned."
        }
    }
}
