//
//  SportStepView.swift
//  FitUp
//
//  Slice 4 step 0: choose challenge sport.
//

import SwiftUI

struct SportStepView: View {
    var onSelect: (ChallengeMetricType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What are you competing in?")
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)

            VStack(spacing: 10) {
                sportCard(
                    metric: .steps,
                    icon: "figure.walk",
                    description: "Daily step count battle",
                    color: FitUpColors.Neon.cyan
                )
                sportCard(
                    metric: .activeCalories,
                    icon: "flame.fill",
                    description: "Active calorie burn-off",
                    color: FitUpColors.Neon.orange
                )
            }
        }
    }

    private func sportCard(
        metric: ChallengeMetricType,
        icon: String,
        description: String,
        color: Color
    ) -> some View {
        Button {
            onSelect(metric)
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 46, height: 46)
                    .overlay {
                        RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                            .strokeBorder(color.opacity(0.30), lineWidth: 1)
                    }
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(color)
                    }

                VStack(alignment: .leading, spacing: 3) {
                    Text(metric.displayName)
                        .font(FitUpFont.display(16, weight: .bold))
                        .foregroundStyle(FitUpColors.Text.primary)
                    Text(description)
                        .font(FitUpFont.body(12, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
            .glassCard(.base)
            .overlay {
                RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                    .strokeBorder(color.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

