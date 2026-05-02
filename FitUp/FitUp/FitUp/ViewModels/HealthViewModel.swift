//
//  HealthViewModel.swift
//  FitUp
//
//  Slice 12 — Health screen state (HealthKit + Supabase).
//

import Combine
import Foundation
import HealthKit

struct HealthWeekComparison: Equatable {
    let metricType: HealthViewModel.StatsTab
    let currentTotal: Int
    let previousTotal: Int
    let currentWeekDaily: [Int]
    let previousWeekDaily: [Int]

    var delta: Int { currentTotal - previousTotal }
    var percentDelta: Int {
        guard previousTotal > 0 else { return currentTotal > 0 ? 100 : 0 }
        return Int((Double(delta) / Double(previousTotal) * 100).rounded())
    }
    var currentBarFraction: Double {
        let maxValue = max(currentTotal, previousTotal, 1)
        return Double(currentTotal) / Double(maxValue)
    }
    var previousBarFraction: Double {
        let maxValue = max(currentTotal, previousTotal, 1)
        return Double(previousTotal) / Double(maxValue)
    }
    var metricUnitLabel: String { metricType == .steps ? "steps" : "cal" }
    var currentValueText: String { currentTotal.formatted() }
    var previousValueText: String { previousTotal.formatted() }
    var headline: String {
        if delta == 0 { return "On pace with last week at this point." }
        if delta > 0 { return "+\(percentDelta)% vs last week" }
        return "\(percentDelta)% vs last week"
    }
}

struct HealthGoalConsistency: Equatable {
    let goalHitCount: Int
    let dayStates: [Bool]
    let currentStreakDays: Int

    var summaryLabel: String {
        "\(goalHitCount)/\(dayStates.count) goal-hit days this week"
    }

