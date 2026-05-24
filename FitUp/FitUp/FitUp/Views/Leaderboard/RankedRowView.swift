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

    private var rankColor: Color {
        row.isCurrentUser ? FitUpColors.Neon.cyan : FitUpColors.Text.tertiary.opacity(0.9)
    }

    var body: some View {
        Button {
            if !row.isCurrentUser {
                onTap()
            }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                Text("\(row.displayRank)")
                    .font(FitUpFont.mono(13, weight: .bold))
                    .foregroundStyle(rankColor)
                    .shadow(
                        color: row.isCurrentUser ? FitUpColors.Neon.cyan.opacity(0.45) : .clear,
                        radius: 6,
                        x: 0,
                        y: 0
                    )
                    .frame(width: 22, alignment: .center)

                avatar

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(row.displayName)
                            .font(FitUpFont.body(13, weight: .bold))
                            .foregroundStyle(row.isCurrentUser ? FitUpColors.Neon.cyan : HomePageStyle.offWhite)
                            .lineLimit(1)

                        if row.isCurrentUser {
                            Text("ME")
                                .font(FitUpFont.mono(9, weight: .bold))
                                .foregroundStyle(FitUpColors.Neon.pink)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background {
                                    Capsule()
                                        .fill(FitUpColors.Neon.pink.opacity(0.16))
                                        .overlay {
                                            Capsule()
                                                .strokeBorder(FitUpColors.Neon.pink.opacity(0.45), lineWidth: 1)
                                        }
                                }
                        }
                    }

                    Text("Weekly steps")
                        .font(FitUpFont.body(11, weight: .medium))
                        .foregroundStyle(HomePageStyle.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(formatSteps(row.totalSteps))
                    .font(FitUpFont.mono(13, weight: .bold))
                    .foregroundStyle(row.isCurrentUser ? FitUpColors.Neon.cyan : HomePageStyle.offWhite)
                    .shadow(
                        color: row.isCurrentUser ? FitUpColors.Neon.cyan.opacity(0.35) : .clear,
                        radius: 6,
                        x: 0,
                        y: 0
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .neonLeaderboardRow(isCurrentUser: row.isCurrentUser)
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

    private var avatar: some View {
        AvatarView(
            initials: row.initials,
            color: ProfileAccentColor.swiftUIColor(hex: row.colorHex),
            size: 38,
            glow: row.isCurrentUser
        )
        .overlay {
            if row.isCurrentUser {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                FitUpColors.Neon.cyan.opacity(0.9),
                                FitUpColors.Neon.pink.opacity(0.65),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: FitUpColors.Neon.pink.opacity(0.4), radius: 8, x: 0, y: 0)
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
