//
//  StatsUserIntradayTimelineChart.swift
//  FitUp
//
//  User-only cumulative intraday steps timeline for the Stats hero card.
//

import SwiftUI

struct StatsUserIntradayTimelineChart: View {
    let domain: StatsUserIntradayDomain
    var stepsGoal: Int = 0
    var liveStepsToday: Int = 0

    private let chartHeight: CGFloat = 104
    private let chartPad = CGPoint(x: 12, y: 8)
    private let baseAccent = FitUpColors.Neon.cyan
    private let successAccent = FitUpColors.Neon.green

    private var nowFraction: CGFloat { domain.nowFraction }

    private var effectiveLiveSteps: Int {
        max(liveStepsToday, domain.liveStepCount, 0)
    }

    /// Highest cumulative steps in the visible series (live count wins over stale samples).
    private var peakStepsInSeries: Int {
        let seriesPeak = domain.points
            .filter { $0.date <= domain.now }
            .map(\.cumulative)
            .max() ?? 0
        return max(effectiveLiveSteps, seriesPeak)
    }

    /// Goal-anchored Y scale; expands in 25% goal increments once progress exceeds the goal.
    private var yScaleMaximum: Int {
        let peak = peakStepsInSeries
        guard stepsGoal > 0 else {
            return max(peak, 1)
        }
        if peak <= stepsGoal {
            return stepsGoal
        }
        var yMax = stepsGoal
        let increment = max(Int((Double(stepsGoal) * 0.25).rounded()), 1)
        while peak > yMax {
            yMax += increment
        }
        return yMax
    }

    private var goalProgress: Double {
        guard stepsGoal > 0 else { return 0 }
        return min(1, Double(effectiveLiveSteps) / Double(stepsGoal))
    }

    private var goalExceeded: Bool {
        stepsGoal > 0 && effectiveLiveSteps >= stepsGoal
    }

    private var accent: Color {
        goalExceeded ? successAccent : baseAccent
    }

    private var sparklineCoreWidth: CGFloat {
        2.75 + CGFloat(goalProgress) * 1.65 + (goalExceeded ? 0.45 : 0)
    }

    private var sparklineGlowWidth: CGFloat {
        7.5 + CGFloat(goalProgress) * 2.8 + (goalExceeded ? 1.0 : 0)
    }

    var body: some View {
        VStack(spacing: 4) {
            if domain.hasRenderableSeries {
                chartContent
            } else {
                emptyState
            }
            axisRow
        }
        .animation(.linear(duration: 0.65), value: effectiveLiveSteps)
        .animation(.easeOut(duration: 0.45), value: yScaleMaximum)
    }

    private var chartContent: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let plotRect = CGRect(origin: .zero, size: CGSize(width: w, height: h))
            let pad = chartPad
            let innerW = max(plotRect.width - pad.x * 2, 1)
            let yMax = yScaleMaximum
            let pts = sampledPoints(plotRect: plotRect, pad: pad, yMax: yMax)
            let nowX = plotRect.minX + pad.x + nowFraction * innerW
            let plotTop = plotRect.minY + pad.y
            let plotBottom = plotRect.maxY - pad.y
            let innerRight = plotRect.maxX - pad.x
            let currentY = pts.last?.y

