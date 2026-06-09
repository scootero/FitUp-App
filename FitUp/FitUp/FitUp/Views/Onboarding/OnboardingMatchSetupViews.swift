//
//  OnboardingMatchSetupViews.swift
//  FitUp
//
//  Step goal setup and start-first-match onboarding screens.
//

import SwiftUI

// MARK: - Shared components

enum OnboardingMatchSetupComponents {
    static func averagesBlock(
        sevenDayAverageSteps: Double?,
        thirtyDayAverageSteps: Double?,
        ninetyDayAverageSteps: Double?,
        isLoadingAverage: Bool,
        onRetryAverage: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
                .padding(.top, 2)
            } else {
                HStack {
                    Spacer(minLength: 0)
                    Button("Refresh", action: onRetryAverage)
                        .buttonStyle(.plain)
                        .font(FitUpFont.body(12, weight: .semibold))
                        .foregroundStyle(FitUpColors.Neon.blue)
                }
            }
        }
    }

    static func tierPicker(
        stepGoalTier: OnboardingViewModel.StepGoalTier,
        isLoadingAverage: Bool,
        onSelectTier: @escaping (OnboardingViewModel.StepGoalTier) -> Void,
        dismissKeyboard: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 8) {
            ForEach(OnboardingViewModel.StepGoalTier.allCases) { tier in
                let selected = stepGoalTier == tier
                Button {
                    dismissKeyboard()
                    onSelectTier(tier)
                } label: {
                    Text(tier.label)
                        .font(FitUpFont.body(12, weight: .bold))
                        .foregroundStyle(selected ? FitUpColors.Neon.cyan : FitUpColors.Text.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
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

    static func matchSettingsPills() -> some View {
        VStack(alignment: .leading, spacing: 8) {
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
    }

    private static func averageLabeledRow(title: String, value: Double?, showSeparator: Bool = true) -> some View {
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
            .padding(.vertical, 5)
            if showSeparator {
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 1)
            }
        }
    }

    private static func formattedAverageSteps(_ value: Double?) -> String {
        guard let value, value > 0 else { return "—" }
        return "\(Int(value.rounded()).formatted())"
    }

    private static func configPill(_ value: String) -> some View {
        Text(value)
            .font(FitUpFont.body(11, weight: .bold))
            .foregroundStyle(FitUpColors.Neon.cyan)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                    .fill(FitUpColors.Neon.cyan.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: FitUpRadius.sm, style: .continuous)
                            .strokeBorder(FitUpColors.Neon.cyan.opacity(0.3), lineWidth: 1)
                    )
            )
    }
}

// MARK: - Step goal setup

struct OnboardingStepGoalView: View {
    let sevenDayAverageSteps: Double?
    let thirtyDayAverageSteps: Double?
    let ninetyDayAverageSteps: Double?
    let isLoadingAverage: Bool
    let errorMessage: String?
    @Binding var stepGoalTier: OnboardingViewModel.StepGoalTier
    @Binding var dailyStepGoalText: String
    var onSelectTier: (OnboardingViewModel.StepGoalTier) -> Void
    var onRetryAverage: () -> Void
    var onNext: () -> Void

    @FocusState private var stepGoalFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Set your step goal")
                    .font(FitUpFont.display(24, weight: .black))
                    .foregroundStyle(FitUpColors.Text.primary)

