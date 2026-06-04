//
//  IntradayOpponentSeriesBuilder.swift
//  FitUp
//
//  Shared step-function logic for opponent intraday cumulative series (Home hero + Match Details).
//

import Foundation

enum IntradayOpponentSeriesBuilder: Sendable {
    /// Step-function cumulative opponent steps at `date`. Returns 0 before the first tick.
    nonisolated static func cumulativeSteps(at date: Date, ticks: [OpponentIntradayStepTick]) -> Int {
        let sorted = ticks.sorted { $0.recordedAt < $1.recordedAt }
        guard let first = sorted.first else { return 0 }
        if date < first.recordedAt { return 0 }
        var last = first
        for tick in sorted where tick.recordedAt <= date {
            last = tick
        }
        return last.cumulativeSteps
    }

    /// Linear ramp 0 → endAnchor when no ticks exist (mirrors viewer HealthKit fallback).
    nonisolated static func rampSteps(fraction: Double, endAnchor: Int) -> Int {
        Int((Double(max(0, endAnchor)) * fraction).rounded())
    }

    /// Builds chart-ready opponent series with a midnight-zero anchor and end anchor at `now`.
    nonisolated static func buildChartSeries(
        ticks: [OpponentIntradayStepTick],
        dayStart: Date,
        now: Date,
        endAnchor: Int
    ) -> [HealthIntradayCumulativePoint] {
        let sortedTicks = ticks
            .filter { $0.recordedAt <= now }
            .sorted { $0.recordedAt < $1.recordedAt }

        var points: [HealthIntradayCumulativePoint] = [
            HealthIntradayCumulativePoint(date: dayStart, cumulative: 0),
        ]

        for tick in sortedTicks {
            let point = HealthIntradayCumulativePoint(date: tick.recordedAt, cumulative: tick.cumulativeSteps)
            if points.last?.date == point.date {
                points[points.count - 1] = point
            } else {
                points.append(point)
            }
        }

        let endSteps = max(0, endAnchor)
        if let last = points.last {
            if last.date < now || last.cumulative != endSteps {
                if last.date == now {
                    points[points.count - 1] = HealthIntradayCumulativePoint(date: now, cumulative: endSteps)
                } else {
                    points.append(HealthIntradayCumulativePoint(date: now, cumulative: endSteps))
                }
            }
        }

        return points.sorted { $0.date < $1.date }
    }
}
