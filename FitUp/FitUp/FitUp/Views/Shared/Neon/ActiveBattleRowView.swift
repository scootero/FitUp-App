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
        Group {
            if match.isEffectivelyOverForHomeUX {
                pendingRow
            } else {
                liveRow
            }
        }
        .neonCompactBattleCard(accent: accent, minHeight: compact ? scaled(62) : nil)
    }

    private var pendingRow: some View {
        VStack(alignment: .leading, spacing: scaled(6)) {
            topRow
            Text(BattlePhaseCopy.pendingTitle)
                .font(FitUpFont.body(scaled(14), weight: .bold))
                .foregroundStyle(HomePageStyle.offWhite)
            Text(BattlePhaseCopy.pendingSubtitle)
                .font(FitUpFont.body(scaled(12), weight: .semibold))
                .foregroundStyle(FitUpColors.Neon.yellow.opacity(0.9))
            Text(BattlePhaseCopy.matchScorePrefixed(myScore: match.myScore, theirScore: match.theirScore))
                .font(FitUpFont.mono(scaled(11), weight: .semibold))
                .foregroundStyle(HomePageStyle.muted)
        }
        .padding(.horizontal, scaled(12))
        .padding(.vertical, scaled(10))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var liveRow: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: scaled(6)) {
                topRow
                Text(match.matchStatusLabel)
                    .font(FitUpFont.body(scaled(12), weight: .heavy))
                    .foregroundStyle(match.matchStatusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(match.matchScoreText)
                    .font(FitUpFont.display(scaled(22), weight: .black))
                    .foregroundStyle(HomePageStyle.offWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, alignment: .center)
                Text(BattlePhaseCopy.matchScoreCaption.uppercased())
                    .font(FitUpFont.mono(scaled(10), weight: .semibold))
                    .foregroundStyle(HomePageStyle.muted)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, scaled(12))
            .padding(.vertical, scaled(10))
            .padding(.bottom, scaled(14))

            Text(match.neonStepDifferenceNowText)
                .font(FitUpFont.mono(scaled(10), weight: .bold))
                .foregroundStyle(match.neonLiveCardAccentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, scaled(12))
                .padding(.bottom, scaled(8))
        }
    }

    private var topRow: some View {
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
        .frame(maxWidth: .infinity)
    }
}
