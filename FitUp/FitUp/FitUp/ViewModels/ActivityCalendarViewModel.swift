//
//  ActivityCalendarViewModel.swift
//  FitUp
//
//  Month grid data for Battles + Steps activity calendar.
//

import Combine
import Foundation

enum ActivityCalendarMode: String, CaseIterable, Identifiable {
    case battles
    case steps

    var id: String { rawValue }

    var pillLabel: String {
        switch self {
        case .battles: return "BATTLES"
        case .steps: return "STEPS"
        }
    }
}

@MainActor
final class ActivityCalendarViewModel: ObservableObject {
    @Published private(set) var displayedMonth: Date
    @Published var mode: ActivityCalendarMode = .battles
    @Published private(set) var gridItems: [CalendarDayItem] = []
    @Published private(set) var battleByDate: [String: CalendarDayBattleState] = [:]
    @Published private(set) var stepsByDate: [String: CalendarDayStepsState] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var showHealthAccessBanner = false
    @Published private(set) var selectedDayItem: CalendarDayItem?
    @Published private(set) var battleDayDetail: CalendarDayBattleDetail?
    @Published private(set) var stepsDayDetail: CalendarDayStepsDetail?
    @Published private(set) var isDayDetailLoading = false
    @Published private(set) var selectedBattleMatchIndex = 0

    var monthTitle: String {
        CalendarMonthLayout.monthTitle(
            for: displayedMonth,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )
    }

    var monthShortTitle: String {
        CalendarMonthLayout.monthShortTitle(
            for: displayedMonth,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )
    }

    private let userId: UUID
    private let profileTimeZoneIdentifier: String?
    private let calendarRepository: CalendarRepository
    private let stepsGoal: Int

    private var battleCache: [String: [String: CalendarDayBattleState]] = [:]
    private var stepsCache: [String: [String: CalendarDayStepsState]] = [:]
    private var loadTask: Task<Void, Never>?

    init(
        userId: UUID,
        profileTimeZoneIdentifier: String?,
        initialMonth: Date = Date(),
        calendarRepository: CalendarRepository = CalendarRepository()
    ) {
        self.userId = userId
        self.profileTimeZoneIdentifier = profileTimeZoneIdentifier
        self.displayedMonth = CalendarMonthLayout.startOfMonth(
            for: initialMonth,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )
        self.calendarRepository = calendarRepository
        self.stepsGoal = ReadinessGoals.loadFromUserDefaults().stepsGoal
        refreshGridItems()
    }

    func start() {
        loadMonthData(forceRefresh: false)
    }

    func reload() {
        battleCache.removeAll()
        stepsCache.removeAll()
        loadMonthData(forceRefresh: true)
    }

    func goToPreviousMonth() {
        displayedMonth = CalendarMonthLayout.addMonths(
            -1,
            to: displayedMonth,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )
        refreshGridItems()
        loadMonthData(forceRefresh: false)
    }

    func goToNextMonth() {
        displayedMonth = CalendarMonthLayout.addMonths(
            1,
            to: displayedMonth,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )
        refreshGridItems()
        loadMonthData(forceRefresh: false)
    }

    func goToToday() {
        displayedMonth = CalendarMonthLayout.startOfMonth(
            for: Date(),
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )
        refreshGridItems()
        loadMonthData(forceRefresh: false)
    }

    func battleState(for dateKey: String) -> CalendarDayBattleState {
        battleByDate[dateKey] ?? .none
    }

    func stepsState(for dateKey: String) -> CalendarDayStepsState? {
        stepsByDate[dateKey]
    }

    var selectedBattleMatch: CalendarDayBattleMatchDetail? {
        guard let detail = battleDayDetail, !detail.matches.isEmpty else { return nil }
        let index = min(max(0, selectedBattleMatchIndex), detail.matches.count - 1)
        return detail.matches[index]
    }

    func selectDay(_ item: CalendarDayItem) {
        guard item.isWithinDisplayedMonth else { return }
        if selectedDayItem?.id == item.id {
            dismissDayDetail()
            return
        }
        selectedDayItem = item
        selectedBattleMatchIndex = 0
        loadDayDetail(for: item)
    }

    func dismissDayDetail() {
        dayDetailTask?.cancel()
        dayDetailTask = nil
        selectedDayItem = nil
        battleDayDetail = nil
        stepsDayDetail = nil
        isDayDetailLoading = false
        selectedBattleMatchIndex = 0
    }

    func selectBattleMatchIndex(_ index: Int) {
        guard let count = battleDayDetail?.matches.count, count > 0 else { return }
        selectedBattleMatchIndex = min(max(0, index), count - 1)
    }

    private var dayDetailTask: Task<Void, Never>?

    private func refreshGridItems() {
        gridItems = CalendarMonthLayout.gridItems(
            for: displayedMonth,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )
    }

