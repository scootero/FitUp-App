//
//  OnboardingEducationViews.swift
//  FitUp
//
//  Hero, how-it-works, and combined permissions screens for onboarding.
//

import SwiftUI

// MARK: - Hero

struct OnboardingHeroView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("Welcome to FitUp")
                .font(FitUpFont.display(28, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: "bolt.heart.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(FitUpColors.Neon.cyan)

                Text("Compete daily using your real activity.")
                    .font(FitUpFont.display(20, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.primary)

                bullet("Steps or active calories — your pick for each match.")
                bullet("Head-to-head 1v1 battles.")
                bullet("A clear winner every day.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassCard(.base)

            Button("Continue") {
                onContinue()
            }
            .solidButton(color: FitUpColors.Neon.cyan)
            .frame(maxWidth: .infinity)
        }
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(FitUpColors.Neon.cyan.opacity(0.85))
                .frame(width: 6, height: 6)
                .padding(.top, 6)
            Text(text)
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
                .multilineTextAlignment(.leading)
        }
    }
}

// MARK: - How it works

struct OnboardingHowItWorksView: View {
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Text("How it works")
                .font(FitUpFont.display(28, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 16) {
                numberedStep(1, "Get matched with someone at a similar activity level.")
                numberedStep(2, "Your real steps or active calories count toward the match.")
                numberedStep(3, "Whoever totals higher for the day wins that day.")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassCard(.base)

            Button("Continue") {
                onContinue()
            }
            .solidButton(color: FitUpColors.Neon.cyan)
            .frame(maxWidth: .infinity)
        }
    }

    private func numberedStep(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(FitUpFont.mono(14, weight: .heavy))
                .foregroundStyle(FitUpColors.Neon.cyan)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(FitUpColors.Neon.cyan.opacity(0.14))
                        .overlay(Circle().strokeBorder(FitUpColors.Neon.cyan.opacity(0.35), lineWidth: 1))
                )
            Text(text)
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
                .multilineTextAlignment(.leading)
        }
    }
}

// MARK: - Permissions (Health + Notifications)

struct OnboardingPermissionsView: View {
    var isRequestingHealth: Bool
    var isRequestingNotifications: Bool
    var isLoadingStepAverages: Bool
    var onContinue: () -> Void

    private var isBusy: Bool {
        isRequestingHealth || isRequestingNotifications || isLoadingStepAverages
    }

    private var buttonTitle: String {
        if isRequestingHealth { return "Opening Health…" }
        if isLoadingStepAverages { return "Loading averages…" }
        if isRequestingNotifications { return "Opening Notifications…" }
        return "Continue"
    }

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(FitUpColors.Neon.cyan)
                .padding(.top, 6)

            Text("Permissions")
                .font(FitUpFont.display(26, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                Text("Apple Health reads your activity so we can score matches fairly — same metrics for you and your opponent.")
                    .font(FitUpFont.body(14, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .multilineTextAlignment(.leading)

                Text("Notifications let you know when a match is found, when a challenge updates, and when a day is finalized.")
                    .font(FitUpFont.body(14, weight: .medium))
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("You’ll see Apple’s prompts next — first Health, then notifications.")
                .font(FitUpFont.body(12, weight: .medium))
                .foregroundStyle(FitUpColors.Text.tertiary)
                .multilineTextAlignment(.center)

            Button(buttonTitle) {
                onContinue()
            }
            .solidButton(color: FitUpColors.Neon.cyan)
            .frame(maxWidth: .infinity)
            .disabled(isBusy)
            .opacity(isBusy ? 0.65 : 1)

            if isLoadingStepAverages {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(FitUpColors.Neon.cyan)
                    Text("Loading your recent step averages…")
                        .font(FitUpFont.body(12, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .glassCard(.base)
    }
}

#Preview("Hero") {
    ZStack {
        BackgroundGradientView()
        OnboardingHeroView(onContinue: {})
            .padding(.horizontal, 16)
    }
}

#Preview("How") {
    ZStack {
        BackgroundGradientView()
        OnboardingHowItWorksView(onContinue: {})
            .padding(.horizontal, 16)
    }
}

#Preview("Permissions") {
    ZStack {
        BackgroundGradientView()
        OnboardingPermissionsView(
            isRequestingHealth: false,
            isRequestingNotifications: false,
            isLoadingStepAverages: false,
            onContinue: {}
        )
        .padding(.horizontal, 16)
    }
}
