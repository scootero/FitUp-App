//
//  TestFlightFeedbackPromptSheet.swift
//  FitUp
//
//  Lightweight intro sheet before the full TestFlight feedback form.
//

import SwiftUI

struct TestFlightFeedbackPromptSheet: View {
    var onGiveFeedback: () -> Void
    var onNotNow: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("Enjoying FitUp?")
                    .font(FitUpFont.display(18, weight: .heavy))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(FitUpColors.Text.primary)

                Text("We'd love your feedback after trying FitUp for a bit.")
                    .font(FitUpFont.body(14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(FitUpColors.Text.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(action: onGiveFeedback) {
                Text("Give Feedback")
                    .font(FitUpFont.body(16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .foregroundStyle(FitUpColors.Neon.cyan)
            .background {
                RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                    .fill(FitUpColors.Neon.cyanDim.opacity(0.4))
                    .overlay {
                        RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                            .strokeBorder(FitUpColors.Neon.cyan.opacity(0.5), lineWidth: 1)
                    }
            }

            Button("Not Now", action: onNotNow)
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
        }
        .padding(24)
        .background(BackgroundGradientView())
    }
}
