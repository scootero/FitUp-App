//
//  StatsChallengeSomeoneCard.swift
//  FitUp
//

import SwiftUI

struct StatsChallengeSomeoneCard: View {
    var onChallenge: () -> Void

    var body: some View {
        Button(action: onChallenge) {
            VStack(spacing: 6) {
                Text("⚔️")
                    .font(.system(size: 31))
                Text("Challenge someone new")
                    .battleStatsStyle(.secondary, weight: .semibold, accent: .neutral)
                Text("Keep your streak alive")
                    .battleStatsStyle(.label, size: BattleStatsTheme.Typography.bodySmall, accent: .warm)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background {
                BattleStatsTheme.cardAccentBackground(accent: .warm)
            }
            .clipShape(RoundedRectangle(cornerRadius: BattleStatsTheme.cardCornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: BattleStatsTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(BattleStatsTheme.cardBorder, lineWidth: 1)
            }
            .overlay {
                RoundedRectangle(cornerRadius: BattleStatsTheme.cardCornerRadius, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(0.12),
                        style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Challenge someone new")
        .accessibilityHint("Opens the battle challenge flow")
    }
}