            ZStack(alignment: .topLeading) {
                horizontalValueGrid(rect: plotRect, pad: pad, yMax: yMax)
                noonGuideLine(plotRect: plotRect, pad: pad, innerW: innerW)
                timeAxisTicks(rect: plotRect, pad: pad, innerW: innerW)

                if stepsGoal > 0 {
                    goalReferenceLine(plotRect: plotRect, pad: pad, yMax: yMax)
                }

                areaFill(points: pts, plotRect: plotRect, pad: pad)

                if let currentY {
                    currentLevelGuide(
                        plotRect: plotRect,
                        pad: pad,
                        y: currentY,
                        endX: pts.last?.x ?? innerRight
                    )
                }

                if nowFraction > 0.005 {
                    Path { path in
                        path.move(to: CGPoint(x: nowX, y: plotTop))
                        path.addLine(to: CGPoint(x: nowX, y: plotBottom))
                    }
                    .stroke(
                        accent.opacity(0.28 + goalProgress * 0.12),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 4])
                    )
                }

                sparkline(points: pts, color: accent)

                if let last = pts.last {
                    glowingDot(at: last)
                }

                if nowFraction > 0.005 {
                    chartAxisLabel("NOW")
                        .fixedSize()
                        .position(x: innerRight - 22, y: plotTop + 8)
                }

                if stepsGoal > 0 {
                    let goalY = yPosition(for: stepsGoal, plotRect: plotRect, pad: pad, yMax: yMax)
                    Text(stepsGoal.formatted())
                        .font(FitUpFont.display(13, weight: .heavy))
                        .foregroundStyle(
                            goalExceeded
                                ? successAccent
                                : BattleStatsTheme.gold
                        )
                        .shadow(color: BattleStatsTheme.gold.opacity(0.35), radius: 3, x: 0, y: 1)
                        .fixedSize()
                        .position(x: innerRight - 22, y: goalY - 10)
                }
            }
        }
        .frame(height: chartHeight)
    }

    private var emptyState: some View {
        HStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(BattleStatsTheme.textPrimary.opacity(0.85))
            Text("No step activity recorded yet today.")
                .font(FitUpFont.body(BattleStatsTheme.Typography.bodySmall, weight: .semibold))
                .foregroundStyle(BattleStatsTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, minHeight: chartHeight, alignment: .center)
    }

    private var axisRow: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 1)
            let padX = chartPad.x
            let innerW = max(w - padX * 2, 1)
            ZStack(alignment: .topLeading) {
                HStack {
                    chartAxisLabel("12 AM")
                    Spacer(minLength: 8)
                    chartAxisLabel("MIDNIGHT")
                }
                noonAxisLabels
                    .frame(maxWidth: .infinity)

                if nowFraction > 0.005 {
                    playerAxisMarker
                        .position(x: padX + nowFraction * innerW, y: 10)
                }
            }
        }
        .frame(height: 20)
        .allowsHitTesting(false)
    }

    private var playerAxisMarker: some View {
        VStack(spacing: 1) {
            Rectangle()
                .fill(accent.opacity(0.92))
                .frame(width: 2, height: 7)
            Circle()
                .fill(accent.opacity(0.95))
                .frame(width: 5, height: 5)
        }
    }

    private var noonAxisLabels: some View {
        chartAxisLabel("NOON")
    }

    private func chartAxisLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: BattleStatsTheme.Typography.caption, weight: .heavy, design: .rounded))
            .foregroundStyle(BattleStatsTheme.textPrimary.opacity(0.92))
            .lineLimit(1)
            .allowsTightening(true)
            .minimumScaleFactor(0.85)
            .tracking(2.0)
    }

    private func sampledPoints(plotRect: CGRect, pad: CGPoint, yMax: Int) -> [CGPoint] {
        var samples = domain.points.filter { $0.date <= domain.now }
        guard samples.count >= 2 else { return [] }

        if effectiveLiveSteps > 0, let last = samples.last {
            samples[samples.count - 1] = HealthIntradayCumulativePoint(
                date: last.date,
                cumulative: effectiveLiveSteps
            )
        }

        let maxVal = max(1, yMax)
        let minX = plotRect.minX + pad.x
        let maxX = plotRect.maxX - pad.x
        let minY = plotRect.minY + pad.y
        let maxY = plotRect.maxY - pad.y

        return samples.map { sample in
            let fraction = domain.timeFraction(sample.date)
            let x = minX + fraction * (maxX - minX)
            let normalized = CGFloat(min(1, max(0, Double(sample.cumulative) / Double(maxVal))))
            let y = maxY - normalized * (maxY - minY)
            return CGPoint(x: x, y: y)
        }
    }

    private func yPosition(for cumulative: Int, plotRect: CGRect, pad: CGPoint, yMax: Int) -> CGFloat {
        let maxVal = max(1, yMax)
        let minY = plotRect.minY + pad.y
        let maxY = plotRect.maxY - pad.y
        let normalized = CGFloat(min(1, max(0, Double(cumulative) / Double(maxVal))))
        return maxY - normalized * (maxY - minY)
    }

    @ViewBuilder
    private func areaFill(points: [CGPoint], plotRect: CGRect, pad: CGPoint) -> some View {
        if points.count >= 2 {
            let baselineY = plotRect.maxY - pad.y
            filledAreaPath(points: points, baselineY: baselineY)
                .fill(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.32 + goalProgress * 0.12),
                            accent.opacity(0.14),
                            goalExceeded
                                ? successAccent.opacity(0.22)
                                : BattleStatsTheme.gold.opacity(0.18),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    private func filledAreaPath(points: [CGPoint], baselineY: CGFloat) -> Path {
        var path = smoothPath(for: points)
        guard let last = points.last, let first = points.first else { return path }
        path.addLine(to: CGPoint(x: last.x, y: baselineY))
        path.addLine(to: CGPoint(x: first.x, y: baselineY))
        path.closeSubpath()
        return path
    }

    private func sparkline(points: [CGPoint], color: Color) -> some View {
        let path = smoothPath(for: points)
        let glowOpacity = 0.62 + goalProgress * 0.18
        let coreOpacity = 0.88 + goalProgress * 0.08
        return path
            .stroke(color.opacity(glowOpacity), style: StrokeStyle(lineWidth: sparklineGlowWidth, lineCap: .round, lineJoin: .round))
            .blur(radius: 5.5)
            .overlay(
                path.stroke(color.opacity(coreOpacity), style: StrokeStyle(lineWidth: sparklineCoreWidth, lineCap: .round, lineJoin: .round))
            )
    }

    private func glowingDot(at point: CGPoint) -> some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.55 + goalProgress * 0.2))
                .frame(width: 18, height: 18)
                .blur(radius: 4)
                .position(point)

            Circle()
                .fill(accent.opacity(0.92))
                .frame(width: 9, height: 9)
                .overlay {
                    Circle()
                        .stroke(Color.white.opacity(0.85), lineWidth: 1.5)
                }
                .shadow(color: accent.opacity(0.65 + goalProgress * 0.2), radius: 8)
                .position(point)
        }
    }

    private func goalReferenceLine(plotRect: CGRect, pad: CGPoint, yMax: Int) -> some View {
        let goalY = yPosition(for: stepsGoal, plotRect: plotRect, pad: pad, yMax: yMax)
        let innerLeft = plotRect.minX + pad.x
        let innerRight = plotRect.maxX - pad.x
        let lineColor = goalExceeded ? successAccent.opacity(0.42) : Color.white.opacity(0.32)

        return Path { path in
            path.move(to: CGPoint(x: innerLeft, y: goalY))
            path.addLine(to: CGPoint(x: innerRight, y: goalY))
        }
        .stroke(
            lineColor,
            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [4, 6])
        )
        .allowsHitTesting(false)
    }

    private func currentLevelGuide(plotRect: CGRect, pad: CGPoint, y: CGFloat, endX: CGFloat) -> some View {
        let innerLeft = plotRect.minX + pad.x
        return Path { path in
            path.move(to: CGPoint(x: innerLeft, y: y))
            path.addLine(to: CGPoint(x: endX, y: y))
        }
        .stroke(
            accent.opacity(0.16 + goalProgress * 0.12),
            style: StrokeStyle(lineWidth: 1, lineCap: .round, dash: [2, 4])
        )
        .allowsHitTesting(false)
    }

    private func smoothPath(for points: [CGPoint]) -> Path {
        var path = Path()
        guard points.count >= 2 else { return path }
        path.move(to: points[0])
        for i in 1 ..< points.count {
            let p0 = points[i - 1]
            let p1 = points[i]
            let mx = CGPoint(x: (p0.x + p1.x) / 2, y: (p0.y + p1.y) / 2)
            path.addQuadCurve(to: mx, control: p0)
            path.addQuadCurve(to: p1, control: mx)
        }
        return path
    }

    private func horizontalValueGrid(rect: CGRect, pad: CGPoint, yMax: Int) -> some View {
        Canvas { context, _ in
            let inner = rect.insetBy(dx: pad.x, dy: pad.y)
            guard inner.width > 8, inner.height > 8 else { return }

            let divisions = 4
            for i in 1 ..< divisions {
                let t = CGFloat(i) / CGFloat(divisions)
                let y = inner.minY + t * inner.height
                var line = Path()
                line.move(to: CGPoint(x: inner.minX, y: y))
                line.addLine(to: CGPoint(x: inner.maxX, y: y))
                context.stroke(
                    line,
                    with: .color(Color.white.opacity(0.08)),
                    style: StrokeStyle(lineWidth: 0.8, lineCap: .round)
                )
            }

            if stepsGoal > 0 {
                let goalY = yPosition(for: stepsGoal, plotRect: rect, pad: pad, yMax: yMax)
                var goalBand = Path()
                goalBand.addRect(CGRect(x: inner.minX, y: goalY - 10, width: inner.width, height: 20))
                context.fill(goalBand, with: .color(accent.opacity(0.035)))
            }
        }
        .allowsHitTesting(false)
    }

    private func noonGuideLine(plotRect: CGRect, pad: CGPoint, innerW: CGFloat) -> some View {
        let noonX = plotRect.minX + pad.x + 0.5 * innerW
        let plotBottom = plotRect.maxY - pad.y
        return Path { path in
            path.move(to: CGPoint(x: noonX, y: plotRect.minY + pad.y))
            path.addLine(to: CGPoint(x: noonX, y: plotBottom))
        }
        .stroke(Color.white.opacity(0.12), style: StrokeStyle(lineWidth: 0.8, dash: [3, 6]))
        .allowsHitTesting(false)
    }

    private func timeAxisTicks(rect: CGRect, pad: CGPoint, innerW: CGFloat) -> some View {
        Canvas { context, _ in
            let inner = rect.insetBy(dx: pad.x, dy: pad.y)
            guard inner.width > 8 else { return }
            let tickCount = 8
            for i in 0 ... tickCount {
                let t = CGFloat(i) / CGFloat(tickCount)
                let x = inner.minX + t * inner.width
                var tick = Path()
                tick.move(to: CGPoint(x: x, y: inner.maxY))
                tick.addLine(to: CGPoint(x: x, y: inner.maxY + 4))
                context.stroke(
                    tick,
                    with: .color(Color.white.opacity(0.22)),
                    style: StrokeStyle(lineWidth: 0.8, lineCap: .round)
                )
            }
        }
        .allowsHitTesting(false)
    }
}
