//
//  NeonStartBattleButton.swift
//  FitUp
//
//  Pulsing neon CTA for the idle hero card ? No - Start a Battle button.
//

import SwiftUI

struct NeonStartBattleButton: View {
    var title: String = "Start a Battle!"
    var isDisabled: Bool = false
    var action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowPhase: CGFloat = 0

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(FitUpFont.display(16, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .padding(.horizontal, 28)
                .padding(.vertical, 14)
                .background {
                    ZStack {
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        FitUpColors.Neon.orange.opacity(0.95),
                                        FitUpColors.Neon.pink.opacity(0.88),
                                        FitUpColors.Neon.orange.opacity(0.92),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )

                        Capsule(style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35 + 0.2 * glowPhase), lineWidth: 1.5)
                    }
                }
                .shadow(color: FitUpColors.Neon.orange.opacity(0.35 + 0.25 * glowPhase), radius: 16 + 10 * glowPhase, y: 4)
                .shadow(color: FitUpColors.Neon.pink.opacity(0.22 + 0.18 * glowPhase), radius: 28 + 12 * glowPhase, y: 0)
                .scaleEffect(1 + 0.015 * glowPhase)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
        .onAppear {
            guard !reduceMotion, !isDisabled else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glowPhase = 1
            }
        }
        .onChange(of: isDisabled) { _, disabled in
            if disabled {
                glowPhase = 0
            } else if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    glowPhase = 1
                }
            }
        }
        .accessibilityHint(isDisabled ? "Match search in progress" : "Opens the new battle flow")
    }
}

#if DEBUG
#Preview {
    ZStack {
        Color.black
        NeonStartBattleButton(action: {})
            .padding()
    }
}
#endif
