//
//  IntradayCumulativeChartView.swift
//  FitUp
//
//  Cumulative today chart for Match Details (viewer from HealthKit; opponent = daily total line — no intraday server samples yet).
//

import Charts
import SwiftUI

struct IntradayCumulativeChartView: View {
    let points: [HealthIntradayCumulativePoint]
    /// Opponent’s synced total for today (flat line = MVP until partial sync exists server-side).
    let opponentTotal: Int
    let isCalories: Bool
    let opponentColor: Color

    @State private var selectedDate: Date?

    private var chartStart: Date {
        points.first?.date ?? Date()
    }

    private var chartEnd: Date {
        points.last?.date ?? Date()
    }

    private var yMax: Double {
        let myMax = points.map(\.cumulative).max() ?? 0
        return Double(max(opponentTotal, myMax, 1)) * 1.05
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TODAY'S PACE")
                .font(FitUpFont.body(10, weight: .heavy))
                .tracking(2)
                .foregroundStyle(FitUpColors.Text.tertiary)

            ZStack(alignment: .topLeading) {
                Chart {
                    if chartEnd > chartStart, opponentTotal >= 0 {
                        // Opponent: flat line at their day total (no per-sample sync yet).
                        RuleMark(
                            y: .value("Them", opponentTotal)
                        )
                        .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                        .foregroundStyle(opponentColor.opacity(0.9))
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
                .chartXSelection(value: $selectedDate)
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
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilitySummary)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
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
        return "Your cumulative total so far, \(formatValue(last)) \(unit), chart from midnight to now."
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
