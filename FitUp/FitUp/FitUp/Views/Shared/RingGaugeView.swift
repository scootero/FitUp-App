//
//  RingGaugeView.swift
//  FitUp
//
//  Maps JSX `CircleProgress` — trim ring, score, ≥75 cyan / ≥50 yellow / red.
//

import SwiftUI

struct RingGaugeView: View {
    let score: Int
    var size: CGFloat = 90

    private var ringColor: Color {
        if score >= 75 { return FitUpColors.Neon.cyan }
        if score >= 50 { return FitUpColors.Neon.yellow }
        return FitUpColors.Neon.red
    }

    private var lineWidth: CGFloat { 8 }
    private var radius: CGFloat { (size - lineWidth) / 2 }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)
                .frame(width: size - lineWidth, height: size - lineWidth)

            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size - lineWidth, height: size - lineWidth)
                .rotationEffect(.degrees(-90))

            VStack(spacing: 1) {
                Text("\(score)")
                    .font(FitUpFont.display(28, weight: .bold))
                    .foregroundStyle(ringColor)
                Text("/100")
                    .font(FitUpFont.mono(9))
                    .foregroundStyle(FitUpColors.Text.tertiary)
            }
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack(spacing: 24) {
        RingGaugeView(score: 82)
        RingGaugeView(score: 60)
        RingGaugeView(score: 40)
    }
    .padding()
    .background { BackgroundGradientView() }
}
