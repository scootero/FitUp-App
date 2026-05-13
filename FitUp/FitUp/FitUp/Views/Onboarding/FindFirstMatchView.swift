//
//  FindFirstMatchView.swift
//  FitUp
//
//  Slice 2: final onboarding step and first search CTA.
//

import SwiftUI

struct FindFirstMatchView: View {
    let sevenDayAverageSteps: Double?
    let thirtyDayAverageSteps: Double?
    let ninetyDayAverageSteps: Double?
    let isLoadingAverage: Bool
    let isSubmitting: Bool
    let statusMessage: String?
    let errorMessage: String?
    @Binding var stepGoalTier: OnboardingViewModel.StepGoalTier
    @Binding var dailyStepGoalText: String
    var onSelectTier: (OnboardingViewModel.StepGoalTier) -> Void
    var onRetryAverage: () -> Void
    var onFindOpponent: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text("Start your first match")
                    .font(FitUpFont.display(26, weight: .black))
                    .foregroundStyle(FitUpColors.Text.primary)

                Text("We use your recent activity to match you with a fair first opponent.")
                    .font(FitUpFont.body(14, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Balanced Battle compares each player against their normal daily pace, so different step levels can compete fairly.")
                    Text("Your first match is Balanced, so you compete by Battle Score instead of raw steps.")
                }
                .font(FitUpFont.body(12, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)

                Text("Your recent average")
                    .font(FitUpFont.mono(10, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.tertiary)
                    .tracking(1)

                averagesBlock

                Text("Choose a daily step goal")
                    .font(FitUpFont.body(14, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.primary)
                    .padding(.top, 4)

                tierPicker

                TextField("Daily steps", text: $dailyStepGoalText)
                    .keyboardType(.numberPad)
                    .font(FitUpFont.display(18, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                            .fill(FitUpColors.Bg.base.opacity(0.55))
                            .overlay(
                                RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    )

                Text("You can change this later in Profile.")
                    .font(FitUpFont.body(12, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.tertiary)
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

            Button("Start My First Match") {
                onFindOpponent()
            }
            .solidButton(color: FitUpColors.Neon.cyan)
            .frame(maxWidth: .infinity)
            .disabled(isSubmitting || isLoadingAverage)
            .opacity((isSubmitting || isLoadingAverage) ? 0.65 : 1)
        }
    }

    private var averagesBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            averageLabeledRow(title: "7-day avg", value: sevenDayAverageSteps)
            averageLabeledRow(title: "30-day avg", value: thirtyDayAverageSteps)
            averageLabeledRow(title: "90-day avg", value: ninetyDayAverageSteps, showSeparator: false)

            if isLoadingAverage {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(FitUpColors.Neon.cyan)
                    Text("Loading your recent step averages…")
                        .font(FitUpFont.body(12, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }
                .padding(.top, 4)
            } else {
                HStack {
                    Spacer(minLength: 0)
                    Button("Refresh") {
                        onRetryAverage()
                    }
                    .buttonStyle(.plain)
                    .font(FitUpFont.body(12, weight: .semibold))
                    .foregroundStyle(FitUpColors.Neon.blue)
                }
                .padding(.top, 2)
            }
        }
    }

    private func averageLabeledRow(title: String, value: Double?, showSeparator: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(FitUpFont.body(13, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                Spacer(minLength: 0)
                Text(formattedAverageSteps(value))
                    .font(FitUpFont.body(14, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.primary)
            }
            .padding(.vertical, 6)
            if showSeparator {
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 1)
            }
        }
    }

    private func formattedAverageSteps(_ value: Double?) -> String {
        guard let value, value > 0 else { return "—" }
        return "\(Int(value.rounded()).formatted())"
    }

    private var tierPicker: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingViewModel.StepGoalTier.allCases) { tier in
                let selected = stepGoalTier == tier
                Button {
                    onSelectTier(tier)
                } label: {
                    Text(tier.label)
                        .font(FitUpFont.body(12, weight: .bold))
                        .foregroundStyle(selected ? FitUpColors.Neon.cyan : FitUpColors.Text.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                                .fill(selected ? FitUpColors.Neon.cyan.opacity(0.16) : Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                                        .strokeBorder(
                                            selected ? FitUpColors.Neon.cyan.opacity(0.45) : Color.white.opacity(0.08),
                                            lineWidth: 1
                                        )
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(isLoadingAverage)
                .opacity(isLoadingAverage ? 0.45 : 1)
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
}

#Preview {
    struct PreviewHolder: View {
        @State private var tier: OnboardingViewModel.StepGoalTier = .moderate
        @State private var goalText = "5750"

        var body: some View {
            ZStack {
                BackgroundGradientView()
                FindFirstMatchView(
                    sevenDayAverageSteps: 5000,
                    thirtyDayAverageSteps: 5000,
                    ninetyDayAverageSteps: 4800,
                    isLoadingAverage: false,
                    isSubmitting: false,
                    statusMessage: nil,
                    errorMessage: nil,
                    stepGoalTier: $tier,
                    dailyStepGoalText: $goalText,
                    onSelectTier: { t in
                        tier = t
                        switch t {
                        case .easy: goalText = "5250"
                        case .moderate: goalText = "5750"
                        case .aggressive: goalText = "6500"
                        }
                    },
                    onRetryAverage: {},
                    onFindOpponent: {}
                )
                .padding(.horizontal, 16)
            }
        }
    }
    return PreviewHolder()
}
