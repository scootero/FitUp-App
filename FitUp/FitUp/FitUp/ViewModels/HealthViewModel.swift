//
//  HealthViewModel.swift
//  FitUp
//
//  Slice 12 — Health screen state (HealthKit + Supabase).
//

import Combine
import Foundation

@MainActor
final class HealthViewModel: ObservableObject {
    enum StatsTab: String, CaseIterable, Identifiable {
        case steps
        case calories

        var id: String { rawValue }
    }

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    /// Shown when HealthKit reports read access denied; use Open Settings in the UI.
    @Published private(set) var showHealthAccessBanner = false
    @Published var statsTab: StatsTab = .steps

    @Published private(set) var battleReadinessScore = 0
    @Published private(set) var battleReadinessLabel = ""
    @Published private(set) var battleReadinessSubtitle = ""

    @Published private(set) var sleepHoursDisplay = "—"
    @Published private(set) var restingHRDisplay = "—"
    @Published private(set) var stepsTodayDisplay = "—"
    @Published private(set) var caloriesTodayDisplay = "—"

    @Published private(set) var goals = ReadinessGoals.loadFromUserDefaults()

    @Published private(set) var weekSteps: [Int] = Array(repeating: 0, count: 7)
    @Published private(set) var weekCalories: [Int] = Array(repeating: 0, count: 7)

    @Published private(set) var sleepSummary: HealthSleepSummary?
    @Published private(set) var hrZoneRows: [HealthHRZoneRow] = []

    @Published private(set) var allTimeBests = HealthAllTimeBests.empty
    @Published private(set) var winRateText = "0%"
    @Published private(set) var winCount = 0
    @Published private(set) var matchCount = 0

    @Published private(set) var activeMatchEdges: [HomeActiveMatch] = []

    @Published private(set) var showSyncedBadge = false
    @Published private(set) var lastLoadFinishedAt: Date?

    @Published private(set) var sleepLastNightHours: Double?
    /// Raw values for component breakdown rows (matches JSX `metric.actual / metric.goal`).
    @Published private(set) var stepsTodayValue = 0
    @Published private(set) var caloriesTodayValue = 0
    @Published private(set) var restingHRValue: Double?

    private let healthRepository = HealthRepository()
    private let homeRepository = HomeRepository()
    private let activityRepository = ActivityRepository()

    private var profileId: UUID?

    func start(profile: Profile?) {
        profileId = profile?.id
        Task { await reload(source: "profile_task") }
    }

