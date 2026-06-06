//
//  HomeIntroTipView.swift
//  FitUp
//
//  Optional app description on the session-restore loading screen.
//

import SwiftUI

struct HomeIntroTipView: View {
    private static let lines = [
        "FitUp is a 1v1 steps competition app.",
        "Whoever has the most steps at the end of each day wins that day.",
        "Whoever wins the most days by the end wins the battle.",
    ]

    private static let fitGradient = LinearGradient(
        colors: [FitUpColors.Neon.cyan, FitUpColors.Neon.blue],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Self.lines, id: \.self) { line in
                Text(line)
                    .font(FitUpFont.body(15, weight: .semibold))
                    .foregroundStyle(Self.fitGradient)
                    .shadow(color: Color.black.opacity(0.35), radius: 1, y: 1)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .homeIntroTipGlassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.lines.joined(separator: " "))
    }
}

struct HomeIntroTipRevealSection: View {
    @Binding var isShowingTip: Bool
    var onTipRevealed: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            FitUpBrandMark(fontSize: 32)
                .frame(maxWidth: .infinity)

            HStack {
                Spacer(minLength: 0)
                WhatIsFitUpExplodedPromptButton {
                    revealTip()
                }
            }

            if isShowingTip {
                HomeIntroTipView()
                    .transition(
                        .scale(scale: 0.94, anchor: .topTrailing)
                            .combined(with: .opacity)
                    )
            }
        }
        .animation(.spring(response: 0.36, dampingFraction: 0.78), value: isShowingTip)
    }

    private func revealTip() {
        guard !isShowingTip else { return }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
            isShowingTip = true
        }
        onTipRevealed()
    }
}

private struct WhatIsFitUpExplodedPromptButton: View {
    var action: () -> Void

    @State private var isPushingOut = false

    private static let words = ["What", "is", "FitUp?"]

    private static let wordGradient = LinearGradient(
        colors: [
            FitUpColors.Neon.cyan.opacity(0.95),
            FitUpColors.Neon.blue.opacity(0.92),
            FitUpColors.Neon.purple.opacity(0.88),
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        Button(action: action) {
            HStack(spacing: isPushingOut ? 7 : 4) {
                ForEach(Array(Self.words.enumerated()), id: \.offset) { index, word in
                    Text(word)
                        .font(FitUpFont.display(12, weight: .heavy))
                        .tracking(0.6)
                        .foregroundStyle(Self.wordGradient)
                        .shadow(color: FitUpColors.Neon.cyan.opacity(0.55), radius: isPushingOut ? 10 : 6, x: 0, y: 0)
                        .shadow(color: FitUpColors.Neon.blue.opacity(0.35), radius: isPushingOut ? 16 : 9, x: 0, y: 0)
                        .scaleEffect(isPushingOut ? 1.06 : 1.0)
                        .rotationEffect(.degrees(isPushingOut ? Double(index - 1) * 1.4 : 0))
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("What is FitUp?")
        .accessibilityHint("Shows a short description of the app.")
        .onAppear {
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                isPushingOut = true
            }
        }
    }
}
