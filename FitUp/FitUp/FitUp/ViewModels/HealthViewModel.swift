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

    @Published private(set) var goals = ReadinessGoals.loadFromUserDefaults()

    @Published private(set) var weekSteps: [Int] = Array(repeating: 0, count: 7)
    @Published private(set) var weekCalories: [Int] = Array(repeating: 0, count: 7)

    @Published private(set) var weekComparisonSteps: HealthWeekComparison?
    @Published private(set) var weekComparisonCalories: HealthWeekComparison?
    @Published private(set) var battleStats = HealthBattleStats.empty
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
    @Published private(set) var rivalStats: [HomeRivalStat] = []
    @Published private(set) var isRivalStatsLoading = false
    @Published private(set) var hasLoadedRivalStats = false
    @Published private(set) var statsBattleImpactMetric: StatsBattleImpactMetric?
    @Published private(set) var statsMonthlyBattleBonusMetric: StatsMonthlyBattleBonusMetric?
    @Published private(set) var statsOpponentStepsRollups: StatsOpponentStepsRollups?
    @Published private(set) var statsBattleStepsDisplay: StatsBattleStepsDisplay?
    /// `nil` = timeline fetch failed; `[]` = loaded with no qualifying battle days.
    @Published private(set) var statsArcadeStreakTimeline: [StatsArcadeStreakDot]?

    @Published private(set) var completedMatches: [ActivityCompletedMatch] = []
    @Published private(set) var isLoadingCompletedMatches = false
    @Published private(set) var statsPersonalRecords: StatsPersonalRecords?
    @Published private(set) var statsAchievements: [StatsAchievementItem] = []
    @Published private(set) var isLoadingPersonalRecords = false

    @Published private(set) var lastLoadFinishedAt: Date?
    @Published private(set) var statsSnapshotSavedAt: Date?

    @Published private(set) var stepsTodayValue = 0
    @Published private(set) var caloriesTodayValue = 0

    private let battleStatsRepository = BattleStatsRepository()
    private let homeRepository = HomeRepository()
    private let activityRepository = ActivityRepository()
    private let calendarRepository = CalendarRepository()
    private let userBattleStepTotalsRepository = UserBattleStepTotalsRepository()
    private let statsSnapshotCacheStore = StatsPageSnapshotCacheStore()
    private let statsSnapshotSoftTTL: TimeInterval = 60 * 5

    private var profileId: UUID?
    private var profileTimeZoneIdentifier: String?
    private var rivalStatsTask: Task<Void, Never>?
    private var completedMatchesListTask: Task<Void, Never>?

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
            statsBattleImpactMetric = nil
            statsMonthlyBattleBonusMetric = nil
            statsOpponentStepsRollups = nil
            statsBattleStepsDisplay = nil
            statsArcadeStreakTimeline = nil
            completedMatches = []
            completedMatchesListTask?.cancel()
            completedMatchesListTask = nil
            isLoadingCompletedMatches = false
            activeMatchEdges = []
            statsPersonalRecords = nil
            statsAchievements = []
            isLoadingPersonalRecords = false
        }
        profileId = newProfileId
        profileTimeZoneIdentifier = profile?.timezone
        updateStatsDateChipText()
        if LegacyStatsFeature.isEnabled, let newProfileId {
            loadStatsSnapshotIfAvailable(profileId: newProfileId)
        }
        Task { await reload(source: "profile_task") }
    }

    func setStatsRange(_ range: StatsRangeKey) async {
        guard LegacyStatsFeature.isEnabled else { return }
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
        guard LegacyStatsFeature.isEnabled else {
            oneDayHourlySteps = []
            isOneDayHourlyLoading = false
            return
        }
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
            level: .debug,
            message: "health screen load started",
            userId: userId,
            metadata: [
                "source": source,
                "pipeline": "HealthViewModel.reload",
            ]
        )

        goals = ReadinessGoals.loadFromUserDefaults()

        await HealthKitService.requestAuthorizationIfNeeded(analyticsUserId: userId)

        if LegacyStatsFeature.isEnabled {
            await reloadLegacyStats(userId: userId, source: source, loadStarted: loadStarted)
        } else {
            await reloadArcadeStats(userId: userId, source: source, loadStarted: loadStarted)
        }
    }

    /// LegacyStatsFeature — arcade-only stats load (no margin charts, week arrays, or hourly buckets).
    private func reloadArcadeStats(userId: UUID, source: String, loadStarted: Date) async {
        errorMessage = nil
        showHealthAccessBanner = false

        async let opponentRollups = homeRepository.fetchOpponentStepsRollups()
        async let rivalStatsLoad = loadRivalStats(force: source == "pull_refresh")
        async let arcadeImpact = refreshArcadeImpactMetrics(userId: userId)
        async let arcadeStreak = refreshArcadeStreakTimeline(userId: userId)
        async let battleStatsLoad = refreshArcadeBattleStats()
        async let battleStepsLoad = refreshBattleStepsMetrics(userId: userId)
        async let activeMatchesLoad = homeRepository.loadActiveMatches(
            for: userId,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )

        await rivalStatsLoad
        await arcadeImpact
        statsOpponentStepsRollups = await opponentRollups
        await arcadeStreak
        await battleStatsLoad
        await battleStepsLoad
        activeMatchEdges = await activeMatchesLoad
        await refreshPersonalRecordsAndAchievements(userId: userId)

        lastLoadFinishedAt = Date()

        let durationMs = Int(loadStarted.timeIntervalSinceNow * -1000)
        AppLogger.log(
            category: "healthkit_read",
            level: .debug,
            message: "health screen arcade load ok",
            userId: userId,
            metadata: [
                "source": source,
                "pipeline": "HealthViewModel.reloadArcadeStats",
                "duration_ms": "\(durationMs)",
                "load_finished_at": ISO8601DateFormatter().string(from: Date()),
                "battle_matches_played": "\(battleStats.matchesPlayed)",
                "battle_wins": "\(battleStats.wins)",
            ]
        )
    }

    /// LegacyStatsFeature — full legacy + arcade stats load (week charts, margins, hourly buckets).
    private func reloadLegacyStats(userId: UUID, source: String, loadStarted: Date) async {
        let stepsToday: Int
        do {
            stepsToday = try await healthKitRead("today_steps", userId: userId) {
                try await HealthKitService.fetchTodayStepCount()
            }
        } catch {
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
                    "pipeline": "HealthViewModel.reloadLegacyStats",
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
                        "pipeline": "HealthViewModel.reloadLegacyStats",
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

        let coreDurationMs = Int(loadStarted.timeIntervalSinceNow * -1000)
        AppLogger.log(
            category: "healthkit_read",
            level: .debug,
            message: "health screen core ok",
            userId: userId,
            metadata: [
                "source": source,
                "pipeline": "HealthViewModel.reloadLegacyStats",
                "steps_today": "\(stepsToday)",
                "active_calories_today": "\(calsToday)",
                "duration_ms": "\(coreDurationMs)",
            ]
        )

        async let weekStepsOutcome = loadOptionalHK("week_steps_array", userId: userId, fallback: Array(repeating: 0, count: 7)) {
            try await HealthKitService.fetchSevenDayStepsArray()
        }
        async let weekCalsOutcome = loadOptionalHK("week_calories_array", userId: userId, fallback: Array(repeating: 0, count: 7)) {
            try await HealthKitService.fetchSevenDayCaloriesArray()
        }

        let wStepsResult = await weekStepsOutcome
        let wCalsResult = await weekCalsOutcome

        let wSteps = wStepsResult.value
        let wCals = wCalsResult.value

        weekSteps = wSteps
        weekCalories = wCals

        async let weekComparisonResult = buildWeekComparisons()
        async let activeMatches = homeRepository.loadActiveMatches(for: userId, profileTimeZoneIdentifier: profileTimeZoneIdentifier)

        let comparisonResolved = await weekComparisonResult
        weekComparisonSteps = comparisonResolved.steps
        weekComparisonCalories = comparisonResolved.calories
        activeMatchEdges = await activeMatches
        let forceStatsRefresh = source == "pull_refresh"
        await refreshStatsRangeMargins(source: source, forceNetworkRefresh: forceStatsRefresh)
        await refreshOneDayHourlyStepsIfNeeded()
        async let opponentRollups = homeRepository.fetchOpponentStepsRollups()
        async let rivalStatsLoad = loadRivalStats(force: source == "pull_refresh")
        async let arcadeImpact = refreshArcadeImpactMetrics(userId: userId)
        async let arcadeStreak = refreshArcadeStreakTimeline(userId: userId)
        await rivalStatsLoad
        await arcadeImpact
        statsOpponentStepsRollups = await opponentRollups
        await arcadeStreak
        saveStatsSnapshotIfPossible()

        lastLoadFinishedAt = Date()

        let durationMs = Int(loadStarted.timeIntervalSinceNow * -1000)
        let hkSnapshot = Self.formatHealthDataSnapshot(
            source: source,
            stepsToday: stepsToday,
            calsToday: calsToday,
            weekSteps: wSteps,
            weekCalories: wCals
        )
        var meta = hkSnapshot
        meta["source"] = source
        meta["pipeline"] = "HealthViewModel.reloadLegacyStats"
        meta["duration_ms"] = "\(durationMs)"
        meta["load_finished_at"] = ISO8601DateFormatter().string(from: Date())
        meta["active_matches_count"] = "\(activeMatchEdges.count)"
        meta["battle_matches_played"] = "\(battleStats.matchesPlayed)"
        meta["battle_wins"] = "\(battleStats.wins)"
        meta["optional_week_steps_ok"] = "\(wStepsResult.ok)"
        meta["optional_week_cals_ok"] = "\(wCalsResult.ok)"
        AppLogger.log(
            category: "healthkit_read",
            level: .debug,
            message: "health screen load ok (HK + home data)",
            userId: userId,
            metadata: meta
        )
    }

    private func refreshArcadeBattleStats() async {
        battleStats = await battleStatsRepository.fetchHealthBattleStats()
        statsBattleStatsScopeLabel = "lifetime"
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
            let rows = await homeRepository.fetchMyRivalStats(limit: 50)
            guard !Task.isCancelled else { return }
            guard self.profileId == requestedProfileId else { return }
            self.rivalStats = rows
            self.hasLoadedRivalStats = true
        }
        await rivalStatsTask?.value
    }

    private func resetHealthDisplayToEmpty() {
        weekSteps = Array(repeating: 0, count: 7)
        weekCalories = Array(repeating: 0, count: 7)
        stepsTodayValue = 0
        caloriesTodayValue = 0
        lastLoadFinishedAt = nil
        weekComparisonSteps = nil
        weekComparisonCalories = nil
        battleStats = .empty
        activeMatchEdges = []
        rivalStats = []
        isRivalStatsLoading = false
        hasLoadedRivalStats = false
        statsBattleImpactMetric = nil
        statsMonthlyBattleBonusMetric = nil
        statsOpponentStepsRollups = nil
        statsBattleStepsDisplay = nil
        statsArcadeStreakTimeline = nil
        statsPersonalRecords = nil
        statsAchievements = []
        isLoadingPersonalRecords = false
        statsRangeMargins = []
        isStatsRangeMarginsRefreshing = false
        statsRangeScopeNote = nil
        statsEffectiveRange = .oneDay
        statsPreviousPeriodPercent = nil
        statsBattleStatsScopeLabel = "lifetime"
        statsSnapshotSavedAt = nil
    }

    private func refreshStatsRangeMargins(source: String, forceNetworkRefresh: Bool = false) async {
        guard LegacyStatsFeature.isEnabled else { return }
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
            level: .debug,
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

    /// Refreshes Battle Steps card after HealthKit sync (today + all-time).
    func refreshBattleStepsAfterSync() async {
        guard let userId = profileId else { return }
        await refreshBattleStepsMetrics(userId: userId)
    }

    private func refreshBattleStepsMetrics(userId: UUID) async {
        async let snapshotTask = userBattleStepTotalsRepository.fetchCumulativeBattleSteps()

        let todayHK: Int
        do {
            todayHK = try await healthKitRead("stats_battle_steps_today", userId: userId) {
                try await HealthKitService.fetchTodayStepCount()
            }
        } catch {
            statsBattleStepsDisplay = nil
            return
        }

        stepsTodayValue = todayHK

        guard let snapshot = await snapshotTask else {
            statsBattleStepsDisplay = nil
            return
        }

        let todaySteps = snapshot.isTodayBattleDay ? todayHK : 0
        let allTime = snapshot.finalizedTotal
            + (snapshot.isTodayBattleDay && !snapshot.isTodayFinalized ? todayHK : 0)
        let avgSteps: Int? = snapshot.finalizedBattleDayCount > 0
            ? snapshot.averageFinalizedBattleDaySteps
            : nil

        statsBattleStepsDisplay = StatsBattleStepsDisplay(
            todaySteps: max(0, todaySteps),
            allTimeSteps: max(0, allTime),
            isTodayBattleDay: snapshot.isTodayBattleDay,
            finalizedBattleDayCount: snapshot.finalizedBattleDayCount,
            averageFinalizedBattleDaySteps: avgSteps
        )
    }

    private func refreshArcadeImpactMetrics(userId: UUID) async {
        let tz = profileTimeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let today = calendar.startOfDay(for: Date())

        guard
            let start90 = calendar.date(byAdding: .day, value: -89, to: today),
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today))
        else {
            statsBattleImpactMetric = nil
            statsMonthlyBattleBonusMetric = nil
            return
        }

        let start90Key = Self.calendarDateKey(for: start90, calendar: calendar, timeZone: tz)
        let todayKey = Self.calendarDateKey(for: today, calendar: calendar, timeZone: tz)
        let monthStartKey = Self.calendarDateKey(for: monthStart, calendar: calendar, timeZone: tz)

        let dailySteps: [String: Int]
        do {
            dailySteps = try await healthKitRead("stats_arcade_daily_steps_90d", userId: userId) {
                try await HealthKitService.fetchDailyStepsByCalendarDate(
                    startCalendarDateKey: start90Key,
                    endCalendarDateKey: todayKey,
                    profileTimeZoneIdentifier: profileTimeZoneIdentifier
                )
            }
        } catch {
            statsBattleImpactMetric = nil
            statsMonthlyBattleBonusMetric = nil
            return
        }

        let finalizedBattleKeys = await calendarRepository.fetchFinalizedStepsBattleDateKeys(
            currentUserId: userId,
            startDateKey: start90Key,
            endDateKey: todayKey
        )

        let battleDays = dailySteps.filter { finalizedBattleKeys.contains($0.key) }
        let normalDays = dailySteps.filter { !finalizedBattleKeys.contains($0.key) }

        let battleCount = battleDays.count
        let normalCount = normalDays.count
        let battleAvg = battleCount > 0 ? Int((Double(battleDays.map(\.value).reduce(0, +)) / Double(battleCount)).rounded()) : 0
        let normalAvg = normalCount > 0 ? Int((Double(normalDays.map(\.value).reduce(0, +)) / Double(normalCount)).rounded()) : 0
        let delta = battleAvg - normalAvg
        let boostPercent = normalAvg > 0
            ? Int((Double(delta) / Double(normalAvg) * 100).rounded())
            : 0

        statsBattleImpactMetric = StatsBattleImpactMetric(
            lookbackDays: 90,
            normalDayAverageSteps: max(0, normalAvg),
            battleDayAverageSteps: max(0, battleAvg),
            deltaSteps: delta,
            boostPercent: boostPercent,
            normalDaySampleCount: normalCount,
            battleDaySampleCount: battleCount
        )

        let monthBattleTotals = dailySteps.filter { entry in
            entry.key >= monthStartKey && entry.key <= todayKey && finalizedBattleKeys.contains(entry.key)
        }
        let monthBattleTotalSteps = monthBattleTotals.map(\.value).reduce(0, +)
        let monthBattleDayCount = monthBattleTotals.count
        let monthExpectedFromBaseline = normalAvg * monthBattleDayCount
        let monthBonus = monthBattleTotalSteps - monthExpectedFromBaseline
        let clampedBonus = max(0, monthBonus)

        statsMonthlyBattleBonusMetric = StatsMonthlyBattleBonusMetric(
            monthBattleDayCount: monthBattleDayCount,
            monthBattleDayTotalSteps: monthBattleTotalSteps,
            bonusSteps: clampedBonus,
            approxMiles: Int((Double(clampedBonus) / 2000.0).rounded())
        )
    }

    private func refreshArcadeStreakTimeline(userId: UUID) async {
        let tz = profileTimeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let today = calendar.startOfDay(for: Date())

        guard let start90 = calendar.date(byAdding: .day, value: -89, to: today) else {
            statsArcadeStreakTimeline = nil
            return
        }

        let start90Key = Self.calendarDateKey(for: start90, calendar: calendar, timeZone: tz)
        let todayKey = Self.calendarDateKey(for: today, calendar: calendar, timeZone: tz)

        guard let states = await calendarRepository.fetchStepsBattleStates(
            currentUserId: userId,
            startDateKey: start90Key,
            endDateKey: todayKey
        ) else {
            statsArcadeStreakTimeline = nil
            return
        }

        var candidates: [(dateKey: String, dot: StatsArcadeStreakDot)] = []
        for (dateKey, state) in states.sorted(by: { $0.key < $1.key }) {
            switch state {
            case .wonAny:
                candidates.append((dateKey, .win))
            case .lostAll:
                candidates.append((dateKey, .loss))
            case .inProgress where dateKey == todayKey:
                candidates.append((dateKey, .today))
            case .none, .voidOnly, .inProgress:
                continue
            }
        }

        statsArcadeStreakTimeline = Array(candidates.suffix(6).map(\.dot))
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
        guard LegacyStatsFeature.isEnabled else { return }
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
        guard LegacyStatsFeature.isEnabled else { return }
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
        weekSteps: [Int],
        weekCalories: [Int]
    ) -> [String: String] {
        let snapshot = [
            "source=\(source)",
            "today_steps=\(stepsToday)",
            "today_active_kcal=\(calsToday)",
            "week_steps_oldest_to_today=\(weekSteps.map(String.init).joined(separator: ","))",
            "week_cal_oldest_to_today=\(weekCalories.map(String.init).joined(separator: ","))",
        ].joined(separator: "\n")
        return [
            "hk_snapshot": snapshot,
            "week_steps_csv": weekSteps.map(String.init).joined(separator: ","),
            "week_cal_csv": weekCalories.map(String.init).joined(separator: ","),
        ]
    }

    private static func calendarDateKey(for date: Date, calendar: Calendar, timeZone: TimeZone) -> String {
        var cal = calendar
        cal.timeZone = timeZone
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
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

    private func refreshPersonalRecordsAndAchievements(userId: UUID) async {
        isLoadingPersonalRecords = true
        defer { isLoadingPersonalRecords = false }

        let tz = profileTimeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let today = calendar.startOfDay(for: Date())
        let lookbackDays = StatsPersonalRecordsBuilder.recordsLookbackDays

        guard let startDate = calendar.date(byAdding: .day, value: -(lookbackDays - 1), to: today) else {
            statsPersonalRecords = StatsPersonalRecords.empty
            statsAchievements = StatsAchievementCatalog.allItems(battleStats: battleStats)
            return
        }

        let startKey = Self.calendarDateKey(for: startDate, calendar: calendar, timeZone: tz)
        let todayKey = Self.calendarDateKey(for: today, calendar: calendar, timeZone: tz)

        async let marginsTask = homeRepository.fetchDailyBattleMargins(
            endDate: Date(),
            dayCount: lookbackDays,
            metricType: HomeBattleHeroCard.HeroMetric.steps.metricType,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )
        async let battleKeysTask = calendarRepository.fetchFinalizedStepsBattleDateKeys(
            currentUserId: userId,
            startDateKey: startKey,
            endDateKey: todayKey
        )
        async let completedTask = activityRepository.loadCompletedMatches(currentUserId: userId)

        let margins = await marginsTask
        let battleKeys = await battleKeysTask
        let completed = await completedTask
        completedMatches = completed

        var dailySteps: [String: Int] = [:]
        do {
            dailySteps = try await healthKitRead("stats_records_daily_steps", userId: userId) {
                try await HealthKitService.fetchDailyStepsByCalendarDate(
                    startCalendarDateKey: startKey,
                    endCalendarDateKey: todayKey,
                    profileTimeZoneIdentifier: profileTimeZoneIdentifier
                )
            }
        } catch {
            dailySteps = [:]
        }

        statsPersonalRecords = StatsPersonalRecordsBuilder.build(
            margins: margins,
            dailySteps: dailySteps,
            battleDateKeys: battleKeys,
            completedMatches: completed,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )

        let longestStreak = StatsPersonalRecordsBuilder.longestMatchWinStreakCount(from: completed)
        let dominatorDays = StatsAchievementCatalog.dominatorDayCount(margins: margins)
        statsAchievements = StatsAchievementCatalog.allItems(
            battleStats: battleStats,
            longestMatchWinStreak: longestStreak,
            dominatorDayCount: dominatorDays
        )
    }

    /// Loads completed match rows for stats opponent cards if the list is still empty.
    func loadCompletedMatchesIfNeeded() async {
        guard let profileId else { return }
        if !completedMatches.isEmpty { return }
        if isLoadingCompletedMatches { return }
        isLoadingCompletedMatches = true
        defer { isLoadingCompletedMatches = false }
        completedMatchesListTask?.cancel()
        completedMatchesListTask = Task { [weak self] in
            guard let self else { return }
            let rows = await activityRepository.loadCompletedMatches(currentUserId: profileId)
            guard !Task.isCancelled else { return }
            guard self.profileId == profileId else { return }
            self.completedMatches = rows
        }
        await completedMatchesListTask?.value
    }

}