    func reload(source: String = "unknown") async {
        guard let userId = profileId else { return }
        let loadStarted = Date()
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        AppLogger.log(
            category: "healthkit_read",
            level: .info,
            message: "health screen load started",
            userId: userId,
            metadata: [
                "source": source,
                "pipeline": "HealthViewModel.reload",
            ]
        )

        goals = ReadinessGoals.loadFromUserDefaults()

        await HealthKitService.requestAuthorizationIfNeeded()

        do {
            showHealthAccessBanner = false

            let stepsToday = try await healthKitStep("today_steps", userId: userId) {
                try await HealthKitService.fetchTodayStepCount()
            }
            let calsToday = try await healthKitStep("today_active_calories", userId: userId) {
                try await HealthKitService.fetchTodayActiveCalories()
            }
            let resting = try await healthKitStep("resting_heart_rate", userId: userId) {
                try await HealthKitService.fetchRestingHeartRate()
            }
            let sleepAgg = try await healthKitStep("sleep_summary_7n", userId: userId) {
                try await HealthKitService.fetchSleepSummary(nights: 7)
            }
            let wSteps = try await healthKitStep("week_steps_array", userId: userId) {
                try await HealthKitService.fetchSevenDayStepsArray()
            }
            let wCals = try await healthKitStep("week_calories_array", userId: userId) {
                try await HealthKitService.fetchSevenDayCaloriesArray()
            }
            let zones = try await healthKitStep("hr_zones", userId: userId) {
                try await HealthKitService.fetchHRZoneRows()
            }

            let sleepForReadiness = sleepAgg.lastNightAsleepHours

            let score = ReadinessCalculator.compute(
                sleepHrsLastNight: sleepForReadiness,
                restingHR: resting,
                stepsToday: stepsToday,
                calsToday: calsToday,
                goals: goals
            )

            battleReadinessScore = score
            battleReadinessLabel = ReadinessCalculator.label(for: score)
            battleReadinessSubtitle = ReadinessCalculator.subtitle(for: score)

            sleepLastNightHours = sleepAgg.lastNightAsleepHours
            sleepHoursDisplay = formatSleepHours(sleepForReadiness)
            restingHRDisplay = resting.map { "\(Int($0.rounded()))" } ?? "—"
            restingHRValue = resting
            stepsTodayValue = stepsToday
            caloriesTodayValue = calsToday
            stepsTodayDisplay = formatStepsShort(stepsToday)
            caloriesTodayDisplay = "\(calsToday)"

            weekSteps = wSteps
            weekCalories = wCals
            sleepSummary = sleepAgg
            hrZoneRows = zones

            lastLoadFinishedAt = Date()
            showSyncedBadge = true

            async let remoteBests = healthRepository.fetchAllTimeBests(userId: userId)
            async let hkBestsTask = loadHealthKitAllTimeBests(userId: userId)
            let remoteResolved = await remoteBests
            let hkResolved = await hkBestsTask
            allTimeBests = HealthAllTimeBests.merged(healthKit: hkResolved, remote: remoteResolved)
            activeMatchEdges = await homeRepository.loadActiveMatches(for: userId)

            let completed = await activityRepository.loadCompletedMatches(currentUserId: userId)
            matchCount = completed.count
            winCount = completed.filter(\.myWon).count
            if matchCount > 0 {
                winRateText = "\(Int((Double(winCount) / Double(matchCount) * 100).rounded()))%"
            } else {
                winRateText = "0%"
            }

            let durationMs = Int(loadStarted.timeIntervalSinceNow * -1000)
            let hkSnapshot = Self.formatHealthDataSnapshot(
                source: source,
                stepsToday: stepsToday,
                calsToday: calsToday,
                restingBPM: resting,
                sleepAgg: sleepAgg,
                weekSteps: wSteps,
                weekCalories: wCals,
                zones: zones,
                readinessScore: score
            )
            var meta = hkSnapshot
            meta["source"] = source
            meta["pipeline"] = "HealthViewModel.reload"
            meta["duration_ms"] = "\(durationMs)"
            meta["load_finished_at"] = ISO8601DateFormatter().string(from: Date())
            meta["active_matches_count"] = "\(activeMatchEdges.count)"
            meta["completed_matches"] = "\(matchCount)"
            meta["wins"] = "\(winCount)"
            AppLogger.log(
                category: "healthkit_read",
                level: .info,
                message: "health screen load ok (HK + home data)",
                userId: userId,
                metadata: meta
            )

        } catch {
            showSyncedBadge = false
            if let hk = error as? HealthKitError, case .authorizationDenied = hk {
                showHealthAccessBanner = true
            } else {
                showHealthAccessBanner = false
            }
            errorMessage = error.localizedDescription
            AppLogger.log(
                category: "healthkit_read",
                level: .warning,
                message: "health screen load failed: \(error.localizedDescription)",
                userId: userId,
                metadata: [
                    "source": source,
                    "pipeline": "HealthViewModel.reload",
                    "error": error.localizedDescription,
                    "error_type": String(describing: type(of: error)),
                ]
            )
        }
    }

    /// Best day / best 7-day totals from Apple Health; empty on failure (merge falls back to Supabase).
    private func loadHealthKitAllTimeBests(userId: UUID) async -> HealthKitAllTimeBests {
        do {
            return try await HealthKitService.fetchAllTimeBestsFromHealth()
        } catch {
            AppLogger.log(
                category: "healthkit_read",
                level: .warning,
                message: "all-time bests from HealthKit failed",
                userId: userId,
                metadata: [
                    "error": error.localizedDescription,
                    "error_type": String(describing: type(of: error)),
                ]
            )
            return .empty
        }
    }

