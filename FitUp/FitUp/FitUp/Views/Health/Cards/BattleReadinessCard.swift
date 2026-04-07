//
//  BattleReadinessCard.swift
//  FitUp
//
//  Slice 12 — `HealthScreen` battle readiness hero (`glassCard(.win)`).
//

import SwiftUI

struct BattleReadinessCard: View {
    let score: Int
    let title: String
    let subtitle: String
    let sleepText: String
    let hrText: String
    let stepsText: String
    let calsText: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("TODAY'S BATTLE READINESS")
                .font(FitUpFont.body(10, weight: .heavy))
                .tracking(2)
                .foregroundStyle(FitUpColors.Text.tertiary)
                .padding(.bottom, 14)

            HStack(alignment: .center, spacing: 16) {
                RingGaugeView(score: score, size: 90)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(FitUpFont.display(22, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.primary)
                    Text(subtitle)
                        .font(FitUpFont.body(13))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .lineSpacing(4)
                }
            }
            .padding(.bottom, 16)

            HStack(spacing: 8) {
                quickChip(icon: "🌙", value: sleepText, label: "Sleep")
                quickChip(icon: "❤️", value: hrText, label: "Resting HR")
                quickChip(icon: "👟", value: stepsText, label: "Steps")
                quickChip(icon: "🔥", value: calsText, label: "Active Cal")
            }
        }
        .padding(20)
        .glassCard(.win)
    }

    private func quickChip(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.system(size: 16))
            Text(value)
                .font(FitUpFont.mono(13, weight: .bold))
                .foregroundStyle(FitUpColors.Text.primary)
                .minimumScaleFactor(0.8)
                .lineLimit(1)
            Text(label)
                .font(FitUpFont.body(9))
                .foregroundStyle(FitUpColors.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .glassCard(.base)
    }
}

#Preview {
    BattleReadinessCard(
        score: 73,
        title: "Strong Readiness",
        subtitle: "You're well-primed for battle today.",
        sleepText: "7.6h",
        hrText: "58",
        stepsText: "11.2k",
        calsText: "520"
    )
    .padding()
    .background { BackgroundGradientView() }
}
