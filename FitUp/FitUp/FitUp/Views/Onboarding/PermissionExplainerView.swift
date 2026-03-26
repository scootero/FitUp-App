//
//  PermissionExplainerView.swift
//  FitUp
//
//  Slice 2 reusable permission explainer card.
//

import SwiftUI

struct PermissionExplainerView: View {
    let title: String
    let bodyText: String
    let iconSystemName: String
    let buttonTitle: String
    var isWorking: Bool = false
    var accentColor: Color = FitUpColors.Neon.cyan
    var onContinue: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: iconSystemName)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(accentColor)
                .padding(.top, 6)

            Text(title)
                .font(FitUpFont.display(26, weight: .black))
                .foregroundStyle(FitUpColors.Text.primary)
                .multilineTextAlignment(.center)

            Text(bodyText)
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)
                .multilineTextAlignment(.center)

            Button(buttonTitle) {
                onContinue()
            }
            .solidButton(color: accentColor)
            .frame(maxWidth: .infinity)
            .disabled(isWorking)
            .opacity(isWorking ? 0.65 : 1)
        }
        .padding(20)
        .glassCard(.base)
    }
}

#Preview {
    ZStack {
        BackgroundGradientView()
        PermissionExplainerView(
            title: "Apple Health Access",
            bodyText: "FitUp reads your steps, active calories, sleep, and resting heart rate to score matches.",
            iconSystemName: "heart.text.square.fill",
            buttonTitle: "Continue",
            onContinue: {}
        )
        .padding(.horizontal, 16)
    }
}