    private func loadMonthData(forceRefresh: Bool) {
        loadTask?.cancel()
        let cacheKey = monthCacheKey(for: displayedMonth)
        let range = CalendarMonthLayout.gridDateKeyRange(
            for: displayedMonth,
            profileTimeZoneIdentifier: profileTimeZoneIdentifier
        )

        if !forceRefresh,
           let cachedBattles = battleCache[cacheKey],
           let cachedSteps = stepsCache[cacheKey] {
            battleByDate = cachedBattles
            stepsByDate = cachedSteps
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        loadTask = Task {
            async let battles = calendarRepository.fetchBattleStates(
                currentUserId: userId,
                startDateKey: range.start,
                endDateKey: range.end
            )
            async let steps = loadSteps(rangeStart: range.start, rangeEnd: range.end)

            let battleResult = await battles
            let stepsResult = await steps

            guard !Task.isCancelled else { return }

            battleByDate = battleResult
            stepsByDate = stepsResult.states
            showHealthAccessBanner = stepsResult.accessDenied
            battleCache[cacheKey] = battleResult
            stepsCache[cacheKey] = stepsResult.states
            isLoading = false

            if let err = stepsResult.errorMessage, mode == .steps {
                errorMessage = err
            }
        }
    }

    private struct StepsLoadResult {
        let states: [String: CalendarDayStepsState]
        let accessDenied: Bool
        let errorMessage: String?
    }

    private func loadSteps(rangeStart: String, rangeEnd: String) async -> StepsLoadResult {
        do {
            let raw = try await HealthKitService.fetchDailyStepsByCalendarDate(
                startCalendarDateKey: rangeStart,
                endCalendarDateKey: rangeEnd,
                profileTimeZoneIdentifier: profileTimeZoneIdentifier
            )
            var states: [String: CalendarDayStepsState] = [:]
            for (key, steps) in raw {
                states[key] = CalendarDayStepsState(steps: steps, stepsGoal: stepsGoal)
            }
            return StepsLoadResult(states: states, accessDenied: false, errorMessage: nil)
        } catch {
            if let hk = error as? HealthKitError, case .authorizationDenied = hk {
                return StepsLoadResult(states: [:], accessDenied: true, errorMessage: nil)
            }
            return StepsLoadResult(
                states: [:],
                accessDenied: false,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func loadDayDetail(for item: CalendarDayItem) {
        dayDetailTask?.cancel()
        isDayDetailLoading = true
        battleDayDetail = nil
        stepsDayDetail = nil

        dayDetailTask = Task {
            async let battle = calendarRepository.fetchDayBattleDetail(
                currentUserId: userId,
                dateKey: item.id
            )
            async let steps = buildStepsDetail(dateKey: item.id, item: item)

            let battleResult = await battle
            let stepsResult = await steps

            guard !Task.isCancelled else { return }

            battleDayDetail = battleResult
            stepsDayDetail = stepsResult
            isDayDetailLoading = false
        }
    }

    private func buildStepsDetail(dateKey: String, item: CalendarDayItem) async -> CalendarDayStepsDetail? {
        let steps = stepsByDate[dateKey]?.steps ?? 0
        let tz = profileTimeZoneIdentifier.flatMap { TimeZone(identifier: $0) } ?? .current

        var points: [HealthIntradayCumulativePoint] = []
        do {
            points = try await HealthKitService.fetchIntradayCumulativeSeries(
                metricType: .steps,
                for: item.date,
                timeZone: tz,
                maxPoints: 32
            )
        } catch {
            points = []
        }

        if points.count <= 1 {
            points = syntheticIntradayPoints(for: item.date, totalSteps: steps, timeZone: tz)
        }

        let maxVal = max(points.map(\.cumulative).max() ?? steps, 1)
        let sparklineValues = points.map { CGFloat($0.cumulative) / CGFloat(maxVal) }
        let timestamps = points.map(\.date)

        return CalendarDayStepsDetail(
            dateKey: dateKey,
            displayTitle: formattedDayChipTitle(dayNumber: item.dayNumber, dateKey: dateKey),
            steps: steps,
            stepsGoal: stepsGoal,
            sparklineValues: sparklineValues,
            pointTimestamps: timestamps
        )
    }

    private func syntheticIntradayPoints(
        for date: Date,
        totalSteps: Int,
        timeZone: TimeZone
    ) -> [HealthIntradayCumulativePoint] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let dayStart = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .hour, value: 23, to: dayStart) ?? dayStart
        return [
            HealthIntradayCumulativePoint(date: dayStart, cumulative: 0),
            HealthIntradayCumulativePoint(date: end, cumulative: totalSteps),
        ]
    }

    private func formattedDayChipTitle(dayNumber: Int, dateKey: String) -> String {
        let parts = dateKey.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]) else { return "DAY \(dayNumber)" }
        let monthSymbols = ["", "JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]
        let monthLabel = (1...12).contains(month) ? monthSymbols[month] : "???"
        return "\(monthLabel) \(dayNumber)"
    }

    private func monthCacheKey(for month: Date) -> String {
        let tz = profileTimeZoneIdentifier.flatMap { TimeZone(identifier: $0) } ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz
        let year = calendar.component(.year, from: month)
        let monthNum = calendar.component(.month, from: month)
        return String(format: "%04d-%02d", year, monthNum)
    }
}
