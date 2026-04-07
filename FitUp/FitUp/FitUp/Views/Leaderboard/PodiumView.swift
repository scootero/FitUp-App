//
//  PodiumView.swift
//  FitUp
//
//  Slice 11 — Top 3 podium (2nd left, 1st center tall, 3rd right).
//

import SwiftUI

struct PodiumView: View {
    /// Index 0 = rank 1, 1 = rank 2, 2 = rank 3.
    let rows: [LeaderboardDisplayRow]

    private let secondHeight: CGFloat = 60
    private let firstHeight: CGFloat = 75
    private let thirdHeight: CGFloat = 50
    private let columnWidth: CGFloat = 82

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            podiumColumn(row: rows[safe: 1], height: secondHeight, medal: "🥈", style: .base)
            podiumColumnFirst(row: rows[safe: 0], height: firstHeight, medal: "🥇")
            podiumColumn(row: rows[safe: 2], height: thirdHeight, medal: "🥉", style: .base)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }

    private func podiumColumnFirst(row: LeaderboardDisplayRow?, height: CGFloat, medal: String) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .top) {
                Text("👑")
                    .font(.system(size: 22))
                    .offset(y: -18)
                if let row {
                    AvatarView(
                        initials: row.initials,
                        color: ProfileAccentColor.swiftUIColor(hex: row.colorHex),
                        size: 54,
                        glow: true
                    )
                    .padding(.top, 8)
                } else {
                    Color.clear
                        .frame(width: 54, height: 54)
                }
            }
            .frame(height: 62)

            podiumCardBody(row: row, height: height, medal: medal, pointsColor: FitUpColors.Neon.yellow)
                .frame(width: columnWidth, height: height)
                .glassCard(.gold)
        }
    }

    private func podiumColumn(row: LeaderboardDisplayRow?, height: CGFloat, medal: String, style: GlassCardVariant) -> some View {
        VStack(spacing: 6) {
            if let row {
                AvatarView(
                    initials: row.initials,
                    color: ProfileAccentColor.swiftUIColor(hex: row.colorHex),
                    size: 44,
                    glow: false
                )
            } else {
                Color.clear.frame(width: 44, height: 44)
            }

            podiumCardBody(row: row, height: height, medal: medal, pointsColor: FitUpColors.Text.secondary)
                .frame(width: columnWidth, height: height)
                .glassCard(style)
        }
    }

    private func podiumCardBody(row: LeaderboardDisplayRow?, height: CGFloat, medal: String, pointsColor: Color) -> some View {
        VStack(spacing: 2) {
            Text(medal)
                .font(.system(size: height >= firstHeight - 1 ? 22 : 20))
            if let row {
                Text(shortName(row.displayName))
                    .font(FitUpFont.body(11, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.primary)
                    .lineLimit(1)
                Text(formatPoints(row.points))
                    .font(FitUpFont.body(10, weight: .semibold))
                    .foregroundStyle(pointsColor)
            } else {
                Text("—")
                    .font(FitUpFont.body(11, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 6)
    }

    private func shortName(_ full: String) -> String {
        full.split(separator: " ").first.map(String.init) ?? full
    }

    private func formatPoints(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        guard index >= 0, index < count else { return nil }
        return self[index]
    }
}
