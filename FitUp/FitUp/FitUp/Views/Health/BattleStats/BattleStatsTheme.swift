//
//  BattleStatsTheme.swift
//  FitUp
//
//  Local visual tokens for the Battle Stats page (GSX-inspired).
//

import SwiftUI

enum BattleStatsTheme {
    static let cardBackground = Color(rgb: 0x0D1117)
    static let cardBorder = Color.white.opacity(0.07)

    static let green = Color(rgb: 0x00E87A)
    static let red = Color(rgb: 0xFF4D4D)
    static let gold = Color(rgb: 0xF5C842)
    static let blue = Color(rgb: 0x4DB8FF)
    static let purple = Color(rgb: 0xA855F7)
    static let orange = Color(rgb: 0xF97316)

    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.90)
    static let textLabel = Color.white.opacity(0.68)

    static let sectionSpacing: CGFloat = 12
    static let cardCornerRadius: CGFloat = 18
    static let cardPadding: CGFloat = 16
    static let unresolvedPlaceholder = "—"

    // MARK: - Typography (slightly larger minimums)

    enum Typography {
        static let headerTitle: CGFloat = 31
        static let headerSubtitle: CGFloat = 17
        static let sectionTitle: CGFloat = 17
        static let body: CGFloat = 17
        static let bodySmall: CGFloat = 14
        static let caption: CGFloat = 13
        static let captionSmall: CGFloat = 12
    }

    /// Per-card accent shifts the subtle gradient tint (warm gold, cool cyan, etc.).
    enum SectionAccent {
        case neutral
        case warm
        case cool
        case mint

        fileprivate var highlight: Color {
            switch self {
            case .neutral: return Color(red: 1, green: 0.94, blue: 0.78)
            case .warm: return gold
            case .cool: return blue
            case .mint: return green
            }
        }
    }

    enum TextTone {
        case primary
        case secondary
        case label
        case sectionTitle
        case headerTitle
        case headerSubtitle

        fileprivate var defaultSize: CGFloat {
            switch self {
            case .primary: return Typography.body
            case .secondary: return Typography.body
            case .label: return Typography.caption
            case .sectionTitle: return Typography.sectionTitle
            case .headerTitle: return Typography.headerTitle
            case .headerSubtitle: return Typography.headerSubtitle
            }
        }

        fileprivate var defaultWeight: Font.Weight {
            switch self {
            case .primary: return .medium
            case .secondary: return .medium
            case .label: return .medium
            case .sectionTitle: return .heavy
            case .headerTitle: return .heavy
            case .headerSubtitle: return .medium
            }
        }

        fileprivate var defaultDesign: Font.Design {
            switch self {
            case .sectionTitle, .headerTitle, .headerSubtitle: return .rounded
            default: return .default
            }
        }

        fileprivate func gradient(accent: SectionAccent) -> LinearGradient {
            let highlight = accent.highlight
            switch self {
            case .primary, .headerTitle:
                return LinearGradient(
                    colors: [
                        Color.white,
                        Color.white.opacity(0.98),
                        highlight.opacity(0.88),
                    ],
                    startPoint: UnitPoint(x: 0.02, y: 0),
                    endPoint: UnitPoint(x: 0.92, y: 0.98)
                )
            case .secondary, .headerSubtitle:
                return LinearGradient(
                    colors: [
                        Color.white.opacity(0.96),
                        Color.white.opacity(0.90),
                        highlight.opacity(0.78),
                    ],
                    startPoint: UnitPoint(x: 0, y: 0.08),
                    endPoint: UnitPoint(x: 0.88, y: 0.95)
                )
            case .label:
                return LinearGradient(
                    colors: [
                        Color.white.opacity(0.84),
                        Color.white.opacity(0.76),
                        highlight.opacity(0.62),
                    ],
                    startPoint: UnitPoint(x: 0.05, y: 0),
                    endPoint: UnitPoint(x: 0.95, y: 1)
                )
            case .sectionTitle:
                return LinearGradient(
                    colors: [
                        Color.white,
                        Color.white.opacity(0.96),
                        highlight.opacity(0.82),
                    ],
                    startPoint: UnitPoint(x: 0, y: 0.12),
                    endPoint: UnitPoint(x: 0.78, y: 0.92)
                )
            }
        }
    }

    static func cardAccentBackground(accent: SectionAccent) -> some View {
        ZStack {
            cardBackground
            LinearGradient(
                colors: [
                    accent.highlight.opacity(0.16),
                    accent.highlight.opacity(0.05),
                    accent.highlight.opacity(0.1),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    static func battleStatsCard<Content: View>(
        accent: SectionAccent? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(cardPadding)
            .background {
                if let accent {
                    cardAccentBackground(accent: accent)
                } else {
                    cardBackground
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .strokeBorder(cardBorder, lineWidth: 1)
            }
    }

    static func sectionTitle(_ text: String, accent: SectionAccent = .neutral) -> some View {
        Text(text)
            .font(.system(size: Typography.sectionTitle, weight: .heavy, design: .rounded))
            .tracking(1.8)
            .foregroundStyle(FitUpColors.Text.title)
    }

    /// Legacy alias — card section headers use the shared plain title color.
    static func sectionLabel(_ text: String, accent: SectionAccent = .neutral) -> some View {
        sectionTitle(text, accent: accent)
    }

    static func rivalTagTitle(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: Typography.sectionTitle, weight: .heavy, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(color)
    }

    static func textGradient(_ tone: TextTone, accent: SectionAccent = .neutral) -> LinearGradient {
        tone.gradient(accent: accent)
    }
}

// MARK: - Gradient text styling

extension Text {
    func battleStatsStyle(
        _ tone: BattleStatsTheme.TextTone,
        size: CGFloat? = nil,
        weight: Font.Weight? = nil,
        design: Font.Design? = nil,
        accent: BattleStatsTheme.SectionAccent = .neutral
    ) -> some View {
        self
            .font(.system(
                size: size ?? tone.defaultSize,
                weight: weight ?? tone.defaultWeight,
                design: design ?? tone.defaultDesign
            ))
            .foregroundStyle(tone.gradient(accent: accent))
    }
}
