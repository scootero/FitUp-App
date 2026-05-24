//
//  PastMatchRow.swift
//  FitUp
//
//  Neon-styled completed battle row (centered layout).
//

import SwiftUI

struct PastMatchRow: View {
    let match: ActivityCompletedMatch
    var rowIndex: Int = 0
    var onTap: () -> Void

    private var accent: Color {
        ActiveBattleRowFormatting.avatarAccent(for: rowIndex)
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 5) {
                    avatarBlock

                    Text(match.opponentName)
                        .font(FitUpFont.body(14, weight: .bold))
                        .foregroundStyle(HomePageStyle.offWhite)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)

                    Text(match.neonScoreText)
                        .font(FitUpFont.display(22, weight: .black))
                        .foregroundStyle(HomePageStyle.offWhite)
                        .shadow(color: match.neonOutcomeColor.opacity(0.28), radius: 4, x: 0, y: 0)
                        .multilineTextAlignment(.center)

                    VStack(spacing: 2) {
                        Text(match.neonSportLabel)
                            .font(FitUpFont.mono(10, weight: .bold))
                            .tracking(0.6)
                            .foregroundStyle(HomePageStyle.muted)
                            .multilineTextAlignment(.center)

                        Text(match.rangeLabel)
                            .font(FitUpFont.body(11, weight: .medium))
                            .foregroundStyle(HomePageStyle.faint)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 2)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 2)

                outcomeBadge
            }
            .neonRowInsetPlate(accent: accent)
        }
        .buttonStyle(.plain)
    }

    private var avatarBlock: some View {
        AvatarView(
            initials: match.opponentInitials,
            color: ProfileAccentColor.swiftUIColor(hex: match.opponentColorHex),
            size: 36,
            glow: true
        )
        .overlay {
            Circle()
                .strokeBorder(accent.opacity(0.9), lineWidth: 2.5)
                .frame(width: 42, height: 42)
                .shadow(color: accent.opacity(0.55), radius: 10, x: 0, y: 0)
        }
    }

    private var outcomeBadge: some View {
        Text(match.neonOutcomeLabel)
            .font(FitUpFont.mono(10, weight: .heavy))
            .tracking(0.8)
            .foregroundStyle(match.neonOutcomeColor)
            .shadow(color: match.neonOutcomeColor.opacity(0.45), radius: 6, x: 0, y: 0)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background {
                Capsule()
                    .fill(match.neonOutcomeColor.opacity(0.12))
                    .overlay {
                        Capsule()
                            .strokeBorder(match.neonOutcomeColor.opacity(0.42), lineWidth: 1)
                    }
            }
    }
}
