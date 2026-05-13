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

    enum StatsRangeKey: String, CaseIterable, Identifiable, Codable {
        case oneDay = "1D"
        case sevenDays = "7D"
        case thirtyDays = "30D"
        case threeMonths = "3M"
        case oneYear = "1Y"
        case all = "ALL"

        var id: String { rawValue }

        var dayCountIfSupported: Int? {
            switch self {
            case .oneDay: return 1
            case .sevenDays: return 7
            case .thirtyDays: return 30
            case .threeMonths, .oneYear, .all: return nil
            }
        }

        var fallbackDayCount: Int {
            dayCountIfSupported ?? 30
        }

        init(apiRawValue: String) {
            self = StatsRangeKey(rawValue: apiRawValue) ?? .oneDay
        }
    }

    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    /// Shown when HealthKit reports read access denied; use Open Settings in the UI.
    @Published private(set) var showHealthAccessBanner = false
    @Published var statsTab: StatsTab = .steps

    @Published private(set) var battleReadinessScore = 0
    @Published private(set) var battleReadinessLabel = ""
    @Published private(set) var battleReadinessSubtitle = ""

    @Published private(set) var restingHRDisplay = "—"
    @Published private(set) var stepsTodayDisplay = "—"
    @Published private(set) var caloriesTodayDisplay = "—"

    @Published private(set) var goals = ReadinessGoals.loadFromUserDefaults()

    @Published private(set) var weekSteps: [Int] = Array(repeating: 0, count: 7)
    @Published private(set) var weekCalories: [Int] = Array(repeating: 0, count: 7)

    @Published private(set) var weekComparisonSteps: HealthWeekComparison?
    @Published private(set) var weekComparisonCalories: HealthWeekComparison?
    @Published private(set) var battleStats = HealthBattleStats.empty
    @Published private(set) var dailyBattleMargins: [DailyBattleMargin] = []
    @Published private(set) var isBattleMarginsRefreshing = false
    @Published private(set) var battleMarginsSavedAt: Date?
    @Published var marginChartDayCount: Int = 7
    @Published var statsSelectedRange: StatsRangeKey = .oneDay
    @Published private(set) var statsRangeDateChipText: String = "—"
    @Published private(set) var statsRangeScopeNote: String? = nil
    @Published private(set) var statsRangeMargins: [DailyBattleMargin] = []
    @Published private(set) var statsEffectiveRange: StatsRangeKey = .oneDay
    @Published private(set) var statsPreviousPeriodPercent: Int? = nil
    @Published private(set) var statsBattleStatsScopeLabel: String = "lifetime"
    @Published private(set) var isStatsRangeMarginsRefreshing = false
    /// Hourly step buckets for today (first hour with activity through the current hour). Populated only while `statsSelectedRange == .oneDay`.
    @Published private(set) var oneDayHourlySteps: [HealthIntradayHourlyBucket] = []
    @Published private(set) var isOneDayHourlyLoading = false

    @Published private(set) var activeMatchEdges: [HomeActiveMatch] = []
    @Published private(set) var completedMatches: [ActivityCompletedMatch] = []
    @Published private(set) var isLoadingCompletedMatches = false
    @Published private(set) var hasLoadedCompletedMatches = false
    @Published private(set) var rivalStats: [HomeRivalStat] = []
    @Published private(set) var isRivalStatsLoading = false
    @Published private(set) var hasLoadedRivalStats = false

    @Published private(set) var showSyncedBadge = false
    @Published private(set) var lastLoadFinishedAt: Date?

    /// Raw values for component breakdown rows (matches JSX `metric.actual / metric.goal`).
    @Published private(set) var stepsTodayValue = 0
    @Published private(set) var caloriesTodayValue = 0
    @Published private(set) var restingHRValue: Double?

    private let battleStatsRepository = BattleStatsRepository()
    private let homeRepository = HomeRepository()
    private let activityRepository = ActivityRepository()
    private let statsSnapshotCacheStore = StatsPageSnapshotCacheStore()
    private let statsSnapshotSoftTTL: TimeInterval = 60 * 5

    private var profileId: UUID?
    private var profileTimeZoneIdentifier: String?
    private var completedMatchesTask: Task<Void, Never>?
    private var rivalStatsTask: Task<Void, Never>?
    private var statsSnapshotSavedAt: Date?

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
            rivalStatsTask?.cancel()
            rivalStatsTask = nil
            rivalStats = []
            isRivalStatsLoading = false
            hasLoadedRivalStats = false
            statsRangeMargins = []
            isStatsRangeMarginsRefreshing = false
            statsRangeScopeNote = nil
            statsEffectiveRange = .oneDay
            statsPreviousPeriodPercent = nil
            statsBattleStatsScopeLabel = "lifetime"
            statsSnapshotSavedAt = nil
            oneDayHourlySteps = []
            isOneDayHourlyLoading = false
        }
        profileId = newProfileId
        profileTimeZoneIdentifier = profile?.timezone
        updateStatsDateChipText()
        if let newProfileId {
            loadStatsSnapshotIfAvailable(profileId: newProfileId)
        }
        Task { await reload(source: "profile_task") }
    }

    func setStatsRange(_ range: StatsRangeKey) async {
        guard statsSelectedRange != range else { return }
        statsSelectedRange = range
        statsEffectiveRange = range.dayCountIfSupported == nil ? .oneDay : range
        updateStatsDateChipText()
        if let profileId {
            loadStatsSnapshotIfAvailable(profileId: profileId)
        }
        async let marginsTask: Void = refreshStatsRangeMargins(source: "stats_range_change", forceNetworkRefresh: true)
        async let hourlyTask: Void = refreshOneDayHourlyStepsIfNeeded()
        _ = await (marginsTask, hourlyTask)
        saveStatsSnapshotIfPossible()
    }

    /// HealthKit hourly buckets for today; only refreshed while the stats range is 1D so we skip the HK round-trip in other ranges.
    private func refreshOneDayHourlyStepsIfNeeded() async {
        guard statsSelectedRange == .oneDay else {
            oneDayHourlySteps = []
            isOneDayHourlyLoading = false
            return
        }
        isOneDayHourlyLoading = true
        defer { isOneDayHourlyLoading = false }
        do {
            let tz = profileTimeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
            let buckets = try await HealthKitService.fetchIntradayHourlyDeltas(
                metricType: .steps,
                for: Date(),
                timeZone: tz
            )
            oneDayHourlySteps = buckets
        } catch {
            oneDayHourlySteps = []
        }
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
        async let weekStepsOutcome = loadOptionalHK("week_steps_array", userId: userId, fallback: Array(repeating: 0, count: 7)) {
            try await HealthKitService.fetchSevenDayStepsArray()
        }
        async let weekCalsOutcome = loadOptionalHK("week_calories_array", userId: userId, fallback: Array(repeating: 0, count: 7)) {
            try await HealthKitService.fetchSevenDayCaloriesArray()
        }

        let restingResult = await restingOutcome
        let wStepsResult = await weekStepsOutcome
        let wCalsResult = await weekCalsOutcome

        let resting = restingResult.value
        let wSteps = wStepsResult.value
        let wCals = wCalsResult.value

        let score = ReadinessCalculator.compute(
            sleepHrsLastNight: nil,
            restingHR: resting,
            stepsToday: stepsToday,
            calsToday: calsToday,
            goals: goals
        )

        battleReadinessScore = score
        battleReadinessLabel = ReadinessCalculator.label(for: score)
        battleReadinessSubtitle = ReadinessCalculator.subtitle(for: score)

        restingHRDisplay = resting.map { "\(Int($0.rounded()))" } ?? "—"
        restingHRValue = resting

        weekSteps = wSteps
        weekCalories = wCals

        async let weekComparisonResult = buildWeekComparisons()
        async let activeMatches = homeRepository.loadActiveMatches(for: userId, profileTimeZoneIdentifier: profileTimeZoneIdentifier)

        let comparisonResolved = await weekComparisonResult
        weekComparisonSteps = comparisonResolved.steps
        weekComparisonCalories = comparisonResolved.calories
        activeMatchEdges = await activeMatches
        await refreshBattleMargins(source: source)
        let forceStatsRefresh = source == "pull_refresh"
        await refreshStatsRangeMargins(source: source, forceNetworkRefresh: forceStatsRefresh)
        await refreshOneDayHourlyStepsIfNeeded()
        await loadRivalStats(force: source == "pull_refresh")
        saveStatsSnapshotIfPossible()
        await loadCompletedMatchesIfNeeded()

        lastLoadFinishedAt = Date()

        let durationMs = Int(loadStarted.timeIntervalSinceNow * -1000)
        let hkSnapshot = Self.formatHealthDataSnapshot(
            source: source,
            stepsToday: stepsToday,
            calsToday: calsToday,
            restingBPM: resting,
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

    func loadRivalStatsIfNeeded() async {
        await loadRivalStats(force: false)
    }

    func loadRivalStats(force: Bool) async {
        guard let requestedProfileId = profileId else { return }
        if isRivalStatsLoading { return }
        if hasLoadedRivalStats, !force { return }
        isRivalStatsLoading = true
        defer { isRivalStatsLoading = false }

        rivalStatsTask?.cancel()
        rivalStatsTask = Task { [weak self] in
            guard let self else { return }
            let rows = await homeRepository.fetchMyRivalStats(limit: 3)
            guard !Task.isCancelled else { return }
            guard self.profileId == requestedProfileId else { return }
            self.rivalStats = rows
            self.hasLoadedRivalStats = true
        }
        await rivalStatsTask?.value
    }

    private func resetHealthDisplayToEmpty() {
        battleReadinessScore = 0
        battleReadinessLabel = ""
        battleReadinessSubtitle = ""
        restingHRDisplay = "—"
        stepsTodayDisplay = "—"
        caloriesTodayDisplay = "—"
        weekSteps = Array(repeating: 0, count: 7)
        weekCalories = Array(repeating: 0, count: 7)
        stepsTodayValue = 0
        caloriesTodayValue = 0
        restingHRValue = nil
        lastLoadFinishedAt = nil
        weekComparisonSteps = nil
        weekComparisonCalories = nil
        battleStats = .empty
        activeMatchEdges = []
        rivalStats = []
        isRivalStatsLoading = false
        hasLoadedRivalStats = false
        dailyBattleMargins = []
        isBattleMarginsRefreshing = false
        battleMarginsSavedAt = nil
        statsRangeMargins = []
        isStatsRangeMarginsRefreshing = false
        statsRangeScopeNote = nil
        statsEffectiveRange = .oneDay
        statsPreviousPeriodPercent = nil
        statsBattleStatsScopeLabel = "lifetime"
    }

    func setMarginChartDayCount(_ n: Int) async {
        let clamped = n >= 10 ? 10 : 7
        guard marginChartDayCount != clamped else { return }
        marginChartDayCount = clamped
        await refreshBattleMargins(source: "chart_range_change")
    }

    private func refreshBattleMargins(source: String) async {
        guard profileId != nil else {
            dailyBattleMargins = []
            battleMarginsSavedAt = nil
            isBattleMarginsRefreshing = false
            return
        }
        isBattleMarginsRefreshing = true
        defer { isBattleMarginsRefreshing = false }

        let rows = await homeRepository.fetchDailyBattleMargins(
            endDate: Date(),
            dayCount: marginChartDayCount,
            metricType: HomeBattleHeroCard.HeroMetric.steps.metricType,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )
        dailyBattleMargins = rows
        battleMarginsSavedAt = Date()
        AppLogger.log(
            category: "healthkit_read",
            level: .info,
            message: "health battle margin refreshed",
            userId: profileId,
            metadata: [
                "source": source,
                "point_count": "\(rows.count)",
                "day_count": "\(marginChartDayCount)"
            ]
        )
    }

    private func refreshStatsRangeMargins(source: String, forceNetworkRefresh: Bool = false) async {
        guard profileId != nil else {
            statsRangeMargins = []
            isStatsRangeMarginsRefreshing = false
            statsRangeScopeNote = nil
            return
        }
        if !forceNetworkRefresh, !shouldRefreshStatsSnapshot() {
            return
        }
        isStatsRangeMarginsRefreshing = true
        defer { isStatsRangeMarginsRefreshing = false }

        let resolvedDayCount = statsSelectedRange.fallbackDayCount
        if let snapshot = await homeRepository.fetchStatsSnapshot(
            rangeKey: statsSelectedRange.rawValue,
            metricType: HomeBattleHeroCard.HeroMetric.steps.metricType
        ) {
            statsEffectiveRange = StatsRangeKey(apiRawValue: snapshot.effectiveRangeKey)
            statsRangeMargins = snapshot.margins
            statsPreviousPeriodPercent = snapshot.previousPeriodPercent
            battleStats = snapshot.battleStats
            statsBattleStatsScopeLabel = snapshot.battleStatsScope
            statsRangeScopeNote = snapshot.rangeSupport == "native"
                ? nil
                : "\(statsSelectedRange.rawValue) uses 30D data until expanded backend range support lands."
        } else {
            statsEffectiveRange = statsSelectedRange.dayCountIfSupported == nil ? .oneDay : statsSelectedRange
            statsRangeScopeNote = statsSelectedRange.dayCountIfSupported == nil
                ? "\(statsSelectedRange.rawValue) uses 30D data until backend snapshot support lands."
                : nil
            statsPreviousPeriodPercent = nil
            let rows = await homeRepository.fetchDailyBattleMargins(
                endDate: Date(),
                dayCount: resolvedDayCount,
                metricType: HomeBattleHeroCard.HeroMetric.steps.metricType,
                profileTimeZoneIdentifier: profileTimeZoneIdentifier
            )
            statsRangeMargins = rows
            battleStats = await battleStatsRepository.fetchHealthBattleStats()
            statsBattleStatsScopeLabel = "lifetime"
        }
        AppLogger.log(
            category: "healthkit_read",
            level: .info,
            message: "stats range battle margin refreshed",
            userId: profileId,
            metadata: [
                "source": source,
                "point_count": "\(statsRangeMargins.count)",
                "day_count": "\(resolvedDayCount)",
                "selected_range": statsSelectedRange.rawValue,
            ]
        )
        statsSnapshotSavedAt = Date()
    }

    private func updateStatsDateChipText(now: Date = Date()) {
        let tz = profileTimeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let endDate = calendar.startOfDay(for: now)
        let dayCount = statsSelectedRange.fallbackDayCount
        guard let startDate = calendar.date(byAdding: .day, value: -(dayCount - 1), to: endDate) else {
            statsRangeDateChipText = "—"
            return
        }
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = tz
        formatter.dateFormat = "MMM d"
        statsRangeDateChipText = "\(formatter.string(from: startDate)) – \(formatter.string(from: endDate))"
    }

    private func loadStatsSnapshotIfAvailable(profileId: UUID) {
        guard let cached = statsSnapshotCacheStore.load(
            profileId: profileId,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier,
            rangeKeyRaw: statsSelectedRange.rawValue
        ) else { return }
        statsRangeMargins = cached.margins
        battleStats = cached.battleStats
        statsEffectiveRange = StatsRangeKey(apiRawValue: cached.effectiveRangeKeyRaw)
        statsPreviousPeriodPercent = cached.previousPeriodPercent
        statsBattleStatsScopeLabel = cached.battleStatsScopeLabel
        statsRangeDateChipText = cached.dateChipText
        statsRangeScopeNote = cached.fallbackScopeNote
        statsSnapshotSavedAt = cached.savedAt
    }

    private func saveStatsSnapshotIfPossible() {
        guard let profileId else { return }
        let snapshot = statsSnapshotCacheStore.makeSnapshot(
            profileId: profileId,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier,
            rangeKeyRaw: statsSelectedRange.rawValue,
            effectiveRangeKeyRaw: statsEffectiveRange.rawValue,
            dateChipText: statsRangeDateChipText,
            fallbackScopeNote: statsRangeScopeNote,
            margins: statsRangeMargins,
            previousPeriodPercent: statsPreviousPeriodPercent,
            battleStatsScopeLabel: statsBattleStatsScopeLabel,
            battleStats: battleStats,
            savedAt: Date()
        )
        statsSnapshotCacheStore.save(snapshot)
        statsSnapshotSavedAt = snapshot.savedAt
    }

    private func shouldRefreshStatsSnapshot(now: Date = Date()) -> Bool {
        guard let savedAt = statsSnapshotSavedAt else { return true }
        return now.timeIntervalSince(savedAt) > statsSnapshotSoftTTL
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
        weekSteps: [Int],
        weekCalories: [Int],
        readinessScore: Int
    ) -> [String: String] {
        let snapshot = [
            "source=\(source)",
            "readiness_score=\(readinessScore)",
            "today_steps=\(stepsToday)",
            "today_active_kcal=\(calsToday)",
            "resting_hr_bpm=\(restingBPM.map { String(format: "%.1f", $0) } ?? "nil")",
            "week_steps_oldest_to_today=\(weekSteps.map(String.init).joined(separator: ","))",
            "week_cal_oldest_to_today=\(weekCalories.map(String.init).joined(separator: ","))",
        ].joined(separator: "\n")
        return [
            "hk_snapshot": snapshot,
            "week_steps_csv": weekSteps.map(String.init).joined(separator: ","),
            "week_cal_csv": weekCalories.map(String.init).joined(separator: ","),
        ]
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
