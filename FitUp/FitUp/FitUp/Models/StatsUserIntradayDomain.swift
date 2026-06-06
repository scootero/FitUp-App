//
//  StatsUserIntradayDomain.swift
//  FitUp
//
//  User-only intraday cumulative steps domain for the Stats hero timeline chart.
//

import CoreGraphics
import Foundation

struct StatsUserIntradayDomain: Equatable {
    let points: [HealthIntradayCumulativePoint]
    let dayStart: Date
    let dayEnd: Date
    let now: Date

    private var daySpan: TimeInterval {
        max(dayEnd.timeIntervalSince(dayStart), 1)
    }

    var nowFraction: CGFloat {
        CGFloat(min(1, max(0, now.timeIntervalSince(dayStart) / daySpan)))
    }

    var hasRenderableSeries: Bool {
        points.filter { $0.date <= now }.count >= 2
    }

    /// Latest cumulative steps through `now` (matches the chart series endpoint).
    var liveStepCount: Int {
        max(0, cumulative(at: now))
    }

    func timeFraction(_ date: Date) -> CGFloat {
        CGFloat(min(1, max(0, date.timeIntervalSince(dayStart) / daySpan)))
    }

    func cumulative(at time: Date) -> Int {
        let sorted = points.sorted { $0.date < $1.date }
        guard !sorted.isEmpty else { return 0 }
        if time <= sorted[0].date {
            return sorted[0].cumulative
        }
        if time >= sorted[sorted.count - 1].date {
            return sorted[sorted.count - 1].cumulative
        }
        var value = sorted[0].cumulative
        for point in sorted where point.date <= time {
            value = point.cumulative
        }
        return value
    }

    static func make(from points: [HealthIntradayCumulativePoint], timeZone: TimeZone) -> StatsUserIntradayDomain? {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let today = Date()
        let dayStart = calendar.startOfDay(for: today)
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            return nil
        }
        let sorted = points.sorted { $0.date < $1.date }
        guard !sorted.isEmpty else { return nil }
        return StatsUserIntradayDomain(
            points: sorted,
            dayStart: dayStart,
            dayEnd: dayEnd,
            now: today
        )
    }
}