    var streakLabel: String {
        if currentStreakDays == 1 { return "1 day" }
        return "\(currentStreakDays) days"
    }
}

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

    @Published private(set) var weekComparisonSteps: HealthWeekComparison?
    @Published private(set) var weekComparisonCalories: HealthWeekComparison?
    @Published private(set) var battleStats = HealthBattleStats.empty

    @Published private(set) var activeMatchEdges: [HomeActiveMatch] = []
    @Published private(set) var completedMatches: [ActivityCompletedMatch] = []
    @Published private(set) var isLoadingCompletedMatches = false
    @Published private(set) var hasLoadedCompletedMatches = false

    @Published private(set) var showSyncedBadge = false
    @Published private(set) var lastLoadFinishedAt: Date?

    @Published private(set) var sleepLastNightHours: Double?
    /// Raw values for component breakdown rows (matches JSX `metric.actual / metric.goal`).
    @Published private(set) var stepsTodayValue = 0
    @Published private(set) var caloriesTodayValue = 0
    @Published private(set) var restingHRValue: Double?

    private let battleStatsRepository = BattleStatsRepository()
    private let homeRepository = HomeRepository()
    private let activityRepository = ActivityRepository()

    private var profileId: UUID?
    private var profileTimeZoneIdentifier: String?
    private var completedMatchesTask: Task<Void, Never>?

    var selectedWeekComparison: HealthWeekComparison? {
        statsTab == .steps ? weekComparisonSteps : weekComparisonCalories
    }

    var goalConsistency: HealthGoalConsistency {
        let dayStates = weekSteps.map { goals.stepsGoal > 0 && $0 >= goals.stepsGoal }
        let hitCount = dayStates.filter { $0 }.count
        var streak = 0
        for hit in dayStates.reversed() {
            guard hit else { break }
            streak += 1
        }
        return HealthGoalConsistency(goalHitCount: hitCount, dayStates: dayStates, currentStreakDays: streak)
    }

    func start(profile: Profile?) {
        let newProfileId = profile?.id
        if profileId != newProfileId {
            completedMatchesTask?.cancel()
            completedMatchesTask = nil
            completedMatches = []
            isLoadingCompletedMatches = false
            hasLoadedCompletedMatches = false
        }
        profileId = newProfileId
        profileTimeZoneIdentifier = profile?.timezone
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

        await HealthKitService.requestAuthorizationIfNeeded(analyticsUserId: userId)

        let stepsToday: Int
        do {
            stepsToday = try await healthKitRead("today_steps", userId: userId) {
                try await HealthKitService.fetchTodayStepCount()
            }
        } catch {
            showSyncedBadge = false
            if let hk = error as? HealthKitError, case .authorizationDenied = hk {
                showHealthAccessBanner = true
            } else {
                showHealthAccessBanner = false
            }
            errorMessage = error.localizedDescription
            resetHealthDisplayToEmpty()
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
            return
        }

        let calsToday: Int
        var caloriesAuthorizationDenied = false
        do {
            calsToday = try await healthKitRead("today_active_calories", userId: userId) {
                try await HealthKitService.fetchTodayActiveCalories()
            }
        } catch {
            calsToday = 0
            if let hk = error as? HealthKitError, case .authorizationDenied = hk {
                caloriesAuthorizationDenied = true
                errorMessage = error.localizedDescription
            } else {
                AppLogger.log(
                    category: "healthkit_read",
                    level: .warning,
                    message: "health screen active calories unavailable; using 0",
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

        showHealthAccessBanner = caloriesAuthorizationDenied
        if !caloriesAuthorizationDenied {
            errorMessage = nil
        }

        stepsTodayValue = stepsToday
        caloriesTodayValue = calsToday
        stepsTodayDisplay = formatStepsShort(stepsToday)
        caloriesTodayDisplay = "\(calsToday)"
        showSyncedBadge = true

        let coreDurationMs = Int(loadStarted.timeIntervalSinceNow * -1000)
        AppLogger.log(
            category: "healthkit_read",
            level: .info,
            message: "health screen core ok",
            userId: userId,
            metadata: [
                "source": source,
                "pipeline": "HealthViewModel.reload",
                "steps_today": "\(stepsToday)",
                "active_calories_today": "\(calsToday)",
                "duration_ms": "\(coreDurationMs)",
            ]
        )

        async let restingOutcome = loadOptionalHK("resting_heart_rate", userId: userId, fallback: nil as Double?) {
            try await HealthKitService.fetchRestingHeartRate()
        }
        async let sleepOutcome = loadOptionalHK("sleep_summary_7n", userId: userId, fallback: nil as HealthSleepSummary?) {
            await HealthKitService.fetchSleepSummary(nights: 7)
        }
        async let weekStepsOutcome = loadOptionalHK("week_steps_array", userId: userId, fallback: Array(repeating: 0, count: 7)) {
            try await HealthKitService.fetchSevenDayStepsArray()
        }
        async let weekCalsOutcome = loadOptionalHK("week_calories_array", userId: userId, fallback: Array(repeating: 0, count: 7)) {
            try await HealthKitService.fetchSevenDayCaloriesArray()
        }

        let restingResult = await restingOutcome
        let sleepResult = await sleepOutcome
        let wStepsResult = await weekStepsOutcome
        let wCalsResult = await weekCalsOutcome

        let resting = restingResult.value
        let sleepAgg = sleepResult.value
        let wSteps = wStepsResult.value
        let wCals = wCalsResult.value

        let sleepForReadiness = sleepAgg?.lastNightAsleepHours

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

        sleepLastNightHours = sleepAgg?.lastNightAsleepHours
        sleepHoursDisplay = formatSleepHours(sleepForReadiness)
        restingHRDisplay = resting.map { "\(Int($0.rounded()))" } ?? "—"
        restingHRValue = resting

        weekSteps = wSteps
        weekCalories = wCals
        sleepSummary = sleepAgg

        async let weekComparisonResult = buildWeekComparisons()
        async let battleStatsResult = battleStatsRepository.fetchHealthBattleStats()
        async let activeMatches = homeRepository.loadActiveMatches(for: userId, profileTimeZoneIdentifier: profileTimeZoneIdentifier)

        let comparisonResolved = await weekComparisonResult
        weekComparisonSteps = comparisonResolved.steps
        weekComparisonCalories = comparisonResolved.calories
        battleStats = await battleStatsResult
        activeMatchEdges = await activeMatches

        lastLoadFinishedAt = Date()

        let durationMs = Int(loadStarted.timeIntervalSinceNow * -1000)
        let hkSnapshot = Self.formatHealthDataSnapshot(
            source: source,
            stepsToday: stepsToday,
            calsToday: calsToday,
            restingBPM: resting,
            sleepAgg: sleepAgg,
            weekSteps: wSteps,
            weekCalories: wCals,
            readinessScore: score
        )
        var meta = hkSnapshot
        meta["source"] = source
        meta["pipeline"] = "HealthViewModel.reload"
        meta["duration_ms"] = "\(durationMs)"
        meta["load_finished_at"] = ISO8601DateFormatter().string(from: Date())
        meta["active_matches_count"] = "\(activeMatchEdges.count)"
        meta["battle_matches_played"] = "\(battleStats.matchesPlayed)"
        meta["battle_wins"] = "\(battleStats.wins)"
        meta["optional_resting_ok"] = "\(restingResult.ok)"
        meta["optional_sleep_ok"] = "\(sleepResult.ok)"
        meta["optional_week_steps_ok"] = "\(wStepsResult.ok)"
        meta["optional_week_cals_ok"] = "\(wCalsResult.ok)"
        AppLogger.log(
            category: "healthkit_read",
            level: .info,
            message: "health screen load ok (HK + home data)",
            userId: userId,
            metadata: meta
        )

        if hasLoadedCompletedMatches {
            await loadCompletedMatches(force: true)
        }
    }

    func loadCompletedMatchesIfNeeded() async {
        await loadCompletedMatches(force: false)
    }

    func loadCompletedMatches(force: Bool) async {
        guard let userId = profileId else { return }
        if isLoadingCompletedMatches { return }
        if hasLoadedCompletedMatches, !force { return }
        isLoadingCompletedMatches = true
        defer { isLoadingCompletedMatches = false }

        completedMatchesTask?.cancel()
        completedMatchesTask = Task { [weak self] in
            guard let self else { return }
            let rows = await activityRepository.loadCompletedMatches(currentUserId: userId)
            guard !Task.isCancelled else { return }
            guard self.profileId == userId else { return }
            self.completedMatches = rows
            self.hasLoadedCompletedMatches = true
        }
        await completedMatchesTask?.value
    }

    private func resetHealthDisplayToEmpty() {
        battleReadinessScore = 0
        battleReadinessLabel = ""
        battleReadinessSubtitle = ""
        sleepHoursDisplay = "—"
        restingHRDisplay = "—"
        stepsTodayDisplay = "—"
        caloriesTodayDisplay = "—"
        weekSteps = Array(repeating: 0, count: 7)
        weekCalories = Array(repeating: 0, count: 7)
        sleepSummary = nil
        sleepLastNightHours = nil
        stepsTodayValue = 0
        caloriesTodayValue = 0
        restingHRValue = nil
        lastLoadFinishedAt = nil
        weekComparisonSteps = nil
        weekComparisonCalories = nil
        battleStats = .empty
        activeMatchEdges = []
    }

    private func healthKitRead<T>(
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
                message: "health screen HK read failed [\(step)]",
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

    private func loadOptionalHK<T>(
        _ step: String,
        userId: UUID,
        fallback: T,
        operation: () async throws -> T
    ) async -> (value: T, ok: Bool) {
        do {
            let v = try await operation()
            return (v, true)
        } catch {
            var metadata: [String: String] = [
                "step": step,
                "error": error.localizedDescription,
                "error_type": String(describing: type(of: error)),
            ]
            if let hk = error as? HKError {
                metadata["hk_error_code"] = "\(hk.code.rawValue)"
            }
            AppLogger.log(
                category: "healthkit_read",
                level: .warning,
                message: "health screen HK read failed [\(step)]",
                userId: userId,
                metadata: metadata
            )
            return (fallback, false)
        }
    }

    private static func formatHealthDataSnapshot(
        source: String,
        stepsToday: Int,
        calsToday: Int,
        restingBPM: Double?,
        sleepAgg: HealthSleepSummary?,
        weekSteps: [Int],
        weekCalories: [Int],
        readinessScore: Int
    ) -> [String: String] {
        let snapshot: String
        if let sleepAgg {
            let stages = sleepAgg.stagePercentagesSevenNight
            snapshot = [
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
            ].joined(separator: "\n")
        } else {
            snapshot = [
                "source=\(source)",
                "readiness_score=\(readinessScore)",
                "today_steps=\(stepsToday)",
                "today_active_kcal=\(calsToday)",
                "resting_hr_bpm=\(restingBPM.map { String(format: "%.1f", $0) } ?? "nil")",
                "sleep_summary=—",
                "week_steps_oldest_to_today=\(weekSteps.map(String.init).joined(separator: ","))",
                "week_cal_oldest_to_today=\(weekCalories.map(String.init).joined(separator: ","))",
            ].joined(separator: "\n")
        }
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

    private func buildWeekComparisons() async -> (steps: HealthWeekComparison?, calories: HealthWeekComparison?) {
        let tz = profileTimeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        var calendar = Calendar.current
        calendar.timeZone = tz
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: startOfToday) else {
            return (nil, nil)
        }
        let currentWeekStart = weekInterval.start
        let elapsed = now.timeIntervalSince(currentWeekStart)
        guard let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart) else {
            return (nil, nil)
        }
        let lastWeekEnd = lastWeekStart.addingTimeInterval(max(0, elapsed))

        async let currentSteps = try? HealthKitService.fetchMetricTotal(metricType: .steps, startDate: currentWeekStart, endDate: now)
        async let previousSteps = try? HealthKitService.fetchMetricTotal(metricType: .steps, startDate: lastWeekStart, endDate: lastWeekEnd)
        async let currentCals = try? HealthKitService.fetchMetricTotal(metricType: .activeCalories, startDate: currentWeekStart, endDate: now)
        async let previousCals = try? HealthKitService.fetchMetricTotal(metricType: .activeCalories, startDate: lastWeekStart, endDate: lastWeekEnd)
        let resolvedCurrentSteps = await currentSteps
        let resolvedPreviousSteps = await previousSteps
        let resolvedCurrentCals = await currentCals
        let resolvedPreviousCals = await previousCals

        let steps: HealthWeekComparison? = {
            guard let current = resolvedCurrentSteps, let previous = resolvedPreviousSteps else { return nil }
            let currentDaily = currentWeekDailyValues(
                weekValuesOldestToToday: weekSteps,
                calendar: calendar,
                now: now
            )
            let previousDaily = syntheticPreviousWeekDailyTotals(
                targetTotal: previous,
                basisDaily: currentDaily
            )
            return HealthWeekComparison(
                metricType: .steps,
                currentTotal: current,
                previousTotal: previous,
                currentWeekDaily: currentDaily,
                previousWeekDaily: previousDaily
            )
        }()
        let calories: HealthWeekComparison? = {
            guard let current = resolvedCurrentCals, let previous = resolvedPreviousCals else { return nil }
            let currentDaily = currentWeekDailyValues(
                weekValuesOldestToToday: weekCalories,
                calendar: calendar,
                now: now
            )
            let previousDaily = syntheticPreviousWeekDailyTotals(
                targetTotal: previous,
                basisDaily: currentDaily
            )
            return HealthWeekComparison(
                metricType: .calories,
                currentTotal: current,
                previousTotal: previous,
                currentWeekDaily: currentDaily,
                previousWeekDaily: previousDaily
            )
        }()
        return (steps, calories)
    }

    /// Maps the visible 7-day oldest->today values into the current Monday->Sunday week slots.
    private func currentWeekDailyValues(
        weekValuesOldestToToday: [Int],
        calendar: Calendar,
        now: Date
    ) -> [Int] {
        guard let currentWeek = calendar.dateInterval(of: .weekOfYear, for: now) else {
            return Array(repeating: 0, count: 7)
        }
        var map: [Date: Int] = [:]
        let todayStart = calendar.startOfDay(for: now)
        for offset in 0..<min(weekValuesOldestToToday.count, 7) {
            guard let day = calendar.date(byAdding: .day, value: -(6 - offset), to: todayStart) else { continue }
            map[calendar.startOfDay(for: day)] = weekValuesOldestToToday[offset]
        }

        var values: [Int] = []
        for i in 0..<7 {
            guard let day = calendar.date(byAdding: .day, value: i, to: currentWeek.start) else {
                values.append(0)
                continue
            }
            values.append(map[calendar.startOfDay(for: day)] ?? 0)
        }
        return values
    }

    /// Synthetic fallback for last-week daily shape when only week-to-date total is known.
    private func syntheticPreviousWeekDailyTotals(
        targetTotal: Int,
        basisDaily: [Int]
    ) -> [Int] {
        guard targetTotal > 0 else { return Array(repeating: 0, count: 7) }
        let dayCount = max(basisDaily.count, 7)
        let basis = basisDaily.count == 7 ? basisDaily : Array(repeating: 1, count: dayCount)
        let safeBasis = basis.map { max(1, $0) }
        let sumBasis = max(1, safeBasis.reduce(0, +))
        let raw = safeBasis.map { Double($0) / Double(sumBasis) * Double(targetTotal) }
        var ints = raw.map { Int($0.rounded()) }
        var delta = targetTotal - ints.reduce(0, +)
        var idx = 0
        while delta != 0, idx < 100 {
            let i = idx % ints.count
            if delta > 0 {
                ints[i] += 1
                delta -= 1
            } else if ints[i] > 0 {
                ints[i] -= 1
                delta += 1
            }
            idx += 1
        }
        if ints.count < 7 {
            return ints + Array(repeating: 0, count: 7 - ints.count)
        }
        return Array(ints.prefix(7))
    }

}
