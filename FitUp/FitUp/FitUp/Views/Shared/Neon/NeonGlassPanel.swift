//
//  NeonGlassPanel.swift
//  FitUp
//
//  Dark rivalry panel with neon title glow for grouped lists.
//

import SwiftUI

struct NeonPanelTitle: View {
    let title: String
    var style: NeonPanelTitleStyle = .standard
    var accent: Color = FitUpColors.Neon.pink

    var body: some View {
        Text(title.uppercased())
            .font(style.font)
            .tracking(style.tracking)
            .foregroundStyle(
                LinearGradient(
                    colors: style.gradientColors(accent: accent),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .shadow(color: style.leadingGlow.opacity(0.45), radius: style.leadingGlowRadius, x: 0, y: 0)
            .shadow(color: accent.opacity(0.7), radius: style.accentGlowRadius, x: 0, y: 0)
            .shadow(color: style.trailingGlow.opacity(0.5), radius: style.trailingGlowRadius, x: 0, y: 0)
    }
}

enum NeonPanelTitleStyle {
    case standard
    case compact

    var font: Font {
        switch self {
        case .standard:
            return FitUpFont.display(22, weight: .heavy)
        case .compact:
            return FitUpFont.display(15, weight: .heavy)
        }
    }

    var tracking: CGFloat {
        switch self {
        case .standard: return 1.4
        case .compact: return 1.0
        }
    }

    var leadingGlow: Color {
        switch self {
        case .standard: return FitUpColors.Neon.orange
        case .compact: return FitUpColors.Neon.cyan
        }
    }

    var trailingGlow: Color {
        switch self {
        case .standard: return FitUpColors.Neon.purple
        case .compact: return FitUpColors.Neon.blue
        }
    }

    var leadingGlowRadius: CGFloat {
        switch self {
        case .standard: return 8
        case .compact: return 5
        }
    }

    var accentGlowRadius: CGFloat {
        switch self {
        case .standard: return 12
        case .compact: return 8
        }
    }

    var trailingGlowRadius: CGFloat {
        switch self {
        case .standard: return 22
        case .compact: return 14
        }
    }

    func gradientColors(accent: Color) -> [Color] {
        switch self {
        case .standard:
            return [
                FitUpColors.Neon.orange.opacity(0.95),
                accent.opacity(0.98),
                FitUpColors.Neon.purple.opacity(0.92),
            ]
        case .compact:
            return [
                FitUpColors.Neon.cyan.opacity(0.92),
                accent.opacity(0.96),
                FitUpColors.Neon.blue.opacity(0.88),
            ]
        }
    }
}

struct NeonGlassPanel<Content: View>: View {
    let title: String
    var titleAccent: Color = FitUpColors.Neon.pink
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            NeonPanelTitle(title: title, style: .standard, accent: titleAccent)
                .padding(.horizontal, 2)
                .padding(.top, 2)

            content()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .neonRivalryPanel()
    }
}

#Preview {
    NeonGlassPanel(title: "Active Battles") {
        Text("Row content")
            .foregroundStyle(FitUpColors.Text.secondary)
    }
    .padding()
    .background { BackgroundGradientView() }
}