                Text("We use your recent activity to suggest a daily target.")
                    .font(FitUpFont.body(13, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Your recent average")
                    .font(FitUpFont.mono(10, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.tertiary)
                    .tracking(1)
                    .padding(.top, 2)

                OnboardingMatchSetupComponents.averagesBlock(
                    sevenDayAverageSteps: sevenDayAverageSteps,
                    thirtyDayAverageSteps: thirtyDayAverageSteps,
                    ninetyDayAverageSteps: ninetyDayAverageSteps,
                    isLoadingAverage: isLoadingAverage,
                    onRetryAverage: onRetryAverage
                )

                Text("Choose a daily step goal")
                    .font(FitUpFont.body(14, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.primary)
                    .padding(.top, 2)

                OnboardingMatchSetupComponents.tierPicker(
                    stepGoalTier: stepGoalTier,
                    isLoadingAverage: isLoadingAverage,
                    onSelectTier: onSelectTier,
                    dismissKeyboard: { stepGoalFieldFocused = false }
                )

                TextField("Daily steps", text: $dailyStepGoalText)
                    .keyboardType(.numberPad)
                    .focused($stepGoalFieldFocused)
                    .font(FitUpFont.display(18, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
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
                    .foregroundStyle(FitUpColors.Text.secondary)
            }
            .padding(16)
            .glassCard(.win)

            Spacer(minLength: 0)

            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(FitUpFont.body(13, weight: .medium))
                    .foregroundStyle(FitUpColors.Neon.pink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 12)
            }

            Button("Next") {
                stepGoalFieldFocused = false
                FitUpKeyboard.dismiss()
                onNext()
            }
            .solidButton(color: FitUpColors.Neon.cyan)
            .frame(maxWidth: .infinity)
            .disabled(isLoadingAverage)
            .opacity(isLoadingAverage ? 0.65 : 1)
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .fitUpKeyboardDoneToolbar { stepGoalFieldFocused = false }
    }
}

// MARK: - Start first match

struct OnboardingStartMatchView: View {
    let isSubmitting: Bool
    let isLoadingAverage: Bool
    let statusMessage: String?
    let errorMessage: String?
    var onFindOpponent: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Start your first match")
                    .font(FitUpFont.display(24, weight: .black))
                    .foregroundStyle(FitUpColors.Text.primary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("FitUp is a 1v1 steps competition app.")
                    Text("Whoever has the most steps at the end of each day wins that day.")
                    Text("FitUp is 1v1. You'll need another player in the queue. Turn on notifications so we can alert you when you're matched.")
                    Text("Your first match uses Balanced scoring so different activity levels can compete fairly.")
                }
                .font(FitUpFont.body(13, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
                .fixedSize(horizontal: false, vertical: true)

                OnboardingMatchSetupComponents.matchSettingsPills()
                    .padding(.top, 4)
            }
            .padding(16)
            .glassCard(.win)

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 10) {
                Text("Once matched, this 1-day battle ends at midnight tonight. Whoever has the most steps at midnight wins.")
                    .font(FitUpFont.body(12, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)

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

                Button("Start My First Match", action: onFindOpponent)
                    .solidButton(color: FitUpColors.Neon.cyan)
                    .frame(maxWidth: .infinity)
                    .disabled(isSubmitting || isLoadingAverage)
                    .opacity((isSubmitting || isLoadingAverage) ? 0.65 : 1)
            }
            .padding(.top, 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Previews

#Preview("Step Goal") {
    struct PreviewHolder: View {
        @State private var tier: OnboardingViewModel.StepGoalTier = .moderate
        @State private var goalText = "5,000"

        var body: some View {
            ZStack {
                BackgroundGradientView()
                OnboardingStepGoalView(
                    sevenDayAverageSteps: 5000,
                    thirtyDayAverageSteps: 5000,
                    ninetyDayAverageSteps: 4800,
                    isLoadingAverage: false,
                    errorMessage: nil,
                    stepGoalTier: $tier,
                    dailyStepGoalText: $goalText,
                    onSelectTier: { _ in },
                    onRetryAverage: {},
                    onNext: {}
                )
                .padding(.horizontal, 16)
                .padding(.top, 24)
            }
        }
    }
    return PreviewHolder()
}

#Preview("Start Match") {
    ZStack {
        BackgroundGradientView()
        OnboardingStartMatchView(
            isSubmitting: false,
            isLoadingAverage: false,
            statusMessage: nil,
            errorMessage: nil,
            onFindOpponent: {}
        )
        .padding(.horizontal, 16)
        .padding(.top, 24)
    }
}

#Preview("Step Goal — SE") {
    struct PreviewHolder: View {
        @State private var tier: OnboardingViewModel.StepGoalTier = .moderate
        @State private var goalText = "5,000"

        var body: some View {
            ZStack {
                BackgroundGradientView()
                OnboardingStepGoalView(
                    sevenDayAverageSteps: nil,
                    thirtyDayAverageSteps: nil,
                    ninetyDayAverageSteps: nil,
                    isLoadingAverage: false,
                    errorMessage: "Could not read your step averages right now.",
                    stepGoalTier: $tier,
                    dailyStepGoalText: $goalText,
                    onSelectTier: { _ in },
                    onRetryAverage: {},
                    onNext: {}
                )
                .padding(.horizontal, 16)
                .padding(.top, 24)
            }
        }
    }
    return PreviewHolder()
        .previewDevice(PreviewDevice(rawValue: "iPhone 16e"))
}
