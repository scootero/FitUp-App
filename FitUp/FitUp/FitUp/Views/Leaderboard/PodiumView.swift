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

    private let secondHeight: CGFloat = 60
    private let firstHeight: CGFloat = 75
    private let thirdHeight: CGFloat = 50
    private let columnWidth: CGFloat = 82

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if let second = rows[safe: 1] {
                podiumColumn(row: second, height: secondHeight, medal: "🥈", style: .base)
            }
            if let first = rows[safe: 0] {
                podiumColumnFirst(row: first, height: firstHeight, medal: "🥇")
            }
            if let third = rows[safe: 2] {
                podiumColumn(row: third, height: thirdHeight, medal: "🥉", style: .base)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 16)
    }

    private func podiumColumnFirst(row: LeaderboardDisplayRow, height: CGFloat, medal: String) -> some View {
        VStack(spacing: 6) {
            ZStack(alignment: .top) {
                Text("👑")
                    .font(.system(size: 22))
                    .offset(y: -18)
                AvatarView(
                    initials: row.initials,
                    color: ProfileAccentColor.swiftUIColor(hex: row.colorHex),
                    size: 54,
                    glow: true
                )
                .padding(.top, 8)
            }
            .frame(height: 62)

            podiumCardBody(row: row, height: height, medal: medal, pointsColor: FitUpColors.Neon.yellow)
                .frame(width: columnWidth, height: height)
                .glassCard(.gold)
        }
    }

    private func podiumColumn(row: LeaderboardDisplayRow, height: CGFloat, medal: String, style: GlassCardVariant) -> some View {
        VStack(spacing: 6) {
            AvatarView(
                initials: row.initials,
                color: ProfileAccentColor.swiftUIColor(hex: row.colorHex),
                size: 44,
                glow: false
            )

            podiumCardBody(row: row, height: height, medal: medal, pointsColor: FitUpColors.Text.secondary)
                .frame(width: columnWidth, height: height)
                .glassCard(style)
        }
    }

    private func podiumCardBody(row: LeaderboardDisplayRow, height: CGFloat, medal: String, pointsColor: Color) -> some View {
        VStack(spacing: 2) {
            Text(medal)
                .font(.system(size: height >= firstHeight - 1 ? 22 : 20))
            Text(shortName(row.displayName))
                .font(FitUpFont.body(11, weight: .bold))
                .foregroundStyle(FitUpColors.Text.primary)
                .lineLimit(1)
            Text(formatSteps(row.totalSteps))
                .font(FitUpFont.body(10, weight: .semibold))
                .foregroundStyle(pointsColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 6)
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
