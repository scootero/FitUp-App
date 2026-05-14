//
//  HomeHeroSparklineLoader.swift
//  FitUp
//
//  Slice 5 — Parallel HealthKit intraday + opponent tick fetch with a hard wait budget,
//  then normalize to `[0…1]` sparkline samples for `DayBattleSparklinePreview`.
//

import CoreGraphics
import Foundation

/// Normalized sparkline samples plus opponent tick freshness for Slice 6 UI.
struct HomeHeroSparklineLoadResult: Sendable {
    let userSeries: [CGFloat]?
    /// Always real samples (flat at zero when no ticks / no steps); never mock-shaped.
    let opponentSeries: [CGFloat]
    /// Latest `recorded_at` among opponent ticks returned for the day, when any rows exist.
    let opponentLatestTickRecordedAt: Date?
}

enum HomeHeroSparklineLoader {
    /// Wall-clock budget for the parallel fetch phase (then tasks are cancelled if still running).
    private static let fetchBudgetNanoseconds: UInt64 = 4_500_000_000
    /// Sample count for normalized hero sparklines; keep in sync with `EnergyBeamHeroMockSeries` and `HomeEnergyBeamHeroCard` fallbacks.
    static let normalizedSparklinePointCount = 18

    /// Loads HK + opponent ticks in parallel, waits at most ``fetchBudgetNanoseconds``, then builds normalized series.
    /// Returns `nil` **user** series when there is no usable HK / step signal (caller may use mock user curve). Opponent series is always real (flat zeros when no ticks / zero day).
    static func loadSparklineSeries(
        profileTimeZoneIdentifier: String?,
        match: HomeActiveMatch
    ) async -> HomeHeroSparklineLoadResult {
        let viewerTZ = profileTimeZoneIdentifier.flatMap { TimeZone(identifier: $0) } ?? .current
        let oppTzId = profileTimeZoneIdentifier ?? TimeZone.current.identifier

        let hkTask = Task {
            try await HealthKitService.fetchIntradayCumulativeSeries(
                metricType: .steps,
                for: Date(),
                timeZone: viewerTZ,
                maxPoints: 48
            )
        }

        let repo = UserIntradayStepTicksRepository()
        let oppTask = Task {
            try await repo.fetchOpponentTicks(
                opponentProfileId: match.opponent.id,
                calendarDate: Date(),
                opponentTimezoneIdentifier: oppTzId,
                sinceRecordedAt: nil
            )
        }

        try? await Task.sleep(nanoseconds: fetchBudgetNanoseconds)
        hkTask.cancel()
        oppTask.cancel()

        let hkPoints = try? await hkTask.value
        let oppTicks: [OpponentIntradayStepTick]?
        if let ticks = try? await oppTask.value {
            oppTicks = ticks
        } else {
            oppTicks = nil
        }

        let built = buildNormalizedSeries(
            hkPoints: hkPoints,
            oppTicks: oppTicks,
            myToday: match.myToday,
            theirToday: match.theirToday,
            viewerTimeZone: viewerTZ,
            pointCount: Self.normalizedSparklinePointCount
        )
        let latestOpp = oppTicks.flatMap { ticks in ticks.map(\.recordedAt).max() }
        return HomeHeroSparklineLoadResult(
            userSeries: built.user,
            opponentSeries: built.opponent,
            opponentLatestTickRecordedAt: latestOpp
        )
    }

    // MARK: - Normalize

    private static func buildNormalizedSeries(
        hkPoints: [HealthIntradayCumulativePoint]?,
        oppTicks: [OpponentIntradayStepTick]?,
        myToday: Int,
        theirToday: Int,
        viewerTimeZone: TimeZone,
        pointCount: Int
    ) -> (user: [CGFloat]?, opponent: [CGFloat]) {
        let n = max(2, pointCount)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = viewerTimeZone
        let now = Date()
        let dayStart = cal.startOfDay(for: now)
        let spanSeconds = max(now.timeIntervalSince(dayStart), 1)

        var userRaw = [Int](repeating: 0, count: n)
        var oppRaw = [Int](repeating: 0, count: n)

        for i in 0 ..< n {
            let fraction = n == 1 ? 1.0 : Double(i) / Double(n - 1)
            let t = dayStart.addingTimeInterval(fraction * spanSeconds)
            userRaw[i] = interpolateCumulative(points: hkPoints, at: t, endAnchor: myToday, fraction: fraction)
            if let ticks = oppTicks, !ticks.isEmpty {
                oppRaw[i] = interpolateOpponentCumulative(ticks: ticks, at: t, endAnchor: theirToday, fraction: fraction)
            } else {
                // No intraday ticks: flat at today's known total (often 0). Never synthesize a ramp.
                oppRaw[i] = max(0, theirToday)
            }
        }

        userRaw[n - 1] = max(0, myToday)
        oppRaw[n - 1] = max(0, theirToday)

        let maxVal = max(
            1,
            myToday,
            theirToday,
            userRaw.max() ?? 0,
            oppRaw.max() ?? 0
        )

        let userCGFloats = userRaw.map { CGFloat(min(1, max(0, Double($0) / Double(maxVal)))) }
        let oppCGFloats = oppRaw.map { CGFloat(min(1, max(0, Double($0) / Double(maxVal)))) }

        let hasUserSignal = (hkPoints?.isEmpty == false) || myToday > 0

        return (
            user: hasUserSignal ? userCGFloats : nil,
            opponent: oppCGFloats
        )
    }

    private static func interpolateCumulative(
        points: [HealthIntradayCumulativePoint]?,
        at date: Date,
        endAnchor: Int,
        fraction: Double
    ) -> Int {
        guard let points, !points.isEmpty else {
            return Int((Double(max(0, endAnchor)) * fraction).rounded())
        }
        let sorted = points.sorted { $0.date < $1.date }
        if date <= sorted.first!.date { return max(0, sorted.first!.cumulative) }
        var last = sorted[0]
        for p in sorted where p.date <= date {
            last = p
        }
        return last.cumulative
    }

    private static func interpolateOpponentCumulative(
        ticks: [OpponentIntradayStepTick],
        at date: Date,
        endAnchor _: Int,
        fraction _: Double
    ) -> Int {
        let sorted = ticks.sorted { $0.recordedAt < $1.recordedAt }
        if date <= sorted.first!.recordedAt { return max(0, sorted.first!.cumulativeSteps) }
        var last = sorted[0]
        for t in sorted where t.recordedAt <= date {
            last = t
        }
        return last.cumulativeSteps
    }
}
