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
                    .font(.system(size: 26))
                Text("Challenge someone new")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BattleStatsTheme.textSecondary)
                Text("Keep your streak alive")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(BattleStatsTheme.textLabel)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
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
