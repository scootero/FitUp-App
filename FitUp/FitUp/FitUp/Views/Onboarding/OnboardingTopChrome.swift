//
//  OnboardingTopChrome.swift
//  FitUp
//
//  Shared back control and wordmark for onboarding steps.
//

import SwiftUI

struct OnboardingTopChrome: View {
    var showsBack: Bool
    var onBack: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if showsBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(FitUpColors.Text.primary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.06))
                                .overlay(Circle().strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }

            FitUpBrandMark(fontSize: 22)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 12)
    }
}

#Preview {
    ZStack {
        BackgroundGradientView()
        VStack {
            OnboardingTopChrome(showsBack: true, onBack: {})
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
    }
}
