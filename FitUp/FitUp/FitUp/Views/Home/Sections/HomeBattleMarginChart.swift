//
//  HomeBattleMarginChart.swift
//  FitUp
//
//  Signed daily bars: net margin (you − opponent) summed across matches per calendar day.
//

import Charts
import SwiftUI

struct HomeBattleMarginChart: View {
    let points: [DailyBattleMargin]
    let unitLabel: String
    let dayCount: Int
    var onDayCountSelected: (Int) -> Void

    private let barWidth: CGFloat = 17
    private let chartHeight: CGFloat = 168

    private var maxAbsMargin: CGFloat {
        let m = points.map { abs($0.margin) }.max() ?? 0
        return CGFloat(max(m, 1))
    }

    private var highlightedDayKey: String? {
        points.last?.calendarDate
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("BATTLE MARGIN")
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

            Text("Net \(unitLabel) vs rivals · ahead up, behind down")
                .font(FitUpFont.body(11, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [FitUpColors.Text.secondary, FitUpColors.Neon.blue.opacity(0.82)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

            if points.isEmpty {
                Text("Margin history will show here once battle data syncs. Pull down to refresh.")
                    .font(FitUpFont.body(12, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            } else {
                Chart {
                    ForEach(points) { point in
                        if point.calendarDate == highlightedDayKey {
                            BarMark(
                                x: .value("Day", point.calendarDate),
                                y: .value("Margin Highlight", point.margin),
                                width: .fixed(barWidth + 6)
                            )
                            .foregroundStyle(
                                point.margin >= 0
                                    ? FitUpColors.Neon.cyan.opacity(0.22)
                                    : FitUpColors.Neon.orange.opacity(0.24)
                            )
                            .cornerRadius(5)
                            .shadow(color: barGlow(for: point.margin).opacity(0.62), radius: 10, x: 0, y: 0)
                        }

                        BarMark(
                            x: .value("Day", point.calendarDate),
                            y: .value("Margin", point.margin),
                            width: .fixed(barWidth)
                        )
                        .foregroundStyle(barGradient(for: point.margin))
                        .cornerRadius(4)
                        .shadow(color: barGlow(for: point.margin), radius: 6, x: 0, y: 0)
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
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let n = value.as(Int.self) {
                                Text("\(n)")
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
                .chartYScale(domain: -maxAbsMargin...maxAbsMargin)
                .frame(height: chartHeight)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .homeLiquidGlassCard(.base)
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
