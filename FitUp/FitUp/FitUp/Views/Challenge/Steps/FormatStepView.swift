//
//  FormatStepView.swift
//  FitUp
//
//  Slice 3: choose battle duration (Duration step).
//

import SwiftUI

struct DurationStepView: View {
    var onSelect: (ChallengeFormatType) -> Void

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose battle duration")
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)

            LazyVGrid(columns: columns, spacing: 8) {
                durationCard(.daily, color: FitUpColors.Neon.yellow)
                durationCard(.firstTo3, color: FitUpColors.Neon.purple)
                durationCard(.bestOf5, color: FitUpColors.Neon.cyan)
                durationCard(.bestOf7, color: FitUpColors.Neon.blue)
            }

            howItWorksSection
        }
    }

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How this works")
                .font(FitUpFont.display(13, weight: .bold))
                .foregroundStyle(FitUpColors.Text.primary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(ChallengeFormatType.allCases, id: \.self) { format in
                    HStack(alignment: .top, spacing: 8) {
                        Text(format.displayName)
                            .font(FitUpFont.mono(11, weight: .bold))
                            .foregroundStyle(FitUpColors.Neon.cyan)
                            .frame(width: 88, alignment: .leading)
                        Text(format.howItWorksLine)
                            .font(FitUpFont.body(12, weight: .medium))
                            .foregroundStyle(FitUpColors.Text.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(.base)
    }

    private func durationCard(_ format: ChallengeFormatType, color: Color) -> some View {
        Button {
            onSelect(format)
        } label: {
            VStack(spacing: 6) {
                Text(format.displayName)
                    .font(FitUpFont.display(16, weight: .black))
                    .foregroundStyle(color)
                    .multilineTextAlignment(.center)
                Text(format.subtitle)
                    .font(FitUpFont.body(11, weight: .semibold))
                    .foregroundStyle(FitUpColors.Text.primary.opacity(0.72))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                    .fill(color.opacity(0.08))
                    .overlay {
                        RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .opacity(0.4)
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: FitUpRadius.lg, style: .continuous)
                    .strokeBorder(color.opacity(0.32), lineWidth: 1.5)
            }
            .shadow(color: color.opacity(0.14), radius: 14, x: 0, y: 6)
            .shadow(color: Color.black.opacity(0.28), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(DurationCardButtonStyle(accent: color))
    }
}

/// Backward-compatible alias while the file retains its legacy name.
typealias FormatStepView = DurationStepView

private struct DurationCardButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .offset(y: configuration.isPressed ? 3 : 0)
            .shadow(
                color: accent.opacity(configuration.isPressed ? 0.06 : 0.14),
                radius: configuration.isPressed ? 4 : 14,
                x: 0,
                y: configuration.isPressed ? 1 : 6
            )
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
