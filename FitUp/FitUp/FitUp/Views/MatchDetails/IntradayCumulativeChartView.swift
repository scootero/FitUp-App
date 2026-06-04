//
//  IntradayCumulativeChartView.swift
//  FitUp
//
//  Cumulative today chart for Match Details (viewer from HealthKit; opponent from intraday ticks when available).
//

import Charts
import SwiftUI

struct IntradayCumulativeChartView: View {
    let points: [HealthIntradayCumulativePoint]
    let opponentPoints: [HealthIntradayCumulativePoint]
    /// Opponent’s synced total for today (flat fallback when tick series is empty).
    let opponentTotal: Int
    let isCalories: Bool
    let opponentColor: Color
    let opponentName: String
    /// When true, parent scroll views should lock so horizontal scrubbing does not fight vertical scroll.
    @Binding var isScrubbing: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var isArming = false
    @State private var isScrubActive = false
    @State private var armProgress: CGFloat = 0
    @State private var scrubDate: Date?
    @State private var pressStartedAt: Date?
    @State private var didFireScrubHaptic = false
    @State private var lastScrubLocationX: CGFloat = 0
    @State private var armingClockTask: Task<Void, Never>?
    @State private var armingVisualDelayTask: Task<Void, Never>?
    @State private var isFingerDown = false

    private let holdDuration: Double = HoldToScrubInteraction.defaultHoldDuration
    private let holdMoveTolerance: CGFloat = HoldToScrubInteraction.defaultMoveTolerance

    init(
        points: [HealthIntradayCumulativePoint],
        opponentPoints: [HealthIntradayCumulativePoint],
        opponentTotal: Int,
        isCalories: Bool,
        opponentColor: Color,
        opponentName: String,
        isScrubbing: Binding<Bool> = .constant(false)
    ) {
        self.points = points
        self.opponentPoints = opponentPoints
        self.opponentTotal = opponentTotal
        self.isCalories = isCalories
        self.opponentColor = opponentColor
        self.opponentName = opponentName
        _isScrubbing = isScrubbing
    }

    private var sortedOpponentPoints: [HealthIntradayCumulativePoint] {
        opponentPoints.sorted { $0.date < $1.date }
    }

    private var hasOpponentLineSeries: Bool { sortedOpponentPoints.count >= 2 }

    private var chartStart: Date {
        let userStart = points.first?.date
        let oppStart = sortedOpponentPoints.first?.date
        switch (userStart, oppStart) {
        case let (user?, opponent?):
            return min(user, opponent)
        case let (user?, nil):
            return user
        case let (nil, opponent?):
            return opponent
        case (nil, nil):
            return Date()
        }
    }

    private var chartEnd: Date {
        let userEnd = points.last?.date
        let oppEnd = sortedOpponentPoints.last?.date
        switch (userEnd, oppEnd) {
        case let (user?, opponent?):
            return max(user, opponent)
        case let (user?, nil):
            return user
        case let (nil, opponent?):
            return opponent
        case (nil, nil):
            return Date()
        }
    }

    private var yMax: Double {
        let myMax = points.map(\.cumulative).max() ?? 0
        let oppMax = opponentPoints.map(\.cumulative).max() ?? opponentTotal
        return Double(max(opponentTotal, myMax, oppMax, 1)) * 1.05
    }

