//
//  CalendarStepsDayDetailPanel.swift
//  FitUp
//
//  Steps day breakdown with home-style sparkline.
//

import SwiftUI

struct CalendarStepsDayDetailPanel: View {
    let detail: CalendarDayStepsDetail

    private var goalMet: Bool {
        detail.stepsGoal > 0 && detail.steps >= detail.stepsGoal
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(detail.displayTitle)
                    .font(FitUpFont.display(18, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.primary)
                Text(goalMet ? "Goal crushed." : "Steps toward your daily target.")
                    .font(FitUpFont.body(12))
                    .foregroundStyle(FitUpColors.Text.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(detail.steps)")
                    .font(FitUpFont.display(32, weight: .bold))
                    .foregroundStyle(goalMet ? FitUpColors.Neon.green : FitUpColors.Neon.cyan)
                Text("/ \(detail.stepsGoal)")
                    .font(FitUpFont.mono(12, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.tertiary)
                Spacer()
                Text(goalMet ? "GOAL" : "\(Int((Double(detail.steps) / Double(max(detail.stepsGoal, 1)) * 100).rounded()))%")
                    .font(FitUpFont.mono(10, weight: .bold))
                    .foregroundStyle(goalMet ? FitUpColors.Neon.green : FitUpColors.Neon.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((goalMet ? FitUpColors.Neon.green : FitUpColors.Neon.cyan).opacity(0.14))
                    .clipShape(Capsule())
            }

            CalendarDaySparklineChart(
                values: detail.sparklineValues,
                accent: goalMet ? FitUpColors.Neon.green : FitUpColors.Neon.cyan
            )
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    }
            )

            HStack {
                Text("12 AM")
                Spacer()
                Text("NOON")
                Spacer()
                Text("DAY END")
            }
            .font(FitUpFont.mono(9, weight: .semibold))
            .foregroundStyle(FitUpColors.Text.tertiary)
            .tracking(1.2)
        }
    }
}
