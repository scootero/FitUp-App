//
//  ActiveBattleRowView.swift
//  FitUp
//
//  Compact neon battle card for Home Active Battles (display-only; parent wraps navigation).
//

import SwiftUI

struct ActiveBattleRowUserProfile: Equatable {
    let displayName: String
    let initials: String
    let colorHex: String
}

struct ActiveBattleRowView: View {
    let match: HomeActiveMatch
    let userProfile: ActiveBattleRowUserProfile
    var compact: Bool = false

    private var scale: CGFloat {
        compact ? HomeHeroCompactLayout.battlesScale : 1
    }

    private func scaled(_ value: CGFloat) -> CGFloat {
        HomeHeroCompactLayout.scaled(value, by: scale)
    }

    private var avatarSize: CGFloat { scaled(30) }
    private var ringSize: CGFloat { scaled(36) }

    private static let captionMuted = Color.white.opacity(0.82)

    var body: some View {
        Group {
            if match.isEffectivelyOverForHomeUX {
                pendingRow
            } else {
                liveRow
            }
        }
        .neonActiveBattleCard(minHeight: compact ? scaled(52) : nil)
    }

    private var pendingRow: some View {
        VStack(alignment: .leading, spacing: scaled(5)) {
            if !match.battleDateRangeLabel.isEmpty {
                Text(match.battleDateRangeLabel)
                    .font(FitUpFont.body(scaled(10), weight: .semibold))
                    .foregroundStyle(HomePageStyle.faint)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            HStack(spacing: scaled(8)) {
                opponentAvatar(accent: FitUpColors.Neon.yellow)
                Text(match.opponent.displayName)
                    .font(FitUpFont.body(scaled(14), weight: .bold))
                    .foregroundStyle(HomePageStyle.offWhite)
                    .lineLimit(1)
            }
            Text(BattlePhaseCopy.pendingTitle)
                .font(FitUpFont.body(scaled(13), weight: .bold))
                .foregroundStyle(HomePageStyle.offWhite)
            Text(BattlePhaseCopy.pendingSubtitle)
                .font(FitUpFont.body(scaled(11), weight: .semibold))
                .foregroundStyle(FitUpColors.Neon.yellow.opacity(0.9))
            Text(BattlePhaseCopy.matchScorePrefixed(myScore: match.myScore, theirScore: match.theirScore))
                .font(FitUpFont.mono(scaled(10), weight: .semibold))
                .foregroundStyle(Self.captionMuted)
        }
        .padding(.horizontal, scaled(10))
        .padding(.vertical, scaled(8))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var liveRow: some View {
        VStack(spacing: scaled(4)) {
            if !match.battleDateRangeLabel.isEmpty {
                Text(match.battleDateRangeLabel)
                    .font(FitUpFont.body(scaled(10), weight: .semibold))
                    .foregroundStyle(HomePageStyle.faint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            HStack(alignment: .top, spacing: scaled(4)) {
                userColumn
                    .frame(maxWidth: .infinity, alignment: .leading)

                centerColumn
                    .frame(minWidth: scaled(88))

                opponentColumn
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.horizontal, scaled(10))
        .padding(.vertical, scaled(8))
    }

    private var userColumn: some View {
        VStack(spacing: scaled(3)) {
            userAvatar
            Text("\(match.myToday.formatted()) steps")
                .font(FitUpFont.body(scaled(9), weight: .semibold))
                .foregroundStyle(FitUpColors.Neon.yellow.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var opponentColumn: some View {
        VStack(spacing: scaled(3)) {
            HStack(spacing: scaled(4)) {
                Text(match.opponent.displayName)
                    .font(FitUpFont.body(scaled(10), weight: .bold))
                    .foregroundStyle(HomePageStyle.offWhite)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                opponentAvatar(accent: FitUpColors.Neon.orange)
            }
            Text("\(match.theirToday.formatted()) steps")
                .font(FitUpFont.body(scaled(9), weight: .semibold))
                .foregroundStyle(FitUpColors.Neon.yellow.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var centerColumn: some View {
        VStack(spacing: scaled(2)) {
            Text(match.matchStatusLabel)
                .font(FitUpFont.body(scaled(9), weight: .heavy))
                .foregroundStyle(match.matchStatusColor)
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(match.matchScoreText)
                .font(FitUpFont.display(scaled(18), weight: .black))
                .foregroundStyle(HomePageStyle.offWhite)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(BattlePhaseCopy.matchScoreCaption.uppercased())
                .font(FitUpFont.mono(scaled(8), weight: .semibold))
                .foregroundStyle(Self.captionMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(match.neonTodayMarginText)
                .font(FitUpFont.body(scaled(9), weight: .bold))
                .foregroundStyle(match.neonTodayMarginColor)
                .lineLimit(2)
                .minimumScaleFactor(0.65)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var userAvatar: some View {
        AvatarView(
            initials: userProfile.initials,
            color: ProfileAccentColor.swiftUIColor(hex: userProfile.colorHex),
            size: avatarSize,
            glow: true
        )
        .overlay {
            Circle()
                .strokeBorder(FitUpColors.Neon.cyan.opacity(0.85), lineWidth: max(1, scaled(1.5)))
                .frame(width: ringSize, height: ringSize)
                .shadow(color: FitUpColors.Neon.cyan.opacity(0.4), radius: scaled(4), x: 0, y: 0)
        }
    }

    private func opponentAvatar(accent: Color) -> some View {
        AvatarView(
            initials: match.opponent.initials,
            color: ProfileAccentColor.swiftUIColor(hex: match.opponent.colorHex),
            size: avatarSize,
            glow: true
        )
        .overlay {
            Circle()
                .strokeBorder(accent.opacity(0.85), lineWidth: max(1, scaled(1.5)))
                .frame(width: ringSize, height: ringSize)
                .shadow(color: accent.opacity(0.4), radius: scaled(4), x: 0, y: 0)
        }
    }
}
