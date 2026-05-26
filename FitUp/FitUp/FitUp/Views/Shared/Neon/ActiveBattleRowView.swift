//
//  ActiveBattleRowView.swift
//  FitUp
//
//  Compact neon battle card for Home Active Battles (display-only; parent wraps navigation).
//

import SwiftUI

struct ActiveBattleRowView: View {
    let match: HomeActiveMatch
    var compact: Bool = false

    private var scale: CGFloat {
        compact ? HomeHeroCompactLayout.battlesScale : 1
    }

    private func scaled(_ value: CGFloat) -> CGFloat {
        HomeHeroCompactLayout.scaled(value, by: scale)
    }

    private var accent: Color {
        match.neonCardAccentColor
    }

    private var avatarSize: CGFloat { scaled(36) }
    private var ringSize: CGFloat { scaled(42) }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: scaled(6)) {
                topRow
                Text(match.neonDayProgressText)
                    .font(FitUpFont.mono(scaled(11), weight: .semibold))
                    .foregroundStyle(HomePageStyle.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, scaled(12))
            .padding(.vertical, scaled(10))
            .padding(.bottom, scaled(14))

            Text(match.neonStepDifferenceNowText)
                .font(FitUpFont.mono(scaled(10), weight: .bold))
                .foregroundStyle(match.neonComparableMarginColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, scaled(12))
                .padding(.bottom, scaled(8))
        }
        .neonCompactBattleCard(accent: accent, minHeight: compact ? scaled(62) : nil)
    }

    private var topRow: some View {
        ZStack {
            HStack(spacing: scaled(8)) {
                AvatarView(
                    initials: match.opponent.initials,
                    color: ProfileAccentColor.swiftUIColor(hex: match.opponent.colorHex),
                    size: avatarSize,
                    glow: true
                )
                .overlay {
                    Circle()
                        .strokeBorder(accent.opacity(0.85), lineWidth: max(1, scaled(2)))
                        .frame(width: ringSize, height: ringSize)
                        .shadow(color: accent.opacity(0.4), radius: scaled(6), x: 0, y: 0)
                }

                Text(match.opponent.displayName)
                    .font(FitUpFont.body(scaled(15), weight: .bold))
                    .foregroundStyle(HomePageStyle.offWhite)
                    .lineLimit(1)

                Spacer(minLength: 0)
            }

            Text(match.neonDayScoreText)
                .font(FitUpFont.display(scaled(24), weight: .black))
                .foregroundStyle(HomePageStyle.offWhite)
                .shadow(color: accent.opacity(0.35), radius: scaled(6), x: 0, y: 0)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
    }
}
