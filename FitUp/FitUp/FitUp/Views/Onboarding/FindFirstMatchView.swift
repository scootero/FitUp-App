//
//  FindFirstMatchView.swift
//  FitUp
//
//  Slice 2: final onboarding step and first search CTA.
//

import SwiftUI

struct FindFirstMatchView: View {
    let sevenDayAverageSteps: Double?
    let isLoadingAverage: Bool
    let isSubmitting: Bool
    let statusMessage: String?
    let errorMessage: String?
    var onRetryAverage: () -> Void
    var onFindOpponent: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Find Your First Match")
                    .font(FitUpFont.display(26, weight: .black))
                    .foregroundStyle(FitUpColors.Text.primary)

                Text("We use your real 7-day step average to find a fair first opponent.")
                    .font(FitUpFont.body(14, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)

                averageRow
            }
            .padding(20)
            .glassCard(.win)

            lockedConfig

            if let statusMessage, !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(FitUpFont.body(13, weight: .semibold))
                    .foregroundStyle(FitUpColors.Neon.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(FitUpFont.body(13, weight: .medium))
                    .foregroundStyle(FitUpColors.Neon.pink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Button("Find Opponent") {
                onFindOpponent()
            }
            .solidButton(color: FitUpColors.Neon.cyan)
            .frame(maxWidth: .infinity)
            .disabled(isSubmitting || isLoadingAverage)
            .opacity((isSubmitting || isLoadingAverage) ? 0.65 : 1)
        }
    }

    private var averageRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.walk")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(FitUpColors.Neon.cyan)
            if isLoadingAverage {
                ProgressView()
                    .tint(FitUpColors.Neon.cyan)
                Text("Reading your 7-day average...")
                    .font(FitUpFont.body(13, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
            } else {
                Text(stepAverageText)
                    .font(FitUpFont.display(20, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.primary)
                Spacer(minLength: 0)
                Button("Refresh") {
                    onRetryAverage()
                }
                .buttonStyle(.plain)
                .font(FitUpFont.body(12, weight: .semibold))
                .foregroundStyle(FitUpColors.Neon.blue)
            }
        }
    }

    private var lockedConfig: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MATCH SETTINGS")
                .font(FitUpFont.mono(10, weight: .bold))
                .foregroundStyle(FitUpColors.Text.tertiary)
                .tracking(1)
            HStack(spacing: 8) {
                configPill("Steps")
                configPill("1 day")
                configPill("Start today")
            }
        }
        .padding(16)
        .glassCard(.base)
    }

    private func configPill(_ value: String) -> some View {
        Text(value)
            .font(FitUpFont.body(12, weight: .bold))
            .foregroundStyle(FitUpColors.Neon.cyan)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(FitUpColors.Neon.cyan.opacity(0.14))
                    .overlay(
                        Capsule()
                            .strokeBorder(FitUpColors.Neon.cyan.opacity(0.3), lineWidth: 1)
                    )
            )
    }

    private var stepAverageText: String {
        guard let sevenDayAverageSteps else { return "-- steps/day" }
        return "\(Int(sevenDayAverageSteps.rounded()).formatted()) steps/day"
    }
}

#Preview {
    ZStack {
        BackgroundGradientView()
        FindFirstMatchView(
            sevenDayAverageSteps: 9480,
            isLoadingAverage: false,
            isSubmitting: false,
            statusMessage: nil,
            errorMessage: nil,
            onRetryAverage: {},
            onFindOpponent: {}
        )
        .padding(.horizontal, 16)
    }
}
