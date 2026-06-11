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
    var displayedStepsValue: Double = 0
    var displayedNowFraction: CGFloat = 0
    var tailOriginSteps: Double = 0
    var tailOriginFraction: CGFloat = 0

    private let chartHeight: CGFloat = 104
    private let chartPad = CGPoint(x: 12, y: 8)
    private let baseAccent = FitUpColors.Neon.cyan
    private let successAccent = FitUpColors.Neon.green
    private let stepsValueTint = BattleStatsTheme.blue

    private var liveNowFraction: CGFloat { domain.nowFraction }

    private var endpointNowFraction: CGFloat {
        let clamped = min(1, max(0, displayedNowFraction))
        if clamped > 0.0005 { return clamped }
        return liveNowFraction
    }

    private var effectiveLiveSteps: Int {
        max(liveStepsToday, domain.liveStepCount, 0)
    }

    private var chartEndpointSteps: Int {
        max(0, Int(displayedStepsValue.rounded()))
    }

    private var hasStraightTail: Bool {
        abs(displayedStepsValue - tailOriginSteps) > 0.5
            || abs(displayedNowFraction - tailOriginFraction) > 0.0005
    }

    /// Highest cumulative steps in the visible series (animated endpoint wins over stale samples).
    private var peakStepsInSeries: Int {
        let seriesPeak = domain.points
            .filter { $0.date <= domain.now }
            .map(\.cumulative)
            .max() ?? 0
        return max(chartEndpointSteps, effectiveLiveSteps, seriesPeak, Int(tailOriginSteps.rounded()))
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
        return min(1, Double(chartEndpointSteps) / Double(stepsGoal))
    }

    private var goalExceeded: Bool {
        stepsGoal > 0 && chartEndpointSteps >= stepsGoal
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
        .animation(.easeOut(duration: 0.45), value: yScaleMaximum)
    }

    private var chartContent: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let plotRect = CGRect(origin: .zero, size: CGSize(width: w, height: h))
            let pad = chartPad
            let innerW = max(plotRect.width - pad.x * 2, 1)
            let innerLeft = plotRect.minX + pad.x
            let yMax = yScaleMaximum
            let pts = sampledPoints(plotRect: plotRect, pad: pad, yMax: yMax)
            let endpointX = innerLeft + endpointNowFraction * innerW
            let plotTop = plotRect.minY + pad.y
            let plotBottom = plotRect.maxY - pad.y
            let innerRight = plotRect.maxX - pad.x
            let endpointY = pts.last?.y

            ZStack(alignment: .topLeading) {
                horizontalValueGrid(rect: plotRect, pad: pad, yMax: yMax)
                chartEdgeIndicators(
                    plotRect: plotRect,
                    pad: pad,
                    innerLeft: innerLeft,
                    innerRight: innerRight,
                    plotTop: plotTop,
                    plotBottom: plotBottom
                )
                noonGuideLine(plotRect: plotRect, pad: pad, innerW: innerW)
                timeAxisTicks(rect: plotRect, pad: pad, innerW: innerW)

                if stepsGoal > 0 {
                    goalReferenceLine(plotRect: plotRect, pad: pad, yMax: yMax)
                    goalPaceGuideLine(plotRect: plotRect, pad: pad, yMax: yMax)
                }

                areaFill(points: pts, plotRect: plotRect, pad: pad, straightTail: hasStraightTail)

                if let endpointY {
                    currentLevelGuide(
                        plotRect: plotRect,
                        pad: pad,
                        y: endpointY,
                        endX: pts.last?.x ?? innerRight
                    )
                }

                if endpointNowFraction > 0.005 {
                    Path { path in
                        path.move(to: CGPoint(x: endpointX, y: plotTop))
                        path.addLine(to: CGPoint(x: endpointX, y: plotBottom))
                    }
                    .stroke(
                        accent.opacity(0.28 + goalProgress * 0.12),
                        style: StrokeStyle(lineWidth: 1, dash: [3, 4])
                    )
                }

                sparkline(points: pts, color: accent, straightTail: hasStraightTail)

                if let last = pts.last {
                    glowingDot(at: last)
                }

                if endpointNowFraction > 0.005 {
                    StatsSmoothStepCount(
                        value: displayedStepsValue,
                        fontSize: 24,
                        tint: stepsValueTint.opacity(0.92)
                    )
                    .fixedSize()
                    .position(
                        x: endpointX,
                        y: max(plotTop + 14, (endpointY ?? plotTop) - 30)
                    )
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
            ZStack(alignment: .top) {
                HStack {
                    chartAxisLabel("12 AM")
                    Spacer(minLength: 4)
                    chartAxisLabel("DAY END")
                }
                .padding(.horizontal, 2)

                noonAxisLabels
                    .frame(maxWidth: .infinity)

                if endpointNowFraction > 0.005 {
                    playerAxisMarker
                        .position(x: padX + endpointNowFraction * innerW, y: 10)
                }
            }
        }
        .frame(height: 20)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("12 AM to day end. Noon at center.")
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

    private func chartEdgeIndicators(
        plotRect: CGRect,
        pad: CGPoint,
        innerLeft: CGFloat,
        innerRight: CGFloat,
        plotTop: CGFloat,
        plotBottom: CGFloat
    ) -> some View {
        let fadeHeight = (plotBottom - plotTop) * 0.55
        return Canvas { context, _ in
            for x in [innerLeft, innerRight] {
                var line = Path()
                line.move(to: CGPoint(x: x, y: plotBottom))
                line.addLine(to: CGPoint(x: x, y: plotBottom - fadeHeight))
                context.stroke(
                    line,
                    with: .linearGradient(
                        Gradient(colors: [
                            Color.white.opacity(0.20),
                            Color.white.opacity(0.04),
                        ]),
                        startPoint: CGPoint(x: x, y: plotBottom),
                        endPoint: CGPoint(x: x, y: plotBottom - fadeHeight)
                    ),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round)
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func sampledPoints(plotRect: CGRect, pad: CGPoint, yMax: Int) -> [CGPoint] {
        let samples = domain.points.filter { $0.date <= domain.now }
        guard samples.count >= 2 else { return [] }

        let maxVal = max(1, yMax)
        let minX = plotRect.minX + pad.x
        let maxX = plotRect.maxX - pad.x
        let minY = plotRect.minY + pad.y
        let maxY = plotRect.maxY - pad.y

        let originX = minX + tailOriginFraction * (maxX - minX)
        let originY = yPosition(for: Int(tailOriginSteps.rounded()), plotRect: plotRect, pad: pad, yMax: yMax)
        let endpointX = minX + endpointNowFraction * (maxX - minX)
        let endpointY = yPosition(for: chartEndpointSteps, plotRect: plotRect, pad: pad, yMax: yMax)

        var points = samples.compactMap { sample -> CGPoint? in
            let fraction = domain.timeFraction(sample.date)
            let x = minX + fraction * (maxX - minX)
            guard x < originX - 0.5 else { return nil }
            let normalized = CGFloat(min(1, max(0, Double(sample.cumulative) / Double(maxVal))))
            let y = maxY - normalized * (maxY - minY)
            return CGPoint(x: x, y: y)
        }

        if points.isEmpty {
            points.append(CGPoint(x: originX, y: originY))
        } else {
            points.append(CGPoint(x: originX, y: originY))
        }

        if hasStraightTail || hypot(originX - endpointX, originY - endpointY) > 0.5 {
            points.append(CGPoint(x: endpointX, y: endpointY))
        }

        return points
    }

    private func yPosition(for cumulative: Int, plotRect: CGRect, pad: CGPoint, yMax: Int) -> CGFloat {
        let maxVal = max(1, yMax)
        let minY = plotRect.minY + pad.y
        let maxY = plotRect.maxY - pad.y
        let normalized = CGFloat(min(1, max(0, Double(cumulative) / Double(maxVal))))
        return maxY - normalized * (maxY - minY)
    }

    @ViewBuilder
    private func areaFill(points: [CGPoint], plotRect: CGRect, pad: CGPoint, straightTail: Bool) -> some View {
        if points.count >= 2 {
            let baselineY = plotRect.maxY - pad.y
            filledAreaPath(points: points, baselineY: baselineY, straightTail: straightTail)
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

    private func filledAreaPath(points: [CGPoint], baselineY: CGFloat, straightTail: Bool) -> Path {
        var path = linePath(for: points, straightTail: straightTail)
        guard let last = points.last, let first = points.first else { return path }
        path.addLine(to: CGPoint(x: last.x, y: baselineY))
        path.addLine(to: CGPoint(x: first.x, y: baselineY))
        path.closeSubpath()
        return path
    }

    private func sparkline(points: [CGPoint], color: Color, straightTail: Bool) -> some View {
        let path = linePath(for: points, straightTail: straightTail)
        let glowOpacity = 0.62 + goalProgress * 0.18
        let coreOpacity = 0.88 + goalProgress * 0.08
        return path
            .stroke(color.opacity(glowOpacity), style: StrokeStyle(lineWidth: sparklineGlowWidth, lineCap: .round, lineJoin: .round))
            .blur(radius: 5.5)
            .overlay(
                path.stroke(color.opacity(coreOpacity), style: StrokeStyle(lineWidth: sparklineCoreWidth, lineCap: .round, lineJoin: .round))
            )
    }

    /// Smooth body with an optional straight-line tail from the cached chart origin to the live endpoint.
    private func linePath(for points: [CGPoint], straightTail: Bool) -> Path {
        guard points.count >= 2 else { return Path() }

        if !straightTail || points.count < 3 {
            return smoothPath(for: points)
        }

        let body = Array(points.dropLast())
        let tailEnd = points[points.count - 1]
        var path = smoothPath(for: body)
        path.addLine(to: tailEnd)
        return path
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

    /// Diagonal pace reference from 8 AM at baseline to day end at the step goal.
    private func goalPaceGuideLine(plotRect: CGRect, pad: CGPoint, yMax: Int) -> some View {
        let innerLeft = plotRect.minX + pad.x
        let innerRight = plotRect.maxX - pad.x
        let plotBottom = plotRect.maxY - pad.y
        let goalY = yPosition(for: stepsGoal, plotRect: plotRect, pad: pad, yMax: yMax)

        let eightAM = domain.dayStart.addingTimeInterval(8 * 3_600)
        let eightAMFraction = domain.timeFraction(eightAM)
        let startX = innerLeft + eightAMFraction * (innerRight - innerLeft)

        let linePath = Path { path in
            path.move(to: CGPoint(x: startX, y: plotBottom))
            path.addLine(to: CGPoint(x: innerRight, y: goalY))
        }

        return StatsNeonDashedGuideLine(
            path: linePath,
            gradientStart: UnitPoint(
                x: startX / max(plotRect.width, 1),
                y: plotBottom / max(plotRect.height, 1)
            ),
            gradientEnd: UnitPoint(
                x: innerRight / max(plotRect.width, 1),
                y: goalY / max(plotRect.height, 1)
            ),
            palette: [
                BattleStatsTheme.gold,
                FitUpColors.Neon.yellow,
                BattleStatsTheme.orange,
                FitUpColors.Neon.cyan.opacity(0.85),
            ],
            dash: [7, 5],
            glowWidth: 4.2,
            coreWidth: 1.65
        )
        .allowsHitTesting(false)
    }

    private func goalReferenceLine(plotRect: CGRect, pad: CGPoint, yMax: Int) -> some View {
        let goalY = yPosition(for: stepsGoal, plotRect: plotRect, pad: pad, yMax: yMax)
        let innerLeft = plotRect.minX + pad.x
        let innerRight = plotRect.maxX - pad.x

        let linePath = Path { path in
            path.move(to: CGPoint(x: innerLeft, y: goalY))
            path.addLine(to: CGPoint(x: innerRight, y: goalY))
        }

        let palette: [Color] = goalExceeded
            ? [
                successAccent,
                FitUpColors.Neon.green,
                FitUpColors.Neon.cyan.opacity(0.9),
                successAccent,
            ]
            : [
                BattleStatsTheme.gold,
                FitUpColors.Neon.yellow,
                BattleStatsTheme.orange,
                BattleStatsTheme.gold,
            ]

        return StatsNeonDashedGuideLine(
            path: linePath,
            gradientStart: UnitPoint(x: 0, y: goalY / max(plotRect.height, 1)),
            gradientEnd: UnitPoint(x: 1, y: goalY / max(plotRect.height, 1)),
            palette: palette,
            dash: [6, 5],
            glowWidth: 3.8,
            coreWidth: 1.55
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
                    with: .color(Color.white.opacity(0.12)),
                    style: StrokeStyle(lineWidth: 0.9, lineCap: .round)
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
        .stroke(Color.white.opacity(0.17), style: StrokeStyle(lineWidth: 0.9, dash: [4, 6]))
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
                    with: .color(Color.white.opacity(0.28)),
                    style: StrokeStyle(lineWidth: 0.9, lineCap: .round)
                )
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Chart overlays

/// Animated fluorescent dashed guide (pace diagonal + goal horizontal).
private struct StatsNeonDashedGuideLine: View {
    let path: Path
    let gradientStart: UnitPoint
    let gradientEnd: UnitPoint
    let palette: [Color]
    var dash: [CGFloat] = [6, 5]
    var glowWidth: CGFloat = 3.5
    var coreWidth: CGFloat = 1.5

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 12, paused: false)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let phase = CGFloat(t * 18).truncatingRemainder(dividingBy: 30)
            let shift = CGFloat(sin(t * 1.05)) * 0.14
            let gradient = LinearGradient(
                colors: palette,
                startPoint: UnitPoint(x: gradientStart.x + shift, y: gradientStart.y - shift * 0.35),
                endPoint: UnitPoint(x: gradientEnd.x - shift, y: gradientEnd.y + shift * 0.35)
            )
            let stroke = StrokeStyle(lineWidth: glowWidth, lineCap: .round, dash: dash, dashPhase: phase)

            ZStack {
                path
                    .stroke(gradient, style: stroke)
                    .blur(radius: 3)
                    .opacity(0.72)
                    .blendMode(.plusLighter)

                path
                    .stroke(gradient, style: StrokeStyle(lineWidth: coreWidth, lineCap: .round, dash: dash, dashPhase: phase))
            }
        }
    }
}

struct StatsCompactGoalChip: View {
    let stepsGoal: Int
    let goalMet: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Group {
                    if goalMet {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(FitUpColors.Neon.green)
                    } else {
                        Image(systemName: "target")
                            .foregroundStyle(BattleStatsTheme.gold)
                    }
                }
                .font(.system(size: 12, weight: .semibold))

                if stepsGoal > 0 {
                    Text("Goal")
                        .font(FitUpFont.body(13, weight: .heavy))
                        .foregroundStyle(BattleStatsTheme.textPrimary)

                    Text(">")
                        .font(FitUpFont.body(12, weight: .heavy))
                        .foregroundStyle(BattleStatsTheme.gold.opacity(0.85))

                    Text(stepsGoal.formatted())
                        .font(FitUpFont.display(20, weight: .heavy))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [BattleStatsTheme.gold, FitUpColors.Neon.yellow.opacity(0.92)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: BattleStatsTheme.gold.opacity(0.35), radius: 3, x: 0, y: 1)
                } else {
                    Text("Set goal")
                        .font(FitUpFont.body(13, weight: .heavy))
                        .foregroundStyle(BattleStatsTheme.textPrimary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(BattleStatsTheme.gold.opacity(0.85))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                BattleStatsTheme.gold.opacity(0.18),
                                BattleStatsTheme.gold.opacity(0.10),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                BattleStatsTheme.gold.opacity(0.55),
                                BattleStatsTheme.gold.opacity(0.28),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
            .shadow(color: BattleStatsTheme.gold.opacity(0.35), radius: 6, x: 0, y: 2)
            .shadow(color: BattleStatsTheme.gold.opacity(0.18), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(StatsGoalChipPressStyle())
        .accessibilityLabel(stepsGoal > 0 ? "Daily step goal \(stepsGoal), tap to edit" : "Set daily step goal")
    }
}

private struct StatsGoalChipPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
