//
//  WeekComparisonCard.swift
//  FitUp
//
//  This week vs last week (same elapsed window).
//

import SwiftUI

private struct WeeklyChartPoint: Identifiable, Equatable {
    let x: Double // 0...7 (day-space)
    let y: Double // raw metric value
    let isBoundary: Bool

    var id: String { "\(x)-\(y)-\(isBoundary)" }
}

private struct SyntheticDayProfile: Equatable {
    let timeFractions: [Double]
    let cumulativeFractions: [Double]

    static let standard = SyntheticDayProfile(
        timeFractions: [0.0, 0.22, 0.5, 0.78, 1.0],
        cumulativeFractions: [0.02, 0.27, 0.58, 0.88, 1.0]
    )
}

struct WeekComparisonCard: View {
    let comparison: HealthWeekComparison?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("THIS WEEK VS LAST WEEK")
                .font(FitUpFont.body(10, weight: .heavy))
                .tracking(2)
                .foregroundStyle(FitUpColors.Text.tertiary)
                .padding(.bottom, 10)

            if let comparison {
                Text(comparison.headline)
                    .font(FitUpFont.body(12))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .padding(.bottom, 12)

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(comparison.currentValueText)
                        .font(FitUpFont.display(26, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.primary)
                    Text(comparison.metricUnitLabel)
                        .font(FitUpFont.body(12, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }
                .padding(.bottom, 10)

                condensedComparisonChart(comparison: comparison)
                .padding(.bottom, 8)
            } else {
                Text("Week comparison unavailable.")
                    .font(FitUpFont.body(12))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }
        }
        .padding(18)
        .glassCard(.base)
    }

    @ViewBuilder
    private func condensedComparisonChart(comparison: HealthWeekComparison) -> some View {
        let currentPoints = syntheticWeeklyPoints(
            dailyTotals: comparison.currentWeekDaily,
            dayProgressClampForToday: true
        )
        let previousPoints = syntheticWeeklyPoints(
            dailyTotals: comparison.previousWeekDaily,
            dayProgressClampForToday: false
        )
        let maxY = max(
            currentPoints.map(\.y).max() ?? 1,
            previousPoints.map(\.y).max() ?? 1,
            1
        )
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geo in
                let frame = geo.frame(in: .local)
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white.opacity(0.04))

                    dayBoundaryGuides(frame: frame)

