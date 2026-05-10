//
//  HomeBattleMarginChart.swift
//  FitUp
//
//  Signed daily bars: per-calendar-day margin from `home_daily_battle_margins` (you − closest relevant rival).
//

import Charts
import SwiftUI

struct HomeBattleMarginChart: View {
    var title: String = "BATTLE MARGIN"
    var subtitle: String? = nil
    let points: [DailyBattleMargin]
    let unitLabel: String
    let dayCount: Int
    var freshnessSavedAt: Date? = nil
    var isRefreshing: Bool = false
    var onDayCountSelected: (Int) -> Void

    private let chartHeight: CGFloat = 168

    private var maxAbsMargin: CGFloat {
        let m = points.map { abs($0.margin) }.max() ?? 0
        return CGFloat(max(m, 1))
    }

    private var marginStubHeight: Int {
        guard !points.isEmpty else { return 1 }
        let vals = points.map(\.margin)
        guard let mn = vals.min(), let mx = vals.max() else { return 1 }
        let span = max(mx - mn, 400)
        return max(1, span / 45)
    }

    private var battleMarginYDomain: ClosedRange<Int> {
        guard !points.isEmpty else { return -400...400 }
        let vals = points.map(\.margin)
        guard let mn = vals.min(), let mx = vals.max() else { return -400...400 }
        let hasZeroDay = vals.contains(0)
        let effectiveMax = hasZeroDay ? max(mx, marginStubHeight) : mx
        return SignedChartYDomain.domain(dataMin: mn, dataMax: effectiveMax)
    }

    private func adaptiveBarWidth(plotWidth: CGFloat, highlighted: Bool) -> CGFloat {
        let n = max(points.count, 1)
        let slot = plotWidth / CGFloat(n)
        let gap: CGFloat = 5
        let minW: CGFloat = 6
        let maxW: CGFloat = 21
        let base = min(max(slot - gap, minW), maxW)
        let boosted = base + (highlighted ? 4 : 0)
        return min(max(boosted, minW), max(slot - 2, minW))
    }

    private func displayedMargin(_ margin: Int) -> Int {
        margin == 0 ? marginStubHeight : margin
    }

    private func barFill(for margin: Int) -> LinearGradient {
        if margin == 0 {
            return LinearGradient(
                colors: [FitUpColors.Neon.blue.opacity(0.92), FitUpColors.Neon.cyan.opacity(0.55)],
                startPoint: .bottom,
                endPoint: .top
            )
        }
        return barGradient(for: margin)
    }

    private func barGlowDisplay(for margin: Int) -> Color {
        margin == 0 ? FitUpColors.Neon.blue.opacity(0.5) : barGlow(for: margin)
    }

