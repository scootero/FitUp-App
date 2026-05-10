//
//  StatsMockShellView.swift
//  FitUp
//
//  Slice 1 — Stats shell above legacy Health content.
//

import Charts
import SwiftUI

struct StatsMockShellView: View {
    let selectedRange: HealthViewModel.StatsRangeKey
    let effectiveRange: HealthViewModel.StatsRangeKey
    let onSelectRange: (HealthViewModel.StatsRangeKey) -> Void
    let dateChipText: String
    let rangeScopeNote: String?
    let previousPeriodPercent: Int?
    let battleStatsScopeLabel: String
    let rangeMargins: [DailyBattleMargin]
    let isRangeMarginsLoading: Bool
    let dailyMargins: [DailyBattleMargin]
    let dailyMarginDayCount: Int
    let dailyMarginsSavedAt: Date?
    let isDailyMarginsRefreshing: Bool
    let onSelectDailyMarginDayCount: (Int) -> Void
    let battleStats: HealthBattleStats
    let weekSteps: [Int]
    let activeMatchEdges: [HomeActiveMatch]
    let rivalStats: [HomeRivalStat]
    let isRivalStatsLoading: Bool
    let hasLoadedRivalStats: Bool
    let oneDayHourlySteps: [HealthIntradayHourlyBucket]
    let isOneDayHourlyLoading: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var marginMode: MarginMode = .net
    @State private var netLineRevealProgress: Double = 0
    @State private var dailyBarsProgress: Double = 0
    @State private var chartAnimationTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.bottom, 10)

            rangeSelector
                .padding(.bottom, 10)

            summaryCard
                .padding(.bottom, 10)

            marginChartCard
                .padding(.bottom, 12)

            competitionEdgeSection
                .padding(.bottom, 10)

            rivalsSection
                .padding(.bottom, 10)

            personalBestsSection
                .padding(.bottom, 10)

            insightsSection
                .padding(.bottom, 12)
        }
        .onAppear {
            startMarginChartAnimation()
        }
        .onDisappear {
            chartAnimationTask?.cancel()
            chartAnimationTask = nil
        }
        .onChange(of: marginMode) { _, _ in
            startMarginChartAnimation()
        }
        .onChange(of: rangeMargins.map(\.id)) { _, _ in
            guard marginMode == .net else { return }
            startMarginChartAnimation()
        }
        .onChange(of: rangeMargins.map(\.margin)) { _, _ in
            guard marginMode == .net else { return }
            startMarginChartAnimation()
        }
        .onChange(of: rangeMargins) { _, _ in
            logStatsMarginSeriesDebug()
        }
        .onChange(of: dailyMargins.map(\.id)) { _, _ in
            guard marginMode == .daily else { return }
            startMarginChartAnimation()
        }
        .onChange(of: dailyMargins.map(\.margin)) { _, _ in
            guard marginMode == .daily else { return }
            startMarginChartAnimation()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("STATS")
                    .font(FitUpFont.display(24, weight: .heavy))
                    .fitUpGlobalTitleStyle(weight: .heavy, tracking: 0.7)

                Text("Your progress. Your rivals. Your edge.")
                    .font(FitUpFont.body(12, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }

            Spacer(minLength: 8)

            Button {} label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.secondary.opacity(0.9))
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.04))
                    .clipShape(Circle())
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 10)
    }

    private var rangeSelector: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(topRangeOptions) { range in
                        Button {
                            onSelectRange(range)
                        } label: {
                            Text(range.rawValue)
                                .font(FitUpFont.body(11, weight: .bold))
                                .foregroundStyle(
                                    selectedRange == range ? Color.white : FitUpColors.Text.secondary
                                )
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 6)
                                .background {
                                    if selectedRange == range {
                                        Capsule()
                                            .fill(FitUpColors.Neon.green.opacity(0.85))
                                            .shadow(color: FitUpColors.Neon.green.opacity(0.5), radius: 9)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 2)
            }
            .padding(4)
            .background(Color.white.opacity(0.055))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.14), lineWidth: 0.8)
            }

            Spacer(minLength: 0)

            HStack(spacing: 7) {
                Image(systemName: "calendar")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.secondary)
                Text(dateChipText)
                    .font(FitUpFont.mono(10, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.04))
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.16), lineWidth: 0.8)
            }
        }
    }

    private var summaryCard: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("THIS \(effectiveRange.fallbackDayCount) DAYS")
                    .font(FitUpFont.body(11, weight: .heavy))
                    .fitUpGlobalTitleStyle(weight: .heavy, tracking: 1.2)

                Text(netMarginDisplayText)
                    .font(FitUpFont.display(36, weight: .heavy))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [FitUpColors.Neon.green, FitUpColors.Neon.cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: FitUpColors.Neon.green.opacity(0.34), radius: 8, x: 0, y: 2)

                Text("NET BATTLE MARGIN")
                    .font(FitUpFont.body(11, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.secondary)

                if let rangeScopeNote {
                    Text(rangeScopeNote)
                        .font(FitUpFont.body(10, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                }

                Text(previousPeriodLabel)
                    .font(FitUpFont.body(11, weight: .semibold))
                    .foregroundStyle(previousPeriodColor)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 9) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("WIN RATE (\(battleStatsScopeLabel.uppercased()))")
                        .font(FitUpFont.body(10, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.tertiary)
                    // TODO(slice3): This is lifetime win rate from health_battle_stats, not 30-day scoped.
                    Text(lifetimeWinRateText)
                        .font(FitUpFont.display(32, weight: .heavy))
                        .foregroundStyle(FitUpColors.Neon.green.opacity(0.95))
                    Text(lifetimeRecordText)
                        .font(FitUpFont.body(11, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }

                Divider()
                    .overlay(Color.white.opacity(0.12))

                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(FitUpColors.Neon.green)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("STREAK (\(battleStatsScopeLabel.uppercased()))")
                            .font(FitUpFont.body(10, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.tertiary)
                        HStack(spacing: 4) {
                            // TODO(slice3): This is lifetime streak from health_battle_stats, not 30-day scoped.
                            Text(lifetimeStreakCountText)
                                .font(FitUpFont.display(26, weight: .heavy))
                                .foregroundStyle(FitUpColors.Neon.green)
                            Text("DAYS")
                                .font(FitUpFont.body(11, weight: .bold))
                                .foregroundStyle(FitUpColors.Text.secondary)
                        }
                    }
                }
            }
            .frame(width: 118, alignment: .leading)
        }
        .padding(12)
        .glassCard(.base)
    }

    private var marginChartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Battle margin mode", selection: $marginMode) {
                ForEach(MarginMode.allCases) { mode in
                    Text(modeLabel(for: mode)).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .tint(marginMode == .net ? FitUpColors.Neon.green.opacity(0.95) : FitUpColors.Neon.cyan.opacity(0.95))

            HStack(alignment: .firstTextBaseline) {
                Text(currentChartHeaderText)
                    .font(FitUpFont.body(11, weight: .heavy))
                    .fitUpGlobalTitleStyle(weight: .heavy, tracking: 1.3)
                Spacer()
                Text(currentChartTrailingText)
                    .font(FitUpFont.body(15, weight: .heavy))
                    .foregroundStyle(marginMode == .net ? FitUpColors.Neon.green : FitUpColors.Neon.cyan)
            }

            Text(currentChartDescriptionText)
                .font(FitUpFont.body(11, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)

            if isOneDayMode {
                if isOneDayHourlyLoading, oneDayHourlySteps.isEmpty {
                    Text("Updating...")
                        .font(FitUpFont.body(11, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }

                if oneDayHourlySteps.isEmpty {
                    emptyOneDayHourlyState
                } else if marginMode == .net {
                    oneDayHourlyLineChart
                } else {
                    oneDayHourlyBarChart
                }
            } else {
                if isCurrentMarginModeLoading, currentMarginRows.isEmpty {
                    Text("Updating...")
                        .font(FitUpFont.body(11, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }

                if currentMarginRows.isEmpty {
                    emptyMarginState
                } else if marginMode == .net {
                    netMarginLineChart
                } else {
                    dailyMarginBarChart
                }
            }

            if !isOneDayMode, marginMode == .daily {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    if let freshnessText = dailyFreshnessText(now: context.date) {
                        Text(freshnessText)
                            .font(FitUpFont.body(11, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.secondary)
                    }
                }
            }
        }
        .padding(12)
        .glassCard(.base)
    }

    private var isOneDayMode: Bool {
        selectedRange == .oneDay
    }

    private var topRangeOptions: [HealthViewModel.StatsRangeKey] {
        HealthViewModel.StatsRangeKey.allCases.filter { $0 != .oneYear && $0 != .all }
    }

    private func modeLabel(for mode: MarginMode) -> String {
        if isOneDayMode {
            return mode == .net ? "Line" : "Bars"
        }
        return mode.label
    }

    private var currentChartHeaderText: String {
        if isOneDayMode {
            return "HOURLY STEPS TODAY"
        }
        return "\(marginMode.headerLabel) (\(marginModeDayCount) DAYS)"
    }

    private var currentChartTrailingText: String {
        if isOneDayMode {
            return "\(oneDayTotalSteps.formatted()) STEPS"
        }
        return marginMode.trailingHeadline(valueText: netMarginTotalLabelText)
    }

    private var currentChartDescriptionText: String {
        if isOneDayMode {
            return "Your steps per hour today, starting from the first hour you logged activity."
        }
        return marginMode.descriptionText
    }

    private var oneDayTotalSteps: Int {
        oneDayHourlySteps.reduce(0) { $0 + $1.value }
    }

    private var oneDayMaxStepsPerHour: Int {
        max(oneDayHourlySteps.map(\.value).max() ?? 0, 1)
    }

    private var oneDayChartYDomain: ClosedRange<Int> {
        // Pad top by ~12% so the data label doesn't clip; never less than 100 for very low-step early hours.
        let padded = max(Int((Double(oneDayMaxStepsPerHour) * 1.12).rounded()), oneDayMaxStepsPerHour + 50, 100)
        return 0...padded
    }

    private var emptyOneDayHourlyState: some View {
        HStack(spacing: 8) {
            Image(systemName: marginMode == .net ? "chart.line.uptrend.xyaxis" : "chart.bar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.tertiary)
            Text("No step activity recorded yet today.")
                .font(FitUpFont.body(11, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 208, alignment: .center)
    }

    private var netMarginLineChart: some View {
        ZStack(alignment: .bottomTrailing) {
            Chart {
                if !useCompactChartStyle {
                    ForEach(cumulativeNetChartPoints) { point in
                        AreaMark(
                            x: .value("Date", point.label),
                            y: .value("Margin", point.margin)
                        )
                        .interpolationMethod(.linear)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    FitUpColors.Neon.purple.opacity(0.22),
                                    FitUpColors.Neon.blue.opacity(0.2),
                                    FitUpColors.Neon.green.opacity(0.26),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }
                }

                ForEach(cumulativeNetChartPoints) { point in
                    LineMark(
                        x: .value("Date", point.label),
                        y: .value("Margin", point.margin)
                    )
                    .interpolationMethod(.linear)
                    .lineStyle(StrokeStyle(lineWidth: useCompactChartStyle ? 2.2 : 4, lineCap: .round))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                FitUpColors.Neon.purple.opacity(useCompactChartStyle ? 0.45 : 0.65),
                                FitUpColors.Neon.blue.opacity(useCompactChartStyle ? 0.45 : 0.6),
                                FitUpColors.Neon.green.opacity(useCompactChartStyle ? 0.5 : 0.7),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: FitUpColors.Neon.blue.opacity(useCompactChartStyle ? 0.12 : 0.32), radius: useCompactChartStyle ? 2 : 9, x: 0, y: 0)

                    if !useCompactChartStyle {
                        LineMark(
                            x: .value("Date", point.label),
                            y: .value("Margin", point.margin)
                        )
                        .interpolationMethod(.linear)
                        .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    FitUpColors.Neon.purple,
                                    FitUpColors.Neon.blue.opacity(0.08),
                                    FitUpColors.Neon.green,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    }
                }

                if let lastPoint = cumulativeNetChartPoints.last {
                    if !useCompactChartStyle {
                        PointMark(
                            x: .value("Date", lastPoint.label),
                            y: .value("Margin", lastPoint.margin)
                        )
                        .symbolSize(180)
                        .foregroundStyle(FitUpColors.Neon.green.opacity(0.3))
                        .shadow(color: FitUpColors.Neon.green.opacity(0.5), radius: 9)
                    }

                    PointMark(
                        x: .value("Date", lastPoint.label),
                        y: .value("Margin", lastPoint.margin)
                    )
                    .symbolSize(useCompactChartStyle ? 14 : 36)
                    .foregroundStyle(useCompactChartStyle ? FitUpColors.Neon.green.opacity(0.95) : Color.white)
                    .shadow(color: (useCompactChartStyle ? FitUpColors.Neon.green : Color.white).opacity(useCompactChartStyle ? 0.4 : 0.8), radius: useCompactChartStyle ? 3 : 6)
                }

                RuleMark(y: .value("Zero", 0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.white.opacity(0.25))
            }
            .chartYScale(domain: cumulativeNetYDomain)
            .chartXAxis {
                AxisMarks(values: chartAxisLabels) { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(FitUpFont.mono(9, weight: .semibold))
                                .foregroundStyle(FitUpColors.Text.tertiary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: cumulativeNetAxisTickValues) { value in
                    AxisValueLabel {
                        if let y = value.as(Int.self) {
                            Text(formattedNetMarginAxisLabel(y))
                                .font(FitUpFont.mono(9, weight: .medium))
                                .foregroundStyle(FitUpColors.Text.secondary)
                        }
                    }
                }
            }
            .frame(height: 208)
            .mask {
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0),
                        .init(color: .white, location: max(0, netLineRevealProgress - 0.08)),
                        .init(color: .clear, location: min(1, netLineRevealProgress)),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }

            if let total = netMarginTotal {
                Text(signedFormatted(total))
                    .font(FitUpFont.mono(11, weight: .heavy))
                    .foregroundStyle(FitUpColors.Neon.green)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.32))
                    .clipShape(Capsule())
                    .overlay {
                        Capsule().strokeBorder(FitUpColors.Neon.green.opacity(0.35), lineWidth: 0.8)
                    }
                    .padding(.trailing, 6)
                    .padding(.bottom, 8)
                    .transition(.opacity)
            }
        }
    }

    private var dailyMarginBarChart: some View {
        GeometryReader { geo in
            let plotW = geo.size.width
            let count = animatedDailyMargins.count
            Chart {
                ForEach(Array(animatedDailyMargins.enumerated()), id: \.element.id) { index, point in
                    let progress = progressForDailyBar(at: index)
                    let animatedMargin = Int((Double(point.margin) * progress).rounded())
                    let displayed = dailyDisplayedMargin(animated: animatedMargin, raw: point.margin)
                    let isHighlightedDay = point.calendarDate == highlightedDailyKey
                    let barW = categoricalBarWidth(plotWidth: plotW, count: max(count, 1), highlighted: isHighlightedDay)

                    BarMark(
                        x: .value("Day", point.calendarDate),
                        y: .value("Margin", displayed),
                        width: .fixed(barW)
                    )
                    .foregroundStyle(dailyBarFill(for: point.margin))
                    .cornerRadius(isHighlightedDay ? 5 : 4)
                    .shadow(
                        color: dailyBarGlowColor(for: point.margin).opacity(isHighlightedDay ? 1.0 : 0.85),
                        radius: isHighlightedDay ? 11 : 6,
                        x: 0,
                        y: 0
                    )
                    .annotation(position: displayed >= 0 ? .top : .bottom, spacing: 4) {
                        if point.margin != 0, animatedMargin != 0 {
                            Text(signedFormatted(animatedMargin))
                                .font(FitUpFont.mono(9, weight: .bold))
                                .foregroundStyle(dailyBarValueColor(for: point.margin))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.22))
                                .clipShape(Capsule())
                        }
                    }
                }

                RuleMark(y: .value("Even", 0))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(Color.white.opacity(0.22))
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let key = value.as(String.self) {
                            Text(shortWeekdayLabel(key))
                                .font(FitUpFont.mono(10, weight: .semibold))
                                .foregroundStyle(
                                    key == highlightedDailyKey
                                        ? LinearGradient(
                                            colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.blue],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        : LinearGradient(
                                            colors: [FitUpColors.Text.tertiary, FitUpColors.Neon.blue.opacity(0.74)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                )
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: SignedChartYDomain.axisTickValues(for: dailyMarginYDomain)) { value in
                    AxisValueLabel {
                        if let n = value.as(Int.self) {
                            Text(formattedNetMarginAxisLabel(n))
                                .font(FitUpFont.mono(9, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [FitUpColors.Neon.cyan.opacity(0.95), FitUpColors.Text.tertiary],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                }
            }
            .chartYScale(domain: dailyMarginYDomain)
        }
        .frame(height: 208)
    }

    private var oneDayHourlyLineChart: some View {
        Chart {
            ForEach(oneDayHourlySteps) { bucket in
                AreaMark(
                    x: .value("Hour", bucket.hourStart),
                    y: .value("Steps", bucket.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            FitUpColors.Neon.cyan.opacity(0.32),
                            FitUpColors.Neon.cyan.opacity(0.04),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Hour", bucket.hourStart),
                    y: .value("Steps", bucket.value)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FitUpColors.Neon.green, FitUpColors.Neon.cyan],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: FitUpColors.Neon.cyan.opacity(0.4), radius: 5)

                PointMark(
                    x: .value("Hour", bucket.hourStart),
                    y: .value("Steps", bucket.value)
                )
                .symbolSize(34)
                .foregroundStyle(FitUpColors.Neon.cyan)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: oneDayHourAxisStride)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(oneDayHourLabel(for: date))
                            .font(FitUpFont.mono(9, weight: .semibold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [FitUpColors.Text.tertiary, FitUpColors.Neon.blue.opacity(0.74)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let n = value.as(Int.self) {
                        Text(formattedHourlyStepsLabel(n))
                            .font(FitUpFont.mono(9, weight: .medium))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [FitUpColors.Neon.cyan.opacity(0.95), FitUpColors.Text.tertiary],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }
                }
            }
        }
        .chartYScale(domain: oneDayChartYDomain)
        .frame(height: 208)
    }

    private var oneDayHourlyBarChart: some View {
        GeometryReader { geo in
            let plotW = geo.size.width
            let nBuckets = oneDayHourlySteps.count
            Chart {
                ForEach(oneDayHourlySteps) { bucket in
                    let displayed = hourlyDisplayedSteps(bucket.value)
                    let barW = categoricalBarWidth(plotWidth: plotW, count: max(nBuckets, 1), highlighted: false)

                    BarMark(
                        x: .value("Hour", bucket.hourStart, unit: .hour),
                        y: .value("Steps", displayed),
                        width: .fixed(barW)
                    )
                    .foregroundStyle(hourlyBarFill(isZero: bucket.value == 0))
                    .cornerRadius(4)
                    .shadow(color: (bucket.value == 0 ? FitUpColors.Text.tertiary : FitUpColors.Neon.cyan).opacity(0.45), radius: bucket.value == 0 ? 2 : 6)
                    .annotation(position: .top, spacing: 4) {
                        if bucket.value != 0 {
                            Text(bucket.value.formatted())
                                .font(FitUpFont.mono(9, weight: .bold))
                                .foregroundStyle(FitUpColors.Neon.cyan)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.22))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: oneDayHourAxisStride)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(oneDayHourLabel(for: date))
                                .font(FitUpFont.mono(9, weight: .semibold))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [FitUpColors.Text.tertiary, FitUpColors.Neon.blue.opacity(0.74)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisValueLabel {
                        if let n = value.as(Int.self) {
                            Text(formattedHourlyStepsLabel(n))
                                .font(FitUpFont.mono(9, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [FitUpColors.Neon.cyan.opacity(0.95), FitUpColors.Text.tertiary],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                }
            }
            .chartYScale(domain: oneDayChartYDomain)
        }
        .frame(height: 208)
    }

    /// Choose hour-stride to keep the x-axis label-density readable: ~6 ticks regardless of how many hours are shown.
    private var oneDayHourAxisStride: Int {
        let n = oneDayHourlySteps.count
        if n <= 6 { return 1 }
        if n <= 12 { return 2 }
        if n <= 18 { return 3 }
        return 4
    }

    private func oneDayHourLabel(for date: Date) -> String {
        Self.oneDayHourFormatter.string(from: date).uppercased()
    }

    private func formattedHourlyStepsLabel(_ value: Int) -> String {
        if value >= 1_000 {
            let k = Double(value) / 1_000
            return String(format: "%.1fK", k)
        }
        return "\(value)"
    }

    private var competitionEdgeSection: some View {
        CompetitionEdgeTodaySection(matches: activeMatchEdges)
    }

    private var rivalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "crown.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FitUpColors.Neon.green)
                Text("YOUR RIVALS")
                    .font(FitUpFont.body(11, weight: .heavy))
                    .fitUpGlobalTitleStyle(weight: .heavy, tracking: 1.5)

                Spacer()

                Button("View all") {}
                    .buttonStyle(.plain)
                    .font(FitUpFont.body(11, weight: .semibold))
                    .foregroundStyle(hasRivals ? FitUpColors.Neon.blue : FitUpColors.Text.tertiary)
                    .disabled(!hasRivals)
            }

            if isRivalStatsLoading && !hasLoadedRivalStats {
                Text("Updating...")
                    .font(FitUpFont.body(11, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
            } else if rivals.isEmpty {
                Text("Rival stats will appear after you complete more matches.")
                    .font(FitUpFont.body(11, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
            } else {
                ForEach(rivals) { rival in
                    rivalRow(rival)
                    if rival.id != rivals.last?.id {
                        Divider()
                            .overlay(Color.white.opacity(0.1))
                    }
                }
            }
        }
        .padding(12)
        .glassCard(.base)
    }

    private var personalBestsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PERSONAL BESTS")
                .font(FitUpFont.body(11, weight: .heavy))
                .fitUpGlobalTitleStyle(weight: .heavy, tracking: 1.5)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8),
                ],
                spacing: 8
            ) {
                ForEach(personalBests) { item in
                    VStack(alignment: .center, spacing: 5) {
                        Image(systemName: item.iconName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(item.accentColor)
                            .frame(height: 18)

                        Text(item.value)
                            .font(FitUpFont.display(24, weight: .heavy))
                            .foregroundStyle(FitUpColors.Text.primary)

                        Text(item.title.uppercased())
                            .font(FitUpFont.body(9, weight: .bold))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .multilineTextAlignment(.center)

                        Text(item.subtitle)
                            .font(FitUpFont.body(11, weight: .medium))
                            .foregroundStyle(item.accentColor)
                    }
                    .frame(maxWidth: .infinity, minHeight: 94, alignment: .center)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.25),
                                        Color.white.opacity(0.08),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 0.9
                            )
                    }
                }
            }
        }
        .padding(12)
        .glassCard(.base)
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INSIGHTS")
                .font(FitUpFont.body(11, weight: .heavy))
                .fitUpGlobalTitleStyle(weight: .heavy, tracking: 1.5)
            // TODO(slice4.2-backend): Populate insights from stats snapshot/RPC instead of local placeholder copy.

            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(FitUpColors.Neon.purple)
                    .frame(width: 16, height: 16)

                Text("Insights will appear as your match history grows.")
                    .font(FitUpFont.body(11, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 6)
        }
        .padding(12)
        .glassCard(.base)
    }

    private func rivalRow(_ rival: RivalRowData) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Text("\(rival.rank)")
                .font(FitUpFont.mono(16, weight: .bold))
                .foregroundStyle(rival.rankColor)
                .frame(width: 16, alignment: .leading)

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [rival.avatarColor.opacity(0.75), rival.avatarColor.opacity(0.35)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Circle()
                            .strokeBorder(rival.avatarColor.opacity(0.55), lineWidth: 1)
                    }
                    .shadow(color: rival.avatarColor.opacity(0.36), radius: 6)
                Text(rival.initials)
                    .font(FitUpFont.body(11, weight: .heavy))
                    .foregroundStyle(.white)
            }
            .frame(width: 30, height: 30)
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(FitUpColors.Neon.green)
                    .frame(width: 6, height: 6)
                    .overlay(Circle().strokeBorder(Color.black, lineWidth: 1))
                    .offset(x: 1, y: 1)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(rival.name)
                    .font(FitUpFont.body(12, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.primary)
                    .lineLimit(1)

                Text("\(rival.finalizedDaysCompeted) FINALIZED DAYS")
                    .font(FitUpFont.body(9, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.tertiary)
            }
            .frame(width: 102, alignment: .leading)

            rivalStatCell(value: rival.record, label: "RECORD")
            rivalStatCell(value: rival.winPercentText, label: "WIN %")
            rivalStatCell(
                value: rival.avgMarginText,
                label: "AVG MARGIN",
                valueColor: rival.avgMarginColor
            )

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(FitUpColors.Text.tertiary)
        }
    }

    private func rivalStatCell(value: String, label: String, valueColor: Color = FitUpColors.Text.primary) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(FitUpFont.mono(16, weight: .bold))
                .foregroundStyle(valueColor)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(label)
                .font(FitUpFont.body(9, weight: .bold))
                .foregroundStyle(FitUpColors.Text.tertiary)
        }
        .frame(width: 52, alignment: .leading)
    }

    /// Y-axis labels for the cumulative net chart (supports magnitudes beyond ±20K).
    private func formattedNetMarginAxisLabel(_ value: Int) -> String {
        if value == 0 { return "0" }
        let absV = abs(value)
        if absV < 1_000 {
            return "\(value)"
        }
        let sign = value > 0 ? "+" : "-"
        let k = Double(absV) / 1_000
        if absV % 1_000 == 0 || k >= 100 {
            return "\(sign)\(Int(k))K"
        }
        return String(format: "%@%.1fK", sign, k)
    }

    private var netMarginTotal: Int? {
        guard !rangeMargins.isEmpty else { return nil }
        return rangeMargins.reduce(0) { $0 + $1.margin }
    }

    private var currentMarginRows: [DailyBattleMargin] {
        rangeMargins
    }

    private var isCurrentMarginModeLoading: Bool {
        isRangeMarginsLoading
    }

    private var marginModeDayCount: Int {
        effectiveRange.fallbackDayCount
    }

    private var netMarginDisplayText: String {
        guard let total = netMarginTotal else { return "—" }
        return signedFormatted(total)
    }

    private var netMarginTotalLabelText: String {
        guard let total = netMarginTotal else { return "— RANGE" }
        return "\(signedFormatted(total)) RANGE"
    }

    private var lifetimeWinRateText: String {
        guard (battleStats.wins + battleStats.losses) > 0 else { return "—" }
        return "\(battleStats.winRate)%"
    }

    private var lifetimeRecordText: String {
        guard battleStats.matchesPlayed > 0 else { return "—" }
        return "\(battleStats.wins)W – \(battleStats.losses)L"
    }

    private var lifetimeStreakCountText: String {
        "\(battleStats.currentStreakCount)"
    }

    /// Daily battle margins (same values as the bar chart).
    private var dailyMarginChartPoints: [MarginPoint] {
        rangeMargins.map { row in
            MarginPoint(label: chartLabel(from: row.calendarDate), margin: row.margin)
        }
    }

    /// Running sum of `daily_margin`; powers the Net line chart and matches `netMarginTotal` at the last day.
    private var cumulativeNetChartPoints: [MarginPoint] {
        var running = 0
        return rangeMargins.map { row in
            running += row.margin
            return MarginPoint(label: chartLabel(from: row.calendarDate), margin: running)
        }
    }

    private var cumulativeNetYDomain: ClosedRange<Int> {
        let pts = cumulativeNetChartPoints
        guard !pts.isEmpty else { return -20_000...20_000 }
        let vals = pts.map(\.margin)
        guard let mn = vals.min(), let mx = vals.max() else { return -20_000...20_000 }
        return SignedChartYDomain.domain(dataMin: mn, dataMax: mx, minimumCoreSpan: 4_000)
    }

    private var cumulativeNetAxisTickValues: [Int] {
        SignedChartYDomain.axisTickValues(for: cumulativeNetYDomain)
    }

    private var animatedDailyMargins: [DailyBattleMargin] {
        currentMarginRows
    }

    private var highlightedDailyKey: String? {
        currentMarginRows.last?.calendarDate
    }

    private var dailyChartMaxAbs: Int {
        max(currentMarginRows.map { abs($0.margin) }.max() ?? 0, 1)
    }

    /// Visible height for tied days (`margin == 0`) so the bar reads without implying real magnitude.
    private var dailyMarginStubHeight: Int {
        let rows = currentMarginRows
        guard !rows.isEmpty else { return 1 }
        let vals = rows.map(\.margin)
        guard let mn = vals.min(), let mx = vals.max() else { return 1 }
        let span = max(mx - mn, 400)
        return max(1, span / 45)
    }

    private var dailyMarginYDomain: ClosedRange<Int> {
        let rows = currentMarginRows
        guard !rows.isEmpty else { return -400...400 }
        let vals = rows.map(\.margin)
        guard let mn = vals.min(), let mx = vals.max() else { return -400...400 }
        let hasZeroDay = vals.contains(0)
        let effectiveMax = hasZeroDay ? max(mx, dailyMarginStubHeight) : mx
        return SignedChartYDomain.domain(dataMin: mn, dataMax: effectiveMax)
    }

    private func categoricalBarWidth(plotWidth: CGFloat, count: Int, highlighted: Bool) -> CGFloat {
        let n = max(count, 1)
        let slot = plotWidth / CGFloat(n)
        let gap: CGFloat = 5
        let minW: CGFloat = 6
        let maxW: CGFloat = 21
        let base = min(max(slot - gap, minW), maxW)
        let boosted = base + (highlighted ? 4 : 0)
        return min(max(boosted, minW), max(slot - 2, minW))
    }

    private func dailyDisplayedMargin(animated: Int, raw: Int) -> Int {
        if raw == 0 { return dailyMarginStubHeight }
        return animated
    }

    private func dailyBarFill(for margin: Int) -> LinearGradient {
        if margin == 0 {
            return LinearGradient(
                colors: [FitUpColors.Neon.blue.opacity(0.92), FitUpColors.Neon.cyan.opacity(0.55)],
                startPoint: .bottom,
                endPoint: .top
            )
        }
        return dailyBarGradient(for: margin)
    }

    private func dailyBarGlowColor(for margin: Int) -> Color {
        if margin == 0 { return FitUpColors.Neon.blue.opacity(0.5) }
        return dailyBarGlow(for: margin)
    }

    private var hourlyStepsStub: Int {
        let m = oneDayHourlySteps.map(\.value).max() ?? 0
        return max(2, m / 45)
    }

    private func hourlyDisplayedSteps(_ value: Int) -> Int {
        value == 0 ? hourlyStepsStub : value
    }

    private func hourlyBarFill(isZero: Bool) -> LinearGradient {
        if isZero {
            return LinearGradient(
                colors: [FitUpColors.Neon.blue.opacity(0.35), FitUpColors.Text.tertiary.opacity(0.45)],
                startPoint: .bottom,
                endPoint: .top
            )
        }
        return LinearGradient(
            colors: [
                FitUpColors.Neon.blue.opacity(0.86),
                FitUpColors.Neon.cyan.opacity(0.97),
                FitUpColors.Neon.green,
            ],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private var useCompactChartStyle: Bool {
        dailyMarginChartPoints.count > 21
    }

    private func startMarginChartAnimation() {
        chartAnimationTask?.cancel()

        if reduceMotion {
            netLineRevealProgress = 1
            dailyBarsProgress = 1
            return
        }

        switch marginMode {
        case .net:
            animateNetMarginLine()
        case .daily:
            animateDailyBars()
        }
    }

    private func animateNetMarginLine() {
        guard !cumulativeNetChartPoints.isEmpty else {
            netLineRevealProgress = 0
            return
        }

        netLineRevealProgress = 0
        dailyBarsProgress = 0

        chartAnimationTask = Task {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.7)) {
                    netLineRevealProgress = 1
                }
            }
        }
    }

    private func animateDailyBars() {
        netLineRevealProgress = 1
        dailyBarsProgress = 0

        chartAnimationTask = Task {
            let frameCount = 32
            let duration: Double = 0.78
            let frameDelay = duration / Double(frameCount)
            for frame in 0...frameCount {
                guard !Task.isCancelled else { return }
                let t = Double(frame) / Double(frameCount)
                await MainActor.run {
                    dailyBarsProgress = t
                }
                try? await Task.sleep(nanoseconds: UInt64(frameDelay * 1_000_000_000))
            }
            await MainActor.run {
                dailyBarsProgress = 1
            }
        }
    }

    private func progressForDailyBar(at index: Int) -> Double {
        if reduceMotion { return 1 }
        let count = max(1, animatedDailyMargins.count)
        let start = Double(index) / Double(count) * 0.3
        let remaining = max(0.001, 1 - start)
        let local = max(0, min(1, (dailyBarsProgress - start) / remaining))
        return max(0, easeOutBack(local))
    }

    private func easeOutBack(_ t: Double) -> Double {
        let s = 1.70158
        let c1 = s
        let c3 = c1 + 1
        let x = t - 1
        return 1 + c3 * pow(x, 3) + c1 * pow(x, 2)
    }

    private var chartAxisLabels: [String] {
        let labels = dailyMarginChartPoints.map(\.label)
        guard labels.count > 7 else { return labels }
        let strideSize = max(1, labels.count / 6)
        var sampled: [String] = stride(from: 0, to: labels.count, by: strideSize).map { labels[$0] }
        if sampled.last != labels.last {
            sampled.append(labels.last!)
        }
        return sampled
    }

    private func logStatsMarginSeriesDebug() {
#if DEBUG
        guard !rangeMargins.isEmpty else { return }
        var prior = 0
        for row in rangeMargins {
            let daily = row.margin
            AppLogger.log(
                category: "stats_chart",
                level: .debug,
                message: "[stats_margin_day] date=\(row.calendarDate) daily_margin=\(daily)"
            )
            let running = prior + daily
            AppLogger.log(
                category: "stats_chart",
                level: .debug,
                message: "[stats_net_running] date=\(row.calendarDate) prior_running_total=\(prior) daily_margin=\(daily) running_total=\(running)"
            )
            prior = running
        }
#endif
    }

    private func chartLabel(from ymd: String) -> String {
        guard let date = Self.chartInputFormatter.date(from: ymd) else { return ymd.uppercased() }
        return Self.chartOutputFormatter.string(from: date).uppercased()
    }

    private func signedFormatted(_ value: Int) -> String {
        if value == 0 { return "0" }
        let formatted = abs(value).formatted()
        return value > 0 ? "+\(formatted)" : "-\(formatted)"
    }

    private func shortWeekdayLabel(_ ymd: String) -> String {
        let utc = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        let formatter = DateFormatter()
        formatter.calendar = cal
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = utc
        guard let date = formatter.date(from: ymd) else { return String(ymd.suffix(2)) }
        let out = DateFormatter()
        out.locale = Locale(identifier: "en_US_POSIX")
        out.dateFormat = "EEE"
        out.timeZone = utc
        return out.string(from: date).uppercased()
    }

    private func normalizedDailyT(_ margin: Int) -> Double {
        let cap = Double(max(dailyChartMaxAbs, 400))
        return max(-1, min(1, Double(margin) / cap))
    }

    private func dailyBarGradient(for margin: Int) -> LinearGradient {
        let t = normalizedDailyT(margin)
        if t >= 0 {
            let c0 = FitUpColors.Neon.blue
            let c1 = t >= 0.35 ? FitUpColors.Neon.cyan : FitUpColors.Neon.blue
            let c2 = t >= 0.65 ? FitUpColors.Neon.green : c1
            return LinearGradient(
                colors: [c0.opacity(0.86), c1.opacity(0.97), c2],
                startPoint: .bottom,
                endPoint: .top
            )
        } else {
            let u = -t
            let c0 = FitUpColors.Neon.orange
            let c1 = u >= 0.35 ? FitUpColors.Neon.red : FitUpColors.Neon.orange
            let c2 = u >= 0.65 ? FitUpColors.Neon.red : c1
            return LinearGradient(
                colors: [c0.opacity(0.9), c1, c2.opacity(0.96)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func dailyBarGlow(for margin: Int) -> Color {
        let t = normalizedDailyT(margin)
        if t >= 0.5 { return FitUpColors.Neon.green.opacity(0.56) }
        if t >= 0.15 { return FitUpColors.Neon.cyan.opacity(0.52) }
        if t > -0.15 { return FitUpColors.Neon.purple.opacity(0.32) }
        if t > -0.5 { return FitUpColors.Neon.orange.opacity(0.56) }
        return FitUpColors.Neon.red.opacity(0.6)
    }

    private func dailyBarValueColor(for margin: Int) -> Color {
        let t = normalizedDailyT(margin)
        if t >= 0.65 { return FitUpColors.Neon.green }
        if t >= 0 { return FitUpColors.Neon.cyan }
        if t <= -0.65 { return FitUpColors.Neon.red }
        return FitUpColors.Neon.orange
    }

    private func dailyFreshnessText(now: Date) -> String? {
        if isDailyMarginsRefreshing {
            return "Updating..."
        }
        guard let dailyMarginsSavedAt else { return nil }
        let delta = max(0, Int(now.timeIntervalSince(dailyMarginsSavedAt)))
        if delta < 60 { return "Updated just now" }
        let minutes = delta / 60
        if minutes < 60 { return "Updated \(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "Updated \(hours)h ago" }
        return "Updated yesterday"
    }

    private var emptyMarginState: some View {
        HStack(spacing: 8) {
            Image(systemName: marginMode == .net ? "chart.line.uptrend.xyaxis" : "chart.bar")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.tertiary)
            Text(marginMode == .net ? "No cumulative net data for this range yet." : "No daily margins for this range yet.")
                .font(FitUpFont.body(11, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 208, alignment: .center)
    }

    private var previousPeriodLabel: String {
        guard let previousPeriodPercent else {
            return "Previous \(effectiveRange.fallbackDayCount) days: pending"
        }
        let arrow = previousPeriodPercent >= 0 ? "↑" : "↓"
        let magnitude = abs(previousPeriodPercent)
        return "\(arrow) \(magnitude)% vs previous \(effectiveRange.fallbackDayCount) days"
    }

    private var previousPeriodColor: Color {
        guard let previousPeriodPercent else { return FitUpColors.Text.tertiary }
        return previousPeriodPercent >= 0 ? FitUpColors.Neon.green : FitUpColors.Neon.orange
    }

    private var hasRivals: Bool {
        !rivals.isEmpty
    }

    private var rivals: [RivalRowData] {
        return rivalStats
            .map { rival in
                // Rival record is match-level series outcome, not day-level record.
                let record = rival.matchTies > 0
                    ? "\(rival.matchWins)–\(rival.matchLosses)–\(rival.matchTies)"
                    : "\(rival.matchWins)–\(rival.matchLosses)"
                return RivalRowData(
                    opponentId: rival.opponentProfileId,
                    name: rival.opponentDisplayName,
                    initials: rival.opponentInitials,
                    avatarColorHex: ProfileAccentColor.hex(for: rival.opponentProfileId),
                    finalizedDaysCompeted: rival.finalizedDaysCompeted,
                    record: record,
                    winPercent: rival.winPercentage,
                    avgFinalizedDailyMargin: rival.avgFinalizedDailyMargin,
                    lastPlayedOn: rival.lastPlayedOn,
                    activeMatchId: rival.activeMatchId
                )
            }
            .sorted {
                if $0.finalizedDaysCompeted != $1.finalizedDaysCompeted { return $0.finalizedDaysCompeted > $1.finalizedDaysCompeted }
                if $0.lastPlayedOn != $1.lastPlayedOn { return ($0.lastPlayedOn ?? .distantPast) > ($1.lastPlayedOn ?? .distantPast) }
                if $0.winPercent != $1.winPercent { return $0.winPercent > $1.winPercent }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .prefix(3)
            .enumerated()
            .map { idx, rival in
                var mutable = rival
                mutable.rank = idx + 1
                return mutable
            }
    }

    private var personalBests: [PersonalBestItem] {
        // TODO(slice4.4-backend): Add all-time personal bests once snapshot/all_time_bests semantics are finalized.
        let bestWeekSteps = weekSteps.max() ?? 0
        let hasWeekStepData = weekSteps.contains { $0 > 0 }
        let averageWeekSteps = hasWeekStepData ? Int((Double(weekSteps.reduce(0, +)) / Double(max(1, weekSteps.count))).rounded()) : 0
        let bestMargin = rangeMargins.map(\.margin).max() ?? 0
        let hasMarginData = !rangeMargins.isEmpty

        // TODO(slice4.4-backend): Selected-range rival stats can be added once backend rollups support range filters.
        // TODO(slice4.4-backend): Biggest comeback needs an explicit backend definition before display.
        return [
            PersonalBestItem(
                title: "WIN STREAK",
                value: (battleStats.currentStreakType == .win && battleStats.currentStreakCount > 0) ? "\(battleStats.currentStreakCount)" : "—",
                subtitle: "Current battle (lifetime)",
                iconName: "flame.fill",
                accentColor: FitUpColors.Neon.green
            ),
            PersonalBestItem(
                title: "BEST STEPS DAY",
                value: hasWeekStepData ? bestWeekSteps.formatted() : "—",
                subtitle: hasWeekStepData ? "Last 7D" : "Not enough data yet",
                iconName: "sparkles",
                accentColor: FitUpColors.Neon.purple
            ),
            PersonalBestItem(
                title: "AVG STEPS",
                value: hasWeekStepData ? averageWeekSteps.formatted() : "—",
                subtitle: hasWeekStepData ? "Last 7D" : "Not enough data yet",
                iconName: "waveform.path.ecg",
                accentColor: FitUpColors.Neon.cyan
            ),
            PersonalBestItem(
                title: "BEST DAILY NET MARGIN",
                value: hasMarginData ? signedFormatted(bestMargin) : "—",
                subtitle: hasMarginData ? "Selected range" : "Not enough data yet",
                iconName: "trophy.fill",
                accentColor: FitUpColors.Neon.orange
            ),
        ]
    }
}

private enum MarginMode: String, CaseIterable, Identifiable {
    case net
    case daily

    var id: String { rawValue }

    var label: String {
        switch self {
        case .net: return "Net"
        case .daily: return "Daily bars"
        }
    }

    var headerLabel: String {
        switch self {
        case .net: return "NET BATTLE MARGIN"
        case .daily: return "DAILY BATTLE MARGIN"
        }
    }

    var descriptionText: String {
        switch self {
        case .net:
            return "Running total of your daily battle margins across this range."
        case .daily:
            return "Each bar compares your full-day steps against the closest rival affecting your standing that day."
        }
    }

    func trailingHeadline(valueText: String) -> String {
        switch self {
        case .net: return valueText
        case .daily: return "PER DAY"
        }
    }
}

private extension StatsMockShellView {
    static let chartInputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let chartOutputFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    static let oneDayHourFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "h a"
        return formatter
    }()
}

private struct MarginPoint: Identifiable {
    let label: String
    let margin: Int
    var id: String { label }
}

private struct RivalRowData: Identifiable {
    var rank: Int = 1
    let opponentId: UUID
    let name: String
    let initials: String
    let avatarColorHex: String
    let finalizedDaysCompeted: Int
    let record: String
    let winPercent: Int
    let avgFinalizedDailyMargin: Double?
    let lastPlayedOn: Date?
    let activeMatchId: UUID?

    var id: UUID { opponentId }
    var winPercentText: String {
        return "\(winPercent)%"
    }
    var avgMarginText: String {
        guard let avgFinalizedDailyMargin else { return "—" }
        let rounded = Int(avgFinalizedDailyMargin.rounded())
        if rounded == 0 { return "0" }
        return rounded > 0 ? "+\(rounded.formatted())" : "-\(abs(rounded).formatted())"
    }
    var avgMarginColor: Color {
        guard let avgFinalizedDailyMargin else { return FitUpColors.Text.secondary }
        if avgFinalizedDailyMargin > 0 { return FitUpColors.Neon.green }
        if avgFinalizedDailyMargin < 0 { return FitUpColors.Neon.orange }
        return FitUpColors.Text.secondary
    }
    var rankColor: Color {
        switch rank {
        case 1: return FitUpColors.Neon.green
        case 2: return FitUpColors.Neon.purple
        default: return FitUpColors.Neon.orange
        }
    }

    var avatarColor: Color {
        ProfileAccentColor.swiftUIColor(hex: avatarColorHex)
    }
}

private struct PersonalBestItem: Identifiable {
    let title: String
    let value: String
    let subtitle: String
    let iconName: String
    let accentColor: Color
    var id: String { title }
}

#Preview {
    ScrollView {
        StatsMockShellView(
            selectedRange: .oneDay,
            effectiveRange: .oneDay,
            onSelectRange: { _ in },
            dateChipText: "May 7 – Jun 5",
            rangeScopeNote: nil,
            previousPeriodPercent: 12,
            battleStatsScopeLabel: "lifetime",
            rangeMargins: [],
            isRangeMarginsLoading: false,
            dailyMargins: [],
            dailyMarginDayCount: 7,
            dailyMarginsSavedAt: nil,
            isDailyMarginsRefreshing: false,
            onSelectDailyMarginDayCount: { _ in },
            battleStats: .empty,
            weekSteps: Array(repeating: 0, count: 7),
            activeMatchEdges: [],
            rivalStats: [],
            isRivalStatsLoading: false,
            hasLoadedRivalStats: true,
            oneDayHourlySteps: [],
            isOneDayHourlyLoading: false
        )
            .padding(.horizontal, 16)
    }
    .background { BackgroundGradientView() }
}
