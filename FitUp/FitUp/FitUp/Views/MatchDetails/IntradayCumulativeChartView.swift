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

    @State private var selectedDate: Date?

    private var hasOpponentSeries: Bool { opponentPoints.count >= 2 }

    private var chartStart: Date {
        let dates = points.map(\.date) + opponentPoints.map(\.date)
        return dates.min() ?? Date()
    }

    private var chartEnd: Date {
        let dates = points.map(\.date) + opponentPoints.map(\.date)
        return dates.max() ?? Date()
    }

    private var yMax: Double {
        let myMax = points.map(\.cumulative).max() ?? 0
        let oppMax = opponentPoints.map(\.cumulative).max() ?? opponentTotal
        return Double(max(opponentTotal, myMax, oppMax, 1)) * 1.05
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY'S PACE")
                .font(FitUpFont.body(10, weight: .heavy))
                .tracking(2)
                .foregroundStyle(FitUpColors.Text.secondary)

            HStack(spacing: 16) {
                legendSwatch(color: FitUpColors.Neon.cyan, label: "You", dashed: false)
                legendSwatch(
                    color: opponentColor,
                    label: opponentName,
                    dashed: !hasOpponentSeries
                )
            }

            ZStack(alignment: .topLeading) {
                Chart {
                    if !hasOpponentSeries, chartEnd > chartStart, opponentTotal >= 0 {
                        RuleMark(y: .value("Them", opponentTotal))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                            .foregroundStyle(opponentColor.opacity(0.9))
                    }

                    if hasOpponentSeries {
                        ForEach(Array(opponentPoints.enumerated()), id: \.offset) { _, pt in
                            LineMark(
                                x: .value("Time", pt.date),
                                y: .value("Them", pt.cumulative)
                            )
                            .interpolationMethod(.linear)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round, dash: [6, 4]))
                            .foregroundStyle(opponentColor.opacity(0.95))
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
                }
                .chartXScale(domain: chartStart...max(chartEnd, chartStart.addingTimeInterval(60)))
                .chartYScale(domain: 0...yMax)
                .chartXSelection(value: $selectedDate)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.1))
                        if let d = value.as(Date.self) {
                            AxisValueLabel {
                                Text(shortTime(d))
                                    .font(FitUpFont.mono(9, weight: .medium))
                                    .foregroundStyle(FitUpColors.Text.secondary)
                            }
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(Color.white.opacity(0.08))
                        let n = value.as(Double.self).map { Int($0.rounded()) } ?? 0
                        AxisValueLabel {
                            Text(formatY(n))
                                .font(FitUpFont.mono(9, weight: .medium))
                                .foregroundStyle(FitUpColors.Text.secondary)
                        }
                    }
                }
                .chartBackground { _ in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.07), Color.white.opacity(0.02)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .frame(height: 180)

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
                                        .fill(Color.black.opacity(0.55))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .strokeBorder(FitUpColors.Neon.cyan.opacity(0.35), lineWidth: 1)
                                        )
                                )
                        }
                        Spacer()
                    }
                    .padding(8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
        }
        .matchDetailsSecondaryCard(
            leadingAccent: FitUpColors.Neon.cyan,
            trailingAccent: opponentColor
        )
    }

    private func legendSwatch(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 6) {
            Group {
                if dashed {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .strokeBorder(color, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        .frame(width: 14, height: 0)
                        .frame(height: 10)
                } else {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(color)
                        .frame(width: 14, height: 3)
                }
            }
            Text(label)
                .font(FitUpFont.body(11, weight: .semibold))
                .foregroundStyle(FitUpColors.Text.secondary)
                .lineLimit(1)
        }
    }

    private var calloutText: String? {
        guard !points.isEmpty, let s = selectedDate else { return nil }
        let closest = points.min(by: { abs($0.date.timeIntervalSince(s)) < abs($1.date.timeIntervalSince(s)) })
        guard let p = closest else { return nil }
        return "\(formatValue(p.cumulative)) · \(timeLabel(p.date))"
    }

    private var accessibilitySummary: String {
        if points.isEmpty { return "No intraday data" }
        let last = points.last!.cumulative
        let unit = isCalories ? "kilocalories" : "steps"
        let opponentNote = hasOpponentSeries
            ? " Opponent pace is plotted from synced samples."
            : " Opponent total shown as a flat line at \(opponentTotal) \(unit)."
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
