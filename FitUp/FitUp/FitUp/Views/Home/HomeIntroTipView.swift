//
//  HomeIntroTipView.swift
//  FitUp
//
//  One-time-per-launch intro card on Home (fades out after a few seconds).
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
                    .font(FitUpFont.body(13, weight: .medium))
                    .foregroundStyle(Self.fitGradient)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                        .fill(Color.black.opacity(0.42))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: FitUpRadius.md, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Self.lines.joined(separator: " "))
    }
}