    private func healthKitStep<T>(
        _ step: String,
        userId: UUID,
        _ operation: () async throws -> T
    ) async throws -> T {
        do {
            return try await operation()
        } catch {
            AppLogger.log(
                category: "healthkit_read",
                level: .warning,
                message: "health screen HK step failed [\(step)]",
                userId: userId,
                metadata: [
                    "step": step,
                    "error": error.localizedDescription,
                    "error_type": String(describing: type(of: error)),
                ]
            )
            throw error
        }
    }

    private static func formatHealthDataSnapshot(
        source: String,
        stepsToday: Int,
        calsToday: Int,
        restingBPM: Double?,
        sleepAgg: HealthSleepSummary,
        weekSteps: [Int],
        weekCalories: [Int],
        zones: [HealthHRZoneRow],
        readinessScore: Int
    ) -> [String: String] {
        let stages = sleepAgg.stagePercentagesSevenNight
        let zonesSummary = zones.map { "\($0.label)=\($0.valueLabel) (\(String(format: "%.0f", $0.percent))%)" }.joined(separator: " | ")
        let snapshot = [
            "source=\(source)",
            "readiness_score=\(readinessScore)",
            "today_steps=\(stepsToday)",
            "today_active_kcal=\(calsToday)",
            "resting_hr_bpm=\(restingBPM.map { String(format: "%.1f", $0) } ?? "nil")",
            "sleep_avg_hrs_7n=\(String(format: "%.2f", sleepAgg.averageHoursLastNights))",
            "sleep_variance_hrs=\(String(format: "%.2f", sleepAgg.varianceHours))",
            "sleep_last_night_hrs=\(sleepAgg.lastNightAsleepHours.map { String(format: "%.2f", $0) } ?? "nil")",
            "sleep_nightly_hrs_oldest_to_today=\(sleepAgg.nightlyAsleepHoursOldestFirst.map { String(format: "%.2f", $0) }.joined(separator: ","))",
            "sleep_last_night_timeline_segments=\(sleepAgg.lastNightTimeline.count)",
            "sleep_ratio_deep_pct=\(sleepAgg.lastNightSleepRatio.map { String(format: "%.1f", $0.deepPercent) } ?? "nil")",
            "sleep_ratio_light_pct=\(sleepAgg.lastNightSleepRatio.map { String(format: "%.1f", $0.lightPercent) } ?? "nil")",
            "sleep_ratio_rem_pct=\(sleepAgg.lastNightSleepRatio.map { String(format: "%.1f", $0.remPercent) } ?? "nil")",
            "sleep_stages_7n_pct_deep=\(String(format: "%.1f", stages.deep)) core=\(String(format: "%.1f", stages.core)) rem=\(String(format: "%.1f", stages.rem)) awake=\(String(format: "%.1f", stages.awake))",
            "week_steps_oldest_to_today=\(weekSteps.map(String.init).joined(separator: ","))",
            "week_cal_oldest_to_today=\(weekCalories.map(String.init).joined(separator: ","))",
            "hr_zones=\(zonesSummary.isEmpty ? "—" : zonesSummary)",
        ].joined(separator: "\n")
        return [
            "hk_snapshot": snapshot,
            "week_steps_csv": weekSteps.map(String.init).joined(separator: ","),
            "week_cal_csv": weekCalories.map(String.init).joined(separator: ","),
        ]
    }

    private func formatSleepHours(_ h: Double?) -> String {
        guard let h, h > 0 else { return "—" }
        return String(format: "%.1fh", h)
    }

    private func formatStepsShort(_ n: Int) -> String {
        if n >= 1000 {
            return String(format: "%.1fk", Double(n) / 1000)
        }
        return "\(n)"
    }

}
