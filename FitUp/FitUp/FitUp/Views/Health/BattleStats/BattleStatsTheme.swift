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
    static let textSecondary = Color.white.opacity(0.72)
    static let textLabel = Color.white.opacity(0.45)

    static let sectionSpacing: CGFloat = 10
    static let cardCornerRadius: CGFloat = 18
    static let cardPadding: CGFloat = 16
    static let unresolvedPlaceholder = "—"

    static func battleStatsCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(cardPadding)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous)
                    .strokeBorder(cardBorder, lineWidth: 1)
            }
    }

    static func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .tracking(1.8)
            .foregroundStyle(textPrimary)
    }

    /// Legacy alias — card section headers use white rounded title styling.
    static func sectionLabel(_ text: String) -> some View {
        sectionTitle(text)
    }

    static func rivalTagTitle(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(color)
    }
}
