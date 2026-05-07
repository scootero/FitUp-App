//
//  RankedRowView.swift
//  FitUp
//
//  Slice 11 — Leaderboard rank 4+ row (maps JSX list rows).
//

import SwiftUI

struct LeaderboardUserRowVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = true
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = nextValue() || value
    }
}

struct RankedRowView: View {
    let row: LeaderboardDisplayRow
    let scrollGeo: GeometryProxy
    var onTap: () -> Void

    var body: some View {
        Button {
            if !row.isCurrentUser {
                onTap()
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Text("\(row.displayRank)")
                    .font(FitUpFont.body(13, weight: .bold))
                    .foregroundStyle(FitUpColors.Text.tertiary)
                    .frame(width: 20, alignment: .center)

                AvatarView(
                    initials: row.initials,
                    color: ProfileAccentColor.swiftUIColor(hex: row.colorHex),
                    size: 38,
                    glow: row.isCurrentUser
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(row.displayName + (row.isCurrentUser ? " (You)" : ""))
                        .font(FitUpFont.body(13, weight: .bold))
                        .foregroundStyle(row.isCurrentUser ? FitUpColors.Neon.cyan : FitUpColors.Text.primary)

                    Text("Weekly steps")
                        .font(FitUpFont.body(11, weight: .medium))
                        .foregroundStyle(FitUpColors.Text.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(formatSteps(row.totalSteps))
                    .font(FitUpFont.body(14, weight: .bold))
                    .foregroundStyle(row.isCurrentUser ? FitUpColors.Neon.cyan : FitUpColors.Text.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .glassCard(row.isCurrentUser ? .win : .base)
        .background {
            if row.isCurrentUser {
                GeometryReader { rowGeo in
                    Color.clear.preference(
                        key: LeaderboardUserRowVisibilityPreferenceKey.self,
                        value: scrollGeo.frame(in: .global).intersects(rowGeo.frame(in: .global))
                    )
                }
            }
        }
    }

    private func formatSteps(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        let formatted = f.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(formatted) steps"
    }
}
