//
//  HomeHeroSparklineLoader.swift
//  FitUp
//
//  Slice 5 — Parallel HealthKit intraday + opponent tick fetch with a hard wait budget,
//  then normalize to `[0…1]` sparkline samples for `DayBattleSparklinePreview`.
//

import CoreGraphics
import Foundation

struct HomeHeroSparklineSample: Sendable, Equatable {
    let timestamp: Date
    let userSteps: Int
    let opponentSteps: Int
}

struct HomeHeroSparklineDomain: Sendable, Equatable {
    let samples: [HomeHeroSparklineSample]
    let dayStart: Date
    let dayEnd: Date
    let now: Date

    var nowFraction: CGFloat {
        let span = dayEnd.timeIntervalSince(dayStart)
        guard span > 0 else { return 0 }
        return CGFloat(min(1, max(0, now.timeIntervalSince(dayStart) / span)))
    }

    var userSeries: [CGFloat]? {
        guard !samples.isEmpty else { return nil }
        let maxVal = max(1, samples.map(\.userSteps).max() ?? 0, samples.map(\.opponentSteps).max() ?? 0)
        return samples.map { CGFloat(min(1, max(0, Double($0.userSteps) / Double(maxVal)))) }
    }

    var opponentSeries: [CGFloat] {
        guard !samples.isEmpty else { return [] }
        let maxVal = max(1, samples.map(\.userSteps).max() ?? 0, samples.map(\.opponentSteps).max() ?? 0)
        return samples.map { CGFloat(min(1, max(0, Double($0.opponentSteps) / Double(maxVal)))) }
    }

    func steps(at time: Date) -> (user: Int, opponent: Int) {
        guard !samples.isEmpty else { return (0, 0) }
        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        if time <= sorted[0].timestamp {
            return (sorted[0].userSteps, sorted[0].opponentSteps)
        }
        if time >= sorted[sorted.count - 1].timestamp {
            let last = sorted[sorted.count - 1]
            return (last.userSteps, last.opponentSteps)
        }
        var userSteps = sorted[0].userSteps
        var oppSteps = sorted[0].opponentSteps
        for sample in sorted where sample.timestamp <= time {
            userSteps = sample.userSteps
            oppSteps = sample.opponentSteps
        }
        return (userSteps, oppSteps)
    }
}

/// Normalized sparkline samples plus opponent tick freshness for Slice 6 UI.
struct HomeHeroSparklineLoadResult: Sendable {
    let domain: HomeHeroSparklineDomain
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

        let built = buildSeries(
            hkPoints: hkPoints,
            oppTicks: oppTicks,
            myToday: match.myToday,
            theirToday: match.theirToday,
            viewerTimeZone: viewerTZ,
            pointCount: Self.normalizedSparklinePointCount
        )
        let latestOpp = oppTicks.flatMap { ticks in ticks.map(\.recordedAt).max() }
        return HomeHeroSparklineLoadResult(
            domain: built.domain,
            userSeries: built.user,
            opponentSeries: built.opponent,
            opponentLatestTickRecordedAt: latestOpp
        )
    }

    // MARK: - Build series

    private static func buildSeries(
        hkPoints: [HealthIntradayCumulativePoint]?,
        oppTicks: [OpponentIntradayStepTick]?,
        myToday: Int,
        theirToday: Int,
        viewerTimeZone: TimeZone,
        pointCount: Int
    ) -> (domain: HomeHeroSparklineDomain, user: [CGFloat]?, opponent: [CGFloat]) {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = viewerTimeZone
        let now = Date()
        let dayStart = cal.startOfDay(for: now)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart) ?? now.addingTimeInterval(86_400)
        let spanSeconds = max(now.timeIntervalSince(dayStart), 1)

        var timestamps = Set<Date>()
        timestamps.insert(dayStart)
        timestamps.insert(now)
        if let hkPoints {
            for point in hkPoints where point.date <= now {
                timestamps.insert(point.date)
            }
        }
        if let oppTicks {
            for tick in oppTicks where tick.recordedAt <= now {
                timestamps.insert(tick.recordedAt)
            }
        }

        let sortedTimes = timestamps.sorted()
        var samples: [HomeHeroSparklineSample] = []
        samples.reserveCapacity(sortedTimes.count)

        for t in sortedTimes {
            let fraction = spanSeconds > 0 ? t.timeIntervalSince(dayStart) / spanSeconds : 1.0
            let userSteps = interpolateCumulative(
                points: hkPoints,
                at: t,
                endAnchor: myToday,
                fraction: fraction
            )
            let oppSteps: Int
            if let ticks = oppTicks, !ticks.isEmpty {
                oppSteps = IntradayOpponentSeriesBuilder.cumulativeSteps(at: t, ticks: ticks)
            } else {
                oppSteps = IntradayOpponentSeriesBuilder.rampSteps(fraction: fraction, endAnchor: theirToday)
            }
            samples.append(HomeHeroSparklineSample(timestamp: t, userSteps: userSteps, opponentSteps: oppSteps))
        }

        if let lastIndex = samples.lastIndex(where: { $0.timestamp == now }) {
            samples[lastIndex] = HomeHeroSparklineSample(
                timestamp: now,
                userSteps: max(0, myToday),
                opponentSteps: max(0, theirToday)
            )
        } else {
            samples.append(
                HomeHeroSparklineSample(
                    timestamp: now,
                    userSteps: max(0, myToday),
                    opponentSteps: max(0, theirToday)
                )
            )
            samples.sort { $0.timestamp < $1.timestamp }
        }

        let domain = HomeHeroSparklineDomain(
            samples: samples,
            dayStart: dayStart,
            dayEnd: dayEnd,
            now: now
        )

        let n = max(2, pointCount)
        var userRaw = [Int](repeating: 0, count: n)
        var oppRaw = [Int](repeating: 0, count: n)
        for i in 0 ..< n {
            let fraction = n == 1 ? 1.0 : Double(i) / Double(n - 1)
            let t = dayStart.addingTimeInterval(fraction * spanSeconds)
            let steps = domain.steps(at: t)
            userRaw[i] = steps.user
            oppRaw[i] = steps.opponent
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
            domain: domain,
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
            return IntradayOpponentSeriesBuilder.rampSteps(fraction: fraction, endAnchor: endAnchor)
        }
        let sorted = points.sorted { $0.date < $1.date }
        if date <= sorted.first!.date { return max(0, sorted.first!.cumulative) }
        var last = sorted[0]
        for p in sorted where p.date <= date {
            last = p
        }
        return last.cumulative
    }
}
