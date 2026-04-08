//
//  ComponentBreakdownCard.swift
//  FitUp
//
//  Slice 12 — Component breakdown (`glassCard(.base)`).
//

import SwiftUI

struct ComponentBreakdownCard: View {
    let goals: ReadinessGoals
    let sleepHours: Double?
    let restingHR: Double?
    let stepsToday: Int
    let calsToday: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("COMPONENT BREAKDOWN")
                .font(FitUpFont.body(10, weight: .heavy))
                .tracking(2)
                .foregroundStyle(FitUpColors.Text.tertiary)
                .padding(.bottom, 16)

            Text("How the readiness score is built for competition context.")
                .font(FitUpFont.body(12))
                .foregroundStyle(FitUpColors.Text.secondary)
                .lineSpacing(6)
                .padding(.bottom, 16)

            VStack(spacing: 14) {
                breakdownRow(
                    label: "Sleep",
                    metricText: sleepMetricText,
                    percent: pctSleep,
                    color: FitUpColors.Neon.blue
                )
                breakdownRow(
                    label: "Resting HR",
                    metricText: hrMetricText,
                    percent: pctHR,
                    color: FitUpColors.Neon.cyan
                )
                breakdownRow(
                    label: "Steps",
                    metricText: stepsMetricText,
                    percent: pctSteps,
                    color: FitUpColors.Neon.orange
                )
                breakdownRow(
                    label: "Calories",
                    metricText: calsMetricText,
                    percent: pctCals,
                    color: FitUpColors.Neon.pink
                )
            }
        }
        .padding(18)
        .glassCard(.base)
    }

    private var sleepMetricText: String {
        let h = sleepHours ?? 0
        return String(format: "%.1f / %.1f hrs", h, goals.sleepGoalHours)
    }

    private var hrMetricText: String {
        guard let hr = restingHR else { return "— / \(Int(goals.restingHRTargetBpm)) bpm" }
        return "\(Int(hr.rounded())) / \(Int(goals.restingHRTargetBpm)) bpm"
    }

    private var stepsMetricText: String {
        "\(stepsToday.formatted()) / \(goals.stepsGoal.formatted()) steps"
    }

    private var calsMetricText: String {
        "\(calsToday) / \(goals.calsGoal) kcal"
    }

    private var pctSleep: Double {
        guard goals.sleepGoalHours > 0 else { return 0 }
        let h = sleepHours ?? 0
        return min((h / goals.sleepGoalHours) * 100, 100)
    }

    private var pctHR: Double {
        guard let hr = restingHR, goals.restingHRTargetBpm > 0 else { return 0 }
        return min((hr / goals.restingHRTargetBpm) * 100, 100)
    }

    private var pctSteps: Double {
        guard goals.stepsGoal > 0 else { return 0 }
        return min((Double(stepsToday) / Double(goals.stepsGoal)) * 100, 100)
    }

    private var pctCals: Double {
        guard goals.calsGoal > 0 else { return 0 }
        return min((Double(calsToday) / Double(goals.calsGoal)) * 100, 100)
    }

    private func breakdownRow(
        label: String,
        metricText: String,
        percent: Double,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                Text(label)
                    .font(FitUpFont.body(13, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.primary)
                Spacer(minLength: 8)
                HStack(spacing: 12) {
                    Text(metricText)
                        .font(FitUpFont.mono(11))
                        .foregroundStyle(FitUpColors.Text.secondary)
                    Text("\(Int(percent.rounded()))%")
                        .font(FitUpFont.body(11, weight: .bold))
                        .foregroundStyle(color)
                        .frame(minWidth: 35, alignment: .trailing)
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * CGFloat(percent / 100)))
                }
            }
            .frame(height: 5)
        }
    }
}

#Preview {
    ComponentBreakdownCard(
        goals: .default,
        sleepHours: 7.8,
        restingHR: 58,
        stepsToday: 5000,
        calsToday: 320
    )
    .padding()
    .background { BackgroundGradientView() }
}
