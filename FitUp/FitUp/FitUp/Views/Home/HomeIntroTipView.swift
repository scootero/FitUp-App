//
//  HomeIntroTipView.swift
//  FitUp
//
//  App description card on Home when there is no active step battle.
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
                    .font(FitUpFont.body(13, weight: .semibold))
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
