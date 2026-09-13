//
//  FormatStepView.swift
//  FitUp
//
//  Slice 3: choose battle duration (Duration step).
//

import SwiftUI

struct DurationStepView: View {
    /// Formats the user may pick. Free users typically receive only `.firstTo3`.
    var allowedFormats: [ChallengeFormatType] = ChallengeFormatType.allCases
    var onSelect: (ChallengeFormatType) -> Void
    var onLockedSelect: (() -> Void)? = nil

    private let columns: [GridItem] = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
    ]

    private var shownFormats: [ChallengeFormatType] {
        let allowed = Set(allowedFormats)
        return ChallengeFormatType.allCases.filter { allowed.contains($0) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose battle duration")
                .font(FitUpFont.body(14, weight: .medium))
                .foregroundStyle(FitUpColors.Text.secondary)

            if shownFormats.count == 1, let only = shownFormats.first {
                freeTierNotice
                durationCard(only, color: accentColor(for: only), locked: false)
            } else {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(ChallengeFormatType.allCases, id: \.self) { format in
                        let allowed = allowedFormats.contains(format)
                        durationCard(
                            format,
                            color: accentColor(for: format),
                            locked: !allowed
                        )
                    }
                }
            }

            howItWorksSection
        }
    }

    private var freeTierNotice: some View {
        Text("Free includes one 3-day battle. Upgrade for 1-, 5-, and 7-day battles.")
            .font(FitUpFont.body(12, weight: .medium))
            .foregroundStyle(FitUpColors.Text.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var howItWorksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How this works")
                .font(FitUpFont.display(13, weight: .bold))
                .foregroundStyle(FitUpColors.Text.primary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(shownFormats.isEmpty ? ChallengeFormatType.allCases : shownFormats, id: \.self) { format in
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

    private func durationCard(_ format: ChallengeFormatType, color: Color, locked: Bool) -> some View {
        Button {
            if locked {
                onLockedSelect?()
            } else {
                onSelect(format)
            }
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
                if locked {
                    Text("PRO")
                        .font(FitUpFont.mono(10, weight: .black))
                        .foregroundStyle(FitUpColors.Neon.yellow)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 80)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .opacity(locked ? 0.55 : 1)
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

    private func accentColor(for format: ChallengeFormatType) -> Color {
        switch format {
        case .daily: return FitUpColors.Neon.yellow
        case .firstTo3: return FitUpColors.Neon.purple
        case .bestOf5: return FitUpColors.Neon.cyan
        case .bestOf7: return FitUpColors.Neon.blue
        }
    }
}

/// Backward-compatible alias while the file retains its legacy name.
typealias FormatStepView = DurationStepView

private struct DurationCardButtonStyle: ButtonStyle {
    let accent: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
