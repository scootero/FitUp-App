//
//  ConsistencyCard.swift
//  FitUp
//
//  Steps-goal consistency summary.
//

import SwiftUI

struct ConsistencyCard: View {
    let consistency: HealthGoalConsistency

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CONSISTENCY")
                .font(FitUpFont.body(10, weight: .heavy))
                .tracking(2)
                .foregroundStyle(FitUpColors.Text.tertiary)
                .padding(.bottom, 10)

            Text(consistency.summaryLabel)
                .font(FitUpFont.body(12))
                .foregroundStyle(FitUpColors.Text.secondary)
                .padding(.bottom, 12)

            HStack(spacing: 8) {
                ForEach(Array(consistency.dayStates.enumerated()), id: \.offset) { _, hit in
                    Circle()
                        .fill(hit ? FitUpColors.Neon.green : Color.white.opacity(0.14))
                        .frame(width: 10, height: 10)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white.opacity(hit ? 0.0 : 0.24), lineWidth: 1)
                        }
                }
            }
            .padding(.bottom, 12)

            HStack {
                Text("Current streak")
                    .font(FitUpFont.body(11))
                    .foregroundStyle(FitUpColors.Text.secondary)
                Spacer()
                Text(consistency.streakLabel)
                    .font(FitUpFont.body(11, weight: .bold))
                    .foregroundStyle(FitUpColors.Neon.green)
            }
        }
        .padding(18)
        .glassCard(.base)
    }
}

#Preview {
    ConsistencyCard(consistency: HealthGoalConsistency(goalHitCount: 4, dayStates: [true, false, true, true, false, true, true], currentStreakDays: 2))
        .padding()
        .background { BackgroundGradientView() }
}
