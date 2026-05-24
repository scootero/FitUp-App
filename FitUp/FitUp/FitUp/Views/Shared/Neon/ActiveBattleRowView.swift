//
//  ActiveBattleRowView.swift
//  FitUp
//
//  Compact neon battle card for Home Active Battles (display-only; parent wraps navigation).
//

import SwiftUI

struct ActiveBattleRowView: View {
    let match: HomeActiveMatch

    private var accent: Color {
        match.neonCardAccentColor
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 6) {
                topRow
                Text(match.neonDayProgressText)
                    .font(FitUpFont.mono(11, weight: .semibold))
                    .foregroundStyle(HomePageStyle.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .padding(.bottom, 14)

            Text(match.neonStepDifferenceNowText)
                .font(FitUpFont.mono(10, weight: .bold))
                .foregroundStyle(match.neonComparableMarginColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .neonCompactBattleCard(accent: accent)
    }

    private var topRow: some View {
        ZStack {
            HStack(spacing: 8) {
                AvatarView(
                    initials: match.opponent.initials,
                    color: ProfileAccentColor.swiftUIColor(hex: match.opponent.colorHex),
                    size: 36,
                    glow: true
                )
                .overlay {
                    Circle()
                        .strokeBorder(accent.opacity(0.85), lineWidth: 2)
                        .frame(width: 42, height: 42)
                        .shadow(color: accent.opacity(0.4), radius: 6, x: 0, y: 0)
                }

                Text(match.opponent.displayName)
                    .font(FitUpFont.body(15, weight: .bold))
                    .foregroundStyle(HomePageStyle.offWhite)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            Text(match.neonDayScoreText)
                .font(FitUpFont.display(24, weight: .black))
                .foregroundStyle(HomePageStyle.offWhite)
                .shadow(color: accent.opacity(0.35), radius: 6, x: 0, y: 0)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
    }
}
