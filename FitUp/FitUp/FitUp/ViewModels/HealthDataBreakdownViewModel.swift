//
//  HealthDataBreakdownViewModel.swift
//  FitUp
//
//  Health Data Info screen — combined totals via existing HealthKitService APIs only.
//

import Combine
import Foundation

@MainActor
final class HealthDataBreakdownViewModel: ObservableObject {
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    @Published private(set) var stepsToday: Int?
    @Published private(set) var caloriesToday: Int?
    @Published private(set) var sleepLastNightDisplay = "—"
    @Published private(set) var restingHRDisplay = "—"

    @Published private(set) var stepsSources: [MetricSourceRow] = []
    @Published private(set) var caloriesSources: [MetricSourceRow] = []
    @Published private(set) var sleepSources: [MetricSourceRow] = []
    @Published private(set) var restingHRSources: [MetricSourceRow] = []

    @Published private(set) var stepsSampleCount = 0
    @Published private(set) var caloriesSampleCount = 0
    @Published private(set) var sleepSampleCount = 0
    @Published private(set) var restingHRSampleCount = 0

    @Published private(set) var queryStart: Date?
    @Published private(set) var queryEnd: Date?
    @Published private(set) var lastNightWindowStart: Date?
    @Published private(set) var lastNightWindowEnd: Date?

    @Published private(set) var breakdownError: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        breakdownError = nil
        defer { isLoading = false }

        await HealthKitService.requestAuthorizationIfNeeded()

        async let stepsTask = fetchSteps()
        async let calsTask = fetchCals()
        async let sleepTask = HealthKitService.fetchSleepSummary(nights: 7)
        async let restingTask = fetchResting()
        async let breakdownTask = fetchBreakdown()

        let steps = await stepsTask
        let cals = await calsTask
        let sleepSummary = await sleepTask
        let resting = await restingTask
        let breakdown = await breakdownTask

        stepsToday = steps.value
        caloriesToday = cals.value
        if let err = steps.error ?? cals.error {
            errorMessage = err
        }

        let sleepHrs = sleepSummary.lastNightAsleepHours
        sleepLastNightDisplay = Self.formatSleepHours(sleepHrs)
        restingHRDisplay = resting.map { "\(Int($0.rounded()))" } ?? "—"

        if let b = breakdown.value {
            stepsSources = b.stepsSources
            caloriesSources = b.caloriesSources
            sleepSources = b.sleepSources
            restingHRSources = b.restingHRSources
            stepsSampleCount = b.stepsSampleCount
            caloriesSampleCount = b.caloriesSampleCount
            sleepSampleCount = b.sleepSampleCount
            restingHRSampleCount = b.restingHRSampleCount
            queryStart = b.todayQueryStart
            queryEnd = b.todayQueryEnd
            lastNightWindowStart = b.lastNightWindowStart
            lastNightWindowEnd = b.lastNightWindowEnd
        } else {
            clearBreakdownState()
            if let err = breakdown.error {
                breakdownError = err
            }
        }
    }

    private func clearBreakdownState() {
        stepsSources = []
        caloriesSources = []
        sleepSources = []
        restingHRSources = []
        stepsSampleCount = 0
        caloriesSampleCount = 0
        sleepSampleCount = 0
        restingHRSampleCount = 0
        let bounds = HealthKitPerSourceBreakdown.todayQueryBounds()
        queryStart = bounds.start
        queryEnd = bounds.end
        if let ln = HealthKitPerSourceBreakdown.lastNightClockWindowBounds() {
            lastNightWindowStart = ln.start
            lastNightWindowEnd = ln.end
        } else {
            lastNightWindowStart = nil
            lastNightWindowEnd = nil
        }
    }

    private func fetchSteps() async -> (value: Int?, error: String?) {
        do {
            let v = try await HealthKitService.fetchTodayStepCount()
            return (v, nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }

    private func fetchCals() async -> (value: Int?, error: String?) {
        do {
            let v = try await HealthKitService.fetchTodayActiveCalories()
            return (v, nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }

    private func fetchResting() async -> Double? {
        do {
            return try await HealthKitService.fetchRestingHeartRate()
        } catch {
            return nil
        }
    }

    private func fetchBreakdown() async -> (value: HealthDataInfoBreakdownResult?, error: String?) {
        do {
            let result = try await HealthKitPerSourceBreakdown.fetchHealthDataInfoBreakdown()
            return (result, nil)
        } catch {
            return (nil, error.localizedDescription)
        }
    }

    private static func formatSleepHours(_ h: Double?) -> String {
        guard let h, h > 0 else { return "—" }
        return String(format: "%.1fh", h)
    }
}