    private var activationGlow: CGFloat {
        if isScrubActive { return 1 }
        if isArming { return armProgress }
        return 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY'S PACE")
                .font(FitUpFont.body(10, weight: .heavy))
                .tracking(2)
                .foregroundStyle(FitUpColors.Text.tertiary)

            ZStack(alignment: .topLeading) {
                Chart {
                    if !hasOpponentLineSeries, chartEnd > chartStart, opponentTotal >= 0 {
                        RuleMark(y: .value("Them", opponentTotal))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .foregroundStyle(opponentColor.opacity(0.9))
                    }

                    if hasOpponentLineSeries {
                        ForEach(Array(sortedOpponentPoints.enumerated()), id: \.offset) { _, pt in
                            LineMark(
                                x: .value("Time", pt.date),
                                y: .value("Them", pt.cumulative)
                            )
                            .interpolationMethod(.linear)
                            .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round, dash: [6, 4]))
                            .foregroundStyle(opponentColor.opacity(0.9))
                        }
                    }

                    if !sortedOpponentPoints.isEmpty {
                        ForEach(Array(sortedOpponentPoints.enumerated()), id: \.offset) { _, pt in
                            PointMark(
                                x: .value("Time", pt.date),
                                y: .value("Them", pt.cumulative)
                            )
                            .symbolSize(30)
                            .symbol {
                                Triangle()
                                    .fill(opponentColor)
                                    .frame(width: 7, height: 7)
                            }
                        }
                    }

                    ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                        AreaMark(
                            x: .value("Time", pt.date),
                            y: .value("You", pt.cumulative)
                        )
                        .interpolationMethod(.linear)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [FitUpColors.Neon.cyan.opacity(0.32), FitUpColors.Neon.cyan.opacity(0.04)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                        LineMark(
                            x: .value("Time", pt.date),
                            y: .value("You", pt.cumulative)
                        )
                        .interpolationMethod(.linear)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                        .foregroundStyle(FitUpColors.Neon.cyan)
                        .shadow(color: FitUpColors.Neon.cyan.opacity(0.45), radius: 4, y: 0)
                    }
                    ForEach(Array(points.enumerated()), id: \.offset) { _, pt in
                        PointMark(
                            x: .value("Time", pt.date),
                            y: .value("You", pt.cumulative)
                        )
                        .symbolSize(36)
                        .symbol {
                            ZStack {
                                Circle()
                                    .fill(FitUpColors.Neon.cyan)
                                    .frame(width: 6, height: 6)
                                Circle()
                                    .stroke(FitUpColors.Neon.cyan.opacity(0.4), lineWidth: 1)
                                    .frame(width: 10, height: 10)
                            }
                        }
                    }
                }
                .chartXScale(domain: chartStart...chartEnd)
                .chartYScale(domain: 0...yMax)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.08))
                        if let d = value.as(Date.self) {
                            AxisValueLabel {
                                Text(shortTime(d))
                                    .font(FitUpFont.mono(9, weight: .medium))
                                    .foregroundStyle(FitUpColors.Text.tertiary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.06))
                        let n = value.as(Double.self).map { Int($0.rounded()) } ?? 0
                        AxisValueLabel {
                            Text(formatY(n))
                                .font(FitUpFont.mono(9, weight: .medium))
                                .foregroundStyle(FitUpColors.Text.tertiary)
                        }
                    }
                }
                .chartBackground { _ in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.05), Color.white.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(height: 180)
                .overlay {
                    GeometryReader { geo in
                        Color.clear
                            .contentShape(Rectangle())
                            .holdToScrubPressTracking(moveTolerance: holdMoveTolerance) { pressing in
                                handlePressTrackingChanged(pressing, plotWidth: geo.size.width)
                            }
                            .simultaneousGesture(scrubGesture(plotWidth: geo.size.width))
                    }
                }

                if isArming, !isScrubActive {
                    VStack {
                        Spacer()
                        Text("Hold to inspect pace…")
                            .font(FitUpFont.mono(10, weight: .semibold))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.black.opacity(0.45))
                            )
                            .opacity(Double(0.35 + armProgress * 0.65))
                    }
                    .padding(.bottom, 10)
                    .allowsHitTesting(false)
                }

                if let callout = calloutText {
                    VStack {
                        HStack {
                            Spacer()
                            Text(callout)
                                .font(FitUpFont.mono(11, weight: .bold))
                                .foregroundStyle(FitUpColors.Text.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(Color.black.opacity(0.5))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .strokeBorder(FitUpColors.Neon.cyan.opacity(0.35), lineWidth: 1)
                                        )
                                )
                        }
                        Spacer()
                    }
                    .padding(8)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
            .accessibilityHint("Hold briefly, then drag horizontally to inspect your pace at a specific time.")
            .accessibilityValue(calloutText ?? "")
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04 + activationGlow * 0.03))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    FitUpColors.Neon.cyan.opacity(0.08 + activationGlow * 0.55),
                                    FitUpColors.Neon.cyan.opacity(0.04 + activationGlow * 0.28),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1 + activationGlow * 1.25
                        )
                }
                .shadow(
                    color: FitUpColors.Neon.cyan.opacity(activationGlow * 0.32),
                    radius: 6 + activationGlow * 12,
                    x: 0,
                    y: 0
                )
        }
        .scaleEffect(reduceMotion ? 1 : (1 + activationGlow * 0.008))
        .animation(.easeOut(duration: 0.22), value: activationGlow)
        .onChange(of: isScrubActive) { _, active in
            isScrubbing = active
        }
        .onDisappear {
            cancelArmingVisuals()
            stopArmingClock()
            didFireScrubHaptic = false
            HoldToScrubInteraction.endSession(
                pressStartedAt: &pressStartedAt,
                isArming: &isArming,
                isScrubActive: &isScrubActive,
                armProgress: &armProgress
            )
            scrubDate = nil
            isScrubbing = false
        }
    }

    private func scrubGesture(plotWidth: CGFloat) -> some Gesture {
        HoldToScrubInteraction.scrubGesture(
            holdDuration: holdDuration,
            moveTolerance: holdMoveTolerance,
            onActivated: {
                activateScrub(plotWidth: plotWidth)
            },
            onDrag: { drag in
                lastScrubLocationX = drag.location.x
                updateScrubDate(x: drag.location.x, plotWidth: plotWidth)
            },
            onEnded: {
                endScrubSession()
            }
        )
    }

    private func handlePressTrackingChanged(_ pressing: Bool, plotWidth: CGFloat) {
        isFingerDown = pressing
        if pressing {
            scheduleArmingVisuals(plotWidth: plotWidth)
        } else if !isScrubActive {
            cancelArmingVisuals()
        }
    }

    private func scheduleArmingVisuals(plotWidth: CGFloat) {
        armingVisualDelayTask?.cancel()
        armingVisualDelayTask = Task { @MainActor in
            let delayNs = UInt64(HoldToScrubInteraction.armingVisualDelay * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delayNs)
            guard !Task.isCancelled, isFingerDown, !isScrubActive else { return }
            isArming = true
            pressStartedAt = Date()
            armProgress = 0
            startArmingClock(plotWidth: plotWidth)
        }
    }

    private func cancelArmingVisuals() {
        armingVisualDelayTask?.cancel()
        armingVisualDelayTask = nil
        stopArmingClock()
        HoldToScrubInteraction.resetPressState(
            pressStartedAt: &pressStartedAt,
            isArming: &isArming,
            armProgress: &armProgress
        )
    }

    private func activateScrub(plotWidth: CGFloat) {
        armingVisualDelayTask?.cancel()
        armingVisualDelayTask = nil
        stopArmingClock()
        isArming = false
        isScrubActive = true
        armProgress = 1
        fireScrubHapticIfNeeded()
        updateScrubDate(x: lastScrubLocationX, plotWidth: plotWidth)
    }

    private func endScrubSession() {
        isFingerDown = false
        cancelArmingVisuals()
        didFireScrubHaptic = false
        HoldToScrubInteraction.endSession(
            pressStartedAt: &pressStartedAt,
            isArming: &isArming,
            isScrubActive: &isScrubActive,
            armProgress: &armProgress
        )
        scrubDate = nil
        isScrubbing = false
    }

    private func startArmingClock(plotWidth: CGFloat) {
        guard armingClockTask == nil else { return }
        armingClockTask = Task { @MainActor in
            defer { armingClockTask = nil }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(40))
                guard let started = pressStartedAt, isArming, !isScrubActive else { return }
                let elapsed = Date().timeIntervalSince(started)
                armProgress = min(1, CGFloat(elapsed / holdDuration))
                if elapsed >= holdDuration {
                    isArming = false
                    isScrubActive = true
                    fireScrubHapticIfNeeded()
                    updateScrubDate(x: lastScrubLocationX, plotWidth: plotWidth)
                    return
                }
            }
        }
    }

    private func stopArmingClock() {
        armingClockTask?.cancel()
        armingClockTask = nil
    }

    private func fireScrubHapticIfNeeded() {
        guard !didFireScrubHaptic else { return }
        didFireScrubHaptic = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func updateScrubDate(x: CGFloat, plotWidth: CGFloat) {
        guard plotWidth > 0, chartEnd > chartStart else { return }
        let fraction = min(1, max(0, x / plotWidth))
        let span = chartEnd.timeIntervalSince(chartStart)
        scrubDate = chartStart.addingTimeInterval(span * Double(fraction))
    }

    private var calloutText: String? {
        guard isScrubActive, !points.isEmpty, let s = scrubDate else { return nil }
        let closest = points.min(by: { abs($0.date.timeIntervalSince(s)) < abs($1.date.timeIntervalSince(s)) })
        guard let p = closest else { return nil }
        return "\(formatValue(p.cumulative)) · \(timeLabel(p.date))"
    }

    private var accessibilitySummary: String {
        if points.isEmpty { return "No intraday data" }
        let last = points.last!.cumulative
        let unit = isCalories ? "kilocalories" : "steps"
        let opponentNote: String
        if hasOpponentLineSeries {
            opponentNote = " \(opponentName) pace is plotted from synced samples."
        } else if !sortedOpponentPoints.isEmpty {
            opponentNote = " \(opponentName) has one synced sample on the chart."
        } else {
            opponentNote = " \(opponentName) total shown as a flat line at \(opponentTotal) \(unit)."
        }
        return "Your cumulative total so far, \(formatValue(last)) \(unit), chart from midnight to now.\(opponentNote)"
    }

    private func shortTime(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "ha"
        f.amSymbol = "a"
        f.pmSymbol = "p"
        return f.string(from: d).lowercased()
    }

    private func timeLabel(_ d: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: d)
    }

    private func formatY(_ n: Int) -> String {
        if isCalories { return "\(n)" }
        if n >= 1000 { return String(format: "%.1fk", Double(n) / 1000) }
        return "\(n)"
    }

    private func formatValue(_ v: Int) -> String {
        if isCalories { return "\(v.formatted()) kcal" }
        return v.formatted()
    }
}

/// Upward-pointing triangle for opponent tick markers.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