                    if previousPoints.allSatisfy({ $0.y == 0 }) && currentPoints.allSatisfy({ $0.y == 0 }) {
                        baselinePath(frame: frame)
                            .stroke(Color.white.opacity(0.14), style: StrokeStyle(lineWidth: 1))
                    } else {
                        linePath(points: previousPoints, in: frame, maxY: maxY)
                            .stroke(
                                Color.white.opacity(0.38),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [4, 4])
                            )
                        linePath(points: currentPoints, in: frame, maxY: maxY)
                            .stroke(
                                FitUpColors.Neon.cyan.opacity(0.95),
                                style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
                            )
                    }
                }
            }
            .frame(height: 86)

            HStack(spacing: 0) {
                ForEach(weekdayAxisLabels, id: \.self) { label in
                    Text(label)
                        .font(FitUpFont.mono(9, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            HStack {
                legendDot(color: FitUpColors.Neon.cyan, dashed: false)
                Text("This Week \(comparison.currentValueText)")
                    .font(FitUpFont.body(10))
                    .foregroundStyle(FitUpColors.Text.secondary)
                Spacer(minLength: 10)
                legendDot(color: Color.white.opacity(0.5), dashed: true)
                Text("Last Week \(comparison.previousValueText)")
                    .font(FitUpFont.body(10))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }
        }
    }

    private func syntheticWeeklyPoints(
        dailyTotals: [Int],
        dayProgressClampForToday: Bool
    ) -> [WeeklyChartPoint] {
        let profile = SyntheticDayProfile.standard
        let totals = dailyTotals.count == 7 ? dailyTotals : Array(dailyTotals.prefix(7)) + Array(repeating: 0, count: max(0, 7 - dailyTotals.count))
        var points: [WeeklyChartPoint] = []
        let todayDayIndex = currentWeekdayIndexMondayFirst()
        let todayProgress = currentDayProgress()

        for day in 0..<7 {
            let total = max(0, totals[day])
            let clamp = (dayProgressClampForToday && day == todayDayIndex) ? todayProgress : 1.0
            for i in 0..<profile.timeFractions.count {
                let t = profile.timeFractions[i]
                if t > clamp + 0.0001 { continue }
                let yFrac = interpolatedYFraction(at: t, profile: profile)
                points.append(
                    WeeklyChartPoint(
                        x: Double(day) + t,
                        y: yFrac * Double(total),
                        isBoundary: i == 0 || i == profile.timeFractions.count - 1
                    )
                )
            }
            if dayProgressClampForToday && day == todayDayIndex && clamp < 1 {
                let yFrac = interpolatedYFraction(at: clamp, profile: profile)
                points.append(
                    WeeklyChartPoint(
                        x: Double(day) + clamp,
                        y: yFrac * Double(total),
                        isBoundary: false
                    )
                )
            }
        }
        return points.sorted { $0.x < $1.x }
    }

    private func interpolatedYFraction(at t: Double, profile: SyntheticDayProfile) -> Double {
        let x = profile.timeFractions
        let y = profile.cumulativeFractions
        if t <= x.first ?? 0 { return y.first ?? 0 }
        if t >= x.last ?? 1 { return y.last ?? 1 }
        for i in 0..<(x.count - 1) {
            let x0 = x[i]
            let x1 = x[i + 1]
            if t >= x0 && t <= x1 {
                let ratio = (t - x0) / max(x1 - x0, 0.0001)
                return y[i] + ((y[i + 1] - y[i]) * ratio)
            }
        }
        return y.last ?? 1
    }

    private func linePath(points: [WeeklyChartPoint], in frame: CGRect, maxY: Double) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }
        let width = frame.width
        let height = frame.height

        func px(_ point: WeeklyChartPoint) -> CGFloat {
            CGFloat(point.x / 7.0) * width
        }
        func py(_ point: WeeklyChartPoint) -> CGFloat {
            let yNorm = max(0, min(1, point.y / max(maxY, 1)))
            return height - (CGFloat(yNorm) * (height - 6)) - 3
        }

        path.move(to: CGPoint(x: px(points[0]), y: py(points[0])))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: px(point), y: py(point)))
        }
        return path
    }

    private func baselinePath(frame: CGRect) -> Path {
        var path = Path()
        let y = frame.height - 6
        path.move(to: CGPoint(x: 0, y: y))
        path.addLine(to: CGPoint(x: frame.width, y: y))
        return path
    }

    private func dayBoundaryGuides(frame: CGRect) -> some View {
        ZStack {
            ForEach(0..<8, id: \.self) { i in
                let x = frame.width * CGFloat(Double(i) / 7.0)
                Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: frame.height))
                }
                .stroke(Color.white.opacity(0.06), style: StrokeStyle(lineWidth: 1))
            }
        }
    }

    private func legendDot(color: Color, dashed: Bool) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 7, height: 7)
            if dashed {
                Circle()
                    .strokeBorder(color.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .frame(width: 9, height: 9)
            }
        }
    }

    private func currentWeekdayIndexMondayFirst() -> Int {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        let weekday = calendar.component(.weekday, from: Date()) // Sun=1...Sat=7
        return (weekday + 5) % 7
    }

    private func currentDayProgress() -> Double {
        let now = Date()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 1 }
        let total = end.timeIntervalSince(start)
        guard total > 0 else { return 1 }
        return max(0, min(1, now.timeIntervalSince(start) / total))
    }

    private var weekdayAxisLabels: [String] {
        ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    }
}

#Preview {
    WeekComparisonCard(
        comparison: HealthWeekComparison(
            metricType: .steps,
            currentTotal: 24_800,
            previousTotal: 21_600,
            currentWeekDaily: [2300, 4100, 2900, 3600, 4200, 5100, 2600],
            previousWeekDaily: [1800, 3200, 3000, 3300, 3900, 3500, 2900]
        )
    )
    .padding()
    .background { BackgroundGradientView() }
}
