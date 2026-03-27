//
//  DayBarChartView.swift
//  FitUp
//
//  Slice 5 day-by-day chart for Match Details.
//

import Charts
import SwiftUI

struct DayBarChartView: View {
    let dayRows: [MatchDetailsDayRow]
    let opponentName: String
    let opponentColor: Color

    private let barWidth: CGFloat = 9
    private let chartHeight: CGFloat = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DAY-BY-DAY BREAKDOWN")
                .font(FitUpFont.mono(11, weight: .bold))
                .foregroundStyle(FitUpColors.Text.secondary)
                .tracking(0.9)

            Chart {
                ForEach(dayRows) { day in
                    BarMark(
                        x: .value("Day", day.dayLabel),
                        y: .value("Total", day.myValue),
                        width: .fixed(barWidth)
                    )
                    .position(by: .value("Player", "You"))
                    .foregroundStyle(FitUpColors.Neon.cyan.opacity(0.85))
                    .cornerRadius(3)

                    BarMark(
                        x: .value("Day", day.dayLabel),
                        y: .value("Total", day.theirValue),
                        width: .fixed(barWidth)
                    )
                    .position(by: .value("Player", opponentName))
                    .foregroundStyle(opponentColor.opacity(0.85))
                    .cornerRadius(3)
                }
            }
            .frame(height: chartHeight)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            Text(label)
                                .font(FitUpFont.mono(10, weight: .medium))
                                .foregroundStyle(FitUpColors.Text.tertiary)
                        }
                    }
                }
            }

            HStack(spacing: 16) {
                legendItem(label: "You", color: FitUpColors.Neon.cyan)
                legendItem(label: opponentName, color: opponentColor)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 16)
        .glassCard(.base)
    }

    private func legendItem(label: String, color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(FitUpFont.body(10, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
        }
    }
}