    private var highlightedDayKey: String? {
        points.last?.calendarDate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title)
                    .font(FitUpFont.mono(11, weight: .bold))
                    .fitUpGlobalTitleStyle(weight: .bold, tracking: 0.9)
                    .shadow(color: FitUpColors.Neon.blue.opacity(0.32), radius: 7)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.04))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.5)
                            )
                    )

                Spacer(minLength: 0)

                HStack(spacing: 0) {
                    rangeButton(title: "7D", value: 7)
                    rangeButton(title: "10D", value: 10)
                }
                .padding(3)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
            }

            Text(subtitle ?? "Net \(unitLabel) vs your closest rival each day · ahead up, behind down")
                .font(FitUpFont.body(11, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FitUpColors.Text.secondary, FitUpColors.Neon.blue.opacity(0.82)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            TimelineView(.periodic(from: .now, by: 60)) { context in
                if let freshnessText = freshnessText(now: context.date) {
                    Text(freshnessText)
                        .font(FitUpFont.body(11, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }
            }

            if points.isEmpty {
                Text("Margin history will show here once battle data syncs. Pull down to refresh.")
                    .font(FitUpFont.body(12, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            } else {
                GeometryReader { geo in
                    let plotW = geo.size.width
                    Chart {
                        ForEach(points) { point in
                            let isHighlightedDay = point.calendarDate == highlightedDayKey
                            let barW = adaptiveBarWidth(plotWidth: plotW, highlighted: isHighlightedDay)
                            let yVal = displayedMargin(point.margin)

                            BarMark(
                                x: .value("Day", point.calendarDate),
                                y: .value("Margin", yVal),
                                width: .fixed(barW)
                            )
                            .foregroundStyle(barFill(for: point.margin))
                            .cornerRadius(isHighlightedDay ? 5 : 4)
                            .shadow(
                                color: barGlowDisplay(for: point.margin).opacity(isHighlightedDay ? 1.0 : 0.85),
                                radius: isHighlightedDay ? 11 : 6,
                                x: 0,
                                y: 0
                            )
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
                                            key == highlightedDayKey
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
                                        .shadow(
                                            color: key == highlightedDayKey ? FitUpColors.Neon.blue.opacity(0.35) : .clear,
                                            radius: key == highlightedDayKey ? 5 : 0
                                        )
                                }
                            }
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading, values: SignedChartYDomain.axisTickValues(for: battleMarginYDomain)) { value in
                            AxisValueLabel {
                                if let n = value.as(Int.self) {
                                    Text(homeMarginAxisLabel(n))
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
                    .chartYScale(domain: battleMarginYDomain)
                }
                .frame(height: chartHeight)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .glassCard(.base)
    }

    private func rangeButton(title: String, value: Int) -> some View {
        Button {
            onDayCountSelected(value)
        } label: {
            Text(title)
                .font(FitUpFont.body(11, weight: .bold))
                .foregroundStyle(dayCount == value ? Color.black : FitUpColors.Text.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background {
                    if dayCount == value {
                        Capsule()
                            .fill(FitUpColors.Neon.cyan)
                            .shadow(color: FitUpColors.Neon.cyan.opacity(0.35), radius: 8)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func homeMarginAxisLabel(_ value: Int) -> String {
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

    /// Maps signed margin to neon fill: far behind → red … near even → purple … far ahead → green.
    private func normalizedT(_ margin: Int) -> Double {
        let cap = Double(max(maxAbsMargin, 400))
        return max(-1, min(1, Double(margin) / cap))
    }

    private func barGradient(for margin: Int) -> LinearGradient {
        let t = normalizedT(margin)
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

    private func barGlow(for margin: Int) -> Color {
        let t = normalizedT(margin)
        if t >= 0.5 { return FitUpColors.Neon.green.opacity(0.56) }
        if t >= 0.15 { return FitUpColors.Neon.cyan.opacity(0.52) }
        if t > -0.15 { return FitUpColors.Neon.purple.opacity(0.32) }
        if t > -0.5 { return FitUpColors.Neon.orange.opacity(0.56) }
        return FitUpColors.Neon.red.opacity(0.6)
    }

    private func freshnessText(now: Date) -> String? {
        if isRefreshing {
            return "Updating..."
        }
        guard let freshnessSavedAt else { return nil }
        let delta = max(0, Int(now.timeIntervalSince(freshnessSavedAt)))
        if delta < 60 { return "Updated just now" }
        let minutes = delta / 60
        if minutes < 60 { return "Updated \(minutes)m ago" }
        let hours = minutes / 60
        if hours < 24 { return "Updated \(hours)h ago" }
        return "Updated yesterday"
    }
}

#Preview {
    HomeBattleMarginChart(
        points: [
            DailyBattleMargin(calendarDate: "2026-04-22", margin: -820),
            DailyBattleMargin(calendarDate: "2026-04-23", margin: -120),
            DailyBattleMargin(calendarDate: "2026-04-24", margin: 40),
            DailyBattleMargin(calendarDate: "2026-04-25", margin: 2100),
            DailyBattleMargin(calendarDate: "2026-04-26", margin: 0),
            DailyBattleMargin(calendarDate: "2026-04-27", margin: 340),
            DailyBattleMargin(calendarDate: "2026-04-28", margin: -45),
        ],
        unitLabel: "steps",
        dayCount: 7,
        onDayCountSelected: { _ in }
    )
    .padding()
    .background { BackgroundGradientView() }
}
