//
//  PodiumView.swift
//  FitUp
//
//  Slice 11 — Top 3 podium (2nd left, 1st center tall, 3rd right).
//

import SwiftUI

struct PodiumView: View {
    /// Top rows in rank order. Only real rows are rendered (no placeholders).
    let rows: [LeaderboardDisplayRow]

    private let secondHeight: CGFloat = 68
    private let firstHeight: CGFloat = 82
    private let thirdHeight: CGFloat = 58
    private let columnWidth: CGFloat = 88
    private let cardCornerRadius: CGFloat = 16

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if let second = rows[safe: 1] {
                podiumColumn(row: second, height: secondHeight, tier: .silver, avatarSize: 46)
            }
            if let first = rows[safe: 0] {
                podiumColumnFirst(row: first, height: firstHeight)
            }
            if let third = rows[safe: 2] {
                podiumColumn(row: third, height: thirdHeight, tier: .bronze, avatarSize: 42)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private func podiumColumnFirst(row: LeaderboardDisplayRow, height: CGFloat) -> some View {
        VStack(spacing: 8) {
            podiumAvatar(
                row: row,
                size: 58,
                tier: .gold,
                showCrown: true
            )

            podiumCardBody(row: row, height: height, tier: .gold, medal: "🥇")
                .frame(width: columnWidth, height: height)
                .neonLeaderboardPodiumCard(tier: .gold, cornerRadius: cardCornerRadius)
        }
    }

    private func podiumColumn(
        row: LeaderboardDisplayRow,
        height: CGFloat,
        tier: LeaderboardPodiumTier,
        avatarSize: CGFloat
    ) -> some View {
        VStack(spacing: 8) {
            podiumAvatar(row: row, size: avatarSize, tier: tier, showCrown: false)

            podiumCardBody(
                row: row,
                height: height,
                tier: tier,
                medal: tier == .silver ? "🥈" : "🥉"
            )
            .frame(width: columnWidth, height: height)
            .neonLeaderboardPodiumCard(tier: tier, cornerRadius: cardCornerRadius)
        }
    }

    private func podiumAvatar(
        row: LeaderboardDisplayRow,
        size: CGFloat,
        tier: LeaderboardPodiumTier,
        showCrown: Bool
    ) -> some View {
        ZStack(alignment: .top) {
            if showCrown {
                Text("👑")
                    .font(.system(size: 24))
                    .shadow(color: FitUpColors.Neon.yellow.opacity(0.8), radius: 8, x: 0, y: 0)
                    .offset(y: -20)
            }

            AvatarView(
                initials: row.initials,
                color: ProfileAccentColor.swiftUIColor(hex: row.colorHex),
                size: size,
                glow: true
            )
            .overlay {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                tier.accent.opacity(0.95),
                                tier.secondaryAccent.opacity(0.75),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: tier.borderLineWidth
                    )
                    .frame(width: size + 8, height: size + 8)
                    .shadow(color: tier.accent.opacity(tier.outerGlowOpacity), radius: tier.outerGlowRadius * 0.45, x: 0, y: 0)
            }
            .padding(.top, showCrown ? 10 : 0)
        }
        .frame(height: showCrown ? 72 : 54)
    }

    private func podiumCardBody(
        row: LeaderboardDisplayRow,
        height: CGFloat,
        tier: LeaderboardPodiumTier,
        medal: String
    ) -> some View {
        VStack(spacing: 3) {
            Text(medal)
                .font(.system(size: height >= firstHeight - 1 ? 24 : 20))
                .shadow(color: tier.accent.opacity(0.5), radius: 6, x: 0, y: 0)

            Text(shortName(row.displayName))
                .font(FitUpFont.body(11, weight: .bold))
                .foregroundStyle(HomePageStyle.offWhite)
                .lineLimit(1)
                .shadow(color: tier.accent.opacity(0.25), radius: 4, x: 0, y: 0)

            Text(formatSteps(row.totalSteps))
                .font(FitUpFont.mono(10, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            tier.accent,
                            tier.secondaryAccent.opacity(0.92),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .shadow(color: tier.accent.opacity(0.45), radius: 5, x: 0, y: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
    }

    private func shortName(_ full: String) -> String {
        full.split(separator: " ").first.map(String.init) ?? full
    }

    private func formatSteps(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        let formatted = f.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted) steps"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
